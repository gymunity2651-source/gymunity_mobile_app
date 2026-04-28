import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/di/providers.dart';
import '../../domain/entities/coach_entity.dart';
import '../../domain/entities/coach_workspace_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../providers/coach_providers.dart';

class CoachCalendarScreen extends ConsumerWidget {
  const CoachCalendarScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(coachBookingsProvider);
    final sessionTypesAsync = ref.watch(coachSessionTypesProvider);
    final availabilityAsync = ref.watch(coachAvailabilityProvider);

    Future<void> refresh() async {
      ref.invalidate(coachBookingsProvider);
      ref.invalidate(coachSessionTypesProvider);
      ref.invalidate(coachAvailabilityProvider);
      await Future.wait<dynamic>([
        ref.read(coachBookingsProvider.future),
        ref.read(coachSessionTypesProvider.future),
        ref.read(coachAvailabilityProvider.future),
      ]);
    }

    final content = RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.lg,
          AppSizes.screenPadding,
          96,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Calendar',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.outlined(
                tooltip: 'Add booking',
                onPressed: () => _openBookingSheet(context, ref),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Session types',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          sessionTypesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CalendarState(
              icon: Icons.cloud_off_outlined,
              title: 'Session types unavailable',
              body: error.toString(),
            ),
            data: (types) => types.isEmpty
                ? _CalendarState(
                    icon: Icons.video_call_outlined,
                    title: 'No session types',
                    body:
                        'Create consultation, check-in, video, or in-person sessions.',
                    actionLabel: 'Add type',
                    onTap: () => _openSessionTypeSheet(context, ref),
                  )
                : Column(
                    children: [
                      ...types.map(
                        (type) => _CalendarTile(
                          icon: _sessionIcon(type.sessionKind),
                          title: type.title,
                          subtitle:
                              '${type.durationMinutes} min - ${type.deliveryMode.replaceAll('_', ' ')} - ${type.isSelfBookable ? 'self-bookable' : 'manual only'}',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _openSessionTypeSheet(context, ref),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add session type'),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Availability',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openAvailabilitySheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Slot'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          availabilityAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CalendarState(
              icon: Icons.cloud_off_outlined,
              title: 'Availability unavailable',
              body: error.toString(),
            ),
            data: (slots) => slots.isEmpty
                ? _CalendarState(
                    icon: Icons.event_available_outlined,
                    title: 'No availability slots',
                    body: 'Add active time windows for client self-booking.',
                    actionLabel: 'Add slot',
                    onTap: () => _openAvailabilitySheet(context, ref),
                  )
                : Column(
                    children: slots
                        .map((slot) => _AvailabilityTile(slot: slot))
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bookings',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openBookingSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Book'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _CalendarState(
              icon: Icons.cloud_off_outlined,
              title: 'Bookings unavailable',
              body: error.toString(),
            ),
            data: (bookings) => bookings.isEmpty
                ? const _CalendarState(
                    icon: Icons.calendar_month_outlined,
                    title: 'No upcoming bookings',
                    body: 'Booked coaching sessions appear here.',
                  )
                : Column(
                    children: bookings
                        .map((booking) => _BookingCard(booking: booking))
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );

    if (embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppColors.background,
      ),
      body: content,
    );
  }

  Future<void> _openSessionTypeSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final titleController = TextEditingController(text: 'Consultation');
    final durationController = TextEditingController(text: '30');
    final bufferBeforeController = TextEditingController(text: '0');
    final bufferAfterController = TextEditingController(text: '10');
    final cancellationController = TextEditingController(text: '12');
    final rescheduleController = TextEditingController(text: '12');
    final locationController = TextEditingController();
    String kind = 'consultation';
    String mode = 'online';
    bool selfBookable = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => ListView(
            shrinkWrap: true,
            children: [
              const _SheetTitle(title: 'Session type'),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'consultation',
                    child: Text('Consultation'),
                  ),
                  DropdownMenuItem(
                    value: 'weekly_checkin_call',
                    child: Text('Weekly check-in call'),
                  ),
                  DropdownMenuItem(
                    value: 'video_coaching_session',
                    child: Text('Video coaching session'),
                  ),
                  DropdownMenuItem(
                    value: 'in_person_training_session',
                    child: Text('In-person training session'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => kind = value ?? 'consultation'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minutes'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: const [
                        DropdownMenuItem(
                          value: 'online',
                          child: Text('Online'),
                        ),
                        DropdownMenuItem(
                          value: 'in_person',
                          child: Text('In person'),
                        ),
                        DropdownMenuItem(
                          value: 'hybrid',
                          child: Text('Hybrid'),
                        ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => mode = value ?? 'online'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location note / meeting note',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: bufferBeforeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Buffer before',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: bufferAfterController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Buffer after',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cancellationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cancel notice (hours)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: rescheduleController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reschedule notice',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow self-booking'),
                value: selfBookable,
                onChanged: (value) => setSheetState(() => selfBookable = value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .saveSessionType(
                          title: titleController.text.trim(),
                          sessionKind: kind,
                          durationMinutes:
                              int.tryParse(durationController.text) ?? 30,
                          bufferBeforeMinutes:
                              int.tryParse(bufferBeforeController.text) ?? 0,
                          bufferAfterMinutes:
                              int.tryParse(bufferAfterController.text) ?? 10,
                          deliveryMode: mode,
                          locationNote: _textOrNull(locationController.text),
                          cancellationNoticeHours:
                              int.tryParse(cancellationController.text) ?? 12,
                          rescheduleNoticeHours:
                              int.tryParse(rescheduleController.text) ?? 12,
                          isSelfBookable: selfBookable,
                        );
                    ref.invalidate(coachSessionTypesProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleController.dispose();
    durationController.dispose();
    bufferBeforeController.dispose();
    bufferAfterController.dispose();
    cancellationController.dispose();
    rescheduleController.dispose();
    locationController.dispose();
  }

  Future<void> _openAvailabilitySheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '12:00');
    int weekday = 1;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSizes.screenPadding),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetTitle(title: 'Availability slot'),
              DropdownButtonFormField<int>(
                initialValue: weekday,
                decoration: const InputDecoration(labelText: 'Day'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                ],
                onChanged: (value) => setSheetState(() => weekday = value ?? 1),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Start time',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endController,
                      decoration: const InputDecoration(labelText: 'End time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .saveAvailabilitySlot(
                          weekday: weekday,
                          startTime: startController.text.trim(),
                          endTime: endController.text.trim(),
                          timezone: DateTime.now().timeZoneName,
                        );
                    ref.invalidate(coachAvailabilityProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    startController.dispose();
    endController.dispose();
  }

  Future<void> _openBookingSheet(BuildContext context, WidgetRef ref) async {
    final subscriptions = await ref.read(
      coachManagedSubscriptionsProvider.future,
    );
    final sessionTypes = await ref.read(coachSessionTypesProvider.future);
    if (!context.mounted) return;

    SubscriptionEntity? subscription = subscriptions.isEmpty
        ? null
        : subscriptions.first;
    CoachSessionTypeEntity? sessionType = sessionTypes.isEmpty
        ? null
        : sessionTypes.first;
    final dateController = TextEditingController(
      text: _dateTimeInput(DateTime.now().add(const Duration(days: 1))),
    );
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => ListView(
            shrinkWrap: true,
            children: [
              const _SheetTitle(title: 'Create booking'),
              if (subscriptions.isEmpty || sessionTypes.isEmpty)
                const _CalendarState(
                  icon: Icons.info_outline,
                  title: 'Missing setup',
                  body:
                      'Create at least one session type and one active client first.',
                )
              else ...[
                DropdownButtonFormField<SubscriptionEntity>(
                  initialValue: subscription,
                  decoration: const InputDecoration(labelText: 'Client'),
                  items: subscriptions
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.memberName ?? item.id),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setSheetState(() => subscription = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<CoachSessionTypeEntity>(
                  initialValue: sessionType,
                  decoration: const InputDecoration(labelText: 'Session type'),
                  items: sessionTypes
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setSheetState(() => sessionType = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Start datetime',
                    hintText: 'YYYY-MM-DD HH:MM',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  onTap: () async {
                    final pickedAt = await _pickDateTime(
                      context,
                      initial:
                          _parseDateTimeInput(dateController.text) ??
                          DateTime.now().add(const Duration(days: 1)),
                    );
                    if (pickedAt != null) {
                      dateController.text = _dateTimeInput(pickedAt);
                    }
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final startsAt = _parseDateTimeInput(dateController.text);
                      if (subscription == null ||
                          sessionType == null ||
                          startsAt == null) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Choose a client, session type, and valid start time.',
                              ),
                            ),
                          );
                        return;
                      }
                      if (!startsAt.isAfter(DateTime.now())) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Choose a future start time.'),
                            ),
                          );
                        return;
                      }
                      await ref
                          .read(coachRepositoryProvider)
                          .createBooking(
                            subscriptionId: subscription!.id,
                            sessionTypeId: sessionType!.id,
                            startsAt: startsAt,
                            timezone: DateTime.now().timeZoneName,
                            note: _textOrNull(noteController.text),
                          );
                      ref.invalidate(coachBookingsProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Create booking'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    dateController.dispose();
    noteController.dispose();
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final CoachBookingEntity booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined, color: AppColors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  booking.title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
              Text(booking.status.replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateTime(booking.startsAt)} · ${booking.deliveryMode.replaceAll('_', ' ')}',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openStatusSheet(context, ref),
                  child: const Text('Update status'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openStatusSheet(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    String status = booking.status;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
          top: AppSizes.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetTitle(title: 'Update booking'),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'scheduled',
                    child: Text('Scheduled'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelled'),
                  ),
                  DropdownMenuItem(
                    value: 'rescheduled',
                    child: Text('Rescheduled'),
                  ),
                ],
                onChanged: (value) =>
                    setSheetState(() => status = value ?? 'scheduled'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(coachRepositoryProvider)
                        .updateBookingStatus(
                          bookingId: booking.id,
                          status: status,
                          reason: _textOrNull(reasonController.text),
                        );
                    ref.invalidate(coachBookingsProvider);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    reasonController.dispose();
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({required this.slot});

  final CoachAvailabilitySlotEntity slot;

  @override
  Widget build(BuildContext context) {
    return _CalendarTile(
      icon: Icons.access_time,
      title: slot.weekdayLabel,
      subtitle: '${slot.startTime} - ${slot.endTime} ${slot.timezone}',
    );
  }
}

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarState extends StatelessWidget {
  const _CalendarState({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.orange),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onTap != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

IconData _sessionIcon(String kind) {
  switch (kind) {
    case 'weekly_checkin_call':
      return Icons.support_agent_outlined;
    case 'video_coaching_session':
      return Icons.video_call_outlined;
    case 'in_person_training_session':
      return Icons.fitness_center_outlined;
    default:
      return Icons.record_voice_over_outlined;
  }
}

String? _textOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDateTimeInput(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  if (normalized.isEmpty) return null;
  return DateTime.tryParse(normalized);
}

Future<DateTime?> _pickDateTime(
  BuildContext context, {
  required DateTime initial,
}) async {
  final now = DateTime.now();
  final initialDate = initial.isBefore(now) ? now : initial;
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 2),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _dateTimeInput(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour}:$minute';
}
