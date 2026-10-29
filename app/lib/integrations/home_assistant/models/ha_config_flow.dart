import 'package:flutter/foundation.dart';

/// A discovered device waiting to be set up (entry of the frontend's
/// `config_entries/flow/progress` WebSocket command).
@immutable
class HaDiscoveredFlow {
  const HaDiscoveredFlow({
    required this.flowId,
    required this.handler,
    required this.source,
    this.name,
  });

  final String flowId;

  /// Integration domain, e.g. `shelly`, `esphome`, `hue`.
  final String handler;

  /// How HA found it: `zeroconf`, `ssdp`, `dhcp`, `bluetooth`, …
  final String source;

  /// Device name from the discovery, if HA has one.
  final String? name;

  static List<HaDiscoveredFlow> parseList(Object? json) => [
    if (json is List)
      for (final f in json)
        if (f is Map && f['flow_id'] is String && f['handler'] is String)
          HaDiscoveredFlow(
            flowId: f['flow_id']! as String,
            handler: f['handler']! as String,
            source: switch (f['context']) {
              {'source': final String s} => s,
              _ => 'unknown',
            },
            name: switch (f['context']) {
              {'title_placeholders': {'name': final String n}} => n,
              _ => null,
            },
          ),
  ];
}

/// One field of a config flow form (voluptuous-serialized schema, either
/// the classic `type` form or the newer `selector` form).
@immutable
class HaFlowField {
  const HaFlowField({
    required this.name,
    required this.kind,
    required this.required,
    this.defaultValue,
    this.options = const [],
    this.min,
    this.max,
    this.secret = false,
  });

  final String name;
  final HaFieldKind kind;
  final bool required;
  final Object? defaultValue;

  /// For selects: (value, label).
  final List<(String, String)> options;
  final num? min;
  final num? max;

  /// Passwords, keys and tokens: obscured and never logged.
  final bool secret;

  static HaFlowField? parse(Object? json) {
    if (json is! Map || json['name'] is! String) return null;
    final name = json['name']! as String;
    final required = json['required'] == true;
    final def = json['default'];
    final secret = RegExp(
      'password|key|token|secret|pin',
      caseSensitive: false,
    ).hasMatch(name);

    List<(String, String)> options(Object? raw) => switch (raw) {
      final List<Object?> l => [
        for (final o in l)
          switch (o) {
            [final Object? v, final Object? label] => ('$v', '$label'),
            {'value': final Object? v, 'label': final Object? label} => (
              '$v',
              '$label',
            ),
            final Object? v => ('$v', '$v'),
          },
      ],
      final Map<Object?, Object?> m => [
        for (final e in m.entries) ('${e.key}', '${e.value}'),
      ],
      _ => const [],
    };

    final selector = json['selector'];
    if (selector is Map && selector.isNotEmpty) {
      final type = selector.keys.first;
      final cfg = selector[type] is Map ? selector[type] as Map : const {};
      return HaFlowField(
        name: name,
        required: required,
        defaultValue: def,
        secret: secret || cfg['type'] == 'password',
        kind: switch (type) {
          'text' => HaFieldKind.text,
          'number' => HaFieldKind.number,
          'boolean' => HaFieldKind.boolean,
          'select' => HaFieldKind.select,
          _ => HaFieldKind.unsupported,
        },
        options: options(cfg['options']),
        min: cfg['min'] is num ? cfg['min'] as num : null,
        max: cfg['max'] is num ? cfg['max'] as num : null,
      );
    }
    return HaFlowField(
      name: name,
      required: required,
      defaultValue: def,
      secret: secret,
      kind: switch (json['type']) {
        'string' => HaFieldKind.text,
        'integer' || 'float' => HaFieldKind.number,
        'boolean' => HaFieldKind.boolean,
        'select' => HaFieldKind.select,
        _ => HaFieldKind.unsupported,
      },
      options: options(json['options']),
      min: json['valueMin'] is num ? json['valueMin'] as num : null,
      max: json['valueMax'] is num ? json['valueMax'] as num : null,
    );
  }
}

enum HaFieldKind { text, number, boolean, select, unsupported }

/// Result of starting / continuing a config flow.
sealed class HaFlowStep {
  const HaFlowStep(this.flowId, this.handler);

  final String flowId;
  final String handler;

  static HaFlowStep parse(Object? json) {
    final m = json is Map ? json : const {};
    final flowId = m['flow_id'] is String ? m['flow_id']! as String : '';
    final handler = m['handler'] is String ? m['handler']! as String : '';
    final placeholders = <String, String>{
      if (m['description_placeholders'] case final Map<Object?, Object?> p)
        for (final e in p.entries) '${e.key}': '${e.value}',
    };
    return switch (m['type']) {
      'form' => HaFlowForm(
        flowId,
        handler,
        stepId: m['step_id'] is String ? m['step_id']! as String : '',
        fields: [
          if (m['data_schema'] case final List<Object?> schema)
            for (final f in schema) ?HaFlowField.parse(f),
        ],
        errors: {
          if (m['errors'] case final Map<Object?, Object?> e)
            for (final x in e.entries) '${x.key}': '${x.value}',
        },
        placeholders: placeholders,
      ),
      'menu' => HaFlowMenu(
        flowId,
        handler,
        stepId: m['step_id'] is String ? m['step_id']! as String : '',
        options: switch (m['menu_options']) {
          final List<Object?> l => [for (final o in l) '$o'],
          final Map<Object?, Object?> mm => [for (final k in mm.keys) '$k'],
          _ => const [],
        },
      ),
      'create_entry' => HaFlowDone(
        flowId,
        handler,
        title: m['title'] is String ? m['title']! as String : handler,
      ),
      'abort' => HaFlowAborted(
        flowId,
        handler,
        reason: m['reason'] is String ? m['reason']! as String : 'unknown',
        placeholders: placeholders,
      ),
      'progress' => HaFlowProgress(flowId, handler),
      _ => HaFlowUnsupported(flowId, handler, type: '${m['type']}'),
    };
  }
}

class HaFlowForm extends HaFlowStep {
  const HaFlowForm(
    super.flowId,
    super.handler, {
    required this.stepId,
    required this.fields,
    this.errors = const {},
    this.placeholders = const {},
  });

  final String stepId;
  final List<HaFlowField> fields;

  /// Field name (or `base`) → error key.
  final Map<String, String> errors;
  final Map<String, String> placeholders;

  bool get supported => fields.every((f) => f.kind != HaFieldKind.unsupported);
}

class HaFlowMenu extends HaFlowStep {
  const HaFlowMenu(
    super.flowId,
    super.handler, {
    required this.stepId,
    required this.options,
  });

  final String stepId;
  final List<String> options;
}

class HaFlowDone extends HaFlowStep {
  const HaFlowDone(super.flowId, super.handler, {required this.title});

  final String title;
}

class HaFlowAborted extends HaFlowStep {
  const HaFlowAborted(
    super.flowId,
    super.handler, {
    required this.reason,
    this.placeholders = const {},
  });

  final String reason;
  final Map<String, String> placeholders;
}

class HaFlowProgress extends HaFlowStep {
  const HaFlowProgress(super.flowId, super.handler);
}

/// External steps (OAuth in a browser, …) the app does not handle.
class HaFlowUnsupported extends HaFlowStep {
  const HaFlowUnsupported(super.flowId, super.handler, {required this.type});

  final String type;
}
