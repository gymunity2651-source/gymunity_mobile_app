import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/member_progress_entity.dart';
import '../providers/member_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightAsync = ref.watch(memberWeightEntriesProvider);
    final measurementAsync = ref.watch(memberBodyMeasurementsProvider);
    final preferencesAsync = ref.watch(memberPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Progress Tracking'),
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
          message: 'GymUnity could not load your preferences.',
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
                'Weight History',
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
                  message: 'Unable to load weight entries.',
                  onRetry: () => ref.refresh(memberWeightEntriesProvider),
                ),
                data: (weights) => weights.isEmpty
                    ? _EmptyState(
                        message: 'No weight entries yet. Add your first entry.',
                        onPressed: () => _showWeightDialog(context),
                        cta: 'Add weight',
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
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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
                'Body Measurements',
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
                  message: 'Unable to load body measurements.',
                  onRetry: () => ref.refresh(memberBodyMeasurementsProvider),
                ),
                data: (measurements) => measurements.isEmpty
                    ? _EmptyState(
                        message:
                            'No body measurements yet. Add your first measurement snapshot.',
                        onPressed: () => _showMeasurementDialog(context),
                        cta: 'Add measurement',
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
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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
                  const SnackBar(content: Text('Weight entry deleted.')),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() => isDeleting = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Weight entry could not be deleted: $error'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Delete weight entry?'),
              content: const Text(
                'This weight entry will be permanently removed from your progress history.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('progress-confirm-delete-weight-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: isDeleting ? null : delete,
                  child: isDeleting
                      ? const Text('Deleting...')
                      : const Text('Delete'),
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
                  const SnackBar(content: Text('Measurement deleted.')),
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() => isDeleting = false);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text('Measurement could not be deleted: $error'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Delete measurement?'),
              content: const Text(
                'This measurement will be permanently removed from your progress history.',
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('progress-confirm-delete-measurement-button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  onPressed: isDeleting ? null : delete,
                  child: isDeleting
                      ? const Text('Deleting...')
                      : const Text('Delete'),
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
    BodyMeasurementEntity entry,
    String measurementUnit,
  ) {
    double convert(double value) =>
        measurementUnit == 'imperial' ? value / 2.54 : value;
    final unit = measurementUnit == 'imperial' ? 'in' : 'cm';
    final parts = <String>[
      if (entry.waistCm != null)
        'Waist ${convert(entry.waistCm!).toStringAsFixed(1)} $unit',
      if (entry.chestCm != null)
        'Chest ${convert(entry.chestCm!).toStringAsFixed(1)} $unit',
      if (entry.hipsCm != null)
        'Hips ${convert(entry.hipsCm!).toStringAsFixed(1)} $unit',
      if (entry.bodyFatPercent != null)
        'BF ${entry.bodyFatPercent!.toStringAsFixed(1)}%',
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
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Weight Entry' : 'Edit Weight Entry',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSaving ? null : _pickDate,
            child: Text(
              'Recorded on ${_selectedDate.toLocal().toString().split(' ').first}',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('progress-save-weight-button'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Saving...') : const Text('Save'),
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
      _showSnackBar('Enter a valid weight value.');
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
        const SnackBar(content: Text('Weight entry saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar('Weight entry could not be saved: $error');
    }
  }

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
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Measurement' : 'Edit Measurement',
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
              decoration: const InputDecoration(labelText: 'Waist (cm)'),
            ),
            TextField(
              controller: _chestController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Chest (cm)'),
            ),
            TextField(
              controller: _hipsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Hips (cm)'),
            ),
            TextField(
              controller: _bodyFatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Body Fat %'),
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note'),
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
              child: Text(
                'Recorded on ${_selectedDate.toLocal().toString().split(' ').first}',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('progress-save-measurement-button'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const Text('Saving...') : const Text('Save'),
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
        _validationMessage = 'Enter at least one measurement before saving.';
      });
      return;
    }
    if (ProgressScreen._hasInvalidMeasurementValue(values)) {
      setState(() {
        _validationMessage = 'Measurements must be positive numbers.';
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
        const SnackBar(content: Text('Measurement saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      _showSnackBar('Measurement could not be saved: $error');
    }
  }

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
      return const Center(child: Text('No chartable measurements yet.'));
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
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
