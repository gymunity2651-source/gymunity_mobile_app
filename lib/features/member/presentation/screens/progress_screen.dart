import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/localization/app_localization_extension.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../providers/member_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightAsync = ref.watch(memberWeightEntriesProvider);
    final measurementAsync = ref.watch(memberBodyMeasurementsProvider);
    final preferencesAsync = ref.watch(memberPreferencesProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(l10n.progressTracking),
        actions: [
          IconButton(
            onPressed: () => _showWeightDialog(context),
            icon: const Icon(Icons.monitor_weight_outlined),
          ),
          IconButton(
            onPressed: () => _showMeasurementDialog(context),
            icon: const Icon(Icons.straighten_outlined),
          ),
        ],
      ),
      body: preferencesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          message: l10n.unableLoadPreferences,
          onRetry: () => ref.refresh(memberPreferencesProvider),
        ),
        data: (preferences) => RefreshIndicator.adaptive(
          onRefresh: () async {
            ref.invalidate(memberWeightEntriesProvider);
            ref.invalidate(memberBodyMeasurementsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.screenPadding),
            children: [
              Text(
                l10n.weightHistory,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              weightAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _ErrorState(
                  message: l10n.unableLoadWeightEntries,
                  onRetry: () => ref.refresh(memberWeightEntriesProvider),
                ),
                data: (weights) => weights.isEmpty
                    ? _EmptyState(
                        message: l10n.noWeightEntriesYet,
                        onPressed: () => _showWeightDialog(context),
                        cta: l10n.addWeight,
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 220,
                            child: _WeightChart(entries: weights),
                          ),
                          const SizedBox(height: 12),
                          ...weights.reversed.map(
                            (entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _formatWeight(
                                  entry.weightKg,
                                  preferences.measurementUnit,
                                ),
                              ),
                              subtitle: Text(
                                '${entry.recordedAt.toLocal().toString().split(' ').first}${entry.note?.trim().isNotEmpty == true ? ' • ${entry.note}' : ''}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showWeightDialog(context, existing: entry);
                                  } else {
                                    _deleteWeightEntry(context, ref, entry);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.edit),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.bodyMeasurements,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              measurementAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _ErrorState(
                  message: l10n.unableLoadBodyMeasurements,
                  onRetry: () => ref.refresh(memberBodyMeasurementsProvider),
                ),
                data: (measurements) => measurements.isEmpty
                    ? _EmptyState(
                        message: l10n.noBodyMeasurementsYet,
                        onPressed: () => _showMeasurementDialog(context),
                        cta: l10n.addMeasurement,
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 220,
                            child: _MeasurementChart(entries: measurements),
                          ),
                          const SizedBox(height: 12),
                          ...measurements.reversed.map(
                            (entry) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                entry.note?.trim().isNotEmpty == true
                                    ? entry.note!
                                    : entry.recordedAt
                                          .toLocal()
                                          .toString()
                                          .split(' ')
                                          .first,
                              ),
                              subtitle: Text(
                                _measurementSummary(
                                  context,
                                  entry,
                                  preferences.measurementUnit,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showMeasurementDialog(
                                      context,
                                      existing: entry,
                                    );
                                  } else {
                                    _deleteMeasurement(context, ref, entry);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.edit),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWeightDialog(
    BuildContext context, {
    WeightEntryEntity? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _WeightEntryDialog(existing: existing),
    );
  }

  Future<void> _showMeasurementDialog(
    BuildContext context, {
    BodyMeasurementEntity? existing,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _BodyMeasurementDialog(existing: existing),
    );
  }

  Future<void> _deleteWeightEntry(
    BuildContext context,
    WidgetRef ref,
    WeightEntryEntity entry,
  ) async {
    var isDeleting = false;
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> delete() async {
              if (isDeleting) {
                return;
              }
              setDialogState(() => isDeleting = true);
              try {
                await ref
                    .read(memberRepositoryProvider)
                    .deleteWeightEntry(entry.id);
                ref.invalidate(memberWeightEntriesProvider);
                ref.invalidate(memberHomeSummaryProvider);
                if (!dialogContext.mounted) {
                  return;
                }
                final messenger = ScaffoldMessenger.of(dialogContext);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.weightEntryDeleted)),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() => isDeleting = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(l10n.weightEntryDeleteFailed('$error')),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(l10n.deleteWeightEntryQuestion),
              content: Text(l10n.deleteWeightEntryBody),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  key: const Key('progress-confirm-delete-weight-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: isDeleting ? null : delete,
                  child: isDeleting ? Text(l10n.deleting) : Text(l10n.delete),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMeasurement(
    BuildContext context,
    WidgetRef ref,
    BodyMeasurementEntity entry,
  ) async {
    var isDeleting = false;
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> delete() async {
              if (isDeleting) {
                return;
              }
              setDialogState(() => isDeleting = true);
              try {
                await ref
                    .read(memberRepositoryProvider)
                    .deleteBodyMeasurement(entry.id);
                ref.invalidate(memberBodyMeasurementsProvider);
                ref.invalidate(memberHomeSummaryProvider);
                if (!dialogContext.mounted) {
                  return;
                }
                final messenger = ScaffoldMessenger.of(dialogContext);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.measurementDeleted)),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() => isDeleting = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(l10n.measurementDeleteFailed('$error')),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(l10n.deleteMeasurementQuestion),
              content: Text(l10n.deleteMeasurementBody),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  key: const Key('progress-confirm-delete-measurement-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: isDeleting ? null : delete,
                  child: isDeleting ? Text(l10n.deleting) : Text(l10n.delete),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static double? _parseNullableDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  static bool _hasAnyMeasurementValue(List<String> values) {
    return values.any((value) => value.trim().isNotEmpty);
  }

  static bool _hasInvalidMeasurementValue(List<String> values) {
    return values.where((value) => value.trim().isNotEmpty).any((value) {
      final parsed = double.tryParse(value.trim());
      return parsed == null || parsed <= 0;
    });
  }

  static String _formatWeight(double valueKg, String measurementUnit) {
    if (measurementUnit == 'imperial') {
      final pounds = valueKg * 2.20462;
      return '${pounds.toStringAsFixed(1)} lb';
    }
    return '${valueKg.toStringAsFixed(1)} kg';
  }

  static String _measurementSummary(
    BuildContext context,
    BodyMeasurementEntity entry,
    String measurementUnit,
  ) {
    final l10n = context.l10n;
    double convert(double value) =>
        measurementUnit == 'imperial' ? value / 2.54 : value;
    final unit = measurementUnit == 'imperial' ? 'in' : 'cm';
    final parts = <String>[
      if (entry.waistCm != null)
        l10n.waistMeasurement(convert(entry.waistCm!).toStringAsFixed(1), unit),
      if (entry.chestCm != null)
        l10n.chestMeasurement(convert(entry.chestCm!).toStringAsFixed(1), unit),
      if (entry.hipsCm != null)
        l10n.hipsMeasurement(convert(entry.hipsCm!).toStringAsFixed(1), unit),
      if (entry.bodyFatPercent != null)
        l10n.bodyFatMeasurement(entry.bodyFatPercent!.toStringAsFixed(1)),
    ];
    return parts.join(' • ');
  }
}

class _WeightEntryDialog extends ConsumerStatefulWidget {
  const _WeightEntryDialog({this.existing});

  final WeightEntryEntity? existing;

  @override
  ConsumerState<_WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends ConsumerState<_WeightEntryDialog> {
  late final TextEditingController _weightController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.existing?.weightKg.toString(),
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _selectedDate = widget.existing?.recordedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.addWeightEntry : l10n.editWeightEntry,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.weightKgLabel),
          ),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.note),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSaving ? null : _pickDate,
            child: Text(l10n.recordedOn(_formattedSelectedDate)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          key: const Key('progress-save-weight-button'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? Text(l10n.saving) : Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      _showSnackBar(context.l10n.enterValidWeightValue);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(memberRepositoryProvider)
          .saveWeightEntry(
            entryId: widget.existing?.id,
            weightKg: weight,
            recordedAt: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      ref.invalidate(memberWeightEntriesProvider);
      ref.invalidate(memberHomeSummaryProvider);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.weightEntrySaved)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar(context.l10n.weightEntrySaveFailed('$error'));
    }
  }

  String get _formattedSelectedDate =>
      _selectedDate.toLocal().toString().split(' ').first;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BodyMeasurementDialog extends ConsumerStatefulWidget {
  const _BodyMeasurementDialog({this.existing});

  final BodyMeasurementEntity? existing;

  @override
  ConsumerState<_BodyMeasurementDialog> createState() =>
      _BodyMeasurementDialogState();
}

class _BodyMeasurementDialogState
    extends ConsumerState<_BodyMeasurementDialog> {
  late final TextEditingController _waistController;
  late final TextEditingController _chestController;
  late final TextEditingController _hipsController;
  late final TextEditingController _bodyFatController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  String? _validationMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _waistController = TextEditingController(
      text: widget.existing?.waistCm?.toString() ?? '',
    );
    _chestController = TextEditingController(
      text: widget.existing?.chestCm?.toString() ?? '',
    );
    _hipsController = TextEditingController(
      text: widget.existing?.hipsCm?.toString() ?? '',
    );
    _bodyFatController = TextEditingController(
      text: widget.existing?.bodyFatPercent?.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _selectedDate = widget.existing?.recordedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _waistController.dispose();
    _chestController.dispose();
    _hipsController.dispose();
    _bodyFatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.addMeasurement : l10n.editMeasurement,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _waistController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.waistCmLabel),
            ),
            TextField(
              controller: _chestController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.chestCmLabel),
            ),
            TextField(
              controller: _hipsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.hipsCmLabel),
            ),
            TextField(
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: l10n.bodyFatPercentLabel),
            ),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.note),
            ),
            if (_validationMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationMessage!,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSaving ? null : _pickDate,
              child: Text(l10n.recordedOn(_formattedSelectedDate)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          key: const Key('progress-save-measurement-button'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? Text(l10n.saving) : Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    final values = <String>[
      _waistController.text,
      _chestController.text,
      _hipsController.text,
      _bodyFatController.text,
    ];
    if (!ProgressScreen._hasAnyMeasurementValue(values)) {
      setState(() {
        _validationMessage = context.l10n.enterOneMeasurementBeforeSaving;
      });
      return;
    }
    if (ProgressScreen._hasInvalidMeasurementValue(values)) {
      setState(() {
        _validationMessage = context.l10n.measurementsPositiveNumbers;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });
    try {
      await ref
          .read(memberRepositoryProvider)
          .saveBodyMeasurement(
            entryId: widget.existing?.id,
            recordedAt: _selectedDate,
            waistCm: ProgressScreen._parseNullableDouble(_waistController.text),
            chestCm: ProgressScreen._parseNullableDouble(_chestController.text),
            hipsCm: ProgressScreen._parseNullableDouble(_hipsController.text),
            bodyFatPercent: ProgressScreen._parseNullableDouble(
              _bodyFatController.text,
            ),
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      ref.invalidate(memberBodyMeasurementsProvider);
      ref.invalidate(memberHomeSummaryProvider);
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.measurementSaved)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar(context.l10n.measurementSaveFailed('$error'));
    }
  }

  String get _formattedSelectedDate =>
      _selectedDate.toLocal().toString().split(' ').first;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries});

  final List<WeightEntryEntity> entries;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightKg),
    ];
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.orange,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _MeasurementChart extends StatelessWidget {
  const _MeasurementChart({required this.entries});

  final List<BodyMeasurementEntity> entries;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      final value =
          entries[i].waistCm ?? entries[i].chestCm ?? entries[i].hipsCm;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    if (spots.isEmpty) {
      return Center(child: Text(context.l10n.noChartableMeasurementsYet));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.limeGreen,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.onPressed,
    required this.cta,
  });

  final String message;
  final VoidCallback onPressed;
  final String cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onPressed, child: Text(cta)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
