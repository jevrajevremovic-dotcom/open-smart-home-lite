import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/l10n.dart';
import '../../app/router/app_router.dart';
import '../../core/utils/value_list.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../kiosk/application/kiosk_controller.dart';

/// Stuffy from this much CO₂ (ppm): the usual "time to air the room" line.
const airCo2Limit = 1200;

/// Damp from this relative humidity (%): mould likes it.
const airHumidityLimit = 70;

/// A room that needs fresh air, and why.
typedef AirAdvice = ({String deviceId, String place, bool co2, int value});

/// Rooms to air now, by what their own sensors say (nothing is guessed).
final airAdviceProvider = Provider<ValueList<AirAdvice>>((ref) {
  final snapshot = ref.watch(homeSnapshotProvider);
  final out = <AirAdvice>[];
  for (final d in snapshot.devices.values) {
    final v = d.state.numericValue;
    if (v == null || !d.available) continue;
    final co2 =
        d.kind == DeviceKind.airQualitySensor &&
        d.metadata.haDeviceClass == 'carbon_dioxide' &&
        v >= airCo2Limit;
    final damp = d.kind == DeviceKind.humiditySensor && v >= airHumidityLimit;
    if (!co2 && !damp) continue;
    out.add((
      deviceId: d.id,
      place: snapshot.rooms[d.roomId]?.name ?? d.name,
      co2: co2,
      value: v.round(),
    ));
  }
  out.sort((a, b) => a.place.compareTo(b.place));
  return ValueList(out);
});

/// "Air the bedroom": one line per room, on Home (phone and wall panel).
class AirAdviceCard extends ConsumerWidget {
  const AirAdviceCard({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advice = ref.watch(airAdviceProvider);
    if (advice.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Card(
        key: const Key('airAdvice'),
        elevation: 0,
        color: scheme.tertiaryContainer,
        child: Column(
          children: [
            for (final a in advice)
              ListTile(
                leading: Icon(Icons.air, color: scheme.onTertiaryContainer),
                title: Text(
                  l10n.airAdviceTitle(a.place),
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
                subtitle: Text(
                  a.co2
                      ? l10n.airAdviceCo2(a.value)
                      : l10n.airAdviceHumidity(a.value),
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
                onTap: () => context.push(
                  AppRoutes.device(
                    a.deviceId,
                    kiosk: ref.read(kioskActiveProvider),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
