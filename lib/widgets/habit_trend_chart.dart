import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// This-period-vs-last-period comparison bar chart for a single habit
/// (Habit Tracker RS §4.3), mirroring the Reports screen's comparison
/// chart but for a plain completion count rather than currency.
class HabitTrendChart extends StatelessWidget {
  const HabitTrendChart({
    super.key,
    required this.current,
    required this.previous,
    required this.color,
  });

  final int current;
  final int previous;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = [current, previous, 1].reduce((a, b) => a > b ? a : b).toDouble();
    final previousColor = Theme.of(context).colorScheme.outlineVariant;

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [BarChartRodData(toY: previous.toDouble(), color: previousColor, width: 28)],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [BarChartRodData(toY: current.toDouble(), color: color, width: 28)],
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(value == 0 ? 'Previous' : 'Current'),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem('${rod.toY.round()}', const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
