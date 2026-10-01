import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../logic/monthly_reports.dart';
import '../providers/expense_providers.dart';
import '../providers/service_providers.dart';
import '../widgets/month_selector.dart';

final _money = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);
final _day = DateFormat('d MMM');

YearMonth _thisMonth() {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
}

YearMonth _shift(YearMonth m, int by) {
  final d = DateTime(m.year, m.month + by);
  return (year: d.year, month: d.month);
}

String _fileStamp(YearMonth m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// Month-wise reports, each downloadable as CSV: one month's entries (all
/// or filtered), two or more months compared, and budget vs actual.
class MonthlyReportsScreen extends StatelessWidget {
  const MonthlyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monthly reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Entries'),
              Tab(text: 'Compare months'),
              Tab(text: 'Budget vs actual'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_EntriesTab(), _CompareTab(), _BudgetTab()],
        ),
      ),
    );
  }
}

Future<void> _download(BuildContext context, WidgetRef ref, String csv, String filename) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(monthlyReportServiceProvider).shareCsv(csv, filename);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: const Icon(Icons.download),
      label: const Text('Download (CSV)'),
    );
  }
}

// ------------------------------------------------------------ Entries tab

class _EntriesTab extends ConsumerStatefulWidget {
  const _EntriesTab();

  @override
  ConsumerState<_EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<_EntriesTab> with AutomaticKeepAliveClientMixin {
  YearMonth _month = _thisMonth();
  EntryFilter _filter = const EntryFilter();
  late Future<(List<EntryRow>, Map<int, ReportCategory>)> _data = _load();

  @override
  bool get wantKeepAlive => true;

  Future<(List<EntryRow>, Map<int, ReportCategory>)> _load() async {
    final service = ref.read(monthlyReportServiceProvider);
    return (await service.entries(_month), await service.categories());
  }

  void _reload() => setState(() {
        _data = _load();
      });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Reload when expenses of this month change.
    ref.listen(expensesInMonthProvider(_month), (_, _) => _reload());
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        final header = MonthSelector(
          year: _month.year,
          month: _month.month,
          onChanged: (d) {
            _month = (year: d.year, month: d.month);
            _reload();
          },
        );
        if (snap.hasError) return Column(children: [header, Text('Error: ${snap.error}')]);
        if (!snap.hasData) return Column(children: [header, const LinearProgressIndicator()]);
        final (all, categories) = snap.data!;
        final shown = filterEntries(all, _filter);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editFilter(categories),
                    icon: const Icon(Icons.filter_list),
                    label: Text(_filter.isEmpty ? 'Filter' : 'Filter (on)'),
                  ),
                  if (!_filter.isEmpty)
                    TextButton(
                      onPressed: () => setState(() => _filter = const EntryFilter()),
                      child: const Text('Clear filter'),
                    ),
                  _DownloadButton(
                    onPressed: shown.isEmpty
                        ? null
                        : () => _download(
                              context,
                              ref,
                              entriesCsv(shown, month: _month, filter: _filter),
                              'expenses_${_fileStamp(_month)}${_filter.isEmpty ? '' : '_filtered'}.csv',
                            ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filter.isEmpty
                            ? '${all.length} entries'
                            : '${shown.length} of ${all.length} entries',
                      ),
                      Text(
                        _money.format(totalOf(shown)),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (shown.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No entries for this month.')),
              ),
            for (final r in shown)
              ListTile(
                dense: true,
                leading: SizedBox(width: 48, child: Text(_day.format(r.date))),
                title: Text(r.categoryLabel),
                subtitle: (r.note ?? '').isEmpty ? null : Text(r.note!),
                trailing: Text(_money.format(r.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editFilter(Map<int, ReportCategory> categories) async {
    final result = await showModalBottomSheet<EntryFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filter, categories: categories),
    );
    if (result != null) setState(() => _filter = result);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.categories});

  final EntryFilter initial;
  final Map<int, ReportCategory> categories;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<int> _ids = {...widget.initial.categoryIds};
  late final _query = TextEditingController(text: widget.initial.query);
  late final _min = TextEditingController(text: widget.initial.minAmount?.toStringAsFixed(0) ?? '');
  late final _max = TextEditingController(text: widget.initial.maxAmount?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _query.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tops = widget.categories.values.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    List<ReportCategory> subsOf(int id) =>
        widget.categories.values.where((c) => c.parentId == id).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text('Filter entries', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _query,
                      decoration: const InputDecoration(
                        labelText: 'Search note or category',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _min,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min amount',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _max,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max amount',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Categories (a category includes its sub-categories)'),
                    const SizedBox(height: 8),
                    for (final top in tops) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: Text(top.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            selected: _ids.contains(top.id),
                            onSelected: (v) => setState(() => v ? _ids.add(top.id) : _ids.remove(top.id)),
                          ),
                          for (final sub in subsOf(top.id))
                            FilterChip(
                              label: Text('› ${sub.name}'),
                              selected: _ids.contains(sub.id) || _ids.contains(top.id),
                              onSelected: _ids.contains(top.id)
                                  ? null
                                  : (v) => setState(() => v ? _ids.add(sub.id) : _ids.remove(sub.id)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(const EntryFilter()),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(EntryFilter(
                      categoryIds: {..._ids},
                      query: _query.text,
                      minAmount: double.tryParse(_min.text.trim()),
                      maxAmount: double.tryParse(_max.text.trim()),
                    )),
                    child: const Text('Apply'),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Compare tab

class _CompareTab extends ConsumerStatefulWidget {
  const _CompareTab();

  @override
  ConsumerState<_CompareTab> createState() => _CompareTabState();
}

class _CompareTabState extends ConsumerState<_CompareTab> with AutomaticKeepAliveClientMixin {
  late List<YearMonth> _months = [_shift(_thisMonth(), -1), _thisMonth()];
  late Future<MonthComparison> _data = _load();

  @override
  bool get wantKeepAlive => true;

  Future<MonthComparison> _load() => ref.read(monthlyReportServiceProvider).compare(_months);

  void _setMonths(List<YearMonth> months) {
    final unique = {for (final m in months) m.year * 12 + m.month: m}.values.toList()
      ..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
    setState(() {
      _months = unique;
      _data = _load();
    });
  }

  Future<void> _addMonth() async {
    final picked = await showDialog<YearMonth>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: _months.isEmpty ? _thisMonth() : _shift(_months.first, -1)),
    );
    if (picked != null) _setMonths([..._months, picked]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Months to compare (2 or more)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final m in _months)
              InputChip(
                label: Text(monthLabel(m)),
                onDeleted: () => _setMonths([..._months]..remove(m)),
              ),
            ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Add month'), onPressed: _addMonth),
          ],
        ),
        const SizedBox(height: 12),
        if (_months.length < 2)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Pick at least two months.')),
          )
        else
          FutureBuilder(
            future: _data,
            builder: (context, snap) {
              if (snap.hasError) return Text('Error: ${snap.error}');
              if (!snap.hasData) return const LinearProgressIndicator();
              final c = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 200, child: _TotalsBarChart(comparison: c)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowHeight: 40,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columns: [
                        const DataColumn(label: Text('Category')),
                        for (final m in c.months)
                          DataColumn(label: Text(DateFormat.yMMM().format(DateTime(m.year, m.month))), numeric: true),
                        const DataColumn(label: Text('Change'), numeric: true),
                      ],
                      rows: [
                        for (final r in c.rows)
                          DataRow(cells: [
                            DataCell(Text(r.name)),
                            for (final a in r.amounts) DataCell(Text(_money.format(a))),
                            DataCell(_ChangeText(MonthComparison.change(r.amounts))),
                          ]),
                        DataRow(
                          color: WidgetStatePropertyAll(theme.colorScheme.primaryContainer),
                          cells: [
                            const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                            for (final t in c.totals)
                              DataCell(Text(_money.format(t), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(_ChangeText(MonthComparison.change(c.totals))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _DownloadButton(
                      onPressed: () => _download(
                        context,
                        ref,
                        comparisonCsv(c),
                        'comparison_${c.months.map(_fileStamp).join('_')}.csv',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _ChangeText extends StatelessWidget {
  const _ChangeText(this.change);

  final double change;

  @override
  Widget build(BuildContext context) {
    final color = change > 0 ? Colors.red : (change < 0 ? Colors.green : null);
    final sign = change > 0 ? '+' : (change < 0 ? '−' : '');
    return Text('$sign${_money.format(change.abs())}', style: TextStyle(color: color));
  }
}

class _TotalsBarChart extends StatelessWidget {
  const _TotalsBarChart({required this.comparison});

  final MonthComparison comparison;

  @override
  Widget build(BuildContext context) {
    final totals = comparison.totals;
    final maxValue = [...totals, 1.0].reduce((a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        barGroups: [
          for (var i = 0; i < totals.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: totals[i], color: color, width: 22)]),
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
                final m = comparison.months[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(DateFormat.MMM().format(DateTime(m.year, m.month)), style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(_money.format(rod.toY), const TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final YearMonth initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _year--)),
          Text('$_year'),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _year++)),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var m = 1; m <= 12; m++)
              ChoiceChip(
                label: Text(DateFormat.MMM().format(DateTime(_year, m))),
                selected: _year == widget.initial.year && m == widget.initial.month,
                onSelected: (_) => Navigator.of(context).pop((year: _year, month: m)),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}

// ------------------------------------------------------------ Budget tab

class _BudgetTab extends ConsumerStatefulWidget {
  const _BudgetTab();

  @override
  ConsumerState<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<_BudgetTab> with AutomaticKeepAliveClientMixin {
  YearMonth _month = _thisMonth();
  late Future<List<BudgetLine>> _data = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<BudgetLine>> _load() => ref.read(monthlyReportServiceProvider).budgetVsActual(_month);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(expensesInMonthProvider(_month), (_, _) => setState(() {
          _data = _load();
        }));
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        MonthSelector(
          year: _month.year,
          month: _month.month,
          onChanged: (d) => setState(() {
            _month = (year: d.year, month: d.month);
            _data = _load();
          }),
        ),
        FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) return Text('Error: ${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();
            final lines = snap.data!;
            if (lines.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No budget or spending this month.')),
              );
            }
            final budget = budgetTotal(lines), actual = actualTotal(lines);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Stat('Budget', _money.format(budget)),
                          _Stat('Spent', _money.format(actual)),
                          _Stat(
                            actual > budget ? 'Over by' : 'Left',
                            _money.format((budget - actual).abs()),
                            color: actual > budget ? Colors.red : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _BudgetBarChart(lines: [for (final l in lines) if (!l.isSub) l]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    _Legend(color: theme.colorScheme.outlineVariant, label: 'Budget'),
                    const SizedBox(width: 16),
                    _Legend(color: theme.colorScheme.primary, label: 'Spent'),
                    const SizedBox(width: 16),
                    const _Legend(color: Colors.red, label: 'Over budget'),
                  ]),
                ),
                const SizedBox(height: 8),
                for (final l in lines) _BudgetLineTile(line: l),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _DownloadButton(
                      onPressed: () => _download(
                        context,
                        ref,
                        budgetCsv(lines, month: _month),
                        'budget_vs_actual_${_fileStamp(_month)}.csv',
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _BudgetBarChart extends StatelessWidget {
  const _BudgetBarChart({required this.lines});

  final List<BudgetLine> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = [for (final l in lines) ...[l.budget, l.actual], 1.0].reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: maxValue * 1.15,
        barGroups: [
          for (var i = 0; i < lines.length; i++)
            BarChartGroupData(x: i, barsSpace: 2, barRods: [
              BarChartRodData(toY: lines[i].budget, color: scheme.outlineVariant, width: 9),
              BarChartRodData(toY: lines[i].actual, color: lines[i].isOver ? Colors.red : scheme.primary, width: 9),
            ]),
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
                final name = lines[value.toInt()].name;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(name.length > 6 ? '${name.substring(0, 6)}…' : name, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              '${lines[groupIndex].name}\n${rodIndex == 0 ? 'Budget' : 'Spent'}: ${_money.format(rod.toY)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetLineTile extends StatelessWidget {
  const _BudgetLineTile({required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final ratio = l.hasBudget ? (l.actual / l.budget).clamp(0.0, 1.0) : 0.0;
    final color = l.isOver ? Colors.red : ((l.percent ?? 0) >= 80 ? Colors.orange : Theme.of(context).colorScheme.primary);
    return Padding(
      padding: EdgeInsets.fromLTRB(l.isSub ? 36 : 16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                l.isSub ? '› ${l.name}' : l.name,
                style: TextStyle(
                  fontWeight: l.isSub ? FontWeight.normal : FontWeight.w600,
                  color: l.isOver ? Colors.red : null,
                  decoration: l.isOver ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              l.hasBudget ? '${_money.format(l.actual)} / ${_money.format(l.budget)}' : '${_money.format(l.actual)} · no budget',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
          if (l.hasBudget) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
