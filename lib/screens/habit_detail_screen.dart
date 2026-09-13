import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/habit_progress.dart';
import '../providers/habit_progress_providers.dart';
import '../widgets/habit_calendar_heatmap.dart';
import '../widgets/habit_trend_chart.dart';

/// Habit Tracker RS §4.3: streaks, completion rates, a calendar heatmap,
/// and this-vs-last trend comparison for a single habit.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitDetailStatsProvider(habitId));

    return Scaffold(
      appBar: AppBar(
        title: statsAsync.maybeWhen(
          data: (stats) => Text(stats.habit.name),
          orElse: () => const Text('Habit'),
        ),
      ),
      body: statsAsync.when(
        data: (stats) => _HabitDetailBody(stats: stats),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _HabitDetailBody extends StatelessWidget {
  const _HabitDetailBody({required this.stats});

  final HabitDetailStats stats;

  @override
  Widget build(BuildContext context) {
    final color = Color(stats.habit.colorValue);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (stats.category != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Chip(
              avatar: CircleAvatar(backgroundColor: Color(stats.category!.colorValue)),
              label: Text(stats.category!.name),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _StatCard(label: 'Current streak', value: '${stats.currentStreak}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(label: 'Longest streak', value: '${stats.longestStreak}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'This week',
                value: '${(stats.completionRateThisWeek * 100).round()}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'This month',
                value: '${(stats.completionRateThisMonth * 100).round()}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Calendar', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        HabitCalendarHeatmap(days: stats.heatmapDays, color: color),
        const SizedBox(height: 24),
        Text('This week vs last week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: HabitTrendChart(
            current: stats.completedThisWeek,
            previous: stats.completedLastWeek,
            color: color,
          ),
        ),
        const SizedBox(height: 24),
        Text('This month vs last month', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: HabitTrendChart(
            current: stats.completedThisMonth,
            previous: stats.completedLastMonth,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
