import '../../../integrations/home_assistant/models/ha_config_flow.dart';
import '../../../integrations/home_assistant/websocket/ha_websocket_manager.dart';

/// Devices Home Assistant found on the network and their setup texts.
///
/// Uses the frontend's WebSocket commands `config_entries/flow/progress`
/// and `frontend/get_translations` (not in the developer docs; admin).
class DiscoveryFlows {
  DiscoveryFlows(this._ws);

  final HaWebSocketManager _ws;

  /// Sources that mean "found automatically" (not user-started flows,
  /// re-authentication or YAML imports).
  static const discoverySources = {
    'zeroconf',
    'ssdp',
    'dhcp',
    'bluetooth',
    'homekit',
    'mqtt',
    'usb',
    'discovery',
    'integration_discovery',
    'hassio',
  };

  Future<List<HaDiscoveredFlow>> discovered() async => [
    for (final f in HaDiscoveredFlow.parseList(
      await _ws.sendCommand({'type': 'config_entries/flow/progress'}),
    ))
      if (discoverySources.contains(f.source)) f,
  ];

  /// Translations for [handlers] (category `config`) in [language], with
  /// English as fallback. Empty when unavailable.
  Future<Map<String, String>> translations(
    String language,
    Set<String> handlers,
  ) async {
    Future<Map<String, String>> load(String lang) async {
      try {
        final result = await _ws.sendCommand({
          'type': 'frontend/get_translations',
          'language': lang,
          'category': 'config',
          'integration': handlers.toList(),
        });
        final resources = result is Map ? result['resources'] : null;
        return {
          if (resources is Map)
            for (final e in resources.entries)
              if (e.value is String) '${e.key}': e.value as String,
        };
      } on Object {
        return const {};
      }
    }

    final english = language == 'en'
        ? const <String, String>{}
        : await load('en');
    return {...english, ...await load(language)};
  }
}

/// Looks up HA's texts for a flow, filling `{placeholders}`.
class FlowTexts {
  const FlowTexts(this._t, this.handler, [this.placeholders = const {}]);

  final Map<String, String> _t;
  final String handler;
  final Map<String, String> placeholders;

  String? _get(String key) {
    var text = _t['component.$handler.config.$key'];
    if (text == null) return null;
    for (final e in placeholders.entries) {
      text = text!.replaceAll('{${e.key}}', e.value);
    }
    // Drop markdown emphasis and leftover placeholders.
    return text!
        .replaceAll(RegExp(r'[`*]'), '')
        .replaceAll(RegExp(r'\{[a-z_]+\}'), '');
  }

  String? stepTitle(String stepId) => _get('step.$stepId.title');
  String? stepDescription(String stepId) => _get('step.$stepId.description');
  String field(String stepId, String name) =>
      _get('step.$stepId.data.$name') ?? prettify(name);
  String? fieldHelp(String stepId, String name) =>
      _get('step.$stepId.data_description.$name');
  String menuOption(String stepId, String option) =>
      _get('step.$stepId.menu_options.$option') ?? prettify(option);
  String? error(String key) => _get('error.$key');
  String? abort(String reason) => _get('abort.$reason');

  /// `noise_psk` → `Noise psk`.
  static String prettify(String key) {
    final s = key.replaceAll('_', ' ').trim();
    return s.isEmpty ? key : s[0].toUpperCase() + s.substring(1);
  }
}
