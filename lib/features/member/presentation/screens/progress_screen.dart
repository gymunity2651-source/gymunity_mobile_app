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
            onPressed: () => _showWeightDialog(context, ref),
            icon: const Icon(Icons.monitor_weight_outlined),
          ),
          IconButton(
            onPressed: () => _showMeasurementDialog(context, ref),
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
                        onPressed: () => _showWeightDialog(context, ref),
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
                                    _showWeightDialog(
                                      context,
                                      ref,
                                      existing: entry,
                                    );
                                  } else {
                                    ref
                                        .read(memberRepositoryProvider)
                                        .deleteWeightEntry(entry.id)
                                        .then((_) {
                                          ref.invalidate(
                                            memberWeightEntriesProvider,
                                          );
                                          ref.invalidate(
                                            memberHomeSummaryProvider,
                                          );
                                        });
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
                        onPressed: () => _showMeasurementDialog(context, ref),
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
                                      ref,
                                      existing: entry,
                                    );
                                  } else {
                                    ref
                                        .read(memberRepositoryProvider)
                                        .deleteBodyMeasurement(entry.id)
                                        .then((_) {
                                          ref.invalidate(
                                            memberBodyMeasurementsProvider,
                                          );
                                          ref.invalidate(
                                            memberHomeSummaryProvider,
                                          );
                                        });
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
    BuildContext context,
    WidgetRef ref, {
    WeightEntryEntity? existing,
  }) async {
    final weightController = TextEditingController(
      text: existing?.weightKg.toString(),
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    DateTime selectedDate = existing?.recordedAt ?? DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Weight Entry' : 'Edit Weight Entry',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  ),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Text(
                      'Recorded on ${selectedDate.toLocal().toString().split(' ').first}',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final weight = double.tryParse(weightController.text.trim());
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid weight value.')),
      );
      return;
    }

    await ref
        .read(memberRepositoryProvider)
        .saveWeightEntry(
          entryId: existing?.id,
          weightKg: weight,
          recordedAt: selectedDate,
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
    ref.invalidate(memberWeightEntriesProvider);
    ref.invalidate(memberHomeSummaryProvider);
  }

  Future<void> _showMeasurementDialog(
    BuildContext context,
    WidgetRef ref, {
    BodyMeasurementEntity? existing,
  }) async {
    final waistController = TextEditingController(
      text: existing?.waistCm?.toString() ?? '',
    );
    final chestController = TextEditingController(
      text: existing?.chestCm?.toString() ?? '',
    );
    final hipsController = TextEditingController(
      text: existing?.hipsCm?.toString() ?? '',
    );
    final bodyFatController = TextEditingController(
      text: existing?.bodyFatPercent?.toString() ?? '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');
    DateTime selectedDate = existing?.recordedAt ?? DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                existing == null ? 'Add Measurement' : 'Edit Measurement',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: waistController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Waist (cm)',
                      ),
                    ),
                    TextField(
                      controller: chestController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Chest (cm)',
                      ),
                    ),
                    TextField(
                      controller: hipsController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Hips (cm)'),
                    ),
                    TextField(
                      controller: bodyFatController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Body Fat %',
                      ),
                    ),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Note'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Text(
                        'Recorded on ${selectedDate.toLocal().toString().split(' ').first}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref
        .read(memberRepositoryProvider)
        .saveBodyMeasurement(
          entryId: existing?.id,
          recordedAt: selectedDate,
          waistCm: _parseNullableDouble(waistController.text),
          chestCm: _parseNullableDouble(chestController.text),
          hipsCm: _parseNullableDouble(hipsController.text),
          bodyFatPercent: _parseNullableDouble(bodyFatController.text),
          note: noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
    ref.invalidate(memberBodyMeasurementsProvider);
    ref.invalidate(memberHomeSummaryProvider);
  }

  static double? _parseNullableDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
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
