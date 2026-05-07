import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A grid of time slot buttons for pickup time selection.
/// Shows 10-minute interval slots from the earliest possible pickup
/// (now + maxPrepTime) through the next 2 hours.
class TimeSlotPicker extends StatelessWidget {
  const TimeSlotPicker({
    super.key,
    required this.maxPrepTimeMinutes,
    required this.selectedSlot,
    required this.onSlotSelected,
    this.disabledSlots = const {},
  });

  /// Maximum prep time across all cart items (minutes).
  final int maxPrepTimeMinutes;

  /// Currently selected slot (null if none).
  final DateTime? selectedSlot;

  /// Callback when user taps a slot.
  final ValueChanged<DateTime> onSlotSelected;

  /// Set of slot start times that are full/disabled.
  final Set<DateTime> disabledSlots;

  @override
  Widget build(BuildContext context) {
    final slots = _generateSlots();
    final timeFormat = DateFormat('h:mm a');

    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No available pickup slots right now. Please try again later.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Select Pickup Time',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Earliest pickup: ${timeFormat.format(slots.first)} ($maxPrepTimeMinutes min prep)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              final isDisabled = disabledSlots.contains(slot);
              final isSelected = selectedSlot != null &&
                  selectedSlot!.hour == slot.hour &&
                  selectedSlot!.minute == slot.minute;

              return ChoiceChip(
                label: Text(timeFormat.format(slot)),
                selected: isSelected,
                onSelected: isDisabled ? null : (_) => onSlotSelected(slot),
                selectedColor: Colors.deepOrange,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isDisabled
                          ? Colors.grey[400]
                          : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: isDisabled ? Colors.grey[200] : null,
                tooltip: isDisabled ? 'Slot is full' : 'Pick up at ${timeFormat.format(slot)}',
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<DateTime> _generateSlots() {
    final now = DateTime.now();
    // Earliest pickup = now + maxPrepTime, rounded up to next 10-minute mark
    final earliest = now.add(Duration(minutes: maxPrepTimeMinutes));
    final roundedMinute = ((earliest.minute / 10).ceil()) * 10;
    var slotStart = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, roundedMinute);

    // If rounding pushed us past the hour
    if (slotStart.isBefore(earliest)) {
      slotStart = slotStart.add(const Duration(minutes: 10));
    }

    final endTime = now.add(const Duration(hours: 2, minutes: 30));
    final slots = <DateTime>[];

    while (slotStart.isBefore(endTime)) {
      slots.add(slotStart);
      slotStart = slotStart.add(const Duration(minutes: 10));
    }

    return slots;
  }
}
