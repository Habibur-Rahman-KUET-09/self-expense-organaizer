import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A "‹ September 2026 ›" header for any screen that operates on a single
/// calendar month (budget setup, dashboard).
class MonthSelector extends StatelessWidget {
  const MonthSelector({
    super.key,
    required this.year,
    required this.month,
    required this.onChanged,
  });

  final int year;
  final int month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.yMMMM().format(DateTime(year, month));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(year, month - 1)),
          tooltip: 'Previous month',
        ),
        SizedBox(
          width: 160,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(year, month + 1)),
          tooltip: 'Next month',
        ),
      ],
    );
  }
}
