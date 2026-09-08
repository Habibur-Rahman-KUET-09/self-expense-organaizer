import '../db/database.dart';
import '../logic/threshold_checker.dart' as logic;

extension BudgetCeiling on Budget {
  /// This budget's effective ceiling: Max if set, otherwise Min. See
  /// lib/logic/threshold_checker.dart's `effectiveCeiling` for why.
  double get effectiveCeiling =>
      logic.effectiveCeiling(minCost: minCost, maxCost: maxCost);
}
