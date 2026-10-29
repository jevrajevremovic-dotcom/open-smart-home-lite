import 'package:web/web.dart' as web;

import 'browser_port.dart';

BrowserPort createBrowserPort() => _WebBrowser();

class _WebBrowser implements BrowserPort {
  @override
  bool get isAvailable => true;

  @override
  Uri get currentUrl => Uri.parse(web.window.location.href);

  @override
  String? sessionGet(String key) => web.window.sessionStorage.getItem(key);

  @override
  void sessionSet(String key, String value) =>
      web.window.sessionStorage.setItem(key, value);

  @override
  void sessionRemove(String key) => web.window.sessionStorage.removeItem(key);

  @override
  void navigate(Uri url) => web.window.location.assign(url.toString());

  @override
  void replaceUrl(Uri url) =>
      web.window.history.replaceState(null, '', url.toString());
}
