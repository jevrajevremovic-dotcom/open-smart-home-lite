import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/localization/l10n.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/storage/credential_store.dart';
import '../kiosk/application/kiosk_controller.dart';
import '../kiosk/presentation/pin_dialog.dart';

/// The guest network, to show as a QR code that phones join by scanning.
@immutable
class GuestWifi {
  const GuestWifi({
    required this.ssid,
    this.password = '',
    this.open = false,
    this.hidden = false,
  });

  final String ssid;
  final String password;

  /// No password at all.
  final bool open;
  final bool hidden;

  /// The `WIFI:` text phone cameras understand (ZXing's format: `\`, `;`,
  /// `,`, `:` and `"` are escaped with a backslash).
  String get qrText {
    String esc(String v) =>
        v.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');
    return 'WIFI:T:${open ? 'nopass' : 'WPA'};S:${esc(ssid)};'
        '${open ? '' : 'P:${esc(password)};'}'
        '${hidden ? 'H:true;' : ''};';
  }
}

/// Name and options in the app's preferences; the password in the
/// device's secret storage (Keystore / Keychain), like the server token.
class GuestWifiController extends AsyncNotifier<GuestWifi?> {
  static const _key = 'guestWifi';
  static const _secret = 'osh.guest_wifi';

  @override
  Future<GuestWifi?> build() async {
    final json = ref.read(appPreferencesProvider).readJson(_key);
    final ssid = json?['ssid'];
    if (ssid is! String || ssid.isEmpty) return null;
    final open = json?['open'] == true;
    final password = open
        ? ''
        : await ref.read(credentialStoreProvider).readCredential(_secret) ?? '';
    return GuestWifi(
      ssid: ssid,
      password: password,
      open: open,
      hidden: json?['hidden'] == true,
    );
  }

  Future<void> save(GuestWifi? wifi) async {
    final prefs = ref.read(appPreferencesProvider);
    final store = ref.read(credentialStoreProvider);
    if (wifi == null) {
      await prefs.writeJson(_key, null);
      await store.deleteCredential(_secret);
    } else {
      await prefs.writeJson(_key, {
        'ssid': wifi.ssid,
        'open': wifi.open,
        'hidden': wifi.hidden,
      });
      if (wifi.open) {
        await store.deleteCredential(_secret);
      } else {
        await store.writeCredential(_secret, wifi.password);
      }
    }
    state = AsyncData(wifi);
  }
}

final guestWifiProvider =
    AsyncNotifierProvider<GuestWifiController, GuestWifi?>(
      GuestWifiController.new,
    );

Future<void> showGuestWifi(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _GuestWifiDialog(),
);

class _GuestWifiDialog extends ConsumerWidget {
  const _GuestWifiDialog();

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    // On the wall panel anyone may look, but only the household may change.
    if (ref.read(kioskActiveProvider) && !await confirmKioskPin(context, ref)) {
      return;
    }
    if (!context.mounted) return;
    final current = ref.read(guestWifiProvider).value;
    final result = await showDialog<(GuestWifi?,)>(
      context: context,
      builder: (_) => _GuestWifiEditor(initial: current),
    );
    if (result != null) {
      await ref.read(guestWifiProvider.notifier).save(result.$1);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final wifi = ref.watch(guestWifiProvider);
    final w = wifi.value;
    return AlertDialog(
      key: const Key('guestWifiDialog'),
      icon: const Icon(Icons.wifi),
      title: Text(l10n.guestWifiTitle),
      content: SizedBox(
        width: 360,
        child: wifi.isLoading
            ? const Center(child: CircularProgressIndicator())
            : w == null
            ? Text(l10n.guestWifiNotSet)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Always dark on white: what phone cameras read best.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      key: const Key('guestWifiQr'),
                      data: w.qrText,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.guestWifiScan, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(w.ssid, style: theme.textTheme.titleMedium),
                  if (!w.open)
                    SelectableText(
                      w.password,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          key: const Key('guestWifiEdit'),
          onPressed: () => _edit(context, ref),
          child: Text(w == null ? l10n.guestWifiSetUp : l10n.guestWifiChange),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _GuestWifiEditor extends StatefulWidget {
  const _GuestWifiEditor({this.initial});

  final GuestWifi? initial;

  @override
  State<_GuestWifiEditor> createState() => _GuestWifiEditorState();
}

class _GuestWifiEditorState extends State<_GuestWifiEditor> {
  late final _ssid = TextEditingController(text: widget.initial?.ssid);
  late final _password = TextEditingController(text: widget.initial?.password);
  late bool _open = widget.initial?.open ?? false;
  late bool _hidden = widget.initial?.hidden ?? false;
  bool _show = false;

  @override
  void dispose() {
    _ssid.dispose();
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final valid =
        _ssid.text.trim().isNotEmpty && (_open || _password.text.length >= 8);
    return AlertDialog(
      title: Text(l10n.guestWifiTitle),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.guestWifiWarning),
              const SizedBox(height: 12),
              TextField(
                key: const Key('guestWifiSsid'),
                controller: _ssid,
                decoration: InputDecoration(labelText: l10n.guestWifiSsid),
                onChanged: (_) => setState(() {}),
              ),
              if (!_open)
                TextField(
                  key: const Key('guestWifiPassword'),
                  controller: _password,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.guestWifiPassword,
                    helperText: l10n.guestWifiPasswordHint,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _show = !_show),
                      icon: Icon(
                        _show ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.guestWifiOpen),
                value: _open,
                onChanged: (v) => setState(() => _open = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.guestWifiHidden),
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop((null,)),
            child: Text(l10n.guestWifiRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('guestWifiSave'),
          onPressed: valid
              ? () => Navigator.of(context).pop((
                  GuestWifi(
                    ssid: _ssid.text.trim(),
                    password: _open ? '' : _password.text,
                    open: _open,
                    hidden: _hidden,
                  ),
                ))
              : null,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
