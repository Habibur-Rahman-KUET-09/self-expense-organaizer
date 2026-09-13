import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A "‹ Today ›" / "‹ Sep 10, 2026 ›" header for browsing a single day
/// (Habit Tracker RS §4.2's backfill support on the Today tab) — mirrors
/// MonthSelector's shape, but for days and capped so it can't go past
/// [lastSelectableDate] (habits can't be logged for the future).
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.date,
    required this.onChanged,
    this.lastSelectableDate,
  });

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final DateTime? lastSelectableDate;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _isSameDay(date, today);
    final lastDate = lastSelectableDate ?? DateTime(today.year, today.month, today.day);
    final canGoForward = date.isBefore(lastDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous day',
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickDate(context, lastDate),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              isToday ? 'Today' : DateFormat.yMMMd().format(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next day',
          onPressed: canGoForward ? () => onChanged(date.add(const Duration(days: 1))) : null,
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime lastDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: lastDate,
    );
    if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
  }
}
