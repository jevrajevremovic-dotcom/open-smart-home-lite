import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/value_list.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';

/// Household members (`person` devices), sorted by name.
final peopleIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final people =
      devices.values.where((d) => d.kind == DeviceKind.person).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final p in people) p.id]);
});

/// A device's picture (a person's photo, album art) by its path. No
/// backend serves pictures yet, so it is always `null` and callers show
/// initials or an icon.
final entityImageProvider = FutureProvider.family<Uint8List?, String>(
  (ref, path) async => null,
);
