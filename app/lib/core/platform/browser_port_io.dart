import 'browser_port.dart';

BrowserPort createBrowserPort() => const _NoBrowser();

class _NoBrowser implements BrowserPort {
  const _NoBrowser();

  @override
  bool get isAvailable => false;

  @override
  Uri get currentUrl => Uri();

  @override
  String? sessionGet(String key) => null;

  @override
  void sessionSet(String key, String value) =>
      throw UnsupportedError('No browser on this platform');

  @override
  void sessionRemove(String key) {}

  @override
  void navigate(Uri url) =>
      throw UnsupportedError('No browser on this platform');

  @override
  void replaceUrl(Uri url) {}
}
