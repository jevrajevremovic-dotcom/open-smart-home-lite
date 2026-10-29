import 'package:flutter/foundation.dart';

import '../automations/domain/simple_automation.dart';

/// Id of the presence simulation automation in Home Assistant (one per
/// home; the app replaces it when the settings change).
const presenceSimId = 'osh_presence_simulation';

/// When the simulation may run.
enum PresenceWhen {
  /// Nobody is home (`zone.home` counts 0 people).
  away,

  /// The alarm panel is armed away.
  alarm,

  /// Whenever the automation is on (the user turns it on when leaving).
  always,
}

/// Lights switched at random in the evening while nobody is home, so the
/// house looks lived in. Runs as an automation in Home Assistant, so it
/// works while this device is off.
@immutable
class PresenceSimulation {
  const PresenceSimulation({
    required this.lights,
    this.fromSunset = true,
    this.start = const ClockTime(18, 0),
    this.end = const ClockTime(23, 30),
    this.when = PresenceWhen.away,
    this.alarmId,
  });

  final List<String> lights;

  /// Start when the sun is below the horizon (else at [start]).
  final bool fromSunset;
  final ClockTime start;

  /// All the chosen lights go off at [end]; nothing happens after it.
  final ClockTime end;
  final PresenceWhen when;

  /// For [PresenceWhen.alarm].
  final String? alarmId;

  PresenceSimulation copyWith({
    List<String>? lights,
    bool? fromSunset,
    ClockTime? start,
    ClockTime? end,
    PresenceWhen? when,
    String? alarmId,
  }) => PresenceSimulation(
    lights: lights ?? this.lights,
    fromSunset: fromSunset ?? this.fromSunset,
    start: start ?? this.start,
    end: end ?? this.end,
    when: when ?? this.when,
    alarmId: alarmId ?? this.alarmId,
  );

  bool get valid =>
      lights.isNotEmpty && (when != PresenceWhen.alarm || alarmId != null);

  /// The automation (HA's automation config, as the UI editor saves it).
  /// Every 15 minutes within the window one random chosen light changes
  /// (on → off, off → on) after a random 0–10 minute wait; at [end] all
  /// go off. The settings are kept in `variables` so the app can show them
  /// again.
  Map<String, Object?> toAutomation({
    required String alias,
    required String description,
  }) {
    final endAt = end.toHa();
    return {
      'alias': alias,
      'description': description,
      'mode': 'single',
      'variables': {
        'osh_lights': lights,
        'osh_from_sunset': fromSunset,
        'osh_start': start.toHa(),
        'osh_end': endAt,
        'osh_when': when.name,
        'osh_alarm': ?alarmId,
      },
      'triggers': [
        {'trigger': 'time_pattern', 'minutes': '/15', 'id': 'tick'},
        {'trigger': 'time', 'at': endAt, 'id': 'end'},
      ],
      'conditions': [
        switch (when) {
          PresenceWhen.away => {
            'condition': 'numeric_state',
            'entity_id': 'zone.home',
            'below': 1,
          },
          PresenceWhen.alarm => {
            'condition': 'state',
            'entity_id': alarmId,
            'state': 'armed_away',
          },
          PresenceWhen.always => null,
        },
      ].nonNulls.toList(),
      'actions': [
        {
          'if': [
            {'condition': 'trigger', 'id': 'end'},
          ],
          'then': [
            {
              'action': 'light.turn_off',
              'target': {'entity_id': lights},
            },
          ],
          'else': [
            if (fromSunset) ...[
              {
                'condition': 'state',
                'entity_id': 'sun.sun',
                'state': 'below_horizon',
              },
              // Evening only: the sun is also down in the early morning.
              {'condition': 'time', 'after': '12:00:00', 'before': endAt},
            ] else
              {'condition': 'time', 'after': start.toHa(), 'before': endAt},
            {
              'delay': {'seconds': '{{ range(0, 600) | random }}'},
            },
            {
              'variables': {'osh_light': '{{ osh_lights | random }}'},
            },
            {
              'if': [
                {
                  'condition': 'template',
                  'value_template': "{{ is_state(osh_light, 'on') }}",
                },
              ],
              'then': [
                {
                  'action': 'light.turn_off',
                  'target': {'entity_id': '{{ osh_light }}'},
                },
              ],
              'else': [
                {
                  'action': 'light.turn_on',
                  'target': {'entity_id': '{{ osh_light }}'},
                },
              ],
            },
          ],
        },
      ],
    };
  }

  /// Settings back from a saved automation; `null` when it was not made by
  /// this app (or was edited beyond recognition).
  static PresenceSimulation? fromAutomation(Map<String, Object?> config) {
    final v = config['variables'];
    if (v is! Map) return null;
    final lights = v['osh_lights'];
    final end = ClockTime.parse(v['osh_end']);
    if (lights is! List || end == null) return null;
    return PresenceSimulation(
      lights: [
        for (final l in lights)
          if (l is String) l,
      ],
      fromSunset: v['osh_from_sunset'] != false,
      start: ClockTime.parse(v['osh_start']) ?? const ClockTime(18, 0),
      end: end,
      when: PresenceWhen.values.firstWhere(
        (w) => w.name == v['osh_when'],
        orElse: () => PresenceWhen.away,
      ),
      alarmId: v['osh_alarm'] is String ? v['osh_alarm']! as String : null,
    );
  }
}
