import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/value_list.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';

/// The media player to show as "now playing": one that is playing, else
/// one that is paused; `null` when nothing is playing.
final nowPlayingIdProvider = Provider<String?>((ref) {
  final players = ref.watch(
    homeSnapshotProvider.select(
      (s) => ValueList(
        [
          for (final d in s.devices.values)
            if (d.available &&
                (d.kind == DeviceKind.mediaPlayer ||
                    d.kind == DeviceKind.speaker ||
                    d.kind == DeviceKind.television))
              (d.id, d.state.raw),
        ]..sort((a, b) => a.$1.compareTo(b.$1)),
      ),
    ),
  );
  for (final state in ['playing', 'paused']) {
    for (final (id, s) in players) {
      if (s == state) return id;
    }
  }
  return null;
});

/// All media players (speakers, TVs, …), sorted by name.
final mediaPlayerIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final players =
      devices.values
          .where(
            (d) =>
                d.kind == DeviceKind.mediaPlayer ||
                d.kind == DeviceKind.speaker ||
                d.kind == DeviceKind.television,
          )
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final p in players) p.id]);
});
