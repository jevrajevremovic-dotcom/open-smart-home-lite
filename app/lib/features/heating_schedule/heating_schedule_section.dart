import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/l10n.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../authentication/application/session_controller.dart';
import '../devices/domain/smart_home_device.dart';
import 'heating_schedule.dart';

/// The saved schedule of a thermostat, read back from Home Assistant.
final heatingScheduleProvider = FutureProvider.autoDispose
    .family<HeatingSchedule?, String>((ref, climateId) async {
      if (!ref.watch(heatingScheduleSetProvider(climateId))) return null;
      final api = ref.watch(homeAssistantApiProvider);
      if (api == null) return null;
      return HeatingSchedule.fromAutomation(
        await api.fetchAutomation(heatingScheduleId(climateId)),
      );
    });

String _degrees(AppLocalizations l10n, double t) =>
    '${NumberFormat('0.#', l10n.localeName).format(t)}°';

/// "Weekly schedule" on a thermostat's screen.
class HeatingScheduleSection extends ConsumerStatefulWidget {
  const HeatingScheduleSection({super.key, required this.device});

  final SmartHomeDevice device;

  @override
  ConsumerState<HeatingScheduleSection> createState() =>
      _HeatingScheduleSectionState();
}

class _HeatingScheduleSectionState
    extends ConsumerState<HeatingScheduleSection> {
  bool _busy = false;

  void _say(ScaffoldMessengerState messenger, String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit(HeatingSchedule? current) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(homeAssistantApiProvider);
    if (api == null) return;
    final d = widget.device;
    final result = await showDialog<_Result>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: _ScheduleEditor(
          initial: current ?? HeatingSchedule.suggested(d.id),
          device: d,
          isSet: current != null,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (result.remove) {
        await api.deleteAutomation(heatingScheduleId(d.id));
        _say(messenger, l10n.heatingScheduleRemoved);
      } else {
        final schedule = result.schedule!;
        await api.saveAutomation(
          schedule.id,
          schedule.automation(l10n, d.name),
        );
        ref.invalidate(heatingScheduleProvider(d.id));
        _say(messenger, l10n.heatingScheduleSaved);
      }
    } on AppFailure catch (e) {
      _say(
        messenger,
        e.kind == FailureKind.authorization ||
                e.kind == FailureKind.authentication
            ? l10n.applianceDoneNeedsAdmin
            : failureMessage(l10n, e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSet = ref.watch(heatingScheduleSetProvider(widget.device.id));
    if (!isSet) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('heatingSchedule'),
          icon: const Icon(Icons.calendar_view_week_outlined),
          label: Text(l10n.heatingScheduleAction),
          onPressed: _busy ? null : () => _edit(null),
        ),
      );
    }
    final schedule = ref.watch(heatingScheduleProvider(widget.device.id));
    final value = schedule.value;
    final (_, next) = value?.around(DateTime.now()) ?? (null, null);
    return Card(
      child: ListTile(
        key: const Key('heatingScheduleSet'),
        leading: const Icon(Icons.calendar_view_week_outlined),
        title: Text(l10n.heatingScheduleTitle),
        subtitle: Text(
          next == null
              ? l10n.applianceDoneOnHint
              : l10n.heatingScheduleNext(
                  next.hhmm,
                  _degrees(l10n, next.temperature),
                ),
        ),
        trailing: TextButton(
          key: const Key('heatingScheduleEdit'),
          onPressed: _busy || schedule.isLoading
              ? null
              : () =>
                    _edit(value ?? HeatingSchedule.suggested(widget.device.id)),
          child: Text(l10n.applianceDoneChange),
        ),
      ),
    );
  }
}

class _Result {
  const _Result.save(HeatingSchedule this.schedule) : remove = false;
  const _Result.remove() : schedule = null, remove = true;

  final HeatingSchedule? schedule;
  final bool remove;
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({
    required this.initial,
    required this.device,
    required this.isSet,
  });

  final HeatingSchedule initial;
  final SmartHomeDevice device;
  final bool isSet;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late HeatingSchedule _schedule = widget.initial;

  double get _min => widget.device.limits.minTemperature ?? 7;
  double get _max => widget.device.limits.maxTemperature ?? 30;
  double get _step => widget.device.limits.temperatureStep ?? 0.5;

  List<SchedulePoint> _points(bool weekend) =>
      weekend ? _schedule.weekend : _schedule.workdays;

  void _set(bool weekend, List<SchedulePoint> points) {
    points.sort((a, b) => a.minute.compareTo(b.minute));
    setState(
      () => _schedule = weekend
          ? _schedule.copyWith(weekend: points)
          : _schedule.copyWith(workdays: points),
    );
  }

  /// Replaces point [i] (another one at the same time gives way).
  void _replace(bool weekend, int i, SchedulePoint p) {
    final points = [..._points(weekend)];
    points.removeAt(i);
    points.removeWhere((o) => o.minute == p.minute);
    _set(weekend, points..add(p));
  }

  void _add(bool weekend) {
    final points = [..._points(weekend)];
    var minute = points.isEmpty ? 7 * 60 : (points.last.minute + 120);
    minute %= 24 * 60;
    while (points.any((p) => p.minute == minute)) {
      minute = (minute + 30) % (24 * 60);
    }
    _set(weekend, points..add(SchedulePoint(minute, 20.0.clamp(_min, _max))));
  }

  Future<void> _pickTime(bool weekend, int i) async {
    final p = _points(weekend)[i];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.hour, minute: p.minute % 60),
    );
    if (picked == null || !mounted) return;
    _replace(
      weekend,
      i,
      SchedulePoint(picked.hour * 60 + picked.minute, p.temperature),
    );
  }

  void _nudge(bool weekend, int i, int direction) {
    final p = _points(weekend)[i];
    final t = (p.temperature + direction * _step).clamp(_min, _max);
    _replace(weekend, i, SchedulePoint(p.minute, t.toDouble()));
  }

  Widget _group(String title, bool weekend) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final points = _points(weekend);
    final tag = weekend ? 'e' : 'w';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        for (final (i, p) in points.indexed)
          Row(
            key: ValueKey('schedulePoint-$tag-$i'),
            children: [
              TextButton.icon(
                key: ValueKey('scheduleTime-$tag-$i'),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(
                  p.hhmm,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                onPressed: () => _pickTime(weekend, i),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('scheduleColder-$tag-$i'),
                tooltip: l10n.heatingScheduleColder,
                icon: const Icon(Icons.remove),
                onPressed: p.temperature <= _min
                    ? null
                    : () => _nudge(weekend, i, -1),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _degrees(l10n, p.temperature),
                  key: ValueKey('scheduleTemp-$tag-$i'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('scheduleWarmer-$tag-$i'),
                tooltip: l10n.heatingScheduleWarmer,
                icon: const Icon(Icons.add),
                onPressed: p.temperature >= _max
                    ? null
                    : () => _nudge(weekend, i, 1),
              ),
              IconButton(
                key: ValueKey('scheduleDelete-$tag-$i'),
                tooltip: l10n.applianceDoneRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _set(weekend, [...points]..removeAt(i)),
              ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('scheduleAdd-$tag'),
            icon: const Icon(Icons.add),
            label: Text(l10n.heatingScheduleAdd),
            onPressed: points.length >= 8 ? null : () => _add(weekend),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.heatingScheduleTitle),
        actions: [
          TextButton(
            key: const Key('heatingScheduleSave'),
            onPressed: _schedule.isEmpty
                ? null
                : () => Navigator.of(context).pop(_Result.save(_schedule)),
            child: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.device.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    l10n.heatingScheduleHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _group(l10n.heatingScheduleWorkdays, false),
                  _group(l10n.heatingScheduleWeekend, true),
                  if (widget.isSet) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('heatingScheduleRemove'),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.heatingScheduleRemove),
                        onPressed: () =>
                            Navigator.of(context).pop(const _Result.remove()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
