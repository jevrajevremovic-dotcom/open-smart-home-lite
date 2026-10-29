import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../authentication/application/session_controller.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_history.dart' show historyStateLabel;
import '../../devices/presentation/device_presentation.dart';
import '../domain/simple_automation.dart';
import '../../../core/widgets/time_picker.dart';

enum _TriggerKind { time, device, value, sun }

String serviceLabel(AppLocalizations l10n, SmartHomeDevice? d, String svc) =>
    switch (svc) {
      'turn_on' when d?.kind.isRoutine ?? false => l10n.svc_activate,
      'turn_on' => l10n.svc_turn_on,
      'turn_off' => l10n.svc_turn_off,
      'open_cover' => l10n.svc_open_cover,
      'close_cover' => l10n.svc_close_cover,
      'lock' => l10n.svc_lock,
      'start' => l10n.svc_start,
      'return_to_base' => l10n.svc_return_to_base,
      'media_play' => l10n.svc_media_play,
      'media_pause' => l10n.svc_media_pause,
      _ => svc,
    };

String _clock(BuildContext context, int hour, int minute) =>
    TimeOfDay(hour: hour, minute: minute).format(context);

String _num(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Builds a "when … (only if …) then …" automation and saves it in HA.
class AutomationEditorScreen extends ConsumerStatefulWidget {
  const AutomationEditorScreen({super.key, this.existingId, this.initial});

  /// Editing: the automation's config id and its parsed content.
  final String? existingId;
  final SimpleAutomation? initial;

  @override
  ConsumerState<AutomationEditorScreen> createState() =>
      _AutomationEditorScreenState();
}

class _AutomationEditorScreenState
    extends ConsumerState<AutomationEditorScreen> {
  final _name = TextEditingController();
  final List<AutomationTrigger> _triggers = [];
  final Set<int> _weekdays = {};
  final List<AutomationCondition> _conditions = [];
  final List<AutomationAction> _actions = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a == null) return;
    _name.text = a.alias;
    _triggers.addAll(a.triggers);
    _actions.addAll(a.actions);
    for (final c in a.conditions) {
      if (c is WeekdayCondition) {
        _weekdays.addAll(c.weekdays);
      } else {
        _conditions.add(c);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<AutomationCondition> get _allConditions => [
    if (_weekdays.isNotEmpty && _weekdays.length < 7)
      WeekdayCondition({..._weekdays}),
    ..._conditions,
  ];

  Future<String?> _pickDevice(bool Function(SmartHomeDevice) filter) =>
      pickAutomationDevice(context, filter);

  Future<void> _editTrigger([int? index]) async {
    final t = await showDialog<AutomationTrigger>(
      context: context,
      builder: (_) =>
          _TriggerDialog(initial: index == null ? null : _triggers[index]),
    );
    if (t == null || !mounted) return;
    setState(() {
      if (index == null) {
        _triggers.add(t);
      } else {
        _triggers[index] = t;
      }
    });
  }

  Future<void> _addCondition() async {
    final l10n = context.l10n;
    final kind = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.autoAddCondition),
        children: [
          for (final (k, icon, label) in [
            ('time', Icons.schedule, l10n.autoCondTime),
            ('device', Icons.sensors, l10n.autoCondDevice),
            ('dark', Icons.nights_stay_outlined, l10n.autoCondDark),
            ('light', Icons.wb_sunny_outlined, l10n.autoCondLight),
          ])
            SimpleDialogOption(
              key: ValueKey('cond-$k'),
              onPressed: () => Navigator.of(context).pop(k),
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final AutomationCondition? c = switch (kind) {
      'time' => await _pickWindow(),
      'device' => await _pickStateCondition(),
      'dark' => const SunCondition(dark: true),
      _ => const SunCondition(dark: false),
    };
    if (c == null || !mounted) return;
    setState(() {
      // Dark and light exclude each other; keep only the newest.
      if (c is SunCondition) _conditions.removeWhere((e) => e is SunCondition);
      _conditions.add(c);
    });
  }

  Future<AutomationCondition?> _pickWindow() async {
    final l10n = context.l10n;
    final from = await showAppTimePicker(
      context: context,
      helpText: l10n.autoCondAfter,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
    );
    if (from == null || !mounted) return null;
    final until = await showAppTimePicker(
      context: context,
      helpText: l10n.autoCondBefore,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
    );
    if (until == null) return null;
    return TimeWindowCondition(
      after: ClockTime(from.hour, from.minute),
      before: ClockTime(until.hour, until.minute),
    );
  }

  Future<AutomationCondition?> _pickStateCondition() async {
    final l10n = context.l10n;
    final id = await _pickDevice((d) => triggerStatesFor(d).isNotEmpty);
    if (id == null || !mounted) return null;
    final d = ref.read(deviceProvider(id));
    if (d == null) return null;
    final state = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${d.name} ${l10n.autoIs}'),
        children: [
          for (final st in triggerStatesFor(d))
            SimpleDialogOption(
              key: ValueKey('condState-$st'),
              onPressed: () => Navigator.of(context).pop(st),
              child: Text(historyStateLabel(l10n, st, d.kind)),
            ),
        ],
      ),
    );
    return state == null ? null : StateCondition(id, state);
  }

  Future<void> _addAction() async {
    final l10n = context.l10n;
    final id = await _pickDevice((d) => actionServicesFor(d).isNotEmpty);
    if (id == null || !mounted) return;
    final d = ref.read(deviceProvider(id));
    if (d == null) return;
    final services = actionServicesFor(d);
    final svc = services.length == 1
        ? services.first
        : await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(d.name),
              children: [
                for (final s in services)
                  SimpleDialogOption(
                    key: ValueKey('svc-$s'),
                    onPressed: () => Navigator.of(context).pop(s),
                    child: Text(serviceLabel(l10n, d, s)),
                  ),
              ],
            ),
          );
    if (svc != null) setState(() => _actions.add(AutomationAction(id, svc)));
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_triggers.isEmpty || _actions.isEmpty) {
      setState(() => _error = l10n.autoIncomplete);
      return;
    }
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final name = _name.text.trim().isEmpty ? _summary() : _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final id =
          widget.existingId ?? DateTime.now().millisecondsSinceEpoch.toString();
      await api.saveAutomation(
        id,
        SimpleAutomation(
          alias: name,
          triggers: _triggers,
          conditions: _allConditions,
          actions: _actions,
        ).toConfig(id),
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoSaved)));
      navigator.pop();
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.autoSaveFailed;
        });
      }
    }
  }

  /// A readable default name, e.g. "07:00 → Hallway light".
  String _summary() {
    final when = triggerLabel(context, ref, _triggers.first);
    final what = _actions
        .map((a) => ref.read(deviceProvider(a.entityId))?.name ?? a.entityId)
        .join(', ');
    return '$when → $what';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = l10n.localeName;

    Widget header(String text, [String? hint]) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );

    Widget removable({
      required Key key,
      required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap,
      required VoidCallback onRemove,
    }) => Card(
      key: key,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: onTap,
        trailing: IconButton(
          tooltip: l10n.cancel,
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingId == null ? l10n.autoNew : l10n.autoEdit),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(l10n.autoHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            key: const Key('autoName'),
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.autoName,
              hintText: l10n.autoNameHint,
            ),
          ),
          header(
            l10n.autoWhen,
            _triggers.length > 1 ? l10n.autoAnyTrigger : null,
          ),
          for (final (i, t) in _triggers.indexed)
            removable(
              key: ValueKey('trigger-$i'),
              icon: triggerIcon(t),
              title: triggerLabel(context, ref, t),
              onTap: () => _editTrigger(i),
              onRemove: () => setState(() => _triggers.removeAt(i)),
            ),
          OutlinedButton.icon(
            key: const Key('autoAddTrigger'),
            onPressed: _editTrigger,
            icon: const Icon(Icons.add),
            label: Text(l10n.autoAddTrigger),
          ),
          header(l10n.autoOnlyIf, l10n.autoOnlyIfHint),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: ValueKey('autoDay-$d'),
                  label: Text(
                    DateFormat.E(locale).format(DateTime(2024, 1, d)),
                  ),
                  selected: _weekdays.contains(d),
                  onSelected: (v) => setState(
                    () => v ? _weekdays.add(d) : _weekdays.remove(d),
                  ),
                ),
            ],
          ),
          if (_weekdays.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l10n.autoEveryDay, style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          for (final (i, c) in _conditions.indexed)
            removable(
              key: ValueKey('condition-$i'),
              icon: switch (c) {
                TimeWindowCondition() => Icons.schedule,
                SunCondition(dark: true) => Icons.nights_stay_outlined,
                SunCondition() => Icons.wb_sunny_outlined,
                _ => Icons.sensors,
              },
              title: conditionLabel(context, ref, c),
              onRemove: () => setState(() => _conditions.removeAt(i)),
            ),
          OutlinedButton.icon(
            key: const Key('autoAddCondition'),
            onPressed: _addCondition,
            icon: const Icon(Icons.add),
            label: Text(l10n.autoAddCondition),
          ),
          header(l10n.autoThen),
          for (final (i, a) in _actions.indexed)
            Card(
              child: Consumer(
                builder: (context, ref, _) {
                  final d = ref.watch(deviceProvider(a.entityId));
                  return ListTile(
                    leading: Icon(
                      d == null ? Icons.bolt : DevicePresentation.icon(d),
                    ),
                    title: Text(d?.name ?? a.entityId),
                    subtitle: Text(serviceLabel(l10n, d, a.service)),
                    trailing: IconButton(
                      tooltip: l10n.cancel,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _actions.removeAt(i)),
                    ),
                  );
                },
              ),
            ),
          OutlinedButton.icon(
            key: const Key('autoAddAction'),
            onPressed: _addAction,
            icon: const Icon(Icons.add),
            label: Text(l10n.autoAddAction),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InlineNotice.error(_error!),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('autoSave'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l10n.autoSave),
          ),
        ],
      ),
    );
  }
}

IconData triggerIcon(AutomationTrigger t) => switch (t) {
  TimeTrigger() => Icons.schedule,
  DeviceTrigger() => Icons.sensors,
  NumericTrigger() => Icons.show_chart,
  SunTrigger(sunset: true) => Icons.nights_stay_outlined,
  SunTrigger() => Icons.wb_sunny_outlined,
};

DeviceKind? _kind(WidgetRef ref, String id) =>
    ref.read(deviceProvider(id))?.kind;

String _deviceName(WidgetRef ref, String id) =>
    ref.read(deviceProvider(id))?.name ?? id;

/// One line describing a trigger, e.g. "Front door → Open".
String triggerLabel(BuildContext context, WidgetRef ref, AutomationTrigger t) {
  final l10n = context.l10n;
  return switch (t) {
    TimeTrigger(:final hour, :final minute) => _clock(context, hour, minute),
    DeviceTrigger(:final entityId, :final toState) =>
      '${_deviceName(ref, entityId)} → '
          '${historyStateLabel(l10n, toState, _kind(ref, entityId))}',
    NumericTrigger(:final entityId, :final above, :final threshold) =>
      '${_deviceName(ref, entityId)} ${above ? '>' : '<'} ${_num(threshold)}'
          '${switch (ref.read(deviceProvider(entityId))?.state.unit) {
            final String u => ' $u',
            _ => '',
          }}',
    SunTrigger(:final sunset, :final offsetMinutes) =>
      '${sunset ? l10n.autoSunset : l10n.autoSunrise}'
          '${offsetMinutes == 0 ? '' : ' (${offsetMinutes > 0 ? '+' : ''}${l10n.autoOffset(offsetMinutes)})'}',
  };
}

/// One line describing a condition.
String conditionLabel(
  BuildContext context,
  WidgetRef ref,
  AutomationCondition c,
) {
  final l10n = context.l10n;
  String clock(ClockTime? t) =>
      t == null ? '…' : _clock(context, t.hour, t.minute);
  return switch (c) {
    WeekdayCondition() => l10n.autoEveryDay,
    TimeWindowCondition(:final after, :final before) =>
      '${clock(after)} – ${clock(before)}',
    StateCondition(:final entityId, :final state) =>
      '${_deviceName(ref, entityId)} ${l10n.autoIs} '
          '${historyStateLabel(l10n, state, _kind(ref, entityId))}',
    SunCondition(:final dark) => dark ? l10n.autoCondDark : l10n.autoCondLight,
  };
}

Future<String?> pickAutomationDevice(
  BuildContext context,
  bool Function(SmartHomeDevice) filter,
) => showDialog<String>(
  context: context,
  builder: (_) => _DevicePicker(filter: filter),
);

/// Chooses or changes one trigger.
class _TriggerDialog extends ConsumerStatefulWidget {
  const _TriggerDialog({this.initial});

  final AutomationTrigger? initial;

  @override
  ConsumerState<_TriggerDialog> createState() => _TriggerDialogState();
}

class _TriggerDialogState extends ConsumerState<_TriggerDialog> {
  _TriggerKind _kind = _TriggerKind.time;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  String? _device;
  String? _state;
  String? _sensor;
  bool _above = true;
  final _threshold = TextEditingController();
  bool _sunset = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    switch (widget.initial) {
      case TimeTrigger(:final hour, :final minute):
        _kind = _TriggerKind.time;
        _time = TimeOfDay(hour: hour, minute: minute);
      case DeviceTrigger(:final entityId, :final toState):
        _kind = _TriggerKind.device;
        _device = entityId;
        _state = toState;
      case NumericTrigger(:final entityId, :final above, :final threshold):
        _kind = _TriggerKind.value;
        _sensor = entityId;
        _above = above;
        _threshold.text = _num(threshold);
      case SunTrigger(:final sunset, :final offsetMinutes):
        _kind = _TriggerKind.sun;
        _sunset = sunset;
        _offset = offsetMinutes.clamp(-120, 120);
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _threshold.dispose();
    super.dispose();
  }

  num? get _value =>
      num.tryParse(_threshold.text.trim().replaceFirst(',', '.'));

  AutomationTrigger? get _result => switch (_kind) {
    _TriggerKind.time => TimeTrigger(_time.hour, _time.minute),
    _TriggerKind.device when _device != null && _state != null => DeviceTrigger(
      _device!,
      _state!,
    ),
    _TriggerKind.value when _sensor != null && _value != null => NumericTrigger(
      _sensor!,
      above: _above,
      threshold: _value!,
    ),
    _TriggerKind.sun => SunTrigger(sunset: _sunset, offsetMinutes: _offset),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final device = _device == null ? null : ref.watch(deviceProvider(_device!));
    final sensor = _sensor == null ? null : ref.watch(deviceProvider(_sensor!));

    return AlertDialog(
      title: Text(l10n.autoWhen),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (k, icon, label) in [
                    (_TriggerKind.time, Icons.schedule, l10n.autoTriggerTime),
                    (
                      _TriggerKind.device,
                      Icons.sensors,
                      l10n.autoTriggerDevice,
                    ),
                    (
                      _TriggerKind.value,
                      Icons.show_chart,
                      l10n.autoTriggerValue,
                    ),
                    (_TriggerKind.sun, Icons.wb_twilight, l10n.autoTriggerSun),
                  ])
                    ChoiceChip(
                      key: ValueKey('trigKind-${k.name}'),
                      showCheckmark: false,
                      avatar: Icon(icon, size: 18),
                      label: Text(label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...switch (_kind) {
                _TriggerKind.time => [
                  OutlinedButton.icon(
                    key: const Key('autoTime'),
                    onPressed: () async {
                      final t = await showAppTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null) setState(() => _time = t);
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(_time.format(context)),
                  ),
                ],
                _TriggerKind.device => [
                  OutlinedButton.icon(
                    key: const Key('autoTriggerDevice'),
                    onPressed: () async {
                      final id = await pickAutomationDevice(
                        context,
                        (d) => triggerStatesFor(d).isNotEmpty,
                      );
                      if (id == null) return;
                      final d = ref.read(deviceProvider(id));
                      setState(() {
                        _device = id;
                        _state = d == null ? null : triggerStatesFor(d).first;
                      });
                    },
                    icon: Icon(
                      device == null
                          ? Icons.add
                          : DevicePresentation.icon(device),
                    ),
                    label: Text(device?.name ?? l10n.autoPickDevice),
                  ),
                  if (device != null) ...[
                    const SizedBox(height: 8),
                    Text(l10n.autoChangesTo, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final st in triggerStatesFor(device))
                          ChoiceChip(
                            key: ValueKey('autoState-$st'),
                            label: Text(
                              historyStateLabel(l10n, st, device.kind),
                            ),
                            selected: _state == st,
                            onSelected: (_) => setState(() => _state = st),
                          ),
                      ],
                    ),
                  ],
                ],
                _TriggerKind.value => [
                  OutlinedButton.icon(
                    key: const Key('autoTriggerSensor'),
                    onPressed: () async {
                      final id = await pickAutomationDevice(
                        context,
                        hasNumericTrigger,
                      );
                      if (id == null) return;
                      final d = ref.read(deviceProvider(id));
                      setState(() {
                        _sensor = id;
                        if (_threshold.text.isEmpty &&
                            d?.state.numericValue != null) {
                          _threshold.text = _num(
                            d!.state.numericValue!.roundToDouble(),
                          );
                        }
                      });
                    },
                    icon: Icon(
                      sensor == null
                          ? Icons.add
                          : DevicePresentation.icon(sensor),
                    ),
                    label: Text(sensor?.name ?? l10n.autoPickDevice),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.trending_up),
                        label: Text(l10n.autoAbove),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.trending_down),
                        label: Text(l10n.autoBelow),
                      ),
                    ],
                    selected: {_above},
                    onSelectionChanged: (s) => setState(() => _above = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('autoThreshold'),
                    controller: _threshold,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.autoThreshold,
                      suffixText: sensor?.state.unit,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                _TriggerKind.sun => [
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.wb_sunny_outlined),
                        label: Text(l10n.autoSunrise),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.nights_stay_outlined),
                        label: Text(l10n.autoSunset),
                      ),
                    ],
                    selected: {_sunset},
                    onSelectionChanged: (s) =>
                        setState(() => _sunset = s.first),
                  ),
                  Slider(
                    value: _offset.toDouble(),
                    min: -120,
                    max: 120,
                    divisions: 16,
                    label: l10n.autoOffset(_offset),
                    onChanged: (v) => setState(() => _offset = v.round()),
                  ),
                  Text(
                    l10n.autoOffset(_offset),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('trigOk'),
          onPressed: _result == null
              ? null
              : () => Navigator.of(context).pop(_result),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

/// Searchable list of devices accepted by [filter].
class _DevicePicker extends ConsumerStatefulWidget {
  const _DevicePicker({required this.filter});

  final bool Function(SmartHomeDevice) filter;

  @override
  ConsumerState<_DevicePicker> createState() => _DevicePickerState();
}

class _DevicePickerState extends ConsumerState<_DevicePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final list =
        devices.values
            .where(
              (d) =>
                  !d.isAuxiliary &&
                  d.kind != DeviceKind.unknown &&
                  widget.filter(d) &&
                  d.name.toLowerCase().contains(_q.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: Text(l10n.autoPickDevice),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 440,
        height: 460,
        child: Column(
          children: [
            TextField(
              key: const Key('pickSearch'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.searchHint,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final d in list)
                    ListTile(
                      key: ValueKey('pick-${d.id}'),
                      leading: Icon(DevicePresentation.icon(d)),
                      title: Text(d.name),
                      onTap: () => Navigator.of(context).pop(d.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
