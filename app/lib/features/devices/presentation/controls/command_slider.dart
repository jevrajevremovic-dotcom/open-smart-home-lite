import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Slider that sends a command only when the user lets go.
///
/// While dragging, and after release until the device reports the new value
/// (or a timeout passes), it shows the local value — so the thumb does not
/// jump back while the command travels to the device.
class CommandSlider extends StatefulWidget {
  const CommandSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    required this.format,
    this.enabled = true,
    this.divisions,
    this.leading,
    this.trailing,
  });

  final String label;

  /// Value reported by the device; `null` when unknown.
  final double? value;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final Future<void> Function(double value) onCommit;
  final String Function(double value) format;
  final Widget? leading;
  final Widget? trailing;

  @override
  State<CommandSlider> createState() => _CommandSliderState();
}

class _CommandSliderState extends State<CommandSlider> {
  double? _local;
  Timer? _settleTimer;

  @override
  void didUpdateWidget(CommandSlider old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) _clearLocal();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  void _clearLocal() {
    _settleTimer?.cancel();
    _local = null;
  }

  /// A tick at every tenth of the range, as on the big slider.
  int? _lastStep;

  void _changed(double v) {
    final step = ((v - widget.min) / (widget.max - widget.min) * 10).floor();
    if (_lastStep != null && step != _lastStep) {
      unawaited(HapticFeedback.selectionClick());
    }
    _lastStep = step;
    setState(() => _local = v);
  }

  Future<void> _commit(double value) async {
    _lastStep = null;
    _settleTimer?.cancel();
    // Fall back to the reported value if the device never confirms.
    _settleTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(_clearLocal);
    });
    await widget.onCommit(value);
  }

  @override
  Widget build(BuildContext context) {
    final shown = (_local ?? widget.value ?? widget.min).clamp(
      widget.min,
      widget.max,
    );
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: theme.textTheme.titleSmall),
            ),
            Text(
              widget.value == null && _local == null
                  ? '—'
                  : widget.format(shown),
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        Row(
          children: [
            ?widget.leading,
            Expanded(
              child: Slider(
                value: shown,
                min: widget.min,
                max: widget.max,
                divisions: widget.divisions,
                label: widget.format(shown),
                semanticFormatterCallback: widget.format,
                onChanged: widget.enabled ? _changed : null,
                onChangeEnd: widget.enabled ? _commit : null,
              ),
            ),
            ?widget.trailing,
          ],
        ),
      ],
    );
  }
}
