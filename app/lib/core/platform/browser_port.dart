import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_port_io.dart'
    if (dart.library.js_interop) 'browser_port_web.dart';

/// The few browser features the web sign-in needs, behind an interface so
/// the flow is testable on the VM. Not available on mobile.
abstract interface class BrowserPort {
  bool get isAvailable;
  Uri get currentUrl;

  String? sessionGet(String key);
  void sessionSet(String key, String value);
  void sessionRemove(String key);

  /// Leaves the app (full page navigation), e.g. to Home Assistant's login.
  void navigate(Uri url);

  /// Changes the address bar without reloading (removes `?code=…`).
  void replaceUrl(Uri url);
}

final browserPortProvider = Provider<BrowserPort>((ref) => createBrowserPort());
