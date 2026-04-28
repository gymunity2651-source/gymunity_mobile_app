import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../../../coach/domain/entities/coach_workspace_entity.dart';
import '../../domain/entities/coach_hub_entity.dart';
import '../providers/member_providers.dart';

class MemberCoachSessionsScreen extends ConsumerStatefulWidget {
  const MemberCoachSessionsScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<MemberCoachSessionsScreen> createState() =>
      _MemberCoachSessionsScreenState();
}

class _MemberCoachSessionsScreenState
    extends ConsumerState<MemberCoachSessionsScreen> {
  String? _selectedSessionTypeId;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(
      memberCoachBookingsProvider(widget.subscriptionId),
    );
    final typesAsync = ref.watch(
      memberBookableSessionTypesProvider(widget.subscriptionId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach Sessions'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(memberCoachBookingsProvider(widget.subscriptionId));
          ref.invalidate(
            memberBookableSessionTypesProvider(widget.subscriptionId),
          );
          await Future.wait<dynamic>([
            ref.read(memberCoachBookingsProvider(widget.subscriptionId).future),
            ref.read(
              memberBookableSessionTypesProvider(widget.subscriptionId).future,
            ),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Sessions with your coach',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Upcoming and recent',
              child: bookingsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(error.toString()),
                data: (bookings) {
                  if (bookings.isEmpty) {
                    return Text(
                      'No sessions booked yet.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  return Column(
                    children: bookings
                        .map((booking) => _BookingTile(booking: booking))
                        .toList(growable: false),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Book a session',
              child: typesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text(error.toString()),
                data: (types) {
                  if (types.isEmpty) {
                    return Text(
                      'No self-bookable session types are available for this package.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  final selected = _selectedSessionTypeId ?? types.first.id;
                  final type = types.firstWhere(
                    (item) => item.id == selected,
                    orElse: () => types.first,
                  );
                  final today = DateTime.now();
                  final query = MemberSlotsQuery(
                    coachId: type.coachId,
                    sessionTypeId: type.id,
                    dateFrom: DateTime(today.year, today.month, today.day),
                    dateTo: DateTime(
                      today.year,
                      today.month,
                      today.day,
                    ).add(const Duration(days: 14)),
                  );
                  final slotsAsync = ref.watch(
                    memberBookableSlotsProvider(query),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: type.id,
                        decoration: const InputDecoration(
                          labelText: 'Session type',
                        ),
                        items: types
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.title),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setState(() => _selectedSessionTypeId = value),
                      ),
                      const SizedBox(height: 12),
                      slotsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Text(error.toString()),
                        data: (slots) {
                          if (slots.isEmpty) {
                            return Text(
                              'No open slots in the next 14 days.',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                              ),
                            );
                          }
                          return Column(
                            children: slots
                                .take(8)
                                .map(
                                  (slot) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.schedule,
                                      color: AppColors.orange,
                                    ),
                                    title: Text(_dateTime(slot.startsAt)),
                                    subtitle: Text(
                                      '${type.durationMinutes} min · ${slot.deliveryMode}',
                                    ),
                                    trailing: OutlinedButton(
                                      onPressed: () => _book(type, slot),
                                      child: const Text('Book'),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _book(
    CoachSessionTypeEntity type,
    MemberBookableSlotEntity slot,
  ) async {
    try {
      await ref
          .read(memberRepositoryProvider)
          .createMemberBooking(
            subscriptionId: widget.subscriptionId,
            sessionTypeId: type.id,
            startsAt: slot.startsAt,
            timezone: slot.timezone,
          );
      ref.invalidate(memberCoachBookingsProvider(widget.subscriptionId));
      ref.invalidate(memberCoachHubProvider(widget.subscriptionId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Session booked.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session could not be booked: $error')),
      );
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.booking});

  final CoachBookingEntity booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined, color: AppColors.orange),
      title: Text(booking.title),
      subtitle: Text('${_dateTime(booking.startsAt)} · ${booking.status}'),
      trailing: booking.status == 'scheduled' || booking.status == 'confirmed'
          ? TextButton(
              onPressed: () async {
                await ref
                    .read(memberRepositoryProvider)
                    .updateMemberBookingStatus(
                      bookingId: booking.id,
                      status: 'cancelled',
                      reason: 'Cancelled by member',
                    );
                if (booking.subscriptionId != null) {
                  ref.invalidate(
                    memberCoachBookingsProvider(booking.subscriptionId!),
                  );
                  ref.invalidate(
                    memberCoachHubProvider(booking.subscriptionId),
                  );
                }
              },
              child: const Text('Cancel'),
            )
          : null,
    );
  }
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  final date = local.toIso8601String().split('T').first;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}
