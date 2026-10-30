import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'lan_transport.dart';

/// A device that answered an SSDP (UPnP) search.
@immutable
class SsdpFound {
  const SsdpFound(this.host, this.headers);

  final String host;

  /// Lower-case header names (`location`, `st`, `usn`, `server`…).
  final Map<String, String> headers;

  String? get location => headers['location'];
  String? get usn => headers['usn'];
}

/// Devices answering an SSDP search for [st] (e.g. `roku:ecp`), one per
/// address.
Future<List<SsdpFound>> ssdpSearch(
  LanUdp udp,
  String st, {
  Duration wait = const Duration(seconds: 3),
}) async {
  final answers = await udp.ask(
    '239.255.255.250',
    1900,
    ascii.encode(
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: 239.255.255.250:1900\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 2\r\n'
      'ST: $st\r\n\r\n',
    ),
    wait: wait,
    first: false,
  );
  final out = <String, SsdpFound>{};
  for (final a in answers) {
    final headers = parseSsdpHeaders(a.text);
    final type = headers['st'] ?? headers['nt'];
    if (type != null && type != st) continue;
    out[a.host] ??= SsdpFound(a.host, headers);
  }
  return out.values.toList();
}

Map<String, String> parseSsdpHeaders(String text) => {
  for (final line in const LineSplitter().convert(text))
    if (line.indexOf(':') case final i when i > 0)
      line.substring(0, i).trim().toLowerCase(): line.substring(i + 1).trim(),
};

/// The text of the first `<tag>` in [xml] (namespace prefixes ignored),
/// unescaped; `null` when there is none.
String? xmlText(String xml, String tag) {
  final m = RegExp('<(?:\\w+:)?$tag(?:\\s[^>]*)?>([\\s\\S]*?)</(?:\\w+:)?$tag>')
      .firstMatch(xml);
  return m == null ? null : xmlUnescape(m.group(1)!.trim());
}

/// The value of [attribute] on the first `<tag>` in [xml].
String? xmlAttribute(String xml, String tag, String attribute) {
  final m = RegExp('<(?:\\w+:)?$tag\\s[^>]*$attribute="([^"]*)"')
      .firstMatch(xml);
  return m == null ? null : xmlUnescape(m.group(1)!);
}

String xmlUnescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
