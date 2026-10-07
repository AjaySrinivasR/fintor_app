import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../providers/category_provider.dart';

class NotificationExpenseParser {
  // Pattern 1: "Paid ₹450 to Swiggy", "Payment of ₹1,200 to Ramesh", "Sent Rs 500 to XYZ"
  static final RegExp _upiDebitPattern1 = RegExp(
    r'(?:paid|sent|transferred|spent|payment\s+of|debited\s*(?:for|with|by)?)\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:to|at|for|towards|on)\s+([A-Za-z0-9@._\s\-&]+)',
    caseSensitive: false,
  );

  // Pattern 2: "₹450 paid to Swiggy", "Rs. 1,200 sent to Ramesh", "₹320 debited for Starbucks"
  static final RegExp _upiDebitPattern2 = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:paid|sent|transferred|debited)\s*(?:to|at|for|towards|on)\s+([A-Za-z0-9@._\s\-&]+)',
    caseSensitive: false,
  );

  // Pattern 3: "Paid Swiggy ₹450"
  static final RegExp _upiDebitPattern3 = RegExp(
    r'(?:paid|sent\s+to)\s+([A-Za-z0-9@._\s\-&]+?)\s+(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)',
    caseSensitive: false,
  );

  // Credit Pattern 1: "Received ₹500 from Amit", "Rs 1,000 received from XYZ", "Payment of ₹500 received from Amit"
  static final RegExp _upiCreditPattern1 = RegExp(
    r'(?:received|credited|received\s+payment\s+of|payment\s+of)\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:from|by)\s+([A-Za-z0-9@._\s\-&]+)',
    caseSensitive: false,
  );

  // Credit Pattern 2: "₹500 received from Amit", "Rs 1,000 credited from XYZ"
  static final RegExp _upiCreditPattern2 = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:received|credited)\s*(?:from|by)\s+([A-Za-z0-9@._\s\-&]+)',
    caseSensitive: false,
  );

  static Expense? parse({
    required String packageName,
    required String title,
    required String text,
    required CategoryProvider categoryProvider,
  }) {
    final combined = '$title $text'.replaceAll('\n', ' ').trim();

    // Debit check Pattern 1
    final debitMatch1 = _upiDebitPattern1.firstMatch(combined);
    if (debitMatch1 != null) {
      final amount =
          double.tryParse(debitMatch1.group(1)!.replaceAll(',', '')) ?? 0.0;
      final merchant = _cleanMerchant(debitMatch1.group(2)!);
      if (amount > 0) {
        String category = categoryProvider.matchCategory('$merchant $combined');
        if (category == 'General') {
          category = categoryProvider.matchCategory(merchant);
        }
        return Expense(
          id: const Uuid().v4(),
          title: merchant,
          amount: amount,
          category: category,
          type: TransactionType.debit,
          source: SourceType.sms,
          date: DateTime.now(),
        );
      }
    }

    // Debit check Pattern 2
    final debitMatch2 = _upiDebitPattern2.firstMatch(combined);
    if (debitMatch2 != null) {
      final amount =
          double.tryParse(debitMatch2.group(1)!.replaceAll(',', '')) ?? 0.0;
      final merchant = _cleanMerchant(debitMatch2.group(2)!);
      if (amount > 0) {
        String category = categoryProvider.matchCategory('$merchant $combined');
        if (category == 'General') {
          category = categoryProvider.matchCategory(merchant);
        }
        return Expense(
          id: const Uuid().v4(),
          title: merchant,
          amount: amount,
          category: category,
          type: TransactionType.debit,
          source: SourceType.sms,
          date: DateTime.now(),
        );
      }
    }

    // Debit check Pattern 3
    final debitMatch3 = _upiDebitPattern3.firstMatch(combined);
    if (debitMatch3 != null) {
      final merchant = _cleanMerchant(debitMatch3.group(1)!);
      final amount =
          double.tryParse(debitMatch3.group(2)!.replaceAll(',', '')) ?? 0.0;
      if (amount > 0) {
        String category = categoryProvider.matchCategory('$merchant $combined');
        if (category == 'General') {
          category = categoryProvider.matchCategory(merchant);
        }
        return Expense(
          id: const Uuid().v4(),
          title: merchant,
          amount: amount,
          category: category,
          type: TransactionType.debit,
          source: SourceType.sms,
          date: DateTime.now(),
        );
      }
    }

    // Credit check Pattern 1
    final creditMatch1 = _upiCreditPattern1.firstMatch(combined);
    if (creditMatch1 != null) {
      final amount =
          double.tryParse(creditMatch1.group(1)!.replaceAll(',', '')) ?? 0.0;
      final sender = _cleanMerchant(creditMatch1.group(2)!);
      if (amount > 0) {
        return Expense(
          id: const Uuid().v4(),
          title: 'Received from $sender',
          amount: amount,
          category: 'Income',
          type: TransactionType.credit,
          source: SourceType.sms,
          date: DateTime.now(),
        );
      }
    }

    // Credit check Pattern 2
    final creditMatch2 = _upiCreditPattern2.firstMatch(combined);
    if (creditMatch2 != null) {
      final amount =
          double.tryParse(creditMatch2.group(1)!.replaceAll(',', '')) ?? 0.0;
      final sender = _cleanMerchant(creditMatch2.group(2)!);
      if (amount > 0) {
        return Expense(
          id: const Uuid().v4(),
          title: 'Received from $sender',
          amount: amount,
          category: 'Income',
          type: TransactionType.credit,
          source: SourceType.sms,
          date: DateTime.now(),
        );
      }
    }

    return null;
  }

  static String _cleanMerchant(String raw) {
    var clean = raw
        .replaceAll(
            RegExp(r'(using\s+UPI|via\s+Bank|using\s+GPay|using\s+PhonePe|was\s+successful|is\s+successful|successful|\bon\b|\bat\b|\.)',
                caseSensitive: false),
            ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.contains('@')) {
      clean = clean.split('@').first.trim();
    }

    return clean.isEmpty ? 'UPI Merchant' : clean;
  }
}
