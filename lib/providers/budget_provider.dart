import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import '../core/database_helper.dart';

class BudgetProvider extends ChangeNotifier {
  final List<CategoryBudget> _budgets = [
    CategoryBudget(
      id: '1',
      category: 'Food & Dining',
      limitAmount: 8000,
      monthYear: DateFormat('yyyy-MM').format(DateTime.now()),
    ),
    CategoryBudget(
      id: '2',
      category: 'Travel & Fuel',
      limitAmount: 4000,
      monthYear: DateFormat('yyyy-MM').format(DateTime.now()),
    ),
    CategoryBudget(
      id: '3',
      category: 'Shopping',
      limitAmount: 5000,
      monthYear: DateFormat('yyyy-MM').format(DateTime.now()),
    ),
    CategoryBudget(
      id: '4',
      category: 'Utilities',
      limitAmount: 3500,
      monthYear: DateFormat('yyyy-MM').format(DateTime.now()),
    ),
  ];

  BudgetProvider() {
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final stored = await DatabaseHelper.instance.getBudgets();
      if (stored.isNotEmpty) {
        _budgets.clear();
        _budgets.addAll(stored);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading budgets: $e');
    }
  }

  // This getter must match the call site
  List<CategoryBudget> get budgets => List.unmodifiable(_budgets);

  double getCategoryBudget(String category) {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    for (final b in _budgets) {
      if (b.category.toLowerCase() == category.toLowerCase() &&
          b.monthYear == currentMonth) {
        return b.limitAmount;
      }
    }
    for (final b in _budgets) {
      if (b.category.toLowerCase() == category.toLowerCase()) {
        return b.limitAmount;
      }
    }
    return 0.0;
  }

  Future<void> setCategoryBudget(String category, double limit) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final index = _budgets.indexWhere(
      (b) =>
          b.category.toLowerCase() == category.toLowerCase() &&
          b.monthYear == currentMonth,
    );

    CategoryBudget budgetItem;
    if (index >= 0) {
      budgetItem = CategoryBudget(
        id: _budgets[index].id,
        category: category,
        limitAmount: limit,
        monthYear: currentMonth,
      );
      _budgets[index] = budgetItem;
    } else {
      budgetItem = CategoryBudget(
        id: const Uuid().v4(),
        category: category,
        limitAmount: limit,
        monthYear: currentMonth,
      );
      _budgets.add(budgetItem);
    }
    notifyListeners();

    try {
      await DatabaseHelper.instance.saveBudget(budgetItem);
    } catch (e) {
      debugPrint('Error saving budget to SQLite: $e');
    }
  }
}
