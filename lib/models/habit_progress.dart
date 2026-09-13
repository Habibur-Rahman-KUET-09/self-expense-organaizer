import '../db/database.dart';

/// A single habit's Today-screen state plus streak stats (Habit Tracker RS
/// §4.2/§4.3), computed as of today.
class HabitProgress {
  const HabitProgress({
    required this.habit,
    required this.category,
    required this.isDueToday,
    required this.todayLog,
    required this.isCompletedToday,
    required this.currentStreak,
    required this.longestStreak,
  });

  final Habit habit;
  final HabitCategory? category;
  final bool isDueToday;
  final HabitLog? todayLog;
  final bool isCompletedToday;
  final int currentStreak;
  final int longestStreak;
}

/// Habit Tracker RS §4.3 "overall daily completion score", e.g. 4/6 habits
/// done today.
typedef DailyHabitScore = ({int done, int total});

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
