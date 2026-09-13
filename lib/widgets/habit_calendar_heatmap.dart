import 'package:flutter/material.dart';

import '../models/habit_progress.dart';

const _cellSize = 14.0;
const _cellGap = 3.0;

/// A GitHub-contribution-graph-style grid of [days] (Habit Tracker RS
/// §4.3), one column per week, oldest week on the left. Cells are colored
/// by [color] when completed, muted when due-but-missed, and faint when
/// the day wasn't due at all (e.g. before a daysOfWeek habit's next
/// scheduled day).
class HabitCalendarHeatmap extends StatelessWidget {
  const HabitCalendarHeatmap({super.key, required this.days, required this.color});

  final List<HeatmapDay> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();

    // Pad the front so the first real day lands in its correct weekday row
    // (Monday-first columns).
    final leadingBlanks = days.first.day.weekday - DateTime.monday;
    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox(width: _cellSize, height: _cellSize),
      for (final day in days) _HeatmapCell(day: day, color: color),
    ];

    final weeks = <List<Widget>>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = (i + 7 > cells.length) ? cells.length : i + 7;
      weeks.add(cells.sublist(i, end));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final week in weeks)
            Padding(
              padding: const EdgeInsets.only(right: _cellGap),
              child: Column(
                children: [
                  for (final cell in week)
                    Padding(padding: const EdgeInsets.only(bottom: _cellGap), child: cell),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.day, required this.color});

  final HeatmapDay day;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final String status;
    if (!day.isDue) {
      background = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
      status = 'not due';
    } else if (day.completed) {
      background = color;
      status = 'done';
    } else {
      background = Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.6);
      status = 'missed';
    }

    return Tooltip(
      message: '${day.day.year}-${day.day.month.toString().padLeft(2, '0')}-'
          '${day.day.day.toString().padLeft(2, '0')} · $status',
      child: Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
