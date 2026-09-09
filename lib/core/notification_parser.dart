import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';
import '../providers/category_provider.dart';

class NotificationExpenseParser {
  // Matches: "Paid ₹450 to Swiggy", "Sent Rs 1,200 to Ramesh", "You paid ₹320 at Starbucks"
  static final RegExp _upiDebitPattern = RegExp(
    r'(?:paid|sent)\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:to|at)\s+([A-Za-z0-9@._\s\-]+)',
    caseSensitive: false,
  );

  // Matches: "Received ₹500 from Amit", "Rs 1,000 received from XYZ"
  static final RegExp _upiCreditPattern = RegExp(
    r'(?:received|credited)\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:from)\s+([A-Za-z0-9@._\s\-]+)',
    caseSensitive: false,
  );

  static Expense? parse({
    required String packageName,
    required String title,
    required String text,
    required CategoryProvider categoryProvider,
  }) {
    final combined = '$title $text'.replaceAll('\n', ' ');

    // Debit check
    final debitMatch = _upiDebitPattern.firstMatch(combined);
    if (debitMatch != null) {
      final amount =
          double.tryParse(debitMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      final rawMerchant = debitMatch.group(2)!.trim();
      final merchant = _cleanMerchant(rawMerchant);

      return Expense(
        id: const Uuid().v4(),
        title: merchant,
        amount: amount,
        category: categoryProvider.matchCategory(merchant),
        type: TransactionType.debit,
        source: SourceType.sms, // Automated capture
        date: DateTime.now(),
      );
    }

    // Credit check
    final creditMatch = _upiCreditPattern.firstMatch(combined);
    if (creditMatch != null) {
      final amount =
          double.tryParse(creditMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      final sender = _cleanMerchant(creditMatch.group(2)!.trim());

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

    return null;
  }

  static String _cleanMerchant(String raw) {
    var clean = raw
        .replaceAll(
            RegExp(r'(using UPI|via Bank|using GPay|\.)', caseSensitive: false),
            '')
        .trim();
    return clean.isEmpty ? 'UPI Merchant' : clean;
  }
}
