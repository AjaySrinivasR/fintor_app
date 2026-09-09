// // lib/views/insights/insights_screen.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:intl/intl.dart';
// import '../../providers/expense_provider.dart';
// import '../../models/expense_model.dart';

// class InsightsScreen extends StatelessWidget {
//   const InsightsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<ExpenseProvider>();
//     final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

//     // Month metrics
//     final now = DateTime.now();
//     final monthExpenses = provider.expenses.where((e) {
//       return e.date.year == now.year && e.date.month == now.month;
//     }).toList();

//     final totalSpent = monthExpenses
//         .where((e) => e.type == TransactionType.debit)
//         .fold(0.0, (sum, item) => sum + item.amount);

//     final totalIncome = monthExpenses
//         .where((e) => e.type == TransactionType.credit)
//         .fold(0.0, (sum, item) => sum + item.amount);

//     // 1. Savings Rate
//     final savings = totalIncome - totalSpent;
//     final savingsRate = totalIncome > 0 ? (savings / totalIncome * 100).clamp(0.0, 100.0) : 0.0;

//     // 2. Average Daily Spending
//     final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
//     final elapsedDays = now.day;
//     final dailyAverage = totalSpent / (elapsedDays > 0 ? elapsedDays : 1);

//     // 3. Top Expense Merchants
//     final Map<String, double> merchantSpend = {};
//     for (final exp in monthExpenses.where((e) => e.type == TransactionType.debit)) {
//       merchantSpend[exp.title] = (merchantSpend[exp.title] ?? 0.0) + exp.amount;
//     }
//     final sortedMerchants = merchantSpend.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value));
//     final topMerchants = sortedMerchants.take(3).toList();

//     // 4. Capture Source counts
//     final smsCount = monthExpenses.where((e) => e.source == SourceType.sms).length;
//     final manualCount = monthExpenses.where((e) => e.source == SourceType.manual).length;
//     final csvCount = monthExpenses.where((e) => e.source == SourceType.csv).length;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Financial Insights',
//             style: TextStyle(fontWeight: FontWeight.bold)),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 110.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Month Summary Card
//             Card(
//               elevation: 0,
//               color: const Color(0xFF1E3A8A),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text(
//                       'Savings Performance',
//                       style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           savings >= 0
//                               ? '+${currency.format(savings)} Net Saved'
//                               : '${currency.format(savings)} Net Deficit',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.white24,
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Text(
//                             '${savingsRate.toStringAsFixed(0)}% Savings Rate',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     ClipRRect(
//                       borderRadius: BorderRadius.circular(4),
//                       child: LinearProgressIndicator(
//                         value: savingsRate / 100,
//                         minHeight: 6,
//                         color: Colors.greenAccent,
//                         backgroundColor: Colors.white24,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Statistics Grid
//             Row(
//               children: [
//                 Expanded(
//                   child: _StatCard(
//                     title: 'Daily Average',
//                     value: currency.format(dailyAverage),
//                     subtitle: 'Spent per day',
//                     icon: Icons.calendar_today_rounded,
//                     color: Colors.indigo.shade600,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _StatCard(
//                     title: 'Projected Spend',
//                     value: currency.format(dailyAverage * daysInMonth),
//                     subtitle: 'Est. total this month',
//                     icon: Icons.trending_up_rounded,
//                     color: Colors.amber.shade800,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Top Merchants Section
//             const Text(
//               'Top Outflows',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
//             ),
//             const SizedBox(height: 10),
//             if (topMerchants.isEmpty)
//               _buildEmptyCard('No expense outflows tracked yet.')
//             else
//               Card(
//                 elevation: 0,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   side: const BorderSide(color: Color(0xFFE2E8F0)),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(vertical: 8.0),
//                   child: Column(
//                     children: List.generate(topMerchants.length, (index) {
//                       final item = topMerchants[index];
//                       return ListTile(
//                         leading: CircleAvatar(
//                           backgroundColor: const Color(0xFFEFF6FF),
//                           child: Text(
//                             '#${index + 1}',
//                             style: const TextStyle(
//                               color: Color(0xFF1E3A8A),
//                               fontWeight: FontWeight.bold,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ),
//                         title: Text(
//                           item.key,
//                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
//                         ),
//                         trailing: Text(
//                           currency.format(item.value),
//                           style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.red),
//                         ),
//                       );
//                     }),
//                   ),
//                 ),
//               ),
//             const SizedBox(height: 20),

//             // Logging Channels Section
//             const Text(
//               'Log Methods breakdown',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
//             ),
//             const SizedBox(height: 10),
//             Card(
//               elevation: 0,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 side: const BorderSide(color: Color(0xFFE2E8F0)),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _SourceColumn(label: 'SMS sync', count: smsCount, icon: Icons.sync_rounded),
//                     _SourceColumn(label: 'Manual', count: manualCount, icon: Icons.edit_note_rounded),
//                     _SourceColumn(label: 'CSV Upload', count: csvCount, icon: Icons.table_view_rounded),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyCard(String text) {
//     return Card(
//       elevation: 0,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//         side: const BorderSide(color: Color(0xFFE2E8F0)),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(32.0),
//         child: Center(
//           child: Text(
//             text,
//             style: const TextStyle(color: Colors.grey),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   final String title;
//   final String value;
//   final String subtitle;
//   final IconData icon;
//   final Color color;

//   const _StatCard({
//     required this.title,
//     required this.value,
//     required this.subtitle,
//     required this.icon,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFE2E8F0)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: color, size: 24),
//           const SizedBox(height: 12),
//           Text(
//             title,
//             style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             subtitle,
//             style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SourceColumn extends StatelessWidget {
//   final String label;
//   final int count;
//   final IconData icon;

//   const _SourceColumn({
//     required this.label,
//     required this.count,
//     required this.icon,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Icon(icon, color: const Color(0xFF64748B), size: 24),
//         const SizedBox(height: 8),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           '$count records',
//           style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
//         ),
//       ],
//     );
//   }
// }

// mobile/lib/views/insights/insights_screen.dart
import 'package:fintor/views/widgets/velocity_forecast_card.dart';
import 'package:fintor/views/widgets/wealth_planner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/forecasting_engine.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  void _showEditProfileSheet(BuildContext context, UserProvider userProvider) {
    final incomeCtrl = TextEditingController(
        text: userProvider.monthlyIncome.toStringAsFixed(0));
    final reservesCtrl = TextEditingController(
        text: userProvider.liquidReserves.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Baseline Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
                'Used to calculate your runway index and safe investment allocations.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: incomeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Monthly Inflow / Income (₹)',
                  prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reservesCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Liquid Savings & FD Reserves (₹)',
                  prefixIcon: Icon(Icons.account_balance)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  final inc = double.tryParse(incomeCtrl.text.trim()) ??
                      userProvider.monthlyIncome;
                  final res = double.tryParse(reservesCtrl.text.trim()) ??
                      userProvider.liquidReserves;
                  userProvider.updateFinancialParameters(
                      monthlyIncome: inc, liquidReserves: res);
                  Navigator.pop(ctx);
                },
                child: const Text('Recalculate Wealth Strategy'),
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

    final forecasts = ForecastingEngine.computeVelocityForecasts(
      expenses: expenseProvider.expenses,
      budgets: budgetProvider.budgets,
      currentDayOfMonth: DateTime.now().day,
    );

    final wealthPlan = ForecastingEngine.generateWealthPlan(
      monthlyIncome: userProvider.monthlyIncome,
      liquidReserves: userProvider.liquidReserves,
      expenses: expenseProvider.expenses,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning & Spend Velocity',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Adjust Financial Baseline',
            onPressed: () => _showEditProfileSheet(context, userProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          WealthPlannerCard(plan: wealthPlan),
          const SizedBox(height: 20),
          const Text(
            'Spend Velocity & Projections',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'End-of-month extrapolations based on day-to-day burn rate.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (forecasts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'No active budgets set for velocity tracking. Configure category limits in the Budgets tab.',
                    textAlign: TextAlign.center),
              ),
            )
          else
            ...forecasts.map((f) => VelocityForecastCard(forecast: f)),
        ],
      ),
    );
  }
}
