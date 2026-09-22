import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../providers/database_providers.dart';
import '../providers/habit_category_providers.dart';
import '../providers/habit_progress_providers.dart';
import '../providers/habit_providers.dart';
import '../widgets/day_selector.dart';
import '../widgets/habit_category_form_dialog.dart';
import '../widgets/habit_editor_sheet.dart';
import '../widgets/habit_overview_chart.dart';
import '../widgets/habit_tile.dart';
import 'habit_detail_screen.dart';

/// Habit Tracker RS §4.1/§4.2: "Today" for daily quick-logging, "Manage"
/// for habit CRUD — its own tab within the app shell, independent of the
/// expense tracker screens (RS §5 "modular UI").
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: 'Habit categories',
            icon: const Icon(Icons.label_outline),
            onPressed: () => _showCategoriesSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Named "Check-in" rather than "Today" — the tab's own content
          // already has a "Today"/date label (DaySelector) directly below
          // it, and two "Today"s stacked on screen at once read as a bug.
          tabs: const [Tab(text: 'Check-in'), Tab(text: 'Manage')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_TodayTab(), _ManageTab()],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _addHabit(context),
              icon: const Icon(Icons.add),
              label: const Text('Habit'),
            )
          : null,
    );
  }

  Future<void> _addHabit(BuildContext context) async {
    final result = await HabitEditorSheet.show(context);
    if (result == null) return;
    await ref.read(habitRepositoryProvider).add(
      HabitsCompanion.insert(
        name: result.name,
        icon: Value(result.icon),
        colorValue: Value(result.colorValue),
        categoryId: Value(result.categoryId),
        type: result.type,
        frequencyType: result.frequencyType,
        frequencyConfig: Value(result.frequencyConfig),
        targetValue: Value(result.targetValue),
        unit: Value(result.unit),
        startDate: result.startDate,
        endDate: Value(result.endDate),
      ),
    );
  }

  void _showCategoriesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HabitCategoriesSheet(),
    );
  }
}

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(habitProgressForDateProvider(_selectedDate));
    final trendAsync = ref.watch(overallWeeklyTrendProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        DaySelector(date: _selectedDate, onChanged: (d) => setState(() => _selectedDate = d)),
        Expanded(
          child: progressAsync.when(
            data: (progress) {
              final due = progress.where((p) => p.isDue).toList()
                ..sort((a, b) => a.habit.name.compareTo(b.habit.name));
              final done = due.where((p) => p.isCompleted).length;
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _isToday
                              ? '$done / ${due.length} habits done today'
                              : '$done / ${due.length} habits done',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Last 7 days', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      height: 140,
                      child: trendAsync.when(
                        data: (points) => HabitOverviewChart(points: points),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Text('Error: $error'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (due.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _isToday
                            ? 'No habits due today. Add one from the Manage tab.'
                            : 'No habits due on this day.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final p in due)
                      HabitTile(
                        progress: p,
                        date: _selectedDate,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HabitDetailScreen(habitId: p.habit.id),
                          ),
                        ),
                      ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }
}

class _ManageTab extends ConsumerStatefulWidget {
  const _ManageTab();

  @override
  ConsumerState<_ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends ConsumerState<_ManageTab> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider(!_showArchived));

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            label: Text(_showArchived ? 'Hide archived' : 'Show archived'),
          ),
        ),
        Expanded(
          child: habitsAsync.when(
            data: (habits) {
              if (habits.isEmpty) {
                return const Center(child: Text('No habits yet — tap + to add one.'));
              }
              // Drag to reorder/pin (Habit Tracker RS §4.1) — persists via
              // HabitRepository.reorder, which the Today tab's ordering
              // already follows.
              return ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                buildDefaultDragHandles: false,
                itemCount: habits.length,
                onReorderItem: (oldIndex, newIndex) => _reorder(habits, oldIndex, newIndex),
                itemBuilder: (context, index) => _ManageHabitTile(
                  key: ValueKey(habits[index].id),
                  habit: habits[index],
                  index: index,
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  Future<void> _reorder(List<Habit> habits, int oldIndex, int newIndex) async {
    // onReorderItem (unlike the deprecated onReorder) already adjusts
    // newIndex for the removed item at oldIndex.
    final reordered = List<Habit>.of(habits);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await ref.read(habitRepositoryProvider).reorder(reordered.map((h) => h.id).toList());
  }
}

class _ManageHabitTile extends ConsumerWidget {
  const _ManageHabitTile({super.key, required this.habit, required this.index});

  final Habit habit;

  /// This tile's position in the ReorderableListView — required by
  /// [ReorderableDragStartListener] to report drags back to onReorder.
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(habit.colorValue),
          child: Text(
            habit.icon?.isNotEmpty == true ? habit.icon! : habit.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          habit.name,
          style: habit.isActive ? null : const TextStyle(decoration: TextDecoration.lineThrough),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (action) => _handle(context, ref, action),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle_active',
                  child: Text(habit.isActive ? 'Archive' : 'Unarchive'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String action) async {
    final repo = ref.read(habitRepositoryProvider);
    switch (action) {
      case 'edit':
        final result = await HabitEditorSheet.show(context, existing: habit);
        if (result == null) return;
        await repo.update(
          habit.copyWith(
            name: result.name,
            icon: Value(result.icon),
            colorValue: result.colorValue,
            categoryId: Value(result.categoryId),
            type: result.type,
            frequencyType: result.frequencyType,
            frequencyConfig: result.frequencyConfig,
            targetValue: Value(result.targetValue),
            unit: Value(result.unit),
            startDate: result.startDate,
            endDate: Value(result.endDate),
          ),
        );
      case 'toggle_active':
        await repo.setActive(habit.id, !habit.isActive);
      case 'delete':
        final messenger = ScaffoldMessenger.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete habit?'),
            content: Text('This permanently deletes "${habit.name}". This can\'t be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await repo.delete(habit.id);
        } on StateError catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
    }
  }
}

class _HabitCategoriesSheet extends ConsumerWidget {
  const _HabitCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(habitCategoriesProvider(false));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Habit categories', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addCategory(context, ref),
                ),
              ],
            ),
            Flexible(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No categories yet.'),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final category in categories)
                        ListTile(
                          leading: CircleAvatar(backgroundColor: Color(category.colorValue)),
                          title: Text(
                            category.name,
                            style: category.isActive
                                ? null
                                : const TextStyle(decoration: TextDecoration.lineThrough),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => _handle(context, ref, category, action),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'toggle_active',
                                child: Text(category.isActive ? 'Archive' : 'Unarchive'),
                              ),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref) async {
    final result = await HabitCategoryFormDialog.show(context);
    if (result == null) return;
    await ref
        .read(habitCategoryRepositoryProvider)
        .add(name: result.name, colorValue: result.colorValue);
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    HabitCategory category,
    String action,
  ) async {
    final repo = ref.read(habitCategoryRepositoryProvider);
    switch (action) {
      case 'edit':
        final result = await HabitCategoryFormDialog.show(context, existing: category);
        if (result == null) return;
        await repo.update(
          category.copyWith(name: result.name, colorValue: result.colorValue),
        );
      case 'toggle_active':
        await repo.setActive(category.id, !category.isActive);
      case 'delete':
        final messenger = ScaffoldMessenger.of(context);
        try {
          await repo.delete(category.id);
        } on StateError catch (e) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        }
    }
  }
}
