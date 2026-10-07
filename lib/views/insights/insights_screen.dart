import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/forecasting_engine.dart';
import '../widgets/velocity_forecast_card.dart';
import '../widgets/wealth_planner.dart';
import '../widgets/spend_forecasting_graph.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  void _showEditProfileSheet(BuildContext context, UserProvider userProvider) {
    final incomeCtrl = TextEditingController(
      text: userProvider.monthlyIncome > 0 ? userProvider.monthlyIncome.toStringAsFixed(0) : '',
    );
    final reservesCtrl = TextEditingController(
      text: userProvider.liquidReserves > 0 ? userProvider.liquidReserves.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Financial Baseline Parameters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Used by the AI engine to compute your runway index and 50/30/20 capital deployment.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: incomeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monthly Inflow / Salary (₹)',
                hintText: 'e.g. 75000',
                prefixText: '₹ ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reservesCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Liquid Reserves / FD Savings (₹)',
                hintText: 'e.g. 150000',
                prefixText: '₹ ',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final inc = double.tryParse(incomeCtrl.text.trim()) ?? userProvider.monthlyIncome;
                  final res = double.tryParse(reservesCtrl.text.trim()) ?? userProvider.liquidReserves;
                  userProvider.updateFinancialParameters(
                    monthlyIncome: inc,
                    liquidReserves: res,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Recalculate Strategy', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final userProvider = context.watch<UserProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final selectedMonth = expenseProvider.selectedMonth;

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isPastMonth =
        selectedMonth.isBefore(DateTime(now.year, now.month));
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final currentDayOfMonth = isPastMonth
        ? daysInMonth
        : (isCurrentMonth ? now.day : 1);

    final monthExpenses = expenseProvider.selectedMonthExpenses;

    final forecasts = ForecastingEngine.computeVelocityForecasts(
      expenses: monthExpenses,
      budgets: budgetProvider.budgets,
      currentDayOfMonth: currentDayOfMonth,
    );

    final wealthPlan = ForecastingEngine.generateWealthPlan(
      monthlyIncome: userProvider.monthlyIncome,
      liquidReserves: userProvider.liquidReserves,
      expenses: monthExpenses,
    );

    final Map<String, double> categoryBudgets = {
      for (final b in budgetProvider.budgets) b.category: b.limitAmount,
    };

    final overrunCount = forecasts.where((f) => f.isOverrunPredicted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wealth Strategy & Velocity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              DateFormat('MMMM yyyy').format(selectedMonth),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'Adjust Financial Baseline',
            onPressed: () => _showEditProfileSheet(context, userProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // 1. Wealth Planner Hub Card
          WealthPlannerCard(plan: wealthPlan),
          const SizedBox(height: 20),

          // 2. Spend Trajectory & Forecast Graph
          SpendForecastingGraphCard(
            expenses: expenseProvider.expenses,
            selectedMonth: selectedMonth,
            totalBudget: expenseProvider.monthlyBudget,
            categoryBudgets: categoryBudgets,
            categories: categoryProvider.categories,
          ),
          const SizedBox(height: 24),

          // 3. Spend Velocity Forecast Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spend Velocity Projections',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Text(
                    'Pace extrapolations based on day-to-day burn rate',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              if (overrunCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        '$overrunCount At Risk',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (forecasts.isEmpty)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.speed_rounded, size: 36, color: Color(0xFF1E3A8A)),
                    const SizedBox(height: 12),
                    const Text(
                      'No Active Category Budgets',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Configure category limits in the Budgets tab to unlock spend velocity forecasting and month-end pace alerts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            ...forecasts.map((f) => VelocityForecastCard(forecast: f)),
        ],
      ),
    );
  }
}
