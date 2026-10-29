import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/status_widgets.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/presentation/device_actions.dart';
import '../devices/presentation/device_presentation.dart';
import 'house_check.dart';

/// "Before I leave" / "Good night": what is still on, open or unlocked,
/// fixed one by one or all at once.
class HouseCheckScreen extends ConsumerStatefulWidget {
  const HouseCheckScreen({super.key, this.mode});

  /// `null`: chosen by the time of day.
  final HouseCheckMode? mode;

  @override
  ConsumerState<HouseCheckScreen> createState() => _HouseCheckScreenState();
}

class _HouseCheckScreenState extends ConsumerState<HouseCheckScreen> {
  late HouseCheckMode _mode =
      widget.mode ?? HouseCheckMode.forTime(DateTime.now());
  bool _fixing = false;

  Future<void> _fixAll(List<HouseCheckItem> items) async {
    setState(() => _fixing = true);
    for (final item in items) {
      final fix = item.fix;
      if (fix == null || !mounted) continue;
      await runDeviceCommand(context, ref, item.device, fix);
    }
    if (mounted) setState(() => _fixing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(houseCheckProvider(_mode));
    final fixable = items.where((i) => i.fix != null).toList();
    final manual = items.any((i) => i.fix == null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.houseCheckTitle)),
      body: MockModeBanner(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<HouseCheckMode>(
                    key: const Key('houseCheckMode'),
                    segments: [
                      ButtonSegment(
                        value: HouseCheckMode.leaving,
                        icon: const Icon(Icons.directions_walk),
                        label: Text(l10n.houseCheckLeaving),
                      ),
                      ButtonSegment(
                        value: HouseCheckMode.night,
                        icon: const Icon(Icons.bedtime_outlined),
                        label: Text(l10n.houseCheckNight),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: items.isEmpty
                        ? _AllGood(
                            key: const Key('houseCheckAllGood'),
                            mode: _mode,
                          )
                        : Column(
                            key: const Key('houseCheckList'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.houseCheckCount(items.length),
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Column(
                                  children: [
                                    for (final item in items)
                                      _ItemTile(item: item, busy: _fixing),
                                  ],
                                ),
                              ),
                              if (manual) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.houseCheckManualHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (fixable.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  key: const Key('houseCheckFixAll'),
                                  onPressed: _fixing
                                      ? null
                                      : () => _fixAll(fixable),
                                  icon: _fixing
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.done_all),
                                  label: Text(
                                    _fixing
                                        ? l10n.houseCheckFixing
                                        : l10n.houseCheckFixAll(fixable.length),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllGood extends StatelessWidget {
  const _AllGood({super.key, required this.mode});

  final HouseCheckMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final ok = context.statusColors.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: ok.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              mode == HouseCheckMode.night
                  ? Icons.bedtime
                  : Icons.verified_outlined,
              size: 48,
              color: ok,
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.houseCheckAllGood, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            mode == HouseCheckMode.night
                ? l10n.houseCheckAllGoodNight
                : l10n.houseCheckAllGoodLeaving,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.busy});

  final HouseCheckItem item;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.statusColors;
    final d = item.device;
    final room = ref.watch(
      homeSnapshotProvider.select((s) => s.rooms[d.roomId]?.name),
    );
    final security = switch (item.problem) {
      HouseCheckProblem.unlocked ||
      HouseCheckProblem.garageOpen ||
      HouseCheckProblem.opened ||
      HouseCheckProblem.alarmOff => true,
      _ => false,
    };
    final status = houseCheckStatus(l10n, item.problem);
    final fix = item.fix;
    final action = switch (fix) {
      LockDevice() => l10n.houseCheckLock,
      CloseCover() => l10n.houseCheckClose,
      MediaPlayPause() => l10n.houseCheckPause,
      null => l10n.houseCheckOpenDevice,
      _ => l10n.houseCheckTurnOff,
    };
    final accent = security ? colors.warning : theme.colorScheme.primary;
    return ListTile(
      key: ValueKey('houseCheck-${d.id}'),
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: 0.14),
        foregroundColor: accent,
        child: Icon(DevicePresentation.icon(d)),
      ),
      title: Text(
        DevicePresentation.shortName(d.name, room),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [?room, status].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: security ? colors.warning : null),
      ),
      trailing: fix == null
          ? TextButton(
              key: ValueKey('houseCheckOpen-${d.id}'),
              onPressed: () => context.push(AppRoutes.device(d.id)),
              child: Text(action),
            )
          : FilledButton.tonal(
              key: ValueKey('houseCheckFix-${d.id}'),
              onPressed: busy
                  ? null
                  : () => runDeviceCommand(context, ref, d, fix),
              child: Text(action),
            ),
      onTap: () => context.push(AppRoutes.device(d.id)),
    );
  }
}

/// What is wrong, in a few words ("light on", "unlocked"…).
String houseCheckStatus(AppLocalizations l10n, HouseCheckProblem p) =>
    switch (p) {
      HouseCheckProblem.lightOn => l10n.houseCheckLightOn,
      HouseCheckProblem.mediaOn => l10n.houseCheckMediaOn,
      HouseCheckProblem.climateOn => l10n.houseCheckClimateOn,
      HouseCheckProblem.unlocked => l10n.houseCheckUnlocked,
      HouseCheckProblem.garageOpen => l10n.houseCheckGarageOpen,
      HouseCheckProblem.opened => l10n.houseCheckOpened,
      HouseCheckProblem.alarmOff => l10n.houseCheckAlarmOff,
    };
