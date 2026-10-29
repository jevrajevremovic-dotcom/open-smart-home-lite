import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/session_controller.dart';

import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/config/platform_info.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/network/server_address.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../application/connection_setup_controller.dart';
import '../application/discovery_controller.dart';
import '../data/server_discovery.dart';
import 'certificate_dialog.dart';

class ServerAddressScreen extends ConsumerStatefulWidget {
  const ServerAddressScreen({super.key});

  @override
  ConsumerState<ServerAddressScreen> createState() =>
      _ServerAddressScreenState();
}

class _ServerAddressScreenState extends ConsumerState<ServerAddressScreen> {
  late final TextEditingController _controller = TextEditingController(
    text:
        ref.read(connectionSetupControllerProvider).address?.toString() ??
        ref.read(platformInfoProvider).suggestedServerAddress ??
        '',
  );

  /// Address parsed while typing, only used to show the risk hint early.
  ServerAddress? _preview;

  @override
  void initState() {
    super.initState();
    _updatePreview(_controller.text);
    // Look for servers on the network unless an address is already known.
    if (_controller.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(discoveryControllerProvider.notifier).start();
      });
    }
  }

  Future<void> _useDiscovered(DiscoveredServer server) async {
    _controller.text = server.address.toString();
    _updatePreview(_controller.text);
    await _check();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview(String text) {
    final parsed = ServerAddress.parse(text);
    setState(
      () => _preview = parsed is ValidServerAddress ? parsed.address : null,
    );
  }

  Future<void> _check() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(connectionSetupControllerProvider.notifier);
    var ok = await controller.checkServer(_controller.text);
    if (!mounted) return;

    final failure = ref.read(connectionSetupControllerProvider).failure;
    final certificate = failure?.certificate;
    if (!ok &&
        failure?.kind == FailureKind.certificate &&
        certificate != null) {
      final trusted = await showCertificateDialog(context, certificate);
      if (!mounted || !trusted) return;
      ok = await controller.trustCertificate(certificate.sha256Fingerprint);
      if (!mounted) return;
    }
    if (ok) await context.push(AppRoutes.connectToken);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(connectionSetupControllerProvider);
    final checking = state.probeStatus == ProbeStatus.checking;
    final shown = _preview;
    final adding = ref.watch(addingHomeProvider);

    void cancelAdding() {
      ref.read(addingHomeProvider.notifier).set(false);
      context.go(AppRoutes.home);
    }

    // Android back while adding a home returns to the current one
    // instead of closing the app.
    return PopScope(
      canPop: !adding,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && adding) cancelAdding();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.serverAddressTitle),
          // Adding a second home from Settings: a way back to the first.
          leading: adding
              ? IconButton(
                  key: const Key('cancelAddHome'),
                  tooltip: l10n.cancel,
                  icon: const Icon(Icons.close),
                  onPressed: cancelAdding,
                )
              : null,
        ),
        body: MockModeBanner(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.serverAddressIntro,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _DiscoveredServers(onSelected: _useDiscovered),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('serverAddressField'),
                      controller: _controller,
                      enabled: !checking,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.go,
                      autofillHints: const [AutofillHints.url],
                      decoration: InputDecoration(
                        labelText: l10n.serverAddressLabel,
                        hintText: l10n.serverAddressHint,
                        prefixIcon: const Icon(Icons.dns_outlined),
                        errorText: state.addressError == null
                            ? null
                            : addressErrorMessage(l10n, state.addressError!),
                        errorMaxLines: 3,
                      ),
                      onChanged: _updatePreview,
                      onSubmitted: (_) => _check(),
                    ),
                    const SizedBox(height: 16),
                    if (shown != null) ...[
                      RiskNotice(address: shown),
                      const SizedBox(height: 8),
                    ],
                    if (shown?.risk == ConnectionRisk.insecureRemote)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: state.insecureAcknowledged,
                        onChanged: (v) => ref
                            .read(connectionSetupControllerProvider.notifier)
                            .setInsecureAcknowledged(v ?? false),
                        title: Text(l10n.insecureAcknowledge),
                      ),
                    if (state.failure != null) ...[
                      const SizedBox(height: 8),
                      InlineNotice.error(failureMessage(l10n, state.failure!)),
                      // Browsers report CORS and mixed-content blocks as a
                      // generic network error, so explain the likely causes.
                      if (state.failure!.kind == FailureKind.network &&
                          ref.watch(platformInfoProvider).isWeb) ...[
                        const SizedBox(height: 8),
                        InlineNotice.info(l10n.webConnectionHint),
                      ],
                    ],
                    if (state.probeStatus == ProbeStatus.reachable &&
                        state.address != null) ...[
                      const SizedBox(height: 8),
                      InlineNotice.success(
                        l10n.serverReachable(state.address.toString()),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('checkServerButton'),
                      onPressed:
                          checking ||
                              (shown?.risk == ConnectionRisk.insecureRemote &&
                                  !state.insecureAcknowledged)
                          ? null
                          : _check,
                      icon: checking
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(
                        checking ? l10n.checking : l10n.checkConnection,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RiskNotice extends StatelessWidget {
  const RiskNotice({super.key, required this.address});

  final ServerAddress address;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (address.risk) {
      ConnectionRisk.none =>
        address.isSecure
            ? const SizedBox.shrink()
            : InlineNotice.info(l10n.riskLocalHttp),
      ConnectionRisk.remoteExposure => InlineNotice.info(
        l10n.riskRemoteExposure,
      ),
      ConnectionRisk.insecureRemote => InlineNotice.warning(
        l10n.riskInsecureRemote,
      ),
      ConnectionRisk.vpnTunnel => InlineNotice.info(l10n.riskVpnTunnel),
    };
  }
}

String addressErrorMessage(AppLocalizations l10n, ServerAddressError error) =>
    switch (error) {
      ServerAddressError.empty => l10n.addressErrorEmpty,
      ServerAddressError.malformed => l10n.addressErrorMalformed,
      ServerAddressError.unsupportedScheme =>
        l10n.addressErrorUnsupportedScheme,
      ServerAddressError.missingHost => l10n.addressErrorMissingHost,
      ServerAddressError.credentialsNotAllowed => l10n.addressErrorCredentials,
      ServerAddressError.pathNotSupported => l10n.addressErrorPath,
      ServerAddressError.queryNotAllowed => l10n.addressErrorQuery,
      ServerAddressError.invalidPort => l10n.addressErrorPort,
      ServerAddressError.blockedMixedContent => l10n.addressErrorMixedContent,
    };

/// Servers found on the local network via mDNS; tap one to use it.
class _DiscoveredServers extends ConsumerWidget {
  const _DiscoveredServers({required this.onSelected});

  final ValueChanged<DiscoveredServer> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(discoveryControllerProvider.notifier);
    if (!controller.isSupported) return const SizedBox.shrink();
    final l10n = context.l10n;
    final state = ref.watch(discoveryControllerProvider);
    final theme = Theme.of(context);

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.discoveryTitle, style: theme.textTheme.titleSmall),
            trailing: state.searching
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    key: const Key('discoveryRetry'),
                    onPressed: controller.start,
                    child: Text(l10n.discoverySearchAgain),
                  ),
          ),
          for (final server in state.servers)
            ListTile(
              key: ValueKey('discovered-${server.key}'),
              leading: const Icon(Icons.home_outlined),
              title: Text(server.name),
              subtitle: Text(
                [
                  server.address.toString(),
                  if (server.version != null)
                    l10n.serverVersion(server.version!),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(server),
            ),
          if (state.servers.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                state.searching
                    ? l10n.discoverySearching
                    : l10n.discoveryNothingFound,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
