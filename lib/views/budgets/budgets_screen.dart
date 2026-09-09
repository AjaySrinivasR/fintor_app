// lib/views/budgets/budgets_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Budgets',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: categoryProvider.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final cat = categoryProvider.categories[index];

          // Calculate amount spent in this category for the current month
          final now = DateTime.now();
          final spent = expenseProvider.expenses.where((e) {
            return e.category == cat.name &&
                e.type == TransactionType.debit &&
                e.date.year == now.year &&
                e.date.month == now.month;
          }).fold(0.0, (sum, item) => sum + item.amount);

          final budget = budgetProvider.getCategoryBudget(cat.name);
          final ratio = (spent / (budget > 0 ? budget : 1)).clamp(0.0, 1.0);
          final isExceeded = spent > budget;

          Color progressColor = cat.color;
          if (ratio > 0.8) progressColor = Colors.orange.shade700;
          if (isExceeded) progressColor = Colors.red.shade600;

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                cat.color.withValues(alpha: 0.12),
                            child: Icon(cat.icon, color: cat.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                isExceeded
                                    ? 'Over budget by ${currency.format(spent - budget)}'
                                    : '${currency.format(budget - spent)} remaining',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isExceeded
                                      ? Colors.red.shade700
                                      : const Color(0xFF64748B),
                                  fontWeight: isExceeded
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showEditCategoryBudgetDialog(
                            context, cat, budget, budgetProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currency.format(spent)} spent',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Budget: ${currency.format(budget)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      color: progressColor,
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditCategoryBudgetDialog(
    BuildContext context,
    CategoryItem category,
    double currentBudget,
    BudgetProvider provider,
  ) {
    final controller =
        TextEditingController(text: currentBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Budget for ${category.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Monthly Limit (₹)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final budget =
                  double.tryParse(controller.text.trim()) ?? currentBudget;
              if (budget >= 0) {
                provider.setCategoryBudget(category.name, budget);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }
}
