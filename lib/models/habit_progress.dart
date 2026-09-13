import '../db/database.dart';

/// A single habit's state for one calendar day (the Today screen's
/// [date], which defaults to today but can browse/backfill other days —
/// Habit Tracker RS §4.2) plus its streak stats. Streaks always reflect
/// the real current date regardless of which day is being viewed — see
/// habit_progress_providers.dart's doc comment on habitProgressForDateProvider.
class HabitProgress {
  const HabitProgress({
    required this.habit,
    required this.category,
    required this.isDue,
    required this.log,
    required this.isCompleted,
    required this.currentStreak,
    required this.longestStreak,
  });

  final Habit habit;
  final HabitCategory? category;

  /// Whether [habit] is due on the day this progress was computed for.
  final bool isDue;

  /// That day's log, if any.
  final HabitLog? log;

  /// Whether that day's log (if any) satisfies [habit].
  final bool isCompleted;
  final int currentStreak;
  final int longestStreak;
}

/// Habit Tracker RS §4.3 "overall daily completion score", e.g. 4/6 habits
/// done — for one day.
typedef DailyHabitScore = ({int done, int total});

/// One day's overall completion score, for the Today tab's weekly overview
/// chart (Habit Tracker RS §4.3 "trend comparison").
typedef DailyScorePoint = ({DateTime day, int done, int total});

/// One day's cell for the calendar heatmap (Habit Tracker RS §4.3).
typedef HeatmapDay = ({DateTime day, bool isDue, bool completed});

/// A single habit's detail-screen stats: streaks, completion rates, trend
/// comparison, and heatmap data.
class HabitDetailStats {
  const HabitDetailStats({
    required this.habit,
    required this.category,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRateThisWeek,
    required this.completionRateThisMonth,
    required this.completedThisWeek,
    required this.completedLastWeek,
    required this.completedThisMonth,
    required this.completedLastMonth,
    required this.heatmapDays,
  });

  final Habit habit;
  final HabitCategory? category;
  final int currentStreak;
  final int longestStreak;

  /// 0.0-1.0 fraction of due days completed. Not meaningful for
  /// count-based frequencies (timesPerWeek/timesPerMonth — any day can be
  /// "due"), which report 0 here; [completedThisWeek]/[completedThisMonth]
  /// carry their real signal instead.
  final double completionRateThisWeek;
  final double completionRateThisMonth;

  /// "How many times this habit was done" in each period — a uniform,
  /// comparable count across binary/quantifiable/count-based habits alike,
  /// used for the this-vs-last trend comparison (Habit Tracker RS §4.3).
  final int completedThisWeek;
  final int completedLastWeek;
  final int completedThisMonth;
  final int completedLastMonth;

  final List<HeatmapDay> heatmapDays;
}
