import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../logic/daily_budget.dart';
import '../models/dashboard_summary.dart';
import '../models/enums.dart';
import '../providers/dashboard_providers.dart';
import '../providers/habit_progress_providers.dart';
import '../providers/navigation_providers.dart';
import '../widgets/backup_menu_button.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

/// FR-8: home dashboard — current month spend vs budget, daily pace,
/// active alerts, and top overspending categories, plus a glance at
/// today's habit completion (cross-module — see [_HabitStatusCard]).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: const [BackupMenuButton()],
      ),
      body: Column(
        children: [
          const _HabitStatusCard(),
          Expanded(
            child: summaryAsync.when(
              data: (summary) {
                if (summary.totalBudget == 0 && summary.topLevelProgress.isEmpty) {
                  return _EmptyState(
                    onSetUpBudgets: () =>
                        ref.read(bottomNavIndexProvider.notifier).state = 2,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _TotalSpendCard(summary: summary),
                      const SizedBox(height: 12),
                      _PaceCard(summary: summary),
                      if (summary.activeAlerts.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AlertBanner(alerts: summary.activeAlerts),
                      ],
                      if (summary.topSpending.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Top Spending Categories',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final progress in summary.topSpending)
                          _CategoryProgressTile(progress: progress),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small "N / M habits done today" glance card — shown regardless of the
/// expense summary's own loading/empty state (it's unrelated to whether
/// budgets are set up), and hidden entirely when no habits are due today.
class _HabitStatusCard extends ConsumerWidget {
  const _HabitStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(todayHabitScoreProvider);
    return scoreAsync.when(
      data: (score) {
        if (score.total == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${score.done} / ${score.total} habits done today',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSetUpBudgets});

  final VoidCallback onSetUpBudgets;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insights_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No budgets set for this month yet.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onSetUpBudgets,
              child: const Text('Set up budgets'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalSpendCard extends StatelessWidget {
  const _TotalSpendCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratio = summary.totalBudget <= 0
        ? 0.0
        : (summary.totalActual / summary.totalBudget).clamp(0.0, 1.5);
    final color = ratio >= 1.0
        ? Colors.red
        : ratio >= 0.8
        ? Colors.orange
        : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This Month', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(summary.totalActual),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'of ${_currencyFormat.format(summary.totalBudget)} budgeted',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  const _PaceCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (summary.pace) {
      PaceStatus.ahead => (Icons.trending_down, 'Ahead of pace', Colors.green),
      PaceStatus.onTrack => (Icons.trending_flat, 'On track', Colors.blue),
      PaceStatus.behind => (Icons.trending_up, 'Behind pace', Colors.red),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        subtitle: Text(
          'Allowed to date: ${_currencyFormat.format(summary.cumulativeAllowedValue)} '
          '· Daily allowance: ${_currencyFormat.format(summary.dailyAllowanceValue)}',
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.alerts});

  final List<CategoryProgress> alerts;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Alerts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final progress in alerts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${progress.category.name} — ${_severityLabel(progress.severity!)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _severityLabel(AlertType type) => switch (type) {
    AlertType.approaching => 'Approaching threshold',
    AlertType.reached => 'Threshold reached',
    AlertType.exceeded => 'Threshold exceeded',
  };
}

class _CategoryProgressTile extends StatelessWidget {
  const _CategoryProgressTile({required this.progress});

  final TopLevelBudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final ratio = (progress.percentOfBudget / 100).clamp(0.0, 1.5);
    final color = ratio >= 1.0
        ? Colors.red
        : ratio >= 0.8
        ? Colors.orange
        : Color(progress.category.colorValue);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(progress.category.colorValue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Always a top-level category — never a sub-category —
                  // so there's nothing here to mistake for one.
                  Text(
                    progress.category.name,
                    style: progress.isOverBudget
                        ? const TextStyle(decoration: TextDecoration.lineThrough)
                        : null,
                  ),
                  if (progress.fromSubCategories)
                    Text(
                      'Includes sub-categories',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${progress.percentOfBudget.round()}%'),
          ],
        ),
      ),
    );
  }
}
