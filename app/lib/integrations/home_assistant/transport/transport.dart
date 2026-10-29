/// Platform-specific HTTP/WebSocket plumbing.
///
/// * `dart:io` (Android, iOS, tests): custom `HttpClient` with certificate
///   pinning, `IOWebSocketChannel`, `dart:io` error classification.
/// * Web: the browser's XHR/fetch and WebSocket; TLS is handled by the
///   browser and cannot be customised.
library;

export 'transport_io.dart' if (dart.library.js_interop) 'transport_web.dart';
