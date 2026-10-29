import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/platform_info.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/native_login.dart';
import '../../authentication/application/web_login.dart';
import '../application/connection_setup_controller.dart';

/// Collects a long-lived access token. On success the session changes and
/// the router moves to the home screen on its own.
class TokenScreen extends ConsumerStatefulWidget {
  const TokenScreen({super.key});

  @override
  ConsumerState<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends ConsumerState<TokenScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _obscured = true;
  bool _remember = false;

  @override
  void dispose() {
    // Do not keep the token in memory longer than needed.
    _controller
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _nativeSignIn() async {
    final controller = ref.read(connectionSetupControllerProvider.notifier);
    final profile = ref.read(connectionSetupControllerProvider).profile;
    if (profile == null) return;
    try {
      final code = await ref
          .read(nativeLoginServiceProvider)
          .obtainCode(context, profile);
      if (code == null) return;
      await controller.signInWithCode(code, NativeLoginService.clientId);
    } on AppFailure catch (e) {
      controller.reportAuthFailure(e);
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(connectionSetupControllerProvider.notifier)
        .authenticate(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(connectionSetupControllerProvider);
    final mockMode = ref.watch(appConfigProvider).mockMode;
    final busy = state.authenticating;
    final failure = state.authFailure;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tokenTitle)),
      body: MockModeBanner(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.address != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.dns_outlined),
                      title: Text(state.address.toString()),
                    ),
                  if (ref.watch(webLoginServiceProvider).isSupported) ...[
                    // Web: OAuth2 on Home Assistant's login page is the
                    // primary way; the token form below is the fallback.
                    Text(
                      l10n.oauthHint,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('oauthSignIn'),
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(
                                  connectionSetupControllerProvider.notifier,
                                )
                                .startWebSignIn(remember: _remember),
                      icon: const Icon(Icons.login),
                      label: Text(l10n.oauthSignIn),
                    ),
                    CheckboxListTile(
                      key: const Key('rememberMe'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      title: Text(l10n.rememberMe),
                      subtitle: Text(l10n.rememberMeHint),
                    ),
                    const Divider(height: 32),
                    Text(
                      l10n.orUseToken,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                  ] else if (ref
                      .watch(nativeLoginServiceProvider)
                      .isSupported) ...[
                    // Phones and tablets: Home Assistant's login page inside
                    // the app; the token form below stays as the fallback.
                    Text(
                      l10n.oauthHintNative,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('oauthSignInNative'),
                      onPressed: busy ? null : _nativeSignIn,
                      icon: const Icon(Icons.login),
                      label: Text(l10n.oauthSignIn),
                    ),
                    const Divider(height: 40),
                    Text(
                      l10n.orUseToken,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    l10n.tokenIntro,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.tokenSteps),
                    ),
                  ),
                  if (ref.watch(platformInfoProvider).isWeb) ...[
                    const SizedBox(height: 12),
                    InlineNotice.info(l10n.webSessionNotice),
                  ],
                  if (mockMode) ...[
                    const SizedBox(height: 12),
                    InlineNotice.info(l10n.tokenMockHint),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('tokenField'),
                    controller: _controller,
                    enabled: !busy,
                    obscureText: _obscured,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.visiblePassword,
                    minLines: 1,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: l10n.tokenLabel,
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        tooltip: _obscured ? l10n.showToken : l10n.hideToken,
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscured = !_obscured),
                      ),
                    ),
                    onSubmitted: (_) => _connect(),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: 12),
                    InlineNotice.error(
                      failure.kind == FailureKind.validation &&
                              failure.statusCode == null
                          ? l10n.tokenInvalidFormat
                          : failureMessage(l10n, failure),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('connectButton'),
                    onPressed: busy ? null : _connect,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(busy ? l10n.connecting : l10n.connect),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
