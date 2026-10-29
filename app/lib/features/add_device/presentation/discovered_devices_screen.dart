import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/app_router.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../../integrations/home_assistant/models/ha_config_flow.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/presentation/device_grid.dart' show EmptyHint;
import '../../devices/presentation/device_presentation.dart';
import '../data/discovery_flows.dart';

final _discoveryProvider = Provider.autoDispose<DiscoveryFlows?>((ref) {
  final ws = ref.watch(webSocketManagerProvider);
  return ws == null ? null : DiscoveryFlows(ws);
});

final discoveredFlowsProvider =
    FutureProvider.autoDispose<List<HaDiscoveredFlow>>((ref) async {
      final d = ref.watch(_discoveryProvider);
      if (d == null) return const [];
      return d.discovered();
    });

final _flowTextsProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, key) async {
      final d = ref.watch(_discoveryProvider);
      if (d == null) return const {};
      return d.translations(key.$1, {key.$2});
    });

IconData _handlerIcon(String handler) => switch (handler) {
  'hue' ||
  'lifx' ||
  'yeelight' ||
  'wiz' ||
  'nanoleaf' => Icons.lightbulb_outline,
  'cast' || 'sonos' || 'dlna_dmr' || 'heos' || 'bluesound' => Icons.speaker,
  'samsungtv' || 'webostv' || 'androidtv_remote' || 'braviatv' => Icons.tv,
  'esphome' => Icons.developer_board,
  'shelly' || 'tasmota' || 'tplink' || 'meross_lan' => Icons.power_outlined,
  'ipp' || 'brother' => Icons.print_outlined,
  'homekit_controller' => Icons.home_outlined,
  _ => Icons.devices_other,
};

/// Devices Home Assistant found on the network, ready to be added.
class DiscoveredDevicesScreen extends ConsumerWidget {
  const DiscoveredDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final flows = ref.watch(discoveredFlowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discoveredTitle),
        actions: [
          IconButton(
            key: const Key('discoveredRefresh'),
            tooltip: l10n.discoveredRefresh,
            onPressed: () => ref.invalidate(discoveredFlowsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(discoveredFlowsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: switch (flows) {
            AsyncData(value: final list) when list.isEmpty => [
              EmptyHint(icon: Icons.wifi_find, text: l10n.discoveredEmpty),
            ],
            AsyncData(value: final list) => [
              for (final f in list)
                Card(
                  key: ValueKey('discovered-${f.flowId}'),
                  child: ListTile(
                    leading: Icon(_handlerIcon(f.handler)),
                    title: Text(f.name ?? FlowTexts.prettify(f.handler)),
                    subtitle: Text(
                      '${FlowTexts.prettify(f.handler)} · '
                      '${l10n.discoveredVia(f.source)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ConfigFlowScreen(flow: f),
                        ),
                      );
                      ref.invalidate(discoveredFlowsProvider);
                    },
                  ),
                ),
            ],
            AsyncError() => [InlineNotice.warning(l10n.discoveredUnavailable)],
            _ => [
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          },
        ),
      ),
    );
  }
}

/// Walks through Home Assistant's setup steps for one device: forms are
/// rendered from HA's schema, texts come from HA's translations.
class ConfigFlowScreen extends ConsumerStatefulWidget {
  const ConfigFlowScreen({super.key, required this.flow});

  final HaDiscoveredFlow flow;

  @override
  ConsumerState<ConfigFlowScreen> createState() => _ConfigFlowScreenState();
}

class _ConfigFlowScreenState extends ConsumerState<ConfigFlowScreen> {
  HaFlowStep? _step;
  AppFailure? _failure;
  bool _busy = true;
  final Map<String, Object?> _values = {};
  final Map<String, TextEditingController> _text = {};
  late final Set<String> _knownDevices;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _knownDevices = {
      for (final d in ref.read(homeSnapshotProvider).devices.values) d.id,
    };
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<HaFlowStep> Function() call) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final step = await call();
      if (!mounted) return;
      _poll?.cancel();
      if (step is HaFlowProgress) {
        _poll = Timer(const Duration(seconds: 2), _load);
      }
      setState(() {
        _step = step;
        _busy = false;
        if (step is HaFlowForm) _prepare(step);
      });
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _failure = e;
          _busy = false;
        });
      }
    }
  }

  Future<void> _load() async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    await _run(() => api.configFlowStep(widget.flow.flowId));
  }

  void _prepare(HaFlowForm form) {
    for (final f in form.fields) {
      _values.putIfAbsent(f.name, () => f.defaultValue);
      if (f.kind == HaFieldKind.text || f.kind == HaFieldKind.number) {
        _text.putIfAbsent(
          f.name,
          () => TextEditingController(text: '${f.defaultValue ?? ''}'),
        );
      }
    }
  }

  Future<void> _submit(HaFlowForm form) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final data = <String, Object?>{};
    for (final f in form.fields) {
      final value = switch (f.kind) {
        HaFieldKind.text => _text[f.name]!.text,
        HaFieldKind.number => num.tryParse(
          _text[f.name]!.text.replaceAll(',', '.'),
        ),
        _ => _values[f.name],
      };
      if (value == null || (value is String && value.isEmpty && !f.required)) {
        continue;
      }
      data[f.name] = value;
    }
    await _run(() => api.configFlowSubmit(form.flowId, data));
  }

  Future<void> _choose(HaFlowMenu menu, String option) async {
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    await _run(
      () => api.configFlowSubmit(menu.flowId, {'next_step_id': option}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final flow = widget.flow;
    final translations =
        ref.watch(_flowTextsProvider((l10n.localeName, flow.handler))).value ??
        const {};
    final step = _step;
    final texts = FlowTexts(translations, flow.handler, {
      'name': flow.name ?? flow.handler,
      if (step is HaFlowForm) ...step.placeholders,
      if (step is HaFlowAborted) ...step.placeholders,
    });
    final name = flow.name ?? FlowTexts.prettify(flow.handler);

    final List<Widget> body = switch (step) {
      _ when _failure != null => [
        InlineNotice.error(failureMessage(l10n, _failure!)),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: Text(l10n.retryNow)),
      ],
      null || HaFlowProgress() => [
        const SizedBox(height: 32),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 12),
        Center(child: Text(l10n.flowWorking)),
      ],
      final HaFlowForm form => _form(context, form, texts, name),
      final HaFlowMenu menu => [
        Text(
          texts.stepTitle(menu.stepId) ?? name,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        for (final o in menu.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: ValueKey('flowMenu-$o'),
              onPressed: _busy ? null : () => _choose(menu, o),
              child: Text(texts.menuOption(menu.stepId, o)),
            ),
          ),
      ],
      final HaFlowDone done => _done(context, done),
      final HaFlowAborted aborted => [
        InlineNotice.warning(
          texts.abort(aborted.reason) == null
              ? l10n.flowAbortedGeneric
              : l10n.flowAborted(texts.abort(aborted.reason)!),
        ),
      ],
      HaFlowUnsupported() => [InlineNotice.info(l10n.flowUnsupported)],
    };

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: body,
      ),
    );
  }

  List<Widget> _form(
    BuildContext context,
    HaFlowForm form,
    FlowTexts texts,
    String name,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final description =
        texts.stepDescription(form.stepId) ??
        (form.fields.isEmpty ? l10n.flowConfirm(name) : null);
    final baseError = form.errors['base'];
    return [
      Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              _handlerIcon(form.handler),
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texts.stepTitle(form.stepId) ?? name,
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      if (description != null) ...[
        const SizedBox(height: 12),
        Text(description, key: const Key('flowDescription')),
      ],
      if (baseError != null) ...[
        const SizedBox(height: 12),
        InlineNotice.error(texts.error(baseError) ?? baseError),
      ],
      if (!form.supported) ...[
        const SizedBox(height: 12),
        InlineNotice.info(l10n.flowUnsupportedField),
      ] else ...[
        for (final f in form.fields) ...[
          const SizedBox(height: 16),
          _field(context, form, f, texts),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('flowSubmit'),
          onPressed: _busy ? null : () => _submit(form),
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(form.fields.isEmpty ? l10n.flowAdd : l10n.flowNext),
        ),
      ],
    ];
  }

  Widget _field(
    BuildContext context,
    HaFlowForm form,
    HaFlowField f,
    FlowTexts texts,
  ) {
    final l10n = context.l10n;
    final label = texts.field(form.stepId, f.name);
    final help = texts.fieldHelp(form.stepId, f.name);
    final error = form.errors[f.name];
    final errorText = error == null ? null : (texts.error(error) ?? error);
    return switch (f.kind) {
      HaFieldKind.text || HaFieldKind.number => TextField(
        key: ValueKey('flowField-${f.name}'),
        controller: _text[f.name],
        obscureText: f.secret,
        autocorrect: !f.secret,
        enableSuggestions: !f.secret,
        keyboardType: f.kind == HaFieldKind.number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          helperText: help ?? (f.required ? l10n.flowRequired : null),
          errorText: errorText,
        ),
      ),
      HaFieldKind.boolean => SwitchListTile(
        key: ValueKey('flowField-${f.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: help == null ? null : Text(help),
        value: _values[f.name] == true,
        onChanged: (v) => setState(() => _values[f.name] = v),
      ),
      HaFieldKind.select => DropdownButtonFormField<String>(
        key: ValueKey('flowField-${f.name}'),
        initialValue: f.options.any((o) => o.$1 == '${_values[f.name]}')
            ? '${_values[f.name]}'
            : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          errorText: errorText,
        ),
        items: [
          for (final (value, text) in f.options)
            DropdownMenuItem(value: value, child: Text(text)),
        ],
        onChanged: (v) => setState(() => _values[f.name] = v),
      ),
      HaFieldKind.unsupported => const SizedBox.shrink(),
    };
  }

  List<Widget> _done(BuildContext context, HaFlowDone done) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final added = [
      for (final d in devices.values)
        if (!_knownDevices.contains(d.id) && !d.isAuxiliary) d,
    ];
    return [
      const SizedBox(height: 16),
      Icon(
        Icons.check_circle_outline,
        size: 64,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.flowDone(done.title),
        key: const Key('flowDone'),
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge,
      ),
      if (added.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(l10n.flowDoneDevices, style: theme.textTheme.titleMedium),
        for (final d in added)
          ListTile(
            leading: Icon(DevicePresentation.icon(d)),
            title: Text(d.name),
            subtitle: Text(DevicePresentation.status(l10n, d)),
            onTap: () => context.push(AppRoutes.device(d.id)),
          ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        key: const Key('flowFinish'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.flowFinish),
      ),
    ];
  }
}
