import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../../integrations/home_assistant/energy/ha_energy.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/data/home_state_repository.dart';
import '../data/energy_repository.dart';
import '../data/tariff.dart';

final energyRepositoryProvider = Provider<EnergyRepository?>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws == null ? null : EnergyRepository(ws);
});

/// Statistics are fetched live (they are not part of the offline cache).
class EnergyUnavailableOffline implements Exception {
  const EnergyUnavailableOffline();
}

/// `null` = Energy is not configured in Home Assistant.
final energyPrefsProvider = FutureProvider<EnergyPrefs?>((ref) async {
  final repository = ref.watch(energyRepositoryProvider);
  final live = ref.watch(syncStatusProvider) == SyncStatus.live;
  if (repository == null || !live) throw const EnergyUnavailableOffline();
  return repository.loadPrefs();
});

class EnergyRangeController extends Notifier<EnergyRange> {
  @override
  EnergyRange build() => EnergyRange.today;

  void select(EnergyRange range) => state = range;
}

final energyRangeProvider =
    NotifierProvider<EnergyRangeController, EnergyRange>(
      EnergyRangeController.new,
    );

final energyReportProvider = FutureProvider<EnergyReport?>((ref) async {
  final prefs = await ref.watch(energyPrefsProvider.future);
  final repository = ref.watch(energyRepositoryProvider);
  if (prefs == null || repository == null) return null;
  final range = ref.watch(energyRangeProvider);
  final devices = ref.read(homeSnapshotProvider).devices;
  return repository.loadReport(
    prefs,
    range,
    now: DateTime.now(),
    // Statistic ids of devices are usually their entity ids.
    nameOf: (id) => devices[id]?.name ?? id,
    lowHours: ref.watch(tariffProvider.select((t) => t?.low?.hours)),
  );
});

/// Total consumption of the previous full period (yesterday, last week,
/// last month), shown next to the current one for comparison.
final previousConsumptionProvider = FutureProvider<double?>((ref) async {
  final prefs = await ref.watch(energyPrefsProvider.future);
  final repository = ref.watch(energyRepositoryProvider);
  if (prefs == null || repository == null || !prefs.hasElectricity) {
    return null;
  }
  final range = ref.watch(energyRangeProvider);
  final (start, _) = range.bounds(DateTime.now());
  final previous = await repository.loadReport(
    prefs,
    range,
    now: start.subtract(const Duration(minutes: 1)),
  );
  return previous.consumption;
});

class TariffController extends Notifier<Tariff?> {
  String? get _key {
    final profile = ref.read(activeProfileProvider);
    return profile == null ? null : 'energy.tariff::${profile.id}';
  }

  @override
  Tariff? build() {
    ref.watch(activeProfileProvider);
    final key = _key;
    return key == null
        ? null
        : Tariff.tryFromJson(ref.read(appPreferencesProvider).readJson(key));
  }

  Future<void> save(Tariff? tariff) async {
    final key = _key;
    if (key == null) return;
    state = tariff;
    await ref.read(appPreferencesProvider).writeJson(key, tariff?.toJson());
  }
}

final tariffProvider = NotifierProvider<TariffController, Tariff?>(
  TariffController.new,
);
