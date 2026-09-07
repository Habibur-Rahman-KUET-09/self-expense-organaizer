import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../logic/daily_budget.dart';
import '../models/dashboard_summary.dart';
import '../models/enums.dart';
import '../providers/dashboard_providers.dart';
import '../providers/navigation_providers.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

/// FR-8: home dashboard — current month spend vs budget, daily pace,
/// active alerts, top overspending categories, and quick links (FR-8.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: summaryAsync.when(
        data: (summary) {
          if (summary.totalMax == 0 && summary.categoryProgress.isEmpty) {
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
                const SizedBox(height: 24),
                const _QuickLinks(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
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
    final ratio = summary.totalMax <= 0
        ? 0.0
        : (summary.totalActual / summary.totalMax).clamp(0.0, 1.5);
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
              'of ${_currencyFormat.format(summary.totalMax)} budgeted',
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

  final CategoryProgress progress;

  @override
  Widget build(BuildContext context) {
    final ratio = (progress.percentOfMax / 100).clamp(0.0, 1.5);
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
                  Text(progress.category.name),
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
            Text('${progress.percentOfMax.round()}%'),
          ],
        ),
      ),
    );
  }
}

class _QuickLinks extends ConsumerWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goTo(int index) => ref.read(bottomNavIndexProvider.notifier).state = index;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickLinkButton(
          icon: Icons.add_circle_outline,
          label: 'Add Expense',
          onTap: () => goTo(1),
        ),
        _QuickLinkButton(
          icon: Icons.bar_chart_outlined,
          label: 'Reports',
          onTap: () => goTo(3),
        ),
        _QuickLinkButton(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Categories',
          onTap: () => goTo(2),
        ),
      ],
    );
  }
}

class _QuickLinkButton extends StatelessWidget {
  const _QuickLinkButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
