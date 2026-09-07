import 'package:expense_tracker/logic/daily_budget.dart';
import 'package:expense_tracker/logic/period_utils.dart';
import 'package:expense_tracker/logic/threshold_checker.dart';
import 'package:expense_tracker/logic/trend_projection.dart';
import 'package:expense_tracker/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('period_utils', () {
    test('daysInMonth handles leap years', () {
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 9), 30);
    });

    test('daysElapsedInMonth clamps before/after the month', () {
      expect(daysElapsedInMonth(DateTime(2026, 8, 31), year: 2026, month: 9), 0);
      expect(daysElapsedInMonth(DateTime(2026, 9, 15), year: 2026, month: 9), 15);
      expect(daysElapsedInMonth(DateTime(2026, 10, 5), year: 2026, month: 9), 30);
    });

    test('quarterOfMonth maps months to quarters 1-4', () {
      expect(quarterOfMonth(1), 1);
      expect(quarterOfMonth(3), 1);
      expect(quarterOfMonth(4), 2);
      expect(quarterOfMonth(12), 4);
    });
  });

  group('daily_budget (Section 7 #1-2)', () {
    test('dailyAllowance = monthly budget / days in month', () {
      expect(dailyAllowance(monthlyBudget: 3000, daysInMonth: 30), 100);
    });

    test('cumulativeAllowed = daily allowance x days elapsed', () {
      expect(
        cumulativeAllowed(dailyAllowanceValue: 100, daysElapsed: 12),
        1200,
      );
    });

    test('paceStatus classifies ahead/on-track/behind with tolerance', () {
      expect(
        paceStatus(cumulativeActual: 800, cumulativeAllowedValue: 1200),
        PaceStatus.ahead,
      );
      expect(
        paceStatus(cumulativeActual: 1210, cumulativeAllowedValue: 1200),
        PaceStatus.onTrack,
      );
      expect(
        paceStatus(cumulativeActual: 1500, cumulativeAllowedValue: 1200),
        PaceStatus.behind,
      );
    });
  });

  group('threshold_checker (Section 7 #3-4, FR-4.5)', () {
    test('thresholdTriggerValue = base x threshold%', () {
      expect(
        thresholdTriggerValue(thresholdBaseValue: 5000, thresholdPercent: 80),
        4000,
      );
    });

    test('resolveThresholdBase picks min or max per setting', () {
      expect(
        resolveThresholdBase(base: ThresholdBase.max, minCost: 3000, maxCost: 5000),
        5000,
      );
      expect(
        resolveThresholdBase(base: ThresholdBase.min, minCost: 3000, maxCost: 5000),
        3000,
      );
    });

    test('isThresholdBreached fires at or above the trigger value', () {
      expect(isThresholdBreached(cumulativeActual: 4000, triggerValue: 4000), isTrue);
      expect(isThresholdBreached(cumulativeActual: 3999, triggerValue: 4000), isFalse);
    });

    test('classifySeverity: none below 80% of the trigger', () {
      // trigger = 4000 (80% of 5000 max); 3000 actual is 75% of the trigger
      expect(
        classifySeverity(cumulativeActual: 3000, triggerValue: 4000),
        isNull,
      );
    });

    test('classifySeverity: approaching between 80-99% of the trigger', () {
      expect(
        classifySeverity(cumulativeActual: 3600, triggerValue: 4000),
        AlertType.approaching,
      );
    });

    test('classifySeverity: reached at ~100% of the trigger', () {
      expect(
        classifySeverity(cumulativeActual: 4000, triggerValue: 4000),
        AlertType.reached,
      );
    });

    test('classifySeverity: exceeded comfortably past the trigger', () {
      expect(
        classifySeverity(cumulativeActual: 5000, triggerValue: 4000),
        AlertType.exceeded,
      );
    });
  });

  group('trend_projection (Section 7 #5-6, FR-7)', () {
    test('projects a plain moving average when no overspend', () {
      final result = projectNextPeriod(
        recentActuals: [1000, 1200, 1100],
        maxBudget: 2000, // well above the last actual — no adjustment
      );
      expect(result.projected, closeTo(1100, 0.001));
      expect(result.projectedMin, closeTo(990, 0.001));
      expect(result.projectedMax, closeTo(1210, 0.001));
    });

    test('adjusts upward when the last period exceeded max (Section 7 #6)', () {
      // moving average = (1000+1200+1500)/3 = 1233.33
      // overspend rate = (1500-1000)/1000 = 0.5
      // projected = 1233.33 * 1.5 = 1850
      final result = projectNextPeriod(
        recentActuals: [1000, 1200, 1500],
        maxBudget: 1000,
      );
      expect(result.projected, closeTo(1850, 0.01));
    });

    test('throws on empty history', () {
      expect(
        () => projectNextPeriod(recentActuals: [], maxBudget: 1000),
        throwsArgumentError,
      );
    });
  });
}
