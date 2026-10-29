import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/storage/app_preferences.dart';
import '../authentication/application/session_controller.dart';
import '../devices/application/device_command_service.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_command.dart';
import '../devices/domain/device_kind.dart';
import '../household/application/household_providers.dart';
import '../household/family_messages.dart';
import 'vacation.dart' show vacationThermostats;

/// What "I'm coming home" does, chosen once on this phone.
@immutable
class ComingHome {
  const ComingHome({
    this.personId,
    this.routineId,
    this.temperature,
    this.announce = true,
  });

  factory ComingHome.fromJson(Map<String, Object?>? json) => ComingHome(
    personId: json?['personId'] as String?,
    routineId: json?['routineId'] as String?,
    temperature: (json?['temperature'] as num?)?.toDouble(),
    announce: json?['announce'] != false,
  );

  /// Who is coming (a `person`), for the household message.
  final String? personId;

  /// A scene or script to run (hall light, music…).
  final String? routineId;

  /// Heating to this, on every thermostat; `null` leaves it.
  final double? temperature;

  /// A household message: the wall panel and the others see it.
  final bool announce;

  bool get doesSomething =>
      routineId != null || temperature != null || announce;

  ComingHome copyWith({
    String? personId,
    String? routineId,
    bool clearRoutine = false,
    double? temperature,
    bool clearTemperature = false,
    bool? announce,
  }) => ComingHome(
    personId: personId ?? this.personId,
    routineId: clearRoutine ? null : routineId ?? this.routineId,
    temperature: clearTemperature ? null : temperature ?? this.temperature,
    announce: announce ?? this.announce,
  );

  Map<String, Object?> toJson() => {
    'personId': ?personId,
    'routineId': ?routineId,
    'temperature': ?temperature,
    'announce': announce,
  };
}

class ComingHomeController extends Notifier<ComingHome> {
  static const _key = 'comingHome';

  @override
  ComingHome build() =>
      ComingHome.fromJson(ref.watch(appPreferencesProvider).readJson(_key));

  Future<void> update(ComingHome Function(ComingHome) change) async {
    state = change(state);
    await ref.read(appPreferencesProvider).writeJson(_key, state.toJson());
  }

  /// Does it all; throws [AppFailure] when Home Assistant is not reachable.
  Future<void> run(AppLocalizations l10n) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) {
      throw const AppFailure(FailureKind.network, debugMessage: 'no server');
    }
    final c = state;
    final routine = c.routineId == null
        ? null
        : ref.read(deviceProvider(c.routineId!));
    final service = ref.read(deviceCommandServiceProvider);
    if (routine != null && service != null) {
      await service.execute(routine, const Activate());
    }
    final temperature = c.temperature;
    if (temperature != null) {
      final devices = ref.read(homeSnapshotProvider).devices.values;
      for (final d in vacationThermostats(devices)) {
        await api.callService(
          'climate',
          'set_temperature',
          data: {'entity_id': d.id, 'temperature': temperature},
        );
      }
    }
    if (c.announce) {
      final name = c.personId == null
          ? null
          : ref.read(deviceProvider(c.personId!))?.name;
      await api.callService(
        'persistent_notification',
        'create',
        data: {
          'notification_id':
              '${FamilyMessage.prefix}${FamilyMessage.everyone}_'
              '${DateTime.now().millisecondsSinceEpoch}',
          'message': name == null
              ? l10n.comingHomeMessageNoName
              : l10n.comingHomeMessage(name),
        },
      );
    }
  }
}

final comingHomeProvider = NotifierProvider<ComingHomeController, ComingHome>(
  ComingHomeController.new,
);

/// Runs "I'm coming home" and says so in a snack bar.
Future<void> runComingHome(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await ref.read(comingHomeProvider.notifier).run(l10n);
    messenger?.showSnackBar(SnackBar(content: Text(l10n.comingHomeDone)));
  } on AppFailure catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(failureMessage(l10n, e))));
  }
}

Future<void> showComingHome(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _ComingHomeSheet(),
);

class _ComingHomeSheet extends ConsumerWidget {
  const _ComingHomeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = ref.watch(comingHomeProvider);
    final controller = ref.read(comingHomeProvider.notifier);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final people = ref.watch(peopleIdsProvider);
    final routines = [
      for (final d in devices.values)
        if ((d.kind == DeviceKind.scene || d.kind == DeviceKind.script) &&
            !d.isAuxiliary)
          d,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final hasThermostats = vacationThermostats(devices.values).isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        key: const Key('comingHomeSheet'),
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(l10n.comingHomeTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l10n.comingHomeHint),
          const SizedBox(height: 16),
          if (people.isNotEmpty)
            DropdownButtonFormField<String?>(
              key: const Key('comingHomePerson'),
              initialValue: people.contains(c.personId) ? c.personId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.comingHomeWho),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.comingHomeNoOne),
                ),
                for (final id in people)
                  DropdownMenuItem(
                    value: id,
                    child: Text(devices[id]?.name ?? id),
                  ),
              ],
              onChanged: (v) => controller.update(
                (s) => ComingHome(
                  personId: v,
                  routineId: s.routineId,
                  temperature: s.temperature,
                  announce: s.announce,
                ),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('comingHomeRoutine'),
            initialValue: devices.containsKey(c.routineId) ? c.routineId : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.comingHomeRoutine),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.comingHomeNone)),
              for (final r in routines)
                DropdownMenuItem(value: r.id, child: Text(r.name)),
            ],
            onChanged: (v) => controller.update(
              (s) => s.copyWith(routineId: v, clearRoutine: v == null),
            ),
          ),
          if (hasThermostats) ...[
            SwitchListTile(
              key: const Key('comingHomeHeating'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                c.temperature == null
                    ? l10n.comingHomeHeatingOff
                    : l10n.comingHomeHeating(c.temperature!.toStringAsFixed(0)),
              ),
              value: c.temperature != null,
              onChanged: (v) => controller.update(
                (s) => v
                    ? s.copyWith(temperature: 21)
                    : s.copyWith(clearTemperature: true),
              ),
            ),
            if (c.temperature != null)
              Slider(
                value: c.temperature!.clamp(16, 26),
                min: 16,
                max: 26,
                divisions: 10,
                label: '${c.temperature!.toStringAsFixed(0)} °C',
                onChanged: (v) =>
                    controller.update((s) => s.copyWith(temperature: v)),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.comingHomeAnnounce),
            subtitle: Text(l10n.comingHomeAnnounceHint),
            value: c.announce,
            onChanged: (v) => controller.update((s) => s.copyWith(announce: v)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('comingHomeRun'),
            onPressed: c.doesSomething
                ? () async {
                    final navigator = Navigator.of(context);
                    await runComingHome(context, ref);
                    navigator.pop();
                  }
                : null,
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(l10n.comingHomeRun),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.comingHomeShortcutHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
