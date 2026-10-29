import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/smart_home_device.dart';
import '../data/zigbee_pairing.dart';

/// Services of the connected Home Assistant (`GET /api/services`).
final haServicesProvider = FutureProvider.autoDispose<Map<String, Set<String>>>(
  (ref) async {
    final api = ref.watch(homeAssistantApiProvider);
    if (api == null) return const {};
    return api.fetchServices();
  },
);

/// Zigbee backends found on the hub (empty = no Zigbee pairing possible).
final zigbeeBackendsProvider = FutureProvider.autoDispose<Set<ZigbeeBackend>>((
  ref,
) async {
  final services = await ref.watch(haServicesProvider.future);
  final devices = ref.read(homeSnapshotProvider).devices.values;
  return detectZigbeeBackends(services, devices);
});

/// How long the network stays open per start.
const pairingWindow = Duration(minutes: 3);

@immutable
class PairingState {
  const PairingState({
    this.backend,
    this.endsAt,
    this.busy = false,
    this.failure,
    this.knownDeviceIds = const {},
    this.knownEntityIds = const {},
  });

  final ZigbeeBackend? backend;

  /// While open: when the network closes again.
  final DateTime? endsAt;
  final bool busy;
  final AppFailure? failure;

  /// What existed when pairing started; anything else is new.
  final Set<String> knownDeviceIds;
  final Set<String> knownEntityIds;

  bool get open => endsAt != null && endsAt!.isAfter(DateTime.now());
  bool get started => knownEntityIds.isNotEmpty;
}

/// Opens the Zigbee network, closes it when time runs out, when the user
/// stops it, or when the screen is left – never left open by accident.
final pairingControllerProvider =
    NotifierProvider.autoDispose<PairingController, PairingState>(
      PairingController.new,
    );

class PairingController extends Notifier<PairingState> {
  Timer? _closeTimer;
  ZigbeePairing? _pairing;

  /// Mirrors the open session outside `state`, which cannot be read while
  /// the provider is being disposed.
  ZigbeeBackend? _openBackend;
  DateTime? _openUntil;

  bool get _isOpen =>
      _openBackend != null &&
      _openUntil != null &&
      _openUntil!.isAfter(DateTime.now());

  @override
  PairingState build() {
    ref.onDispose(() {
      _closeTimer?.cancel();
      if (_isOpen) {
        // Best effort; the hub also closes on its own when time is up.
        unawaited(
          _pairing?.permit(_openBackend!, Duration.zero).catchError((_) {}),
        );
        _openBackend = null;
      }
    });
    return const PairingState();
  }

  Future<void> start(ZigbeeBackend backend) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null || state.busy) return;
    final pairing = _pairing = ZigbeePairing(api);
    final devices = ref.read(homeSnapshotProvider).devices.values;
    // Keep the original baseline when extending an open session.
    final known = state.started
        ? (state.knownDeviceIds, state.knownEntityIds)
        : (
            {for (final d in devices) ?d.deviceId},
            {for (final d in devices) d.id},
          );
    state = PairingState(
      backend: backend,
      busy: true,
      knownDeviceIds: known.$1,
      knownEntityIds: known.$2,
    );
    try {
      await pairing.permit(backend, pairingWindow);
      _openBackend = backend;
      _openUntil = DateTime.now().add(pairingWindow);
      state = PairingState(
        backend: backend,
        endsAt: DateTime.now().add(pairingWindow),
        knownDeviceIds: known.$1,
        knownEntityIds: known.$2,
      );
      _closeTimer?.cancel();
      _closeTimer = Timer(pairingWindow, _expired);
    } on AppFailure catch (e) {
      state = PairingState(
        backend: backend,
        failure: e,
        knownDeviceIds: known.$1,
        knownEntityIds: known.$2,
      );
    }
  }

  void _expired() {
    _openBackend = null;
    state = PairingState(
      backend: state.backend,
      knownDeviceIds: state.knownDeviceIds,
      knownEntityIds: state.knownEntityIds,
    );
  }

  /// Called while the pairing screen is being disposed: closes the
  /// network without touching provider state (not allowed at that point).
  Future<void> closeIfOpen() async {
    final backend = _openBackend;
    if (!_isOpen || backend == null) return;
    _openBackend = null;
    _closeTimer?.cancel();
    try {
      await _pairing?.permit(backend, Duration.zero);
    } on Object {
      // The hub closes on its own when the window runs out.
    }
  }

  Future<void> stop() async {
    final backend = state.backend;
    _closeTimer?.cancel();
    _expired();
    if (backend == null) return;
    try {
      await _pairing?.permit(backend, Duration.zero);
    } on AppFailure catch (e) {
      state = PairingState(
        backend: backend,
        failure: e,
        knownDeviceIds: state.knownDeviceIds,
        knownEntityIds: state.knownEntityIds,
      );
    }
  }
}

/// A device that joined during this pairing session.
@immutable
class NewDevice {
  const NewDevice({
    required this.key,
    required this.haDeviceId,
    required this.primary,
    required this.entityIds,
  });

  final String key;
  final String? haDeviceId;

  /// The main entity (shown with its name and icon).
  final SmartHomeDevice primary;
  final List<String> entityIds;

  @override
  bool operator ==(Object other) =>
      other is NewDevice &&
      other.key == key &&
      other.primary == primary &&
      listEquals(other.entityIds, entityIds);

  @override
  int get hashCode => Object.hash(key, primary, Object.hashAll(entityIds));
}

/// New devices since pairing started, grouped by Home Assistant device.
final newDevicesProvider = Provider.autoDispose<List<NewDevice>>((ref) {
  final pairing = ref.watch(pairingControllerProvider);
  if (!pairing.started) return const [];
  final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
  final groups = <String, List<SmartHomeDevice>>{};
  for (final d in devices.values) {
    if (pairing.knownEntityIds.contains(d.id)) continue;
    if (d.deviceId != null && pairing.knownDeviceIds.contains(d.deviceId)) {
      continue;
    }
    groups.putIfAbsent(d.deviceId ?? d.id, () => []).add(d);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      () {
        final sorted = [...value]
          ..sort((a, b) {
            if (a.isAuxiliary != b.isAuxiliary) return a.isAuxiliary ? 1 : -1;
            return a.id.compareTo(b.id);
          });
        return NewDevice(
          key: key,
          haDeviceId: sorted.first.deviceId,
          primary: sorted.first,
          entityIds: [for (final d in sorted) d.id],
        );
      }(),
  ];
});
