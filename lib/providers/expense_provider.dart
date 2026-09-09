import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense_model.dart';
import '../core/sms_parser.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';
import '../core/notification_parser.dart';
import 'category_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/forecasting_engine.dart';

class ExpenseProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.fintor.app/sms');
  static const MethodChannel _notifChannel =
      MethodChannel('com.fintor.app/notifications');

  void setAuthToken(String token) {
    _jwtToken = token;
    fetchAndSyncRemote();
  }

  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  Future<void> evaluateRealtimeAlerts(Expense newExpense) async {
    final currentDay = DateTime.now().day;
    final budgets = await DatabaseHelper.instance.getBudgets(); // Local SQLite

    final forecasts = ForecastingEngine.computeVelocityForecasts(
      expenses: _expenses,
      budgets: budgets,
      currentDayOfMonth: currentDay,
    );

    if (forecasts.isEmpty) return;

    final categoryForecast = forecasts.firstWhere(
      (f) => f.category.toLowerCase() == newExpense.category.toLowerCase(),
      orElse: () => forecasts.first,
    );

    if (categoryForecast.isOverrunPredicted) {
      _dispatchNotification(
        title: '⚠️ Spend Velocity Warning: ${categoryForecast.category}',
        body:
            'Current rate projects ₹${categoryForecast.projectedSpend.toStringAsFixed(0)} '
            '(${categoryForecast.overrunPercentage.toStringAsFixed(0)}% overrun). '
            'Limit spend to ₹${categoryForecast.safeDailySpend.toStringAsFixed(0)}/day to stay safe.',
      );
    }
  }

  Future<void> _dispatchNotification(
      {required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'velocity_alerts',
      'Spend Velocity Warnings',
      channelDescription: 'Proactive overrun and run-rate alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _localNotifs.show(
      Random().nextInt(10000),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
// Inside ExpenseProvider in mobile/lib/providers/expense_provider.dart

  Future<void> updateExpense(Expense updated) async {
    final index = _expenses.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    _expenses[index] = updated;
    notifyListeners();

    // 1. Commit update to local SQLite ledger
    await DatabaseHelper.instance.updateExpense(updated);

    // 2. Dispatch update to remote server if authenticated
    if (_jwtToken != null) {
      final success = await ApiService.updateExpense(
        expense: updated,
        jwtToken: _jwtToken!,
      );
      if (success) {
        await DatabaseHelper.instance.markAsSynced([updated.id]);
      }
    }
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();

    // 1. Remove from local SQLite database
    await DatabaseHelper.instance.deleteExpense(id);

    // 2. Remove from backend if online
    if (_jwtToken != null) {
      await ApiService.deleteExpense(
        expenseId: id,
        jwtToken: _jwtToken!,
      );
    }
  }

  Future<void> editExpense(Expense updatedExpense) async {
    final index = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (index != -1) {
      _expenses[index] = updatedExpense;
      notifyListeners();

      // 1. Update SQLite
      await DatabaseHelper.instance.updateExpense(updatedExpense);

      // 2. Sync to cloud if online
      if (_jwtToken != null) {
        final success = await ApiService.updateExpense(
          expense: updatedExpense,
          jwtToken: _jwtToken!,
        );
        if (success) {
          await DatabaseHelper.instance.markAsSynced([updatedExpense.id]);
        }
      }
    }
  }

  // Future<void> deleteExpense(String id) async {
  //   _expenses.removeWhere((e) => e.id == id);
  //   notifyListeners();

  //   await DatabaseHelper.instance.deleteExpense(id);

  //   if (_jwtToken != null) {
  //     await ApiService.deleteExpenseRemote(id, _jwtToken!);
  //   }
  // }

  // In lib/providers/expense_provider.dart:
  Future<void> fetchAndSyncRemote() async {
    if (_jwtToken == null) return;

    final remoteExpenses = await ApiService.fetchExpenses(_jwtToken!);

    if (remoteExpenses.isNotEmpty) {
      // Wipe old corrupted cache and replace with clean data
      await DatabaseHelper.instance.clearAllExpenses();
      for (final exp in remoteExpenses) {
        await DatabaseHelper.instance.insertExpense(exp, isSynced: true);
      }
      await loadLocalExpenses();
    }
  }

  Future<void> initializeNotificationListener(
      CategoryProvider categoryProvider) async {
    _notifChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationReceived') {
        final data = Map<String, dynamic>.from(call.arguments);
        final pkg = data['package'] as String? ?? '';
        final title = data['title'] as String? ?? '';
        final text = data['text'] as String? ?? '';

        final parsed = NotificationExpenseParser.parse(
          packageName: pkg,
          title: title,
          text: text,
          categoryProvider: categoryProvider,
        );

        if (parsed != null) {
          final isDuplicate = _expenses.any((e) =>
              e.amount == parsed.amount &&
              e.date.difference(parsed.date).inMinutes.abs() < 2);

          if (!isDuplicate) {
            await addExpense(parsed);
          }
        }
      }
    });
  }

  Future<void> requestNotificationListenerPermission() async {
    await _notifChannel.invokeMethod('openNotificationSettings');
  }

  List<Expense> _expenses = [];
  double _monthlyBudget = 30000.0;
  bool _isSmsSyncActive = false;
  String? _jwtToken;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  double get monthlyBudget => _monthlyBudget;
  bool get isSmsSyncActive => _isSmsSyncActive;

  double get totalSpent => _expenses
      .where((e) => e.type == TransactionType.debit)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalIncome => _expenses
      .where((e) => e.type == TransactionType.credit)
      .fold(0.0, (sum, item) => sum + item.amount);

  Map<String, double> get categoryBreakdown {
    final Map<String, double> breakdown = {};
    for (var e in _expenses.where((e) => e.type == TransactionType.debit)) {
      breakdown[e.category] = (breakdown[e.category] ?? 0.0) + e.amount;
    }
    return breakdown;
  }

  Future<void> loadLocalExpenses() async {
    _expenses = await DatabaseHelper.instance.getAllExpenses();
    notifyListeners();
  }

  void clearAuthToken() {
    _jwtToken = null;
    notifyListeners();
  }

  void setBudget(double budget) {
    _monthlyBudget = budget;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    _expenses.insert(0, expense);
    notifyListeners();

    // 1. Save locally to SQLite
    await DatabaseHelper.instance.insertExpense(expense, isSynced: false);

    // 2. Trigger remote synchronization
    await syncPendingExpenses();
  }

  Future<void> syncPendingExpenses() async {
    if (_jwtToken == null) return;

    final unsynced = await DatabaseHelper.instance.getUnsyncedExpenses();
    if (unsynced.isEmpty) return;

    final success = await ApiService.syncBatchExpenses(
      expenses: unsynced,
      jwtToken: _jwtToken!,
    );

    if (success) {
      final syncedIds = unsynced.map((e) => e.id).toList();
      await DatabaseHelper.instance.markAsSynced(syncedIds);
    }
  }

  Future<void> initializeSmsListener() async {
    final status = await Permission.sms.request();
    if (status.isGranted) {
      _isSmsSyncActive = true;
      _channel.setMethodCallHandler(_handleNativeMethodCall);
      notifyListeners();
    }
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onSmsReceived') {
      final data = Map<String, dynamic>.from(call.arguments);
      final sender = data['sender'] as String? ?? '';
      final body = data['body'] as String? ?? '';

      final parsedExpense = SmsExpenseParser.parse(sender, body);
      if (parsedExpense != null) {
        final isDuplicate = _expenses.any((e) =>
            e.amount == parsedExpense.amount &&
            e.date.difference(parsedExpense.date).inMinutes.abs() < 2);

        if (!isDuplicate) {
          await addExpense(parsedExpense);
        }
      }
    }
  }

  void initConnectivityListener() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        // Reconnected to internet -> auto-sync offline data to MongoDB
        syncPendingExpenses();
      }
    });
  }

// Drain messages collected while app was closed/offline
  Future<void> drainOfflineSms() async {
    try {
      final List<dynamic>? pendingList =
          await _channel.invokeMethod('getOfflinePendingSms');
      if (pendingList != null && pendingList.isNotEmpty) {
        for (final item in pendingList) {
          final data = Map<String, dynamic>.from(item);
          final sender = data['sender'] as String? ?? '';
          final body = data['body'] as String? ?? '';

          final parsedExpense = SmsExpenseParser.parse(sender, body);
          if (parsedExpense != null) {
            await addExpense(parsedExpense);
          }
        }
      }
    } catch (e) {
      debugPrint("Error draining offline SMS: $e");
    }
  }
}
