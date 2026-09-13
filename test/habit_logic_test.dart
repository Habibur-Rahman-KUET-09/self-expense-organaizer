import 'package:expense_tracker/logic/frequency_schedule.dart';
import 'package:expense_tracker/logic/habit_completion.dart';
import 'package:expense_tracker/logic/streak_calculator.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrequencySchedule (Habit Tracker RS §3 Frequency)', () {
    test('daily is always due', () {
      final schedule = FrequencySchedule.parse(HabitFrequencyType.daily, '{}');
      expect(schedule.isDueOn(DateTime(2026, 9, 1)), isTrue);
      expect(schedule.isDueOn(DateTime(2026, 9, 2)), isTrue);
    });

    test('daysOfWeek is due only on the configured ISO weekdays', () {
      final schedule = FrequencySchedule.parse(
        HabitFrequencyType.daysOfWeek,
        FrequencySchedule.encodeDaysOfWeek([DateTime.monday, DateTime.wednesday]),
      );
      // 2026-09-07 is a Monday.
      expect(schedule.isDueOn(DateTime(2026, 9, 7)), isTrue);
      expect(schedule.isDueOn(DateTime(2026, 9, 8)), isFalse); // Tuesday
      expect(schedule.isDueOn(DateTime(2026, 9, 9)), isTrue); // Wednesday
    });

    test('customInterval is due every N days counting from the anchor', () {
      final schedule = FrequencySchedule.parse(
        HabitFrequencyType.customInterval,
        FrequencySchedule.encodeCustomInterval(
          everyNDays: 3,
          anchorDate: DateTime(2026, 9, 1),
        ),
      );
      expect(schedule.isDueOn(DateTime(2026, 9, 1)), isTrue);
      expect(schedule.isDueOn(DateTime(2026, 9, 2)), isFalse);
      expect(schedule.isDueOn(DateTime(2026, 9, 3)), isFalse);
      expect(schedule.isDueOn(DateTime(2026, 9, 4)), isTrue);
      expect(schedule.isDueOn(DateTime(2026, 8, 31)), isFalse); // before anchor
    });

    test('timesPerWeek/timesPerMonth are count-based: always "due", never day-scheduled', () {
      final weekly = FrequencySchedule.parse(
        HabitFrequencyType.timesPerWeek,
        FrequencySchedule.encodeCount(3),
      );
      expect(weekly.isDueOn(DateTime(2026, 9, 1)), isTrue);
      expect(weekly.targetCount, 3);
      expect(HabitFrequencyType.timesPerWeek.isCountBased, isTrue);
      expect(HabitFrequencyType.daily.isCountBased, isFalse);
    });
  });

  group('dayBasedStreak (Habit Tracker RS §3 Streak)', () {
    bool isDueDaily(DateTime day) => true;

    test('consecutive completed due-days build the streak', () {
      final completed = {
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      };
      final result = dayBasedStreak(
        startDate: DateTime(2026, 9, 1),
        asOf: DateTime(2026, 9, 3),
        isDue: isDueDaily,
        isCompleted: completed.contains,
      );
      expect(result.current, 3);
      expect(result.longest, 3);
    });

    test('a missed due day resets the current streak but keeps the longest', () {
      final completed = {
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
        // 9/4 missed
        DateTime(2026, 9, 5),
      };
      final result = dayBasedStreak(
        startDate: DateTime(2026, 9, 1),
        asOf: DateTime(2026, 9, 5),
        isDue: isDueDaily,
        isCompleted: completed.contains,
      );
      expect(result.current, 1);
      expect(result.longest, 3);
    });

    test('non-due days are skipped without breaking the streak', () {
      // Mon/Wed/Fri only.
      final schedule = FrequencySchedule.parse(
        HabitFrequencyType.daysOfWeek,
        FrequencySchedule.encodeDaysOfWeek([1, 3, 5]),
      );
      // 2026-09-07 Mon, 09 Wed, 11 Fri — all logged; Tue/Thu/weekend skipped.
      final completed = {
        DateTime(2026, 9, 7),
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 11),
      };
      final result = dayBasedStreak(
        startDate: DateTime(2026, 9, 7),
        asOf: DateTime(2026, 9, 13), // Sunday, not due
        isDue: schedule.isDueOn,
        isCompleted: completed.contains,
      );
      expect(result.current, 3);
      expect(result.longest, 3);
    });
  });

  group('periodBasedStreak + period ranges', () {
    test('weeklyPeriodRanges spans Mon-Sun weeks oldest-first', () {
      final ranges = weeklyPeriodRanges(DateTime(2026, 9, 1), DateTime(2026, 9, 10));
      expect(ranges.length, 2);
      expect(ranges.first.$1, DateTime(2026, 8, 31)); // Monday of week containing Sep 1
    });

    test('a period meeting its target count extends the streak', () {
      final ranges = weeklyPeriodRanges(DateTime(2026, 9, 1), DateTime(2026, 9, 10));
      // First week: 3 logs (meets target of 3). Second week: 1 log (misses).
      final counts = {ranges[0]: 3, ranges[1]: 1};
      final result = periodBasedStreak(
        periodRanges: ranges,
        countInRange: (start, end) => counts[(start, end)] ?? 0,
        targetCount: 3,
      );
      expect(result.current, 0); // most recent week missed
      expect(result.longest, 1);
    });
  });

  group('isLogComplete (Habit Tracker RS §4.3)', () {
    test('binary habit just needs a log to exist', () {
      expect(
        isLogComplete(type: HabitType.binary, targetValue: null, hasLog: true),
        isTrue,
      );
      expect(
        isLogComplete(type: HabitType.binary, targetValue: null, hasLog: false),
        isFalse,
      );
    });

    test('quantifiable habit without a target just needs a log', () {
      expect(
        isLogComplete(
          type: HabitType.quantifiable,
          targetValue: null,
          hasLog: true,
          loggedValue: 0,
        ),
        isTrue,
      );
    });

    test('quantifiable habit with a target needs the value to meet it', () {
      expect(
        isLogComplete(
          type: HabitType.quantifiable,
          targetValue: 8,
          hasLog: true,
          loggedValue: 6,
        ),
        isFalse,
      );
      expect(
        isLogComplete(
          type: HabitType.quantifiable,
          targetValue: 8,
          hasLog: true,
          loggedValue: 8,
        ),
        isTrue,
      );
    });
  });

  group('dayBasedCompletionRate', () {
    test('fraction of due days completed within the range', () {
      final completed = {DateTime(2026, 9, 1), DateTime(2026, 9, 3)};
      final rate = dayBasedCompletionRate(
        start: DateTime(2026, 9, 1),
        endExclusive: DateTime(2026, 9, 5), // 4 due days: 1,2,3,4
        isDue: (_) => true,
        isCompleted: completed.contains,
      );
      expect(rate, 0.5);
    });

    test('returns 0 when there are no due days in the range', () {
      final rate = dayBasedCompletionRate(
        start: DateTime(2026, 9, 1),
        endExclusive: DateTime(2026, 9, 5),
        isDue: (_) => false,
        isCompleted: (_) => false,
      );
      expect(rate, 0);
    });
  });
}
