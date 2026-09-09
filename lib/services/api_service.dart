// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expense_model.dart';

class ApiService {
  // Use http://10.0.2.2:5000 for Android Emulator pointing to local Node.js server
  //static const String baseUrl = 'http://10.0.2.2:5001/api';
  static const String baseUrl = 'http://192.168.29.189:5001/api';

  static Future<bool> syncBatchExpenses({
    required List<Expense> expenses,
    required String jwtToken,
  }) async {
    if (expenses.isEmpty) return true;

    final url = Uri.parse('$baseUrl/expenses/sync-batch');
    final payload = jsonEncode({
      'expenses': expenses.map((e) {
        final timestamp = e.date.millisecondsSinceEpoch;
        return {
          'title': e.title,
          'amount': e.amount,
          'category': e.category,
          'type': e.type.name,
          'source': e.source.name,
          'accountLast4': e.accountLast4,
          'syncHash':
              '${e.accountLast4 ?? 'NA'}_${e.amount}_${timestamp}_${e.type.name}',
          'date': e.date.toIso8601String(),
        };
      }).toList(),
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: payload,
      );

      return response.statusCode == 200;
    } catch (e) {
      // Network failure or offline
      return false;
    }
  }

  // Inside ApiService.fetchExpenses in mobile/lib/services/api_service.dart:

  static String _sanitizeCategory(String? category, String title) {
    final isHexId = RegExp(r'^[0-9a-fA-F]{24}$');

    if (category != null &&
        category.isNotEmpty &&
        !isHexId.hasMatch(category)) {
      return category;
    }

    // Fallback keyword matcher
    final t = title.toLowerCase();
    if (t.contains('biriyani') ||
        t.contains('cafe') ||
        t.contains('zomato') ||
        t.contains('swiggy')) {
      return 'Dining Out';
    } else if (t.contains('oil') ||
        t.contains('petrol') ||
        t.contains('fuel') ||
        t.contains('uber') ||
        t.contains('ola')) {
      return 'Transportation';
    } else if (t.contains('market') ||
        t.contains('mart') ||
        t.contains('grocery') ||
        t.contains('super')) {
      return 'Groceries';
    }
    return 'General';
  }
  // In lib/services/api_service.dart:
// Inside ApiService in mobile/lib/services/api_service.dart

  static Future<bool> updateExpense({
    required Expense expense,
    required String jwtToken,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/expenses/${expense.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'title': expense.title,
          'amount': expense.amount,
          'category': expense.category,
          'type': expense.type.name,
          'date': expense.date.toIso8601String(),
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteExpense({
    required String expenseId,
    required String jwtToken,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/expenses/$expenseId'),
        headers: {'Authorization': 'Bearer $jwtToken'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // static Future<bool> updateExpenseRemote(
  //     Expense expense, String jwtToken) async {
  //   try {
  //     final response = await http.put(
  //       Uri.parse('$baseUrl/expenses/${expense.id}'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $jwtToken',
  //       },
  //       body: jsonEncode({
  //         'title': expense.title,
  //         'amount': expense.amount,
  //         'category': expense.category,
  //         'type': expense.type.name,
  //         'date': expense.date.toIso8601String(),
  //       }),
  //     );
  //     return response.statusCode == 200;
  //   } catch (_) {
  //     return false; // Offline; SQLite is already marked unsynced
  //   }
  // }

  // static Future<bool> deleteExpenseRemote(String id, String jwtToken) async {
  //   try {
  //     final response = await http.delete(
  //       Uri.parse('$baseUrl/expenses/$id'),
  //       headers: {'Authorization': 'Bearer $jwtToken'},
  //     );
  //     return response.statusCode == 200;
  //   } catch (_) {
  //     return false;
  //   }
  // }

  // Append inside ApiService class in lib/services/api_service.dart:
  static Future<List<Expense>> fetchExpenses(String jwtToken) async {
    final url = Uri.parse('$baseUrl/expenses');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['data'] ?? [];

        return items.map((json) {
          final title = json['title'] ??
              json['merchant'] ??
              json['description'] ??
              'Expense';
          final rawCategory = json['category']?.toString();

          return Expense(
            id: json['id'] ?? json['_id'] ?? '',
            title: title,
            amount: (json['amount'] as num).toDouble(),
            category: _sanitizeCategory(rawCategory, title),
            type: (json['type'] == 'credit')
                ? TransactionType.credit
                : TransactionType.debit,
            source: SourceType.values.firstWhere(
              (s) => s.name == (json['source'] ?? 'manual'),
              orElse: () => SourceType.manual,
            ),
            accountLast4: json['accountLast4'],
            date: DateTime.parse(json['date']),
          );
        }).toList();
      }
    } catch (e) {
      print('Error fetching expenses from backend: $e');
    }
    return [];
  }
}
