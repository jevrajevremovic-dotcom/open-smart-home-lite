import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Facts about the runtime platform that change app behaviour.
@immutable
class PlatformInfo {
  const PlatformInfo({required this.isWeb, this.pageUri});

  factory PlatformInfo.current() =>
      PlatformInfo(isWeb: kIsWeb, pageUri: kIsWeb ? Uri.base : null);

  final bool isWeb;

  /// URL the web app was loaded from (`null` on mobile).
  final Uri? pageUri;

  /// Browsers block `http://` requests from pages loaded over `https://`.
  bool get isSecurePage => isWeb && pageUri?.scheme == 'https';

  /// When the web build is hosted by Home Assistant itself (for example from
  /// `/config/www`, served at `/local/…`), the page origin *is* the server.
  String? get suggestedServerAddress {
    final uri = pageUri;
    if (!isWeb || uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.origin;
  }
}

final platformInfoProvider = Provider<PlatformInfo>(
  (ref) => PlatformInfo.current(),
);
