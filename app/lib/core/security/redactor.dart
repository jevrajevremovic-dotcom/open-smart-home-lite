/// Removes secrets from text before it reaches any log sink.
///
/// This is a safety net: code should not pass secrets to the logger in the
/// first place. Patterns cover bearer tokens, JWT-shaped strings (Home
/// Assistant access tokens are JWTs), and common secret-bearing JSON/query
/// keys.
abstract final class Redactor {
  static const String mask = '«redacted»';

  static final List<(RegExp, String Function(Match))> _rules = [
    // Authorization: Bearer <token>
    (
      RegExp(r'(bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      (m) => '${m[1]}$mask',
    ),
    // JSON: "access_token": "…", "refresh_token", "password", "token", …
    (
      RegExp(
        r'("(?:access_token|refresh_token|token|password|api_password|client_secret|authorization)"\s*:\s*")[^"]*(")',
        caseSensitive: false,
      ),
      (m) => '${m[1]}$mask${m[2]}',
    ),
    // Query / form: access_token=…, token=…, password=…, code=…
    (
      RegExp(
        r'((?:access_token|refresh_token|token|password|code|authSig)=)[^&\s"]+',
        caseSensitive: false,
      ),
      (m) => '${m[1]}$mask',
    ),
    // Any remaining JWT-looking value (header.payload.signature).
    (
      RegExp(r'eyJ[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{5,}'),
      (_) => mask,
    ),
  ];

  static String redact(String input) {
    var output = input;
    for (final (pattern, replace) in _rules) {
      output = output.replaceAllMapped(pattern, replace);
    }
    return output;
  }

  /// Shows only the last four characters, e.g. for "token ends with …a1b2".
  static String tail(String secret, {int visible = 4}) {
    if (secret.length <= visible * 2) return mask;
    return '…${secret.substring(secret.length - visible)}';
  }
}
