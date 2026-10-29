import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/l10n.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/capability.dart';
import '../../devices/domain/device_command.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/domain/smart_home_device.dart';
import '../../devices/presentation/device_presentation.dart';
import '../../weather/application/weather_providers.dart';
import '../application/routines_controller.dart';
import '../domain/routines.dart';
import 'scene_editor_screen.dart' show pickDevice;

/// A new automation, or [automation] to change: when (triggers), only if
/// (conditions), then (actions).
class AutomationEditorScreen extends ConsumerStatefulWidget {
  const AutomationEditorScreen({super.key, this.automation});

  final LocalAutomation? automation;

  @override
  ConsumerState<AutomationEditorScreen> createState() =>
      _AutomationEditorScreenState();
}

class _AutomationEditorScreenState
    extends ConsumerState<AutomationEditorScreen> {
  late final _name = TextEditingController(text: widget.automation?.name);
  late final _triggers = [...?widget.automation?.triggers];
  late final _conditions = [...?widget.automation?.conditions];
  late final _actions = [...?widget.automation?.actions];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<String, SmartHomeDevice> get _devices =>
      ref.read(homeSnapshotProvider).devices;

  String _deviceName(String id) => _devices[id]?.name ?? id;

  // -------------------------------------------------------------------------
  // Labels

  String _target(DeviceStateTarget t) {
    final l10n = context.l10n;
    return switch (t) {
      DeviceStateTarget.on => l10n.autoTargetOn,
      DeviceStateTarget.off => l10n.autoTargetOff,
      DeviceStateTarget.open => l10n.autoTargetOpen,
      DeviceStateTarget.closed => l10n.autoTargetClosed,
      DeviceStateTarget.active => l10n.autoTargetActive,
      DeviceStateTarget.inactive => l10n.autoTargetInactive,
      DeviceStateTarget.locked => l10n.autoTargetLocked,
      DeviceStateTarget.unlocked => l10n.autoTargetUnlocked,
    };
  }

  String _offset(int minutes) {
    final l10n = context.l10n;
    if (minutes == 0) return l10n.autoOffset(0);
    return '${l10n.autoOffset(minutes.abs())} '
        '${minutes < 0 ? l10n.autoBefore : l10n.autoAfter}';
  }

  String _triggerLabel(AutomationTrigger t) {
    final l10n = context.l10n;
    return switch (t) {
      TimeTrigger(:final at) => l10n.autoTriggerAt('$at'),
      SunTrigger(:final sunset, :final offsetMinutes) =>
        '${sunset ? l10n.autoSunset : l10n.autoSunrise} · ${_offset(offsetMinutes)}',
      DeviceTrigger(:final deviceId, :final to) => l10n.autoStateIs(
        _deviceName(deviceId),
        _target(to),
      ),
      ValueTrigger(:final deviceId, :final above, :final threshold) =>
        (above ? l10n.autoValueAbove : l10n.autoValueBelow)(
          _deviceName(deviceId),
          '$threshold ${_devices[deviceId]?.state.unit ?? ''}'.trim(),
        ),
    };
  }

  String _days(Set<int> days) {
    final l10n = context.l10n;
    if (days.isEmpty || days.length == 7) return l10n.autoEveryDay;
    final monday = DateTime(2024, 1, 1); // a Monday
    return [
      for (final d in days.toList()..sort())
        DateFormat.E(l10n.localeName).format(monday.add(Duration(days: d - 1))),
    ].join(', ');
  }

  String _conditionLabel(AutomationCondition c) {
    final l10n = context.l10n;
    return switch (c) {
      WeekdayCondition(:final weekdays) => _days(weekdays),
      TimeWindowCondition(:final after, :final before) =>
        '${l10n.autoCondAfter} ${after ?? '00:00'} '
            '${l10n.autoCondBefore} ${before ?? '24:00'}',
      StateCondition(:final deviceId, :final state) => l10n.autoStateIs(
        _deviceName(deviceId),
        _target(state),
      ),
      DarkCondition(:final dark) =>
        dark ? l10n.autoCondDark : l10n.autoCondLight,
    };
  }

  String _commandLabel(DeviceCommand c) {
    final l10n = context.l10n;
    return switch (c) {
      TurnOn() => l10n.autoActionTurnOn,
      TurnOff() => l10n.autoActionTurnOff,
      Toggle() => l10n.autoActionToggle,
      SetBrightness(:final percent) => l10n.autoActionBrightness(percent),
      OpenCover() => l10n.open,
      CloseCover() => l10n.close,
      SetCoverPosition(:final percent) => l10n.coverOpenPercent(percent),
      LockDevice() => l10n.lock,
      Activate() => l10n.autoActionScene,
      SetColorTemperature(:final kelvin) => '$kelvin K',
      SetRgbColor() => l10n.autoActionTurnOn,
      SetTargetTemperature(:final temperature) => '$temperature °',
      SetHvacMode(:final mode) => mode,
      _ => '${c.runtimeType}',
    };
  }

  // -------------------------------------------------------------------------
  // Adding

  Future<void> _addTrigger() async {
    final l10n = context.l10n;
    final kind = await _choose<String>(l10n.autoAddTrigger, {
      'time': (Icons.schedule, l10n.autoTriggerTime),
      'sun': (Icons.wb_twilight, l10n.autoTriggerSun),
      'device': (Icons.devices_other, l10n.autoTriggerDevice),
      'value': (Icons.show_chart, l10n.autoTriggerValue),
    });
    if (kind == null || !mounted) return;
    final AutomationTrigger? t = switch (kind) {
      'time' => await _pickTime().then(
        (v) => v == null ? null : TimeTrigger(v),
      ),
      'sun' => await _pickSun(),
      'device' => await _pickDeviceState().then(
        (v) => v == null ? null : DeviceTrigger(v.$1, v.$2),
      ),
      _ => await _pickValue(),
    };
    if (t != null) setState(() => _triggers.add(t));
  }

  Future<void> _addCondition() async {
    final l10n = context.l10n;
    final kind = await _choose<String>(l10n.autoAddCondition, {
      'days': (Icons.calendar_view_week, l10n.autoDays),
      'between': (Icons.schedule, l10n.autoCondTime),
      'device': (Icons.devices_other, l10n.autoCondDevice),
      'dark': (Icons.dark_mode_outlined, l10n.autoCondDark),
      'light': (Icons.light_mode_outlined, l10n.autoCondLight),
    });
    if (kind == null || !mounted) return;
    final AutomationCondition? c = switch (kind) {
      'days' => await _pickDays(),
      'between' => await _pickWindow(),
      'device' => await _pickDeviceState().then(
        (v) => v == null ? null : StateCondition(v.$1, v.$2),
      ),
      'dark' => const DarkCondition(dark: true),
      _ => const DarkCondition(dark: false),
    };
    if (c != null) setState(() => _conditions.add(c));
  }

  Future<void> _addAction() async {
    final l10n = context.l10n;
    final id = await pickDevice(
      context,
      where: (d) =>
          !d.isAuxiliary &&
          (d.kind == DeviceKind.scene ||
              d.supports(Capability.power) && d.kind != DeviceKind.automation ||
              d.supports(Capability.open) ||
              d.supports(Capability.lock)),
    );
    final d = id == null ? null : _devices[id];
    if (d == null || !mounted) return;
    final options = <String, (IconData, String, DeviceCommand)>{
      if (d.kind == DeviceKind.scene)
        'scene': (Icons.play_arrow, l10n.autoActionScene, const Activate()),
      if (d.supports(Capability.power) && d.kind != DeviceKind.scene) ...{
        'on': (Icons.power_settings_new, l10n.autoActionTurnOn, const TurnOn()),
        'off': (Icons.power_off, l10n.autoActionTurnOff, const TurnOff()),
        'toggle': (Icons.sync, l10n.autoActionToggle, const Toggle()),
      },
      if (d.supports(Capability.open)) ...{
        'open': (Icons.arrow_upward, l10n.open, const OpenCover()),
        'close': (Icons.arrow_downward, l10n.close, const CloseCover()),
      },
      if (d.supports(Capability.lock))
        'lock': (Icons.lock_outline, l10n.lock, const LockDevice()),
    };
    if (d.supports(Capability.brightness)) {
      options['brightness'] = (
        Icons.brightness_6,
        l10n.brightness,
        const SetBrightness(50),
      );
    }
    final chosen = options.length == 1
        ? options.keys.single
        : await _choose<String>(l10n.autoPickAction, {
            for (final e in options.entries) e.key: (e.value.$1, e.value.$2),
          });
    if (chosen == null || !mounted) return;
    var command = options[chosen]!.$3;
    if (chosen == 'brightness') {
      final percent = await _pickPercent(l10n.brightness, 50);
      if (percent == null) return;
      command = SetBrightness(percent);
    }
    setState(() => _actions.add(DeviceAction(d.id, command)));
  }

  // -------------------------------------------------------------------------
  // Dialogs

  Future<T?> _choose<T>(String title, Map<T, (IconData, String)> options) =>
      showDialog<T>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(title),
          children: [
            for (final e in options.entries)
              ListTile(
                key: ValueKey('choose-${e.key}'),
                leading: Icon(e.value.$1),
                title: Text(e.value.$2),
                onTap: () => Navigator.of(context).pop(e.key),
              ),
          ],
        ),
      );

  Future<ClockTime?> _pickTime([ClockTime? initial]) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initial?.hour ?? 7,
        minute: initial?.minute ?? 0,
      ),
    );
    return t == null ? null : ClockTime(t.hour, t.minute);
  }

  Future<SunTrigger?> _pickSun() async {
    final l10n = context.l10n;
    var sunset = true;
    var offset = 0.0;
    return showDialog<SunTrigger>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.autoTriggerSun),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.autoSunrise)),
                  ButtonSegment(value: true, label: Text(l10n.autoSunset)),
                ],
                selected: {sunset},
                onSelectionChanged: (v) => setState(() => sunset = v.first),
              ),
              const SizedBox(height: 16),
              Text(_offset(offset.round())),
              Slider(
                value: offset,
                min: -120,
                max: 120,
                divisions: 48,
                onChanged: (v) => setState(() => offset = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('sunOk'),
              onPressed: () => Navigator.of(
                context,
              ).pop(SunTrigger(sunset: sunset, offsetMinutes: offset.round())),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<(String, DeviceStateTarget)?> _pickDeviceState() async {
    final id = await pickDevice(
      context,
      where: (d) =>
          !d.kind.isRoutine &&
          d.kind != DeviceKind.button &&
          (d.supports(Capability.power) ||
              d.state.isActive != null ||
              d.state.coverState != null ||
              d.state.lockState != null),
    );
    final d = id == null ? null : _devices[id];
    if (d == null || !mounted) return null;
    final states = DeviceStateTarget.of(d);
    final s = await _choose<DeviceStateTarget>(d.name, {
      for (final t in states) t: (Icons.circle_outlined, _target(t)),
    });
    return s == null ? null : (d.id, s);
  }

  Future<ValueTrigger?> _pickValue() async {
    final l10n = context.l10n;
    final id = await pickDevice(
      context,
      where: (d) => d.state.numericValue != null && !d.kind.isRoutine,
    );
    final d = id == null ? null : _devices[id];
    if (d == null || !mounted) return null;
    var above = true;
    final controller = TextEditingController(
      text: '${d.state.numericValue?.round() ?? 0}',
    );
    final result = await showDialog<ValueTrigger>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(d.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(l10n.autoAbove)),
                  ButtonSegment(value: false, label: Text(l10n.autoBelow)),
                ],
                selected: {above},
                onSelectionChanged: (v) => setState(() => above = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('valueThreshold'),
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.autoThreshold,
                  suffixText: d.state.unit,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('valueOk'),
              onPressed: () {
                final v = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (v == null) return;
                Navigator.of(context)
                    .pop(ValueTrigger(d.id, above: above, threshold: v));
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<WeekdayCondition?> _pickDays() async {
    final l10n = context.l10n;
    final days = <int>{1, 2, 3, 4, 5};
    final monday = DateTime(2024, 1, 1);
    return showDialog<WeekdayCondition>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.autoDays),
          content: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: ValueKey('day-$d'),
                  label: Text(
                    DateFormat.E(l10n.localeName)
                        .format(monday.add(Duration(days: d - 1))),
                  ),
                  selected: days.contains(d),
                  onSelected: (v) =>
                      setState(() => v ? days.add(d) : days.remove(d)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('daysOk'),
              onPressed: () =>
                  Navigator.of(context).pop(WeekdayCondition({...days})),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<TimeWindowCondition?> _pickWindow() async {
    final after = await _pickTime(const ClockTime(22, 0));
    if (after == null || !mounted) return null;
    final before = await _pickTime(const ClockTime(6, 0));
    if (before == null) return null;
    return TimeWindowCondition(after: after, before: before);
  }

  Future<int?> _pickPercent(String title, int initial) {
    var value = initial.toDouble();
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value.round()} %'),
              Slider(
                value: value,
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('percentOk'),
              onPressed: () => Navigator.of(context).pop(value.round()),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_triggers.isEmpty || _actions.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.autoIncomplete)));
      return;
    }
    final old = widget.automation;
    final name = _name.text.trim().isEmpty
        ? _triggerLabel(_triggers.first)
        : _name.text.trim();
    await ref
        .read(routinesProvider.notifier)
        .saveAutomation(
          (old ?? LocalAutomation(id: RoutinesController.newId(), name: name))
              .copyWith(
                name: name,
                triggers: [..._triggers],
                conditions: [..._conditions],
                actions: [..._actions],
              ),
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.autoSavedLocal)));
    navigator.pop();
  }

  Widget _item(String key, IconData icon, String label, VoidCallback remove) =>
      Card.outlined(
        child: ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: Text(label),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.delete,
            onPressed: remove,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    ref.watch(homeSnapshotProvider.select((s) => s.devices.length));
    final needsHome =
        _triggers.any((t) => t is SunTrigger) &&
        ref.watch(homeLocationWeatherEnabledProvider) == null;
    Widget header(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.automation?.name ?? l10n.autoNew)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ConstrainedContent(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InlineNotice.info(l10n.autoHintLocal),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('autoName'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.autoName,
                    hintText: l10n.autoNameHint,
                  ),
                ),
                header(l10n.autoWhen, hint: l10n.autoAnyTrigger),
                for (final (i, t) in _triggers.indexed)
                  _item(
                    'trigger-$i',
                    switch (t) {
                      TimeTrigger() => Icons.schedule,
                      SunTrigger() => Icons.wb_twilight,
                      DeviceTrigger() => Icons.devices_other,
                      ValueTrigger() => Icons.show_chart,
                    },
                    _triggerLabel(t),
                    () => setState(() => _triggers.removeAt(i)),
                  ),
                if (needsHome) InlineNotice.warning(l10n.autoSunNeedsHome),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('autoAddTrigger'),
                    onPressed: _addTrigger,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.autoAddTrigger),
                  ),
                ),
                header(l10n.autoOnlyIf, hint: l10n.autoOnlyIfHint),
                for (final (i, c) in _conditions.indexed)
                  _item(
                    'condition-$i',
                    Icons.rule,
                    _conditionLabel(c),
                    () => setState(() => _conditions.removeAt(i)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('autoAddCondition'),
                    onPressed: _addCondition,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.autoAddCondition),
                  ),
                ),
                header(l10n.autoThen),
                for (final (i, a) in _actions.indexed)
                  _item(
                    'action-$i',
                    switch (_devices[a.deviceId]) {
                      final d? => DevicePresentation.icon(d),
                      null => Icons.help_outline,
                    },
                    '${_deviceName(a.deviceId)}: ${_commandLabel(a.command)}',
                    () => setState(() => _actions.removeAt(i)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('autoAddAction'),
                    onPressed: _addAction,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.autoAddAction),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('autoSave'),
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
