import 'dart:math';
import '../models/expense_model.dart';
import '../models/budget_model.dart';

enum MacroType { need, want }

class VelocityForecast {
  final String category;
  final double currentSpent;
  final double budgetLimit;
  final double projectedSpend;
  final double dailyVelocity;
  final double safeDailySpend;
  final bool isOverrunPredicted;
  final double overrunPercentage;

  VelocityForecast({
    required this.category,
    required this.currentSpent,
    required this.budgetLimit,
    required this.projectedSpend,
    required this.dailyVelocity,
    required this.safeDailySpend,
    required this.isOverrunPredicted,
    required this.overrunPercentage,
  });
}

class WealthPlanRecommendation {
  final double netInflow;
  final double needsTotal;
  final double wantsTotal;
  final double surplus;
  final double emergencyRunwayMonths;
  final double guaranteedFdAllocation;
  final double sipAllocation;
  final String strategyDescription;

  WealthPlanRecommendation({
    required this.netInflow,
    required this.needsTotal,
    required this.wantsTotal,
    required this.surplus,
    required this.emergencyRunwayMonths,
    required this.guaranteedFdAllocation,
    required this.sipAllocation,
    required this.strategyDescription,
  });
}

class ForecastingEngine {
  static const int cycleDays = 30;

  /// Categorizes expenses into 50/30 needs vs wants
  static MacroType classifyMacroCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('utilit') ||
        lower.contains('grocer') ||
        lower.contains('rent') ||
        lower.contains('fuel') ||
        lower.contains('health')) {
      return MacroType.need;
    }
    return MacroType.want;
  }

  /// Calculates real-time spend velocity & month-end projections
  static List<VelocityForecast> computeVelocityForecasts({
    required List<Expense> expenses,
    required List<CategoryBudget> budgets,
    required int currentDayOfMonth,
  }) {
    final t = currentDayOfMonth.clamp(1, cycleDays);
    final daysRemaining = max(1, cycleDays - t);
    final Map<String, double> spends = {};

    for (final exp in expenses.where((e) => e.type == TransactionType.debit)) {
      spends[exp.category] = (spends[exp.category] ?? 0.0) + exp.amount;
    }

    final List<VelocityForecast> forecasts = [];

    for (final b in budgets) {
      final spent = spends[b.category] ?? 0.0;
      final velocity = spent / t;
      final projected = t >= 7 ? (spent / t) * cycleDays : spent;
      final remainingBudget = max(0.0, b.limitAmount - spent);
      final safeDaily = remainingBudget / daysRemaining;

      final isPredictedOverrun =
          t >= 7 && projected > b.limitAmount && b.limitAmount > 0;
      final overrunPct = isPredictedOverrun
          ? ((projected - b.limitAmount) / b.limitAmount) * 100
          : 0.0;

      forecasts.add(VelocityForecast(
        category: b.category,
        currentSpent: spent,
        budgetLimit: b.limitAmount,
        projectedSpend: projected,
        dailyVelocity: velocity,
        safeDailySpend: safeDaily,
        isOverrunPredicted: isPredictedOverrun,
        overrunPercentage: overrunPct,
      ));
    }

    return forecasts;
  }

  /// Evaluates financial runway and generates capital deployment plan
  static WealthPlanRecommendation generateWealthPlan({
    required double monthlyIncome,
    required double liquidReserves,
    required List<Expense> expenses,
  }) {
    double needs = 0.0;
    double wants = 0.0;

    for (final exp in expenses.where((e) => e.type == TransactionType.debit)) {
      if (classifyMacroCategory(exp.category) == MacroType.need) {
        needs += exp.amount;
      } else {
        wants += exp.amount;
      }
    }

    // Default minimum need projection if month just started
    final normalizedNeeds = max(needs, monthlyIncome * 0.40);
    final runway =
        normalizedNeeds > 0 ? (liquidReserves / normalizedNeeds) : 0.0;
    final surplus = max(0.0, monthlyIncome - (needs + wants));

    double fdAlloc = 0.0;
    double sipAlloc = 0.0;
    String desc;

    if (runway < 3.0) {
      // Preserve capital: 100% to liquid reserves / recurring deposit
      fdAlloc = surplus;
      sipAlloc = 0.0;
      desc =
          "Emergency buffer below 3 months (${runway.toStringAsFixed(1)} mo). Direct 100% of surplus to High-Yield Liquid Deposits/FDs.";
    } else {
      // Balanced growth: 50% fixed capital, 50% safe index/debt SIP
      const beta = 0.50;
      sipAlloc = surplus * beta;
      fdAlloc = surplus * (1.0 - beta);
      desc =
          "Reserves healthy (${runway.toStringAsFixed(1)} mo runway). Surplus partitioned into guaranteed deposits and broad index/debt SIPs.";
    }

    return WealthPlanRecommendation(
      netInflow: monthlyIncome,
      needsTotal: needs,
      wantsTotal: wants,
      surplus: surplus,
      emergencyRunwayMonths: runway,
      guaranteedFdAllocation: fdAlloc,
      sipAllocation: sipAlloc,
      strategyDescription: desc,
    );
  }
}
