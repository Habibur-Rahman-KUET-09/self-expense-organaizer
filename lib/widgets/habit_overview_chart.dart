import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/habit_progress.dart';

/// The last 7 days' overall completion % across every due habit each day
/// (Habit Tracker RS §4.3 "trend comparison") — an at-a-glance
/// improving/declining signal for the whole habit set, not just one habit.
class HabitOverviewChart extends StatelessWidget {
  const HabitOverviewChart({super.key, required this.points});

  final List<DailyScorePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    final dayFormat = DateFormat.E(); // Mon, Tue, ...

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].total == 0 ? 0 : points[i].done / points[i].total * 100,
                  color: color,
                  width: 18,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dayFormat.format(points[index].day),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x];
              return BarTooltipItem(
                '${point.done}/${point.total}',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
