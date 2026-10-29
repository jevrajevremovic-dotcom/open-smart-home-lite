import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/status_widgets.dart';

/// Home Assistant's login page inside the app. Pops with the redirect URL
/// (carrying `code` and `state`) as soon as Home Assistant redirects to it.
class HaLoginPage extends StatefulWidget {
  const HaLoginPage({
    super.key,
    required this.authorizeUrl,
    required this.isCallback,
  });

  final Uri authorizeUrl;
  final bool Function(Uri url) isCallback;

  @override
  State<HaLoginPage> createState() => _HaLoginPageState();
}

class _HaLoginPageState extends State<HaLoginPage> {
  late final WebViewController _web;
  bool _loading = true;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // HA's page needs it
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = Uri.tryParse(request.url);
            if (url != null && widget.isCallback(url)) {
              _finish(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) => setState(() {
            _loading = true;
            _failed = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _failed = true;
              });
            }
          },
        ),
      )
      ..loadRequest(widget.authorizeUrl);
  }

  void _finish(Uri callback) {
    if (_done) return;
    _done = true;
    // Leave no Home Assistant session behind in the web view.
    WebViewCookieManager().clearCookies();
    Navigator.of(context).pop(callback);
  }

  @override
  void dispose() {
    if (!_done) WebViewCookieManager().clearCookies();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('closeHaLogin'),
          tooltip: l10n.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.oauthSignIn),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _failed
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineNotice.error(l10n.oauthPageFailed),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _failed = false);
                      _web.loadRequest(widget.authorizeUrl);
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retryNow),
                  ),
                ],
              ),
            )
          : WebViewWidget(controller: _web),
    );
  }
}
