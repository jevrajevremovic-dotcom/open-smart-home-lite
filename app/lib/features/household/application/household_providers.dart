import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/value_list.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';

final _log = AppLogger('Household');

/// Household members (`person` entities), sorted by name.
final peopleIdsProvider = Provider<ValueList<String>>((ref) {
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final people =
      devices.values.where((d) => d.kind == DeviceKind.person).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ValueList([for (final p in people) p.id]);
});

/// A picture served by Home Assistant (e.g. a person's photo), loaded with
/// the session token. `null` when it cannot be loaded; callers then show
/// initials. Results stay cached for the session.
final entityImageProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  path,
) async {
  final api = ref.watch(homeAssistantApiProvider);
  if (api == null) return null;
  try {
    return await api.fetchImage(path);
  } on Object catch (e) {
    _log.info('Picture unavailable: ${e.runtimeType}');
    return null;
  }
});
