// lib/providers/subscription_provider.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../models/subscription_model.dart';

class SubscriptionProvider extends ChangeNotifier {
  final List<Subscription> _subscriptions = [];

  List<Subscription> get subscriptions => List.unmodifiable(_subscriptions);

  double get monthlyCommitment => _subscriptions.fold(
        0.0,
        (sum, item) =>
            sum + (item.frequency == 'Yearly' ? item.amount / 12 : item.amount),
      );

  void detectRecurringSubscriptions(List<Expense> expenses) {
    final debits =
        expenses.where((e) => e.type == TransactionType.debit).toList();
    final Map<String, List<Expense>> groupedByTitle = {};

    for (final exp in debits) {
      final key = exp.title.toUpperCase().trim();
      groupedByTitle.putIfAbsent(key, () => []).add(exp);
    }

    final List<Subscription> detected = [];

    groupedByTitle.forEach((title, history) {
      if (history.length >= 2) {
        history.sort((a, b) => b.date.compareTo(a.date)); // Latest first
        final latest = history[0];
        final previous = history[1];

        final dayDifference =
            latest.date.difference(previous.date).inDays.abs();

        // Recurring monthly pattern (~26 to 34 days interval)
        if (dayDifference >= 26 &&
            dayDifference <= 35 &&
            (latest.amount - previous.amount).abs() < 5.0) {
          detected.add(
            Subscription(
              id: const Uuid().v4(),
              name: title,
              amount: latest.amount,
              category: latest.category,
              nextBillingDate: latest.date.add(Duration(days: dayDifference)),
              frequency: 'Monthly',
              isAutoDetected: true,
            ),
          );
        }
      }
    });

    for (final det in detected) {
      if (!_subscriptions.any((s) => s.name == det.name)) {
        _subscriptions.add(det);
      }
    }
    notifyListeners();
  }

  void addManualSubscription(Subscription sub) {
    _subscriptions.add(sub);
    notifyListeners();
  }

  void removeSubscription(String id) {
    _subscriptions.removeWhere((s) => s.id == id);
    notifyListeners();
  }
}
