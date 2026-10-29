import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../integrations/home_assistant/home_assistant_providers.dart';
import '../data/server_profile.dart';
import '../presentation/ha_login_page.dart';

/// OAuth2 sign-in on phones and tablets with Home Assistant's own login
/// page, so nobody has to create and copy a long-lived token.
///
/// The page opens inside the app (as in Home Assistant's companion apps).
/// `client_id` and `redirect_uri` share one host that is never loaded: the
/// app catches the redirect before it happens. Home Assistant accepts a
/// redirect on the client id's own host without fetching anything, so this
/// works on a LAN without internet. The password is typed into Home
/// Assistant's page only; the app receives a one-time code.
class NativeLoginService {
  NativeLoginService(this._ref);

  final Ref _ref;

  static const clientId = 'http://open-smart-home.localhost/';
  static final redirectUri = Uri.parse(
    'http://open-smart-home.localhost/auth-callback',
  );

  bool get isSupported => !kIsWeb;

  /// Shows the login page and returns the authorization code, or `null`
  /// when the user closed it.
  Future<String?> obtainCode(
    BuildContext context,
    ServerProfile profile,
  ) async {
    final state = _randomState();
    final url = _ref
        .read(haAuthClientFactoryProvider)(profile)
        .authorizeUrl(
          clientId: clientId,
          redirectUri: redirectUri,
          state: state,
        );
    // The mock server "logs in" at once and returns the callback directly.
    final callback = isCallback(url)
        ? url
        : await Navigator.of(context).push<Uri>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) =>
                  HaLoginPage(authorizeUrl: url, isCallback: isCallback),
            ),
          );
    if (callback == null) return null;
    final code = callback.queryParameters['code'];
    // Login CSRF: accept only the answer to the request made here.
    if (code == null || callback.queryParameters['state'] != state) {
      throw const AppFailure(
        FailureKind.validation,
        debugMessage: 'OAuth state mismatch',
      );
    }
    return code;
  }

  static bool isCallback(Uri url) =>
      url.scheme == redirectUri.scheme &&
      url.host == redirectUri.host &&
      url.path == redirectUri.path;

  static String _randomState() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(24, (_) => r.nextInt(256)))
        .replaceAll('=', '');
  }
}

final nativeLoginServiceProvider = Provider<NativeLoginService>(
  NativeLoginService.new,
);
