import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/l10n.dart';
import '../devices/application/device_providers.dart';
import '../devices/domain/device_kind.dart';
import '../devices/domain/smart_home_device.dart';
import '../household/family_messages.dart';
import '../ha_notify/ha_push.dart';

/// One automation per appliance (its power sensor), shared by the
/// household: every phone that turns it on is added to its recipients.
String applianceDoneId(String powerId) => 'osh_done_${haSlug(powerId)}';

/// Power above the threshold this long counts as "running".
const applianceStartMinutes = 2;

/// "The washing machine is done": when the appliance's power has been
/// above [thresholdWatts] and then stays below it for [doneMinutes], Home
/// Assistant tells the chosen phones and, with [household], leaves a
/// message for everyone (the app and the wall tablet show it).
@immutable
class ApplianceDone {
  const ApplianceDone({
    required this.powerId,
    required this.name,
    this.thresholdWatts = 5,
    this.doneMinutes = 3,
    this.notify = const [],
    this.household = true,
  });

  /// Back from the saved automation (its `variables`), or null.
  static ApplianceDone? fromAutomation(Map<String, Object?> config) {
    final v = config['variables'];
    if (v is! Map) return null;
    final power = v['osh_power'];
    final name = v['osh_name'];
    final threshold = v['osh_threshold'];
    final minutes = v['osh_minutes'];
    if (power is! String || name is! String) return null;
    return ApplianceDone(
      powerId: power,
      name: name,
      thresholdWatts: threshold is num ? threshold.toInt() : 5,
      doneMinutes: minutes is num ? minutes.toInt() : 3,
      notify: [
        if (v['osh_notify'] case final List<Object?> list)
          for (final s in list)
            if (s is String) s,
      ],
      household: v['osh_household'] != false,
    );
  }

  final String powerId;
  final String name;
  final int thresholdWatts;
  final int doneMinutes;

  /// `notify.mobile_app_…` services of the phones to tell.
  final List<String> notify;
  final bool household;

  String get id => applianceDoneId(powerId);

  bool get hasRecipient => notify.isNotEmpty || household;

  ApplianceDone copyWith({
    String? name,
    int? thresholdWatts,
    int? doneMinutes,
    List<String>? notify,
    bool? household,
  }) => ApplianceDone(
    powerId: powerId,
    name: name ?? this.name,
    thresholdWatts: thresholdWatts ?? this.thresholdWatts,
    doneMinutes: doneMinutes ?? this.doneMinutes,
    notify: notify ?? this.notify,
    household: household ?? this.household,
  );

  /// The automation: a `numeric_state` trigger (running), then
  /// `wait_for_trigger` for the drop (done), both documented Home
  /// Assistant automation features. Waits at most 12 hours.
  Map<String, Object?> automation(AppLocalizations l10n) {
    final message = l10n.applianceDoneMessage(name);
    return {
      'alias': l10n.applianceDoneAlias(name),
      'description': 'Open Smart Home',
      'mode': 'single',
      'variables': {
        'osh_power': powerId,
        'osh_name': name,
        'osh_threshold': thresholdWatts,
        'osh_minutes': doneMinutes,
        'osh_notify': notify,
        'osh_household': household,
      },
      'triggers': [
        {
          'trigger': 'numeric_state',
          'entity_id': powerId,
          'above': thresholdWatts,
          'for': {'minutes': applianceStartMinutes},
        },
      ],
      'conditions': <Object>[],
      'actions': [
        {
          'wait_for_trigger': [
            {
              'trigger': 'numeric_state',
              'entity_id': powerId,
              'below': thresholdWatts,
              'for': {'minutes': doneMinutes},
            },
          ],
          'timeout': {'hours': 12},
          'continue_on_timeout': false,
        },
        for (final service in notify)
          {
            'action': service,
            // One phone that is gone must not stop the others.
            'continue_on_error': true,
            'data': {
              'title': l10n.applianceDoneTitle,
              'message': message,
              'data': {'tag': id, 'entity_id': powerId},
            },
          },
        if (household)
          {
            'action': 'persistent_notification.create',
            'data': {
              // A household message for everyone (see FamilyMessage).
              'notification_id':
                  '${FamilyMessage.prefix}${FamilyMessage.everyone}_'
                  '{{ now().timestamp() | int }}',
              'message': message,
            },
          },
      ],
    };
  }
}

/// The power sensor that tells whether [device] runs: itself, or the
/// power sensor of the same physical device (a smart plug's).
final appliancePowerProvider = Provider.family<SmartHomeDevice?, String>((
  ref,
  deviceId,
) {
  final device = ref.watch(deviceProvider(deviceId));
  if (device == null) return null;
  if (device.kind == DeviceKind.powerMeter) return device;
  final physical = device.deviceId;
  if (physical == null) return null;
  return ref.watch(
    homeSnapshotProvider.select((s) {
      for (final d in s.devices.values) {
        if (d.deviceId == physical && d.kind == DeviceKind.powerMeter) {
          return d;
        }
      }
      return null;
    }),
  );
});

/// Whether the appliance's automation exists (its entity carries the id).
final applianceDoneSetProvider = Provider.family<bool, String>((ref, powerId) {
  final id = applianceDoneId(powerId);
  return ref.watch(
    homeSnapshotProvider.select(
      (s) => s.devices.values.any((d) => d.metadata.configId == id),
    ),
  );
});
