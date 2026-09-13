import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../logic/frequency_schedule.dart';
import '../logic/habit_completion.dart';
import '../logic/period_utils.dart';
import '../logic/streak_calculator.dart';
import '../models/enums.dart';
import '../models/habit_progress.dart';
import 'database_providers.dart';
import 'habit_log_providers.dart';
import 'habit_providers.dart';

/// Today's overall completion score — exposed at the top level (not just
/// inside the Habits tab) so cross-module summaries like the expense
/// Dashboard's small habit status card can show it without reaching into
/// the full per-habit list themselves.
final todayHabitScoreProvider = FutureProvider.autoDispose<DailyHabitScore>((
  ref,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final progress = await ref.watch(habitProgressForDateProvider(today).future);
  final due = progress.where((p) => p.isDue).toList();
  final done = due.where((p) => p.isCompleted).length;
  return (done: done, total: due.length);
});

/// Habit Tracker RS §4.2 (Today screen, browsable to any past day for
/// backfilling) + §4.3 (streaks) — every active habit's due/log/completed
/// state for [date], reactive to habit/log changes. [date] should be
/// midnight-normalized.
///
/// Streaks are always computed as of the *real* current date, never as of
/// [date] — browsing back to backfill a missed day shows that day's own
/// due/completed state, but the streak numbers on the tile always reflect
/// where the habit actually stands today.
final habitProgressForDateProvider = FutureProvider.autoDispose
    .family<List<HabitProgress>, DateTime>((ref, date) async {
      ref.watch(allHabitLogsProvider); // reactive trigger only, see its doc comment
      final habits = await ref.watch(habitsProvider(true).future);
      final habitLogRepo = ref.watch(habitLogRepositoryProvider);
      final habitCategoryRepo = ref.watch(habitCategoryRepositoryProvider);

      final categories = await habitCategoryRepo.getAll(activeOnly: false);
      final categoriesById = {for (final c in categories) c.id: c};

      final targetDay = DateTime(date.year, date.month, date.day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final result = <HabitProgress>[];
      for (final habit in habits) {
        final schedule = FrequencySchedule.parse(habit.frequencyType, habit.frequencyConfig);
        final startDate = DateTime(
          habit.startDate.year,
          habit.startDate.month,
          habit.startDate.day,
        );
        final isWithinRunOnTarget =
            !startDate.isAfter(targetDay) &&
            (habit.endDate == null || !habit.endDate!.isBefore(targetDay));
        final isDueOnTarget = isWithinRunOnTarget && schedule.isDueOn(targetDay);

        final logs = await habitLogRepo.getForHabitInRange(habit.id, startDate, tomorrow);
        final logsByDay = {
          for (final log in logs)
            DateTime(log.logDate.year, log.logDate.month, log.logDate.day): log,
        };
        final targetLog = logsByDay[targetDay];
        bool completedOn(DateTime day) {
          final log = logsByDay[day];
          return isLogComplete(
            type: habit.type,
            targetValue: habit.targetValue,
            hasLog: log != null,
            loggedValue: log?.value,
          );
        }

        final isDueToday =
            !startDate.isAfter(today) &&
            (habit.endDate == null || !habit.endDate!.isBefore(today)) &&
            schedule.isDueOn(today);
        final StreakResult streak;
        if (schedule.type.isCountBased) {
          final ranges = schedule.type == HabitFrequencyType.timesPerWeek
              ? weeklyPeriodRanges(startDate, today)
              : monthlyPeriodRanges(startDate, today);
          streak = periodBasedStreak(
            periodRanges: ranges,
            countInRange: (start, endExclusive) => logs
                .where((l) => !l.logDate.isBefore(start) && l.logDate.isBefore(endExclusive))
                .length,
            targetCount: schedule.targetCount,
          );
        } else {
          // A due-but-not-yet-logged "today" shouldn't zero out an otherwise
          // intact streak before the day is even over — only let today count
          // against the streak once it actually has a log (see
          // dayBasedStreak's doc comment on this exact grace period).
          final asOf = (isDueToday && logsByDay[today] == null)
              ? today.subtract(const Duration(days: 1))
              : today;
          streak = dayBasedStreak(
            startDate: startDate,
            asOf: asOf,
            isDue: schedule.isDueOn,
            isCompleted: completedOn,
          );
        }

        result.add(
          HabitProgress(
            habit: habit,
            category: habit.categoryId != null ? categoriesById[habit.categoryId] : null,
            isDue: isDueOnTarget,
            log: targetLog,
            isCompleted: completedOn(targetDay),
            currentStreak: streak.current,
            longestStreak: streak.longest,
          ),
        );
      }
      return result;
    });

/// Habit Tracker RS §4.3 "trend comparison" at the whole-habit-set level
/// (not just one habit) — each of the last 7 days' overall completion
/// score, oldest first, so the Today tab can show an at-a-glance
/// improving/declining trend instead of just a single day's snapshot.
final overallWeeklyTrendProvider = FutureProvider.autoDispose<List<DailyScorePoint>>((
  ref,
) async {
  ref.watch(allHabitLogsProvider); // reactive trigger only
  final habits = await ref.watch(habitsProvider(true).future);
  final habitLogRepo = ref.watch(habitLogRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = today.subtract(const Duration(days: 6));

  final schedulesByHabit = {
    for (final habit in habits)
      habit.id: FrequencySchedule.parse(habit.frequencyType, habit.frequencyConfig),
  };
  final logsByHabit = <int, Map<DateTime, HabitLog>>{};
  for (final habit in habits) {
    final logs = await habitLogRepo.getForHabitInRange(
      habit.id,
      windowStart,
      today.add(const Duration(days: 1)),
    );
    logsByHabit[habit.id] = {
      for (final log in logs)
        DateTime(log.logDate.year, log.logDate.month, log.logDate.day): log,
    };
  }

  final points = <DailyScorePoint>[];
  for (var day = windowStart; !day.isAfter(today); day = day.add(const Duration(days: 1))) {
    var due = 0;
    var done = 0;
    for (final habit in habits) {
      final startDate = DateTime(
        habit.startDate.year,
        habit.startDate.month,
        habit.startDate.day,
      );
      final withinRun =
          !startDate.isAfter(day) && (habit.endDate == null || !habit.endDate!.isBefore(day));
      if (!withinRun || !schedulesByHabit[habit.id]!.isDueOn(day)) continue;
      due += 1;
      final log = logsByHabit[habit.id]?[day];
      final completed = isLogComplete(
        type: habit.type,
        targetValue: habit.targetValue,
        hasLog: log != null,
        loggedValue: log?.value,
      );
      if (completed) done += 1;
    }
    points.add((day: day, done: done, total: due));
  }
  return points;
});

/// Habit Tracker RS §4.3 — a single habit's detail-screen stats: streaks,
/// completion rates, this-vs-last trend, and heatmap data. [habitId] must
/// name an existing habit.
final habitDetailStatsProvider = FutureProvider.autoDispose.family<HabitDetailStats, int>((
  ref,
  habitId,
) async {
  ref.watch(allHabitLogsProvider); // reactive trigger only
  final habit = await ref.watch(habitRepositoryProvider).getById(habitId);
  if (habit == null) {
    throw StateError('Habit $habitId not found');
  }
  final category = habit.categoryId != null
      ? await ref.watch(habitCategoryRepositoryProvider).getById(habit.categoryId!)
      : null;

  final schedule = FrequencySchedule.parse(habit.frequencyType, habit.frequencyConfig);
  final startDate = DateTime(habit.startDate.year, habit.startDate.month, habit.startDate.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));

  final habitLogRepo = ref.watch(habitLogRepositoryProvider);
  final logs = await habitLogRepo.getForHabitInRange(habitId, startDate, tomorrow);
  final logsByDay = {
    for (final log in logs) DateTime(log.logDate.year, log.logDate.month, log.logDate.day): log,
  };
  bool completedOn(DateTime day) {
    final log = logsByDay[day];
    return isLogComplete(
      type: habit.type,
      targetValue: habit.targetValue,
      hasLog: log != null,
      loggedValue: log?.value,
    );
  }

  int countInRange(DateTime start, DateTime endExclusive) {
    var count = 0;
    for (var day = start; day.isBefore(endExclusive); day = day.add(const Duration(days: 1))) {
      if (completedOn(day)) count += 1;
    }
    return count;
  }

  final StreakResult streak;
  if (schedule.type.isCountBased) {
    final ranges = schedule.type == HabitFrequencyType.timesPerWeek
        ? weeklyPeriodRanges(startDate, today)
        : monthlyPeriodRanges(startDate, today);
    streak = periodBasedStreak(
      periodRanges: ranges,
      countInRange: (start, endExclusive) => logs
          .where((l) => !l.logDate.isBefore(start) && l.logDate.isBefore(endExclusive))
          .length,
      targetCount: schedule.targetCount,
    );
  } else {
    final todayLog = logsByDay[today];
    final isDueToday = !startDate.isAfter(today) && schedule.isDueOn(today);
    final asOf =
        (isDueToday && todayLog == null) ? today.subtract(const Duration(days: 1)) : today;
    streak = dayBasedStreak(
      startDate: startDate,
      asOf: asOf,
      isDue: schedule.isDueOn,
      isCompleted: completedOn,
    );
  }

  final (thisWeekStart, thisWeekEnd) = reportPeriodRange(ReportPeriod.week, today, 0);
  final (lastWeekStart, lastWeekEnd) = reportPeriodRange(ReportPeriod.week, today, -1);
  final (thisMonthStart, thisMonthEnd) = reportPeriodRange(ReportPeriod.month, today, 0);
  final (lastMonthStart, lastMonthEnd) = reportPeriodRange(ReportPeriod.month, today, -1);

  final completionRateThisWeek = schedule.type.isCountBased
      ? 0.0
      : dayBasedCompletionRate(
          start: thisWeekStart,
          endExclusive: thisWeekEnd,
          isDue: schedule.isDueOn,
          isCompleted: completedOn,
        );
  final completionRateThisMonth = schedule.type.isCountBased
      ? 0.0
      : dayBasedCompletionRate(
          start: thisMonthStart,
          endExclusive: thisMonthEnd,
          isDue: schedule.isDueOn,
          isCompleted: completedOn,
        );

  // A contribution-graph-style window: from the habit's start, capped at
  // the last 126 days (18 weeks) so long-running habits still get a
  // compact grid.
  final heatmapStart = today.subtract(const Duration(days: 125)).isAfter(startDate)
      ? today.subtract(const Duration(days: 125))
      : startDate;
  final heatmapDays = <HeatmapDay>[
    for (var day = heatmapStart; !day.isAfter(today); day = day.add(const Duration(days: 1)))
      (day: day, isDue: schedule.isDueOn(day), completed: completedOn(day)),
  ];

  return HabitDetailStats(
    habit: habit,
    category: category,
    currentStreak: streak.current,
    longestStreak: streak.longest,
    completionRateThisWeek: completionRateThisWeek,
    completionRateThisMonth: completionRateThisMonth,
    completedThisWeek: countInRange(thisWeekStart, thisWeekEnd),
    completedLastWeek: countInRange(lastWeekStart, lastWeekEnd),
    completedThisMonth: countInRange(thisMonthStart, thisMonthEnd),
    completedLastMonth: countInRange(lastMonthStart, lastMonthEnd),
    heatmapDays: heatmapDays,
  );
});
