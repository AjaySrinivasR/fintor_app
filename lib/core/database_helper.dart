// Inside DatabaseHelper in mobile/lib/core/database_helper.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // Upgraded version from 1 to 2
    _database = await _initDB('fintor_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        account_last4 TEXT,
        sync_hash TEXT UNIQUE,
        date TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createUserProfileTable(db);
    await _createBudgetsTable(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUserProfileTable(db);
    }
  }

  Future<void> _createBudgetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        limitAmount REAL NOT NULL,
        monthYear TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createUserProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        monthly_income REAL NOT NULL DEFAULT 50000,
        liquid_reserves REAL NOT NULL DEFAULT 100000,
        risk_profile TEXT NOT NULL DEFAULT 'conservative'
      )
    ''');
  }

  Future<void> saveUserProfile({
    required double monthlyIncome,
    required double liquidReserves,
    String riskProfile = 'conservative',
  }) async {
    final db = await instance.database;
    await db.insert(
      'user_profile',
      {
        'id': 'active_user',
        'monthly_income': monthlyIncome,
        'liquid_reserves': liquidReserves,
        'risk_profile': riskProfile,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final db = await instance.database;
    final res = await db
        .query('user_profile', where: 'id = ?', whereArgs: ['active_user']);
    if (res.isNotEmpty) {
      return res.first;
    }
    return {
      'monthly_income': 50000.0,
      'liquid_reserves': 100000.0,
      'risk_profile': 'conservative',
    };
  }

  Future<List<CategoryBudget>> getBudgets() async {
    final db = await instance.database;
    await _createBudgetsTable(db);
    final result = await db.query('budgets');
    if (result.isEmpty) {
      final currentMonth =
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      return [
        CategoryBudget(
            id: '1',
            category: 'Food & Dining',
            limitAmount: 8000,
            monthYear: currentMonth),
        CategoryBudget(
            id: '2',
            category: 'Travel & Fuel',
            limitAmount: 4000,
            monthYear: currentMonth),
        CategoryBudget(
            id: '3',
            category: 'Shopping',
            limitAmount: 5000,
            monthYear: currentMonth),
        CategoryBudget(
            id: '4',
            category: 'Utilities',
            limitAmount: 3500,
            monthYear: currentMonth),
      ];
    }
    return result.map((map) => CategoryBudget.fromJson(map)).toList();
  }

  Future<void> saveBudget(CategoryBudget budget) async {
    final db = await instance.database;
    await _createBudgetsTable(db);
    await db.insert(
      'budgets',
      budget.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // In lib/core/database_helper.dart:
  Future<void> clearAllExpenses() async {
    final db = await instance.database;
    await db.delete('expenses');
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      {
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category,
        'type': expense.type.name,
        'source': expense.source.name,
        'account_last4': expense.accountLast4,
        'date': expense.date.toIso8601String(),
        'is_synced': 0, // Flag for re-syncing modifications to remote cloud
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertExpense(Expense expense, {bool isSynced = false}) async {
    final db = await instance.database;
    final timestamp = expense.date.millisecondsSinceEpoch;
    final syncHash =
        '${expense.accountLast4 ?? "NA"}_${expense.amount}_${timestamp}_${expense.type.name}';

    return await db.insert(
      'expenses',
      {
        'id': expense.id,
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category,
        'type': expense.type.name,
        'source': expense.source.name,
        'account_last4': expense.accountLast4,
        'sync_hash': syncHash,
        'date': expense.date.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'date DESC');

    return result.map((map) => _mapToExpense(map)).toList();
  }

  Future<List<Expense>> getUnsyncedExpenses() async {
    final db = await instance.database;
    final result =
        await db.query('expenses', where: 'is_synced = ?', whereArgs: [0]);

    return result.map((map) => _mapToExpense(map)).toList();
  }

  Future<void> markAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('expenses', {'is_synced': 1},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  static Expense _mapToExpense(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: map['amount'] as double,
      category: map['category'] as String,
      type: (map['type'] as String) == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      source: SourceType.values.firstWhere(
        (s) => s.name == (map['source'] as String? ?? 'manual'),
        orElse: () => SourceType.manual,
      ),
      accountLast4: map['account_last4'] as String?,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
