import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../services/api_service.dart';
import 'sms_parser.dart';

class BankRule {
  final String bank;
  final RegExp senderRegex;
  final RegExp? debitRegex;
  final RegExp? creditRegex;
  final int amountGroup;
  final int accountGroup;
  final int merchantGroup;

  BankRule({
    required this.bank,
    required this.senderRegex,
    this.debitRegex,
    this.creditRegex,
    required this.amountGroup,
    required this.accountGroup,
    required this.merchantGroup,
  });

  factory BankRule.fromJson(Map<String, dynamic> json) {
    return BankRule(
      bank: json['bank'] ?? 'Generic',
      senderRegex: RegExp(json['senderPattern'] ?? '.*', caseSensitive: false),
      debitRegex: json['debitRegex'] != null
          ? RegExp(json['debitRegex'], caseSensitive: false)
          : null,
      creditRegex: json['creditRegex'] != null
          ? RegExp(json['creditRegex'], caseSensitive: false)
          : null,
      amountGroup: json['amountGroup'] ?? 1,
      accountGroup: json['accountGroup'] ?? 2,
      merchantGroup: json['merchantGroup'] ?? 3,
    );
  }
}

class DynamicSmsEngine {
  static final List<BankRule> _rules = [];

  static Future<void> fetchRemoteTemplates() async {
    try {
      final res =
          await http.get(Uri.parse('${ApiService.baseUrl}/sms/templates'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List templates = data['templates'] ?? [];
        _rules.clear();
        for (var t in templates) {
          _rules.add(BankRule.fromJson(t));
        }
      }
    } catch (_) {
      // Retain fallback rules if offline
    }
  }

  static Expense? parse(String sender, String rawBody) {
    final body = rawBody.replaceAll('\n', ' ').trim();

    for (final rule in _rules) {
      if (!rule.senderRegex.hasMatch(sender)) continue;

      // Check Debit Pattern
      if (rule.debitRegex != null) {
        final match = rule.debitRegex!.firstMatch(body);
        if (match != null) {
          final amtStr =
              match.group(rule.amountGroup)?.replaceAll(',', '') ?? '0';
          final acc =
              match.group(rule.accountGroup)?.replaceAll(RegExp(r'[^\d]'), '');
          final merchant = match.groupCount >= rule.merchantGroup
              ? match.group(rule.merchantGroup) ?? 'POS/Online'
              : 'POS/Online';

          return Expense(
            id: const Uuid().v4(),
            title: merchant.trim().toUpperCase(),
            amount: double.tryParse(amtStr) ?? 0.0,
            category: SmsExpenseParser.categorizeExpense(merchant, body),
            type: TransactionType.debit,
            source: SourceType.sms,
            accountLast4: acc,
            date: DateTime.now(),
          );
        }
      }

      // Check Credit Pattern
      if (rule.creditRegex != null) {
        final match = rule.creditRegex!.firstMatch(body);
        if (match != null) {
          final amtStr =
              match.group(rule.amountGroup)?.replaceAll(',', '') ?? '0';
          final acc =
              match.group(rule.accountGroup)?.replaceAll(RegExp(r'[^\d]'), '');

          return Expense(
            id: const Uuid().v4(),
            title: 'Bank Deposit / Credit',
            amount: double.tryParse(amtStr) ?? 0.0,
            category: 'Income',
            type: TransactionType.credit,
            source: SourceType.sms,
            accountLast4: acc,
            date: DateTime.now(),
          );
        }
      }
    }
    return null;
  }
}

