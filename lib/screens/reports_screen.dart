import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../db/database.dart';
import '../logic/trend_projection.dart';
import '../models/enums.dart';
import '../providers/category_providers.dart';
import '../providers/report_providers.dart';
import '../widgets/backup_menu_button.dart';

final _currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);
final _compactCurrencyFormat = NumberFormat.compactCurrency(
  symbol: currencySymbol,
  decimalDigits: 0,
);

const _periods = [
  ReportPeriod.week,
  ReportPeriod.month,
  ReportPeriod.quarter,
  ReportPeriod.year,
];

/// FR-6: weekly/monthly/quarterly/yearly comparison reports (totals and
/// category breakdown, as bar/pie/line charts), plus FR-7's cost
/// projection for month/quarter/year.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: const [BackupMenuButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Week'),
            Tab(text: 'Month'),
            Tab(text: 'Quarter'),
            Tab(text: 'Year'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _CategoryFilterDropdown(
              value: _categoryFilter,
              onChanged: (value) => setState(() => _categoryFilter = value),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final period in _periods)
                  _ReportPeriodView(
                    period: period,
                    categoryId: _categoryFilter,
                    showProjection: period != ReportPeriod.week,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterDropdown extends ConsumerWidget {
  const _CategoryFilterDropdown({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(allCategoriesProvider);
    return categoriesAsync.when(
      data: (categories) => DropdownButtonFormField<int?>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Category filter',
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All categories')),
          for (final category in categories)
            DropdownMenuItem(value: category.id, child: Text(category.name)),
        ],
        onChanged: onChanged,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Error: $error'),
    );
  }
}

class _ReportPeriodView extends ConsumerWidget {
  const _ReportPeriodView({
    required this.period,
    required this.categoryId,
    required this.showProjection,
  });

  final ReportPeriod period;
  final int? categoryId;
  final bool showProjection;

  double _totalFor(Map<int, double> breakdown) {
    if (categoryId != null) return breakdown[categoryId] ?? 0;
    return breakdown.values.fold(0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(
      periodCategoryBreakdownProvider((period: period, offset: 0)),
    );
    final previousAsync = ref.watch(
      periodCategoryBreakdownProvider((period: period, offset: -1)),
    );
    final trendAsync = ref.watch(
      periodTrendProvider((period: period, count: 6, categoryId: categoryId)),
    );
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Comparison', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: currentAsync.when(
            data: (current) => previousAsync.when(
              data: (previous) => _ComparisonBarChart(
                current: _totalFor(current),
                previous: _totalFor(previous),
                period: period,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
        if (categoryId == null) ...[
          const SizedBox(height: 24),
          Text('Category Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: currentAsync.when(
              data: (current) => categoriesAsync.when(
                data: (categories) => _CategoryPieChart(
                  breakdown: current,
                  categories: categories,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Trend', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: trendAsync.when(
            data: (trend) => _TrendLineChart(values: trend),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
        if (showProjection) ...[
          const SizedBox(height: 24),
          Text('Projection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final projectionAsync = ref.watch(
                periodProjectionProvider((period: period, categoryId: categoryId)),
              );
              return projectionAsync.when(
                data: (projection) => _ProjectionCard(projection: projection),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Error: $error'),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ComparisonBarChart extends StatelessWidget {
  const _ComparisonBarChart({
    required this.current,
    required this.previous,
    required this.period,
  });

  final double current;
  final double previous;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final maxValue = [current, previous, 1.0].reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    final previousColor = Theme.of(context).colorScheme.outlineVariant;

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [BarChartRodData(toY: previous, color: previousColor, width: 28)],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [BarChartRodData(toY: current, color: color, width: 28)],
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 8),
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
                BarTooltipItem(_currencyFormat.format(rod.toY), const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({required this.breakdown, required this.categories});

  final Map<int, double> breakdown;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) {
      return const Center(child: Text('No spending in this period.'));
    }
    final categoriesById = {for (final c in categories) c.id: c};
    final entries = breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                for (final entry in entries)
                  PieChartSectionData(
                    value: entry.value,
                    color: categoriesById[entry.key] != null
                        ? Color(categoriesById[entry.key]!.colorValue)
                        : Colors.grey,
                    title: '${(entry.value / total * 100).round()}%',
                    radius: 56,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ListView(
            children: [
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 6,
                        backgroundColor: categoriesById[entry.key] != null
                            ? Color(categoriesById[entry.key]!.colorValue)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          categoriesById[entry.key]?.name ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.every((v) => v == 0)) {
      return const Center(child: Text('No spending history yet.'));
    }
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        maxY: maxValue * 1.2,
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
            ],
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) =>
                  Text(_compactCurrencyFormat.format(value), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.projection});

  final ProjectionResult projection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projected next period',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(projection.projected),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Range: ${_currencyFormat.format(projection.projectedMin)} – '
              '${_currencyFormat.format(projection.projectedMax)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
