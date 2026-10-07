import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  String _selectedFilter = 'All'; // 'All', 'Exceeded', 'Near Limit', 'Healthy'

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final selectedMonth = expenseProvider.selectedMonth;

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isPastMonth =
        selectedMonth.isBefore(DateTime(now.year, now.month));
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final daysRemaining = isPastMonth
        ? 0
        : (isCurrentMonth
            ? (daysInMonth - now.day).clamp(1, daysInMonth)
            : daysInMonth);

    // Aggregate monthly totals across categories for the selected month
    double totalBudget = 0.0;
    double totalSpent = 0.0;

    final categoryData = categoryProvider.categories.map((cat) {
      final spent = expenseProvider.expenses.where((e) {
        return e.category.toLowerCase() == cat.name.toLowerCase() &&
            e.type == TransactionType.debit &&
            e.date.year == selectedMonth.year &&
            e.date.month == selectedMonth.month;
      }).fold(0.0, (sum, item) => sum + item.amount);

      final budget = budgetProvider.getCategoryBudget(cat.name);
      totalBudget += budget;
      totalSpent += spent;

      final ratio = budget > 0 ? (spent / budget) : (spent > 0 ? 1.0 : 0.0);
      final isExceeded = spent > budget && budget > 0;
      final isNearLimit = ratio >= 0.8 && !isExceeded;

      return _CategoryBudgetData(
        category: cat,
        budget: budget,
        spent: spent,
        ratio: ratio,
        isExceeded: isExceeded,
        isNearLimit: isNearLimit,
      );
    }).toList();

    // Filter categories based on selected filter
    final filteredData = categoryData.where((item) {
      if (_selectedFilter == 'Exceeded') return item.isExceeded;
      if (_selectedFilter == 'Near Limit') return item.isNearLimit;
      if (_selectedFilter == 'Healthy') return !item.isExceeded && !item.isNearLimit;
      return true;
    }).toList();

    final overallRatio = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final overallRemaining = (totalBudget - totalSpent).clamp(0.0, double.infinity);
    final overallDailySafe = daysRemaining > 0 ? (overallRemaining / daysRemaining) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Budgets & Spending Limits',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Budgeting Guidelines',
            onPressed: () => _showBudgetInfoModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // 1. Overall Budget Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            totalSpent > totalBudget && totalBudget > 0
                                ? Icons.warning_amber_rounded
                                : Icons.shield_rounded,
                            size: 14,
                            color: totalSpent > totalBudget && totalBudget > 0
                                ? Colors.amberAccent
                                : const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(overallRatio * 100).toStringAsFixed(0)}% Used',
                      style: TextStyle(
                        color: totalSpent > totalBudget && totalBudget > 0
                            ? Colors.redAccent.shade100
                            : const Color(0xFF38BDF8),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  currency.format(totalSpent),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Total Spent out of ${currency.format(totalBudget)} Budget',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: overallRatio,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalSpent > totalBudget && totalBudget > 0
                          ? Colors.redAccent
                          : overallRatio >= 0.8
                              ? Colors.amberAccent
                              : const Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildHeroStat(
                      label: 'Remaining Limit',
                      value: currency.format(totalBudget > totalSpent ? (totalBudget - totalSpent) : 0),
                      color: Colors.white,
                    ),
                    _buildHeroStat(
                      label: 'Safe Daily Pace',
                      value: '${currency.format(overallDailySafe)}/day',
                      color: const Color(0xFF38BDF8),
                    ),
                    _buildHeroStat(
                      label: 'Days Left',
                      value: '$daysRemaining days',
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All (${categoryData.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Over Budget (${categoryData.where((c) => c.isExceeded).length})',
                  'Exceeded',
                  badgeColor: Colors.red.shade600,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Near Limit (${categoryData.where((c) => c.isNearLimit).length})',
                  'Near Limit',
                  badgeColor: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Healthy (${categoryData.where((c) => !c.isExceeded && !c.isNearLimit).length})',
                  'Healthy',
                  badgeColor: const Color(0xFF059669),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Category Budgets List
          if (filteredData.isEmpty)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No categories in "$_selectedFilter"',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All your category allocations are in good shape.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredData.map((item) {
              return _buildCategoryBudgetCard(context, item, currency, budgetProvider);
            }),
        ],
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? badgeColor}) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBudgetCard(
    BuildContext context,
    _CategoryBudgetData item,
    NumberFormat currency,
    BudgetProvider budgetProvider,
  ) {
    final cat = item.category;
    final ratio = item.ratio.clamp(0.0, 1.0);

    Color statusColor = cat.color;
    String statusLabel = '${(item.ratio * 100).toStringAsFixed(0)}% used';

    if (item.isExceeded) {
      statusColor = Colors.red.shade600;
      statusLabel = 'Exceeded by ${currency.format(item.spent - item.budget)}';
    } else if (item.isNearLimit) {
      statusColor = Colors.orange.shade700;
      statusLabel = 'Near Limit (${(item.ratio * 100).toStringAsFixed(0)}%)';
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isExceeded
              ? Colors.red.shade200
              : item.isNearLimit
                  ? Colors.orange.shade200
                  : const Color(0xFFE2E8F0),
          width: item.isExceeded ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.budget > 0
                            ? item.isExceeded
                                ? 'Over limit'
                                : '${currency.format(item.budget - item.spent)} remaining'
                            : 'No budget set',
                        style: TextStyle(
                          fontSize: 12,
                          color: item.isExceeded ? Colors.red.shade700 : const Color(0xFF64748B),
                          fontWeight: item.isExceeded ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: statusColor,
                backgroundColor: const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spent so far', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(
                      currency.format(item.spent),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Monthly Limit', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    Text(
                      currency.format(item.budget),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  tooltip: 'Set ${cat.name} Budget',
                  onPressed: () => _showEditBudgetBottomSheet(context, cat, item.budget, budgetProvider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBudgetBottomSheet(
    BuildContext context,
    CategoryItem category,
    double currentBudget,
    BudgetProvider provider,
  ) {
    final controller = TextEditingController(
      text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(category.icon, color: category.color, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set ${category.name} Budget',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Text(
                            'Enter your planned monthly spending limit',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Monthly Limit',
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick presets
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [2000, 5000, 10000, 20000, 35000].map((preset) {
                      return ActionChip(
                        label: Text('₹${NumberFormat.compact().format(preset)}'),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () {
                          setModalState(() {
                            controller.text = preset.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final val = double.tryParse(controller.text.trim()) ?? 0.0;
                        if (val >= 0) {
                          provider.setCategoryBudget(category.name, val);
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text(
                        'Save Budget Limit',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBudgetInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How Category Budgets Work',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Category budgets automatically track transactions parsed from SMS and manual entries.\n\n'
              '• Progress is color-coded:\n'
              '   - Blue / Category Color: Safe burn rate (< 80%)\n'
              '   - Amber: Near limit (80% - 100%)\n'
              '   - Red: Over budget limit\n\n'
              '• Set realistic limits for each category to unlock spend velocity forecasting and runaway alerts.',
              style: TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetData {
  final CategoryItem category;
  final double budget;
  final double spent;
  final double ratio;
  final bool isExceeded;
  final bool isNearLimit;

  _CategoryBudgetData({
    required this.category,
    required this.budget,
    required this.spent,
    required this.ratio,
    required this.isExceeded,
    required this.isNearLimit,
  });
}
