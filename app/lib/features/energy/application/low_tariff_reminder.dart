import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../ha_notify/ha_push.dart';
import '../data/tariff.dart';

/// `tag` of the reminder message: the next one replaces it, and it is
/// cleared when the low rate ends. A tap on it opens the energy screen.
const lowTariffTag = 'osh_low_tariff';

/// One reminder automation per phone (each phone gets its own message).
String lowTariffReminderId(MobileAppRegistration registration) {
  final slug = haSlug(registration.deviceName);
  return 'osh_low_tariff_${slug.length > 40 ? slug.substring(0, 40) : slug}';
}

String _hour(int h) => '${h.toString().padLeft(2, '0')}:00:00';

/// "The lower rate has started" automation: at [LowTariff.fromHour] Home
/// Assistant sends a message to this phone (`notify.mobile_app_…`, over the
/// app's own WebSocket push channel), and at [LowTariff.toHour] clears it
/// (`clear_notification`, as Home Assistant's own apps do).
Map<String, Object?> lowTariffAutomation({
  required AppLocalizations l10n,
  required MobileAppRegistration registration,
  required LowTariff low,
  required String currency,
}) {
  final until = '${low.toHour.toString().padLeft(2, '0')}:00';
  final price = NumberFormat.decimalPattern(l10n.localeName).format(low.price);
  return {
    'alias': l10n.lowTariffAlias(registration.deviceName),
    'description': 'Open Smart Home',
    'mode': 'single',
    'variables': {'osh_from': low.fromHour, 'osh_to': low.toHour},
    'triggers': [
      {'trigger': 'time', 'at': _hour(low.fromHour), 'id': 'start'},
      {'trigger': 'time', 'at': _hour(low.toHour), 'id': 'end'},
    ],
    'conditions': <Object>[],
    'actions': [
      {
        'if': [
          {'condition': 'trigger', 'id': 'start'},
        ],
        'then': [
          {
            'action': registration.notifyService,
            'data': {
              'title': l10n.lowTariffTitle,
              'message': l10n.lowTariffMessage(until, '$price $currency'),
              'data': {'tag': lowTariffTag},
            },
          },
        ],
        'else': [
          {
            'action': registration.notifyService,
            'data': {
              'message': 'clear_notification',
              'data': {'tag': lowTariffTag},
            },
          },
        ],
      },
    ],
  };
}
