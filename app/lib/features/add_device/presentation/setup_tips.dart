import 'package:flutter/material.dart';

import '../../../app/localization/l10n.dart';

/// What a maker's devices need before the app can talk to them, by
/// adapter id (`shelly`, `tuya`…); `null` for ours (demo, routines).
String? setupTip(AppLocalizations l10n, String adapter) => switch (adapter) {
  'shelly' => l10n.tipShelly,
  'wled' => l10n.tipWled,
  'tasmota' => l10n.tipTasmota,
  'esphome' => l10n.tipEsphome,
  'hue' => l10n.tipHue,
  'yeelight' => l10n.tipYeelight,
  'wiz' => l10n.tipWiz,
  'lifx' => l10n.tipLifx,
  'govee' => l10n.tipGovee,
  'nanoleaf' => l10n.tipNanoleaf,
  'sonoff' => l10n.tipSonoff,
  'kasa' || 'tapo' => l10n.tipTpLink,
  'dirigera' => l10n.tipDirigera,
  'tuya' => l10n.tipTuya,
  'miio' => l10n.tipXiaomi,
  'broadlink' => l10n.tipBroadlink,
  'samsung' => l10n.tipSamsung,
  'lg' => l10n.tipLg,
  'roku' => l10n.tipRoku,
  'sonos' => l10n.tipSonos,
  'camera' => l10n.tipCamera,
  'ble' => l10n.tipBluetooth,
  _ => null,
};

/// Every maker's setup, folded: for when a device does not show up.
class SetupHelp extends StatelessWidget {
  const SetupHelp({super.key});

  static const _makers = [
    ('Shelly', 'shelly'),
    ('Philips Hue', 'hue'),
    ('IKEA DIRIGERA', 'dirigera'),
    ('ESPHome', 'esphome'),
    ('WLED', 'wled'),
    ('Tasmota', 'tasmota'),
    ('WiZ', 'wiz'),
    ('LIFX', 'lifx'),
    ('Govee', 'govee'),
    ('Yeelight', 'yeelight'),
    ('Nanoleaf', 'nanoleaf'),
    ('Sonoff', 'sonoff'),
    ('TP-Link Kasa / Tapo', 'tapo'),
    ('Tuya / Smart Life', 'tuya'),
    ('Xiaomi', 'miio'),
    ('Broadlink', 'broadlink'),
    ('Samsung TV', 'samsung'),
    ('LG TV', 'lg'),
    ('Roku', 'roku'),
    ('Sonos', 'sonos'),
    ('', 'camera'),
    ('Bluetooth', 'ble'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card.outlined(
      child: ExpansionTile(
        key: const Key('setupHelp'),
        leading: const Icon(Icons.help_outline),
        title: Text(l10n.setupHelpTitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.setupHelpHint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final (name, adapter) in _makers) ...[
            const SizedBox(height: 8),
            Text(
              adapter == 'camera' ? l10n.cameraAdd : name,
              style: theme.textTheme.titleSmall,
            ),
            Text(setupTip(l10n, adapter)!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
