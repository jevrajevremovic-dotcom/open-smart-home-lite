import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../application/device_command_service.dart';
import '../application/device_providers.dart';

/// Turns every light in [roomId] (or, with [wholeHome], the whole home)
/// on or off.
Future<void> setAllLights(
  BuildContext context,
  WidgetRef ref, {
  required bool on,
  String? roomId,
  bool wholeHome = false,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final devices = ref.read(homeSnapshotProvider).devices.values;
  final lights = [
    for (final d in devices)
      if (d.kind.isLight && !d.isAuxiliary && (wholeHome || d.roomId == roomId))
        d,
  ];
  try {
    await ref.read(deviceCommandServiceProvider)?.setLights(lights, on: on);
  } on AppFailure catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
  }
}

/// "All on / all off" for a room's lights.
class AllLightsButtons extends ConsumerWidget {
  const AllLightsButtons({super.key, this.roomId, this.wholeHome = false});

  final String? roomId;
  final bool wholeHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: const Key('allLightsOn'),
          onPressed: () => setAllLights(
            context,
            ref,
            on: true,
            roomId: roomId,
            wholeHome: wholeHome,
          ),
          icon: const Icon(Icons.lightbulb),
          label: Text(l10n.allLightsOn),
        ),
        OutlinedButton.icon(
          key: const Key('allLightsOff'),
          onPressed: () => setAllLights(
            context,
            ref,
            on: false,
            roomId: roomId,
            wholeHome: wholeHome,
          ),
          icon: const Icon(Icons.lightbulb_outline),
          label: Text(l10n.allLightsOff),
        ),
      ],
    );
  }
}

/// Opens or closes every blind and curtain in [roomId].
Future<void> setAllCovers(
  BuildContext context,
  WidgetRef ref, {
  required bool open,
  String? roomId,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final covers = [
    for (final d in ref.read(homeSnapshotProvider).devices.values)
      if (isGroupCover(d) && !d.isAuxiliary && d.roomId == roomId) d,
  ];
  try {
    await ref.read(deviceCommandServiceProvider)?.setCovers(covers, open: open);
  } on AppFailure catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
  }
}

/// "Open all / close all" for a room's blinds and curtains.
class AllCoversButtons extends ConsumerWidget {
  const AllCoversButtons({super.key, this.roomId});

  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: const Key('allCoversOpen'),
          onPressed: () =>
              setAllCovers(context, ref, open: true, roomId: roomId),
          icon: const Icon(Icons.blinds),
          label: Text(l10n.allCoversOpen),
        ),
        OutlinedButton.icon(
          key: const Key('allCoversClose'),
          onPressed: () =>
              setAllCovers(context, ref, open: false, roomId: roomId),
          icon: const Icon(Icons.blinds_closed),
          label: Text(l10n.allCoversClose),
        ),
      ],
    );
  }
}

/// Small sheet with the whole-home buttons (from the lights summary).
Future<void> showAllLightsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.allLightsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            const AllLightsButtons(wholeHome: true),
          ],
        ),
      ),
    );
