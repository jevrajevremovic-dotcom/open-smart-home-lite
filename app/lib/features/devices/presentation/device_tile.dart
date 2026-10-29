import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../kiosk/application/kiosk_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../application/device_providers.dart';
import '../data/home_state_repository.dart';
import '../domain/capability.dart';
import '../domain/device_command.dart';
import '../domain/device_kind.dart';
import '../domain/smart_home_device.dart';
import 'big_slider.dart';
import 'device_actions.dart';
import 'device_detail_screen.dart' show deviceHeroTag;
import 'device_sheet.dart';
import 'device_presentation.dart';

/// Compact card for one device. Watches only its own device, so a state
/// change elsewhere in the home does not rebuild it.
class DeviceTile extends ConsumerWidget {
  const DeviceTile({
    super.key,
    required this.deviceId,
    this.withoutRoomName = false,
    this.group,
  });

  final String deviceId;

  /// The card stands for a whole physical device ([deviceId] is its main
  /// part): its name, how many parts, and a tap opens all of them.
  final ({String id, String name, int count})? group;

  /// Inside a room's own screen the room name in front is redundant.
  final bool withoutRoomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProvider(deviceId));
    if (device == null) return const SizedBox.shrink();
    final roomName = withoutRoomName
        ? ref.watch(
            homeSnapshotProvider.select((s) => s.rooms[device.roomId]?.name),
          )
        : null;
    return _DeviceCard(
      device: device,
      name: DevicePresentation.shortName(group?.name ?? device.name, roomName),
      group: group,
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  const _DeviceCard({required this.device, required this.name, this.group});

  final SmartHomeDevice device;
  final String name;
  final ({String id, String name, int count})? group;

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _busy = false;

  /// Brightness while the in-card slider is being dragged.
  double? _dragging;

  /// The tenth the swipe was last in (a tick when it changes).
  int? _swipeStep;

  Future<void> _run(DeviceCommand command) async {
    setState(() => _busy = true);
    await runDeviceCommand(context, ref, widget.device, command);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = context.statusColors;
    final accents = context.deviceAccents;
    final tone = DevicePresentation.tone(device);
    final statusText = DevicePresentation.status(l10n, device);

    // Active devices take their accent colour; alerts take warning/critical.
    final swatch = switch (tone) {
      DeviceTone.active => DevicePresentation.swatch(accents, device),
      DeviceTone.warning => accents.warning,
      DeviceTone.critical => accents.critical,
      _ => null,
    };
    final fill = swatch?.container ?? scheme.surfaceContainerLow;
    final onFill = swatch?.onContainer ?? scheme.onSurface;
    final onFillMuted = swatch?.onContainer ?? scheme.onSurfaceVariant;
    final iconColor =
        swatch?.icon ??
        (tone == DeviceTone.unavailable
            ? status.unavailable
            : scheme.onSurfaceVariant);
    final disc = swatch != null ? accents.iconDisc : scheme.surfaceContainer;

    final live = ref.watch(syncStatusProvider) == SyncStatus.live;
    // A light that is on and dims: its slider sits in the card.
    final dims =
        device.available &&
        device.kind.isLight &&
        device.supports(Capability.brightness);
    final dimmableOn = dims && (device.state.isOn == true || _dragging != null);
    // Sideways across the whole card sets the brightness (on a phone; the
    // wall panel swipes between rooms instead).
    final swipe =
        dims &&
        live &&
        !_busy &&
        widget.group == null &&
        !ref.watch(kioskActiveProvider);
    final Widget? action = !device.available
        ? null
        : DevicePresentation.hasQuickToggle(device)
        ? Switch(
            value: device.state.isOn ?? false,
            activeTrackColor: swatch?.icon,
            onChanged: _busy || !live
                ? null
                : (on) => _run(on ? const TurnOn() : const TurnOff()),
          )
        : DevicePresentation.hasQuickActivate(device)
        ? IconButton.filledTonal(
            tooltip: l10n.activate,
            onPressed: _busy || !live ? null : () => _run(const Activate()),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
          )
        : null;

    return Semantics(
      label: '${widget.name}, $statusText',
      button: true,
      excludeSemantics: action == null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppTheme.tileRadius),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppTheme.tileRadius),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            key: ValueKey('tileSwipe-${device.id}'),
            onHorizontalDragStart: swipe
                ? (_) => setState(() {
                    _dragging = device.state.isOn == true
                        ? (device.state.brightnessPercent ?? 0).toDouble()
                        : 0;
                    _swipeStep = (_dragging! / 10).floor();
                  })
                : null,
            onHorizontalDragUpdate: swipe
                ? (d) {
                    final width = context.size?.width ?? 160;
                    final v = ((_dragging ?? 0) + d.delta.dx / width * 100)
                        .clamp(0.0, 100.0);
                    final step = (v / 10).floor();
                    if (step != _swipeStep) {
                      _swipeStep = step;
                      unawaited(HapticFeedback.selectionClick());
                    }
                    setState(() => _dragging = v);
                  }
                : null,
            onHorizontalDragEnd: swipe
                ? (_) async {
                    final v = (_dragging ?? 0).round();
                    await _run(
                      v < 1 ? const TurnOff() : SetBrightness(v.clamp(1, 100)),
                    );
                    if (mounted) setState(() => _dragging = null);
                  }
                : null,
            child: InkWell(
              onTap: () {
                final kiosk = ref.read(kioskActiveProvider);
                if (widget.group != null) {
                  context.push(
                    AppRoutes.deviceGroup(widget.group!.id, kiosk: kiosk),
                  );
                } else if (kiosk || device.kind == DeviceKind.camera) {
                  context.push(AppRoutes.device(device.id, kiosk: kiosk));
                } else {
                  // The main controls in a sheet, without leaving the list.
                  showDeviceSheet(context, device.id);
                }
              },
              // A level to slide (light, blind, volume): the big slider;
              // anything else: its full screen.
              onLongPress: () {
                unawaited(HapticFeedback.mediumImpact());
                if (bigSliderFor(l10n, device) != null) {
                  showBigSlider(context, device.id);
                } else {
                  context.push(
                    AppRoutes.device(
                      device.id,
                      kiosk: ref.read(kioskActiveProvider),
                    ),
                  );
                }
              },
              child: Opacity(
                opacity: device.available ? 1 : 0.6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: deviceHeroTag(device.id),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: disc,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                DevicePresentation.icon(device),
                                color: iconColor,
                                size: 22,
                              ),
                            ),
                          ),
                          // The parts count gives way on a narrow card.
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: widget.group == null
                                  ? null
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _groupBadge(
                                        widget.group!,
                                        l10n,
                                        theme,
                                        disc,
                                        onFillMuted,
                                      ),
                                    ),
                            ),
                          ),
                          if (device.hasLowBattery)
                            Tooltip(
                              message: l10n.lowBattery,
                              child: Icon(
                                Icons.battery_alert,
                                color: swatch == accents.warning
                                    ? onFill
                                    : status.warning,
                                size: 20,
                              ),
                            ),
                          ?action,
                        ],
                      ),
                      const Spacer(),
                      Text(
                        widget.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: onFill,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (dimmableOn)
                        _BrightnessSlider(
                          key: ValueKey('tileBrightness-${device.id}'),
                          value:
                              (_dragging ??
                                      (device.state.brightnessPercent ?? 0)
                                          .toDouble())
                                  .clamp(0, 100),
                          color: swatch?.onContainer ?? scheme.primary,
                          track: swatch?.icon ?? scheme.outlineVariant,
                          enabled: live && !_busy,
                          onChanged: (v) => setState(() => _dragging = v),
                          onChangeEnd: (v) async {
                            await _run(SetBrightness(v.round().clamp(1, 100)));
                            if (mounted) setState(() => _dragging = null);
                          },
                        )
                      else
                        Row(
                          children: [
                            if (!device.available) ...[
                              Icon(Icons.cloud_off, size: 14, color: iconColor),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                statusText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: onFillMuted,
                                  fontWeight: tone == DeviceTone.critical
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupBadge(
    ({String id, String name, int count}) g,
    AppLocalizations l10n,
    ThemeData theme,
    Color disc,
    Color foreground,
  ) => Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Tooltip(
      message: l10n.kioskBundleCount(g.count),
      child: Container(
        key: ValueKey('tileGroupCount-${g.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: disc,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${g.count}',
          style: theme.textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    ),
  );
}

/// Brightness inside a light's card: a thick track and the percentage.
class _BrightnessSlider extends StatelessWidget {
  const _BrightnessSlider({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final Color color;
  final Color track;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: color,
              inactiveTrackColor: track.withValues(alpha: 0.35),
              thumbColor: color,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: value,
              max: 100,
              padding: EdgeInsets.zero,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '${value.round()} %',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    ],
  );
}
