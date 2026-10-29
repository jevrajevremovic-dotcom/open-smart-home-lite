import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/localization/l10n.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../devices/application/device_providers.dart';
import '../../devices/domain/device_kind.dart';
import '../../devices/presentation/device_grid.dart';
import '../../devices/presentation/device_presentation.dart';
import '../application/energy_providers.dart';
import '../data/energy_repository.dart';
import '../data/tariff.dart';
import 'energy_chart.dart';
import 'energy_format.dart';
import 'low_tariff_reminder_button.dart';
import '../../../core/widgets/skeleton.dart';

/// Energy overview: live power, consumption for today / this week / this
/// month, grid, solar, battery, gas, top consumers and a cost estimate.
/// Everything comes from Home Assistant; nothing is estimated except the
/// cost, which is labelled as such and needs a tariff from the user.
class EnergyScreen extends ConsumerWidget {
  const EnergyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(energyRangeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.energyTitle)),
      body: MockModeBanner(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(energyPrefsProvider);
            await ref.read(energyReportProvider.future).catchError((_) => null);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ConstrainedContent(
                maxWidth: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CurrentPower(),
                    const SizedBox(height: 8),
                    SegmentedButton<EnergyRange>(
                      segments: [
                        ButtonSegment(
                          value: EnergyRange.today,
                          label: Text(l10n.energyToday),
                        ),
                        ButtonSegment(
                          value: EnergyRange.week,
                          label: Text(l10n.energyWeek),
                        ),
                        ButtonSegment(
                          value: EnergyRange.month,
                          label: Text(l10n.energyMonth),
                        ),
                      ],
                      selected: {range},
                      onSelectionChanged: (s) => ref
                          .read(energyRangeProvider.notifier)
                          .select(s.single),
                    ),
                    const SizedBox(height: 8),
                    const _ReportSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live power from power sensors (not part of statistics, always current).
class _CurrentPower extends ConsumerWidget {
  const _CurrentPower();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devices = ref.watch(homeSnapshotProvider.select((s) => s.devices));
    final meters =
        devices.values
            .where(
              (d) =>
                  d.kind == DeviceKind.powerMeter &&
                  d.available &&
                  d.state.numericValue != null,
            )
            .toList()
          ..sort(
            (a, b) => b.state.numericValue!.compareTo(a.state.numericValue!),
          );
    if (meters.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.energyCurrentPower),
        TileWrap(
          children: [
            for (final m in meters.take(4))
              _StatTile(
                icon: Icons.bolt,
                label: m.name,
                value: DevicePresentation.sensorValue(l10n, m.state),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReportSection extends ConsumerWidget {
  const _ReportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(energyReportProvider);
    return switch (report) {
      AsyncData(value: null) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: InlineNotice.info(l10n.energyNotConfigured),
      ),
      AsyncData(:final value?) => _Report(report: value),
      AsyncError(error: EnergyUnavailableOffline()) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: InlineNotice.warning(l10n.energyOffline),
      ),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: InlineNotice.error(
          error is AppFailure
              ? failureMessage(l10n, error)
              : l10n.failureUnknown,
        ),
      ),
      _ => Shimmer(
        label: l10n.loadingContent,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 8),
            TileWrap(
              children: [
                SkeletonBox(height: 72, radius: 20),
                SkeletonBox(height: 72, radius: 20),
                SkeletonBox(height: 72, radius: 20),
                SkeletonBox(height: 72, radius: 20),
              ],
            ),
            SizedBox(height: 24),
            SkeletonBox(height: 240, radius: 24),
          ],
        ),
      ),
    };
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.report});

  final EnergyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    final tariff = ref.watch(tariffProvider);
    String kwh(double v) => formatKwh(locale, v);
    final cost = tariff?.estimate(
      gridImport: report.gridImport,
      gridExport: report.gridExport,
      gridImportLow: report.gridImportLow,
    );
    final low = tariff?.low;
    final importLow = low == null ? null : report.gridImportLow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        if (low != null) ...[_RateNow(low: low), const SizedBox(height: 12)],
        TileWrap(
          children: [
            if (report.consumption != null)
              _StatTile(
                key: const Key('energyConsumptionTile'),
                icon: Icons.home_outlined,
                label: l10n.energyConsumption,
                value: kwh(report.consumption!),
                detail: switch (ref.watch(previousConsumptionProvider).value) {
                  final double prev => switch (report.range) {
                    EnergyRange.today => l10n.energyPrevDay(kwh(prev)),
                    EnergyRange.week => l10n.energyPrevWeek(kwh(prev)),
                    EnergyRange.month => l10n.energyPrevMonth(kwh(prev)),
                  },
                  _ => null,
                },
              ),
            if (report.gridImport != null)
              _StatTile(
                icon: Icons.electrical_services,
                label: l10n.energyFromGrid,
                value: kwh(report.gridImport!),
              ),
            if (importLow != null && report.gridImport != null) ...[
              _StatTile(
                key: const Key('energyHighRate'),
                icon: Icons.wb_sunny_outlined,
                label: l10n.energyHighRateKwh,
                value: kwh(
                  (report.gridImport! - importLow).clamp(0, double.infinity),
                ),
              ),
              _StatTile(
                key: const Key('energyLowRate'),
                icon: Icons.nights_stay_outlined,
                label: l10n.energyLowRateKwh,
                value: kwh(importLow),
                detail: report.gridImport! > 0
                    ? l10n.energyLowShare(
                        (importLow / report.gridImport! * 100).round(),
                      )
                    : null,
              ),
            ],
            if (report.gridExport != null)
              _StatTile(
                icon: Icons.upload_outlined,
                label: l10n.energyToGrid,
                value: kwh(report.gridExport!),
              ),
            if (report.solar != null)
              _StatTile(
                icon: Icons.solar_power_outlined,
                label: l10n.energySolar,
                value: kwh(report.solar!),
              ),
            if (report.batteryCharge != null)
              _StatTile(
                icon: Icons.battery_charging_full,
                label: l10n.energyBatteryCharge,
                value: kwh(report.batteryCharge!),
              ),
            if (report.batteryDischarge != null)
              _StatTile(
                icon: Icons.battery_std,
                label: l10n.energyBatteryDischarge,
                value: kwh(report.batteryDischarge!),
              ),
            if (report.gas != null)
              _StatTile(
                icon: Icons.local_fire_department_outlined,
                label: l10n.energyGas,
                value: formatNumber(locale, report.gas!, unit: 'm³'),
              ),
            if (cost != null)
              _StatTile(
                key: const Key('energyCost'),
                icon: Icons.payments_outlined,
                label: l10n.energyCostEstimate,
                value: formatMoney(locale, cost, tariff!.currency),
                onTap: () => _editTariff(context, ref, tariff),
              ),
          ],
        ),
        if (tariff == null && report.gridImport != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('energySetTariff'),
              onPressed: () => _editTariff(context, ref, null),
              icon: const Icon(Icons.payments_outlined),
              label: Text(l10n.energySetTariff),
            ),
          ),
        if (report.consumption != null) ...[
          SectionHeader(
            report.range == EnergyRange.today
                ? l10n.energyPerHour
                : l10n.energyPerDay,
          ),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConsumptionChart(report: report, lowHours: low?.hours),
            ),
          ),
        ],
        SectionHeader(l10n.energyTopConsumers),
        if (report.devices.isEmpty)
          InlineNotice.info(l10n.energyNoDevices)
        else
          _TopConsumers(report: report),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TopConsumers extends StatelessWidget {
  const _TopConsumers({required this.report});

  final EnergyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final max = report.devices.first.kwh;
    final total = report.consumption;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final d in report.devices.take(8))
              InkWell(
                key: ValueKey('energyDevice-${d.statisticId}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showDevice(context, d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            [
                              formatKwh(l10n.localeName, d.kwh),
                              if (total != null && total > 0)
                                '${(d.kwh / total * 100).round()} %',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ExcludeSemantics(
                        // Name and value are read from the row above.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: max > 0
                                      ? (d.kwh / max).clamp(0.0, 1.0)
                                      : 0,
                                  child: ColoredBox(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDevice(BuildContext context, DeviceEnergy d) {
    final l10n = context.l10n;
    final total = report.consumption;
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          key: const Key('energyDeviceSheet'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(d.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                [
                  formatKwh(l10n.localeName, d.kwh),
                  if (total != null && total > 0)
                    l10n.energyShareOfHome((d.kwh / total * 100).round()),
                ].join(' · '),
              ),
              const SizedBox(height: 16),
              ConsumptionChart(report: report, buckets: d.buckets),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which rate applies now and until when (two-rate meter).
class _RateNow extends StatefulWidget {
  const _RateNow({required this.low});

  final LowTariff low;

  @override
  State<_RateNow> createState() => _RateNowState();
}

class _RateNowState extends State<_RateNow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh when the rate changes, not on a polling loop.
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(widget.low.nextChange(now).difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final lowNow = widget.low.containsHour(now.hour);
    final time = DateFormat.Hm(l10n.localeName)
        .format(widget.low.nextChange(now));
    final color = lowNow
        ? context.statusColors.ok
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      key: const Key('energyRateNow'),
      children: [
        Icon(
          lowNow ? Icons.nights_stay : Icons.wb_sunny_outlined,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            lowNow ? l10n.energyLowNow(time) : l10n.energyHighNow(time),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: lowNow ? color : null,
              fontWeight: lowNow ? FontWeight.w600 : null,
            ),
          ),
        ),
        LowTariffReminderButton(
          startsAt: '${widget.low.fromHour.toString().padLeft(2, '0')}:00',
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Small line under the value (e.g. the previous period).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelMedium,
                        maxLines: 2,
                      ),
                      Text(value, style: theme.textTheme.titleLarge),
                      if (detail != null)
                        Text(
                          detail!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _editTariff(
  BuildContext context,
  WidgetRef ref,
  Tariff? current,
) async {
  final result = await showDialog<_TariffResult>(
    context: context,
    builder: (_) => _TariffDialog(current: current),
  );
  if (result != null) {
    final l10n = context.mounted ? context.l10n : null;
    await ref.read(tariffProvider.notifier).save(result.tariff);
    // A reminder in Home Assistant follows the new hours and price.
    if (l10n != null && ref.read(lowTariffReminderSetProvider)) {
      try {
        await saveLowTariffReminder(ref, l10n);
      } on AppFailure {
        // Kept as it was; the bell still shows it and can replace it.
      }
    }
  }
}

class _TariffResult {
  const _TariffResult(this.tariff);
  final Tariff? tariff;
}

class _TariffDialog extends StatefulWidget {
  const _TariffDialog({this.current});

  final Tariff? current;

  @override
  State<_TariffDialog> createState() => _TariffDialogState();
}

class _TariffDialogState extends State<_TariffDialog> {
  late final _import = TextEditingController(
    text: widget.current?.importPrice.toString() ?? '',
  );
  late final _export = TextEditingController(
    text: widget.current?.exportPrice?.toString() ?? '',
  );
  late final _currency = TextEditingController(
    text: widget.current?.currency ?? 'RSD',
  );
  late final _lowPrice = TextEditingController(
    text: widget.current?.low?.price.toString() ?? '',
  );
  late bool _twoRate = widget.current?.low != null;
  late int _lowFrom = widget.current?.low?.fromHour ?? 0;
  late int _lowTo = widget.current?.low?.toHour ?? 8;
  String? _error;
  String? _lowError;

  @override
  void dispose() {
    _import.dispose();
    _export.dispose();
    _currency.dispose();
    _lowPrice.dispose();
    super.dispose();
  }

  double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  void _save() {
    final price = _number(_import.text);
    final exportText = _export.text.trim();
    final export = exportText.isEmpty ? null : _number(exportText);
    if (price == null ||
        price < 0 ||
        (exportText.isNotEmpty && (export == null || export < 0))) {
      setState(() => _error = context.l10n.energyTariffInvalid);
      return;
    }
    final lowPrice = _number(_lowPrice.text);
    if (_twoRate && (lowPrice == null || lowPrice < 0 || _lowFrom == _lowTo)) {
      setState(() => _lowError = context.l10n.energyTariffInvalid);
      return;
    }
    Navigator.of(context).pop(
      _TariffResult(
        Tariff(
          importPrice: price,
          exportPrice: export,
          currency: _currency.text.trim().isEmpty
              ? 'RSD'
              : _currency.text.trim(),
          low: _twoRate
              ? LowTariff(fromHour: _lowFrom, toHour: _lowTo, price: lowPrice!)
              : null,
        ),
      ),
    );
  }

  Widget _hourField(
    String label,
    int value,
    void Function(int) set,
    String key,
  ) => DropdownButtonFormField<int>(
    key: ValueKey('$key-$value'),
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var h = 0; h < 24; h++)
        DropdownMenuItem(
          value: h,
          child: Text('${h.toString().padLeft(2, '0')}:00'),
        ),
    ],
    onChanged: (h) => setState(() => set(h!)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AlertDialog(
      title: Text(l10n.energyTariffTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.energyTariffHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('tariffImport'),
              controller: _import,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numeric,
              decoration: InputDecoration(
                labelText: _twoRate
                    ? l10n.energyHighPrice
                    : l10n.energyTariffImport,
                errorText: _error,
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('tariffTwoRate'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.energyTwoRate),
              value: _twoRate,
              onChanged: (v) => setState(() => _twoRate = v),
            ),
            if (_twoRate) ...[
              Text(
                l10n.energyTwoRateHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('tariffLowPrice'),
                controller: _lowPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: numeric,
                decoration: InputDecoration(
                  labelText: l10n.energyLowPrice,
                  errorText: _lowError,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _hourField(
                      l10n.energyLowFrom,
                      _lowFrom,
                      (h) => _lowFrom = h,
                      'tariffLowFrom',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _hourField(
                      l10n.energyLowTo,
                      _lowTo,
                      (h) => _lowTo = h,
                      'tariffLowTo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (label, from, to) in [
                    (l10n.energyLowPresetBelgrade, 0, 8),
                    (l10n.energyLowPresetVojvodina, 23, 7),
                    (l10n.energyLowPresetCentral, 22, 6),
                  ])
                    ActionChip(
                      key: ValueKey('tariffPreset-$from'),
                      label: Text(label),
                      onPressed: () => setState(() {
                        _lowFrom = from;
                        _lowTo = to;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _export,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: numeric,
              decoration: InputDecoration(labelText: l10n.energyTariffExport),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _currency,
              decoration: InputDecoration(labelText: l10n.energyTariffCurrency),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _TariffResult(null)),
            child: Text(l10n.delete),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('tariffSave'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
