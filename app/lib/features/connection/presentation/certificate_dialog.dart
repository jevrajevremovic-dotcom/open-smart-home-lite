import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/status_widgets.dart';

/// Shows the untrusted certificate and returns `true` only if the user
/// explicitly ticked the confirmation and pressed "Trust".
Future<bool> showCertificateDialog(
  BuildContext context,
  CertificateInfo certificate,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CertificateDialog(certificate: certificate),
  );
  return result ?? false;
}

class _CertificateDialog extends StatefulWidget {
  const _CertificateDialog({required this.certificate});

  final CertificateInfo certificate;

  @override
  State<_CertificateDialog> createState() => _CertificateDialogState();
}

class _CertificateDialogState extends State<_CertificateDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cert = widget.certificate;
    final expired = cert.isExpiredAt(DateTime.now());
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    Widget field(String label, String value, {bool mono = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          SelectableText(
            value,
            style: mono
                ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
                : null,
          ),
        ],
      ),
    );

    return AlertDialog(
      icon: const Icon(Icons.gpp_maybe_outlined),
      title: Text(l10n.certificateUntrustedTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineNotice.warning(l10n.certificateUntrustedBody),
            const SizedBox(height: 16),
            field(l10n.certificateSubject, cert.subject),
            field(l10n.certificateIssuer, cert.issuer),
            field(l10n.certificateValidUntil, date.format(cert.validUntil)),
            if (expired) ...[
              InlineNotice.error(l10n.certificateExpired),
              const SizedBox(height: 12),
            ],
            field(
              l10n.certificateFingerprint,
              cert.sha256Fingerprint,
              mono: true,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              title: Text(l10n.certificateConfirm),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _confirmed ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.trustCertificate),
        ),
      ],
    );
  }
}
