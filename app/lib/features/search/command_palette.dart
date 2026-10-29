import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/smart_home_device.dart';
import '../devices/presentation/device_actions.dart';
import '../devices/presentation/device_presentation.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../restricted/application/restricted_mode.dart';

/// Lower case without Serbian diacritics, so "kuh" finds "Kuhinja" and
/// "cas" finds "Čas".
String searchFold(String text) {
  const map = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'dj'};
  return text.toLowerCase().split('').map((c) => map[c] ?? c).join();
}

/// One hit: a room, or a device (scenes included).
typedef PaletteHit = ({String? roomId, SmartHomeDevice? device, String name});

/// What [query] finds, rooms first, then scenes, then devices; every word
/// must match the name (or, for a device, its room's name).
List<PaletteHit> paletteSearch(
  String query,
  Map<String, Room> rooms,
  Iterable<SmartHomeDevice> devices,
) {
  final words = searchFold(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  bool matches(String text) {
    final t = searchFold(text);
    return words.every(t.contains);
  }

  final roomHits = [
    for (final r in rooms.values)
      if (matches(r.name)) (roomId: r.id, device: null, name: r.name),
  ]..sort((a, b) => a.name.compareTo(b.name));
  final deviceHits =
      [
        for (final d in devices)
          if (matches('${d.name} ${rooms[d.roomId]?.name ?? ''}'))
            (roomId: null, device: d, name: d.name),
      ]..sort((a, b) {
        final ra = a.device.kind.isRoutine ? 0 : 1;
        final rb = b.device.kind.isRoutine ? 0 : 1;
        return ra != rb ? ra - rb : a.name.compareTo(b.name);
      });
  return [...roomHits, ...deviceHits].take(12).toList();
}

/// Ctrl+K (⌘K on a Mac) anywhere once signed in: find a room or device and
/// open or switch it with Enter.
class CommandPaletteHost extends ConsumerStatefulWidget {
  const CommandPaletteHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CommandPaletteHost> createState() => _CommandPaletteHostState();
}

class _CommandPaletteHostState extends ConsumerState<CommandPaletteHost> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.keyK ||
        !(keyboard.isControlPressed || keyboard.isMetaPressed)) {
      return false;
    }
    if (_open || ref.read(activeProfileProvider) == null) return false;
    final context = ref
        .read(routerProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context == null) return false;
    _open = true;
    unawaited(showCommandPalette(context).whenComplete(() => _open = false));
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showCommandPalette(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _Palette());

class _Palette extends ConsumerStatefulWidget {
  const _Palette();

  @override
  ConsumerState<_Palette> createState() => _PaletteState();
}

class _PaletteState extends ConsumerState<_Palette> {
  String _query = '';
  int _selected = 0;

  Future<void> _go(PaletteHit hit, {bool open = false}) async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final kiosk = ref.read(kioskActiveProvider);
    final d = hit.device;
    if (d == null) {
      navigator.pop();
      unawaited(router.push(AppRoutes.room(hit.roomId, kiosk: kiosk)));
      return;
    }
    // Enter does the obvious thing: a scene runs, a light toggles;
    // anything else (or a tap on the name) opens.
    final DeviceCommand? command = open
        ? null
        : DevicePresentation.hasQuickActivate(d)
        ? const Activate()
        : DevicePresentation.hasQuickToggle(d)
        ? const Toggle()
        : null;
    if (command == null) {
      navigator.pop();
      unawaited(router.push(AppRoutes.device(d.id, kiosk: kiosk)));
      return;
    }
    if (await runDeviceCommand(context, ref, d, command)) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final snapshot = ref.watch(homeSnapshotProvider);
    final visible = ref.watch(visibleDeviceIdsProvider);
    final restricted = ref.watch(restrictedModeProvider);
    final shown = visible.toSet();
    final hits = paletteSearch(_query, snapshot.rooms, [
      // Devices as the lists show them, and every scene and script.
      for (final d in snapshot.devices.values)
        if ((shown.contains(d.id) || d.kind.isRoutine) &&
            !d.isAuxiliary &&
            !restricted.hides(d))
          d,
    ]);
    final selected = hits.isEmpty ? 0 : _selected.clamp(0, hits.length - 1);
    return Dialog(
      key: const Key('commandPalette'),
      alignment: const Alignment(0, -0.6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Focus(
                // Arrows move the choice; Enter does it.
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    setState(() => _selected = selected + 1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    setState(() => _selected = selected > 0 ? selected - 1 : 0);
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  key: const Key('paletteField'),
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.paletteHint,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() {
                    _query = v;
                    _selected = 0;
                  }),
                  onSubmitted: (_) {
                    if (hits.isNotEmpty) unawaited(_go(hits[selected]));
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: hits.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _query.trim().isEmpty
                            ? l10n.paletteEmpty
                            : l10n.paletteNothing,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      children: [
                        for (final (i, hit) in hits.indexed)
                          _HitTile(
                            hit: hit,
                            selected: i == selected,
                            roomName: hit.device == null
                                ? null
                                : snapshot.rooms[hit.device!.roomId]?.name,
                            onTap: () => _go(hit, open: true),
                            onAction: () => _go(hit),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Text(
                l10n.paletteKeys,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({
    required this.hit,
    required this.selected,
    required this.roomName,
    required this.onTap,
    required this.onAction,
  });

  final PaletteHit hit;
  final bool selected;
  final String? roomName;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = hit.device;
    return ListTile(
      key: ValueKey('paletteHit-${d?.id ?? hit.roomId}'),
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      leading: Icon(
        d == null ? Icons.meeting_room_outlined : DevicePresentation.icon(d),
      ),
      title: Text(hit.name),
      subtitle: Text(
        d == null
            ? l10n.paletteRoom
            : [?roomName, DevicePresentation.status(l10n, d)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: d == null
          ? const Icon(Icons.chevron_right)
          : DevicePresentation.hasQuickActivate(d)
          ? IconButton(
              tooltip: l10n.activate,
              onPressed: onAction,
              icon: const Icon(Icons.play_arrow),
            )
          : DevicePresentation.hasQuickToggle(d)
          ? Switch(value: d.state.isOn ?? false, onChanged: (_) => onAction())
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
