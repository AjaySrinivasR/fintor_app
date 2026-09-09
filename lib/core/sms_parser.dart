import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';

class SmsExpenseParser {
  // Pattern A: "Your A/c ... is credited with Rs. 500" OR "Rs. 500 credited to A/c ..."
  static final RegExp _creditPattern = RegExp(
    r'(?:(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*)\s*(?:is\s+)?credited\s+(?:with\s+)?(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)|(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:is\s+)?credited\s+(?:to\s+)?(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*))',
    caseSensitive: false,
  );

  // Pattern B: "Your A/c ... is debited with Rs. 500" OR "Rs. 500 debited from A/c ..."
  static final RegExp _debitPattern = RegExp(
    r'(?:(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*)\s*(?:is\s+)?debited\s+(?:for|with)?\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)|(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:is\s+)?debited\s+(?:from\s+)?(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*))',
    caseSensitive: false,
  );

  // Counterparty / UPI VPA Pattern: "linked to xxxx@okaxis", "to VPA abc@upi", "at Merchant"
  static final RegExp _counterpartyPattern = RegExp(
    r'(?:linked\s+to|to\s+vpa|to|at|info)\s+([A-Za-z0-9@._\-]+)',
    caseSensitive: false,
  );

  static Expense? parse(String sender, String body) {
    final cleanBody = body.replaceAll('\n', ' ').trim();

    // Check if "Your A/c" is credited first (prevents mismatch from sender's debit note)
    final creditMatch = _creditPattern.firstMatch(cleanBody);
    if (creditMatch != null) {
      final account = creditMatch.group(1) ?? creditMatch.group(4) ?? '';
      final amountStr = (creditMatch.group(2) ?? creditMatch.group(3) ?? '0')
          .replaceAll(',', '');
      final amount = double.tryParse(amountStr) ?? 0.0;

      final vpaMatch = _counterpartyPattern.firstMatch(cleanBody);
      String sourceName = 'UPI Transfer / Deposit';
      if (vpaMatch != null) {
        sourceName = 'From ${vpaMatch.group(1)!}';
      }

      return Expense(
        id: const Uuid().v4(),
        title: sourceName,
        amount: amount,
        category: 'Income',
        type: TransactionType.credit,
        source: SourceType.sms,
        accountLast4: account.replaceAll(RegExp(r'[^\d]'), ''),
        date: DateTime.now(),
      );
    }

    // Check Debits
    final debitMatch = _debitPattern.firstMatch(cleanBody);
    if (debitMatch != null) {
      final account = debitMatch.group(1) ?? debitMatch.group(4) ?? '';
      final amountStr = (debitMatch.group(2) ?? debitMatch.group(3) ?? '0')
          .replaceAll(',', '');
      final amount = double.tryParse(amountStr) ?? 0.0;

      final vpaMatch = _counterpartyPattern.firstMatch(cleanBody);
      String merchant = 'Bank Outflow';
      if (vpaMatch != null) {
        merchant = vpaMatch.group(1)!;
      }

      return Expense(
        id: const Uuid().v4(),
        title: _cleanMerchant(merchant),
        amount: amount,
        category: _categorize(merchant),
        type: TransactionType.debit,
        source: SourceType.sms,
        accountLast4: account.replaceAll(RegExp(r'[^\d]'), ''),
        date: DateTime.now(),
      );
    }

    return null;
  }

  static String _cleanMerchant(String raw) {
    var clean = raw
        .replaceAll(RegExp(r'(UPI|Ref|No|on|at|to)', caseSensitive: false), '')
        .trim();
    if (clean.contains('@')) clean = clean.split('@').first;
    return clean.isEmpty ? 'Online Transfer' : clean.toUpperCase();
  }

//   static String _categorize(String name) {
//     final m = name.toLowerCase();
//     if (m.contains('swiggy') || m.contains('zomato') || m.contains('food')) return 'Food & Dining';
//     if (m.contains('uber') || m.contains('ola') || m.contains('fuel')) return 'Transportation';
//     if (m.contains('mart') || m.contains('amazon') || m.contains('market')) return 'Groceries';
//     return 'General';
//   }
// }

  static String _categorize(String merchant) {
    final m = merchant.toLowerCase();
    if (m.contains('swiggy') ||
        m.contains('zomato') ||
        m.contains('food') ||
        m.contains('starbucks') ||
        m.contains('cafe')) {
      return 'Food & Dining';
    } else if (m.contains('uber') ||
        m.contains('ola') ||
        m.contains('fuel') ||
        m.contains('metro') ||
        m.contains('irctc')) {
      return 'Travel & Fuel';
    } else if (m.contains('amazon') ||
        m.contains('flipkart') ||
        m.contains('myntra') ||
        m.contains('retail') ||
        m.contains('mart')) {
      return 'Shopping';
    } else if (m.contains('netflix') ||
        m.contains('prime') ||
        m.contains('hotstar') ||
        m.contains('cinema') ||
        m.contains('pvr')) {
      return 'Entertainment';
    } else if (m.contains('electric') ||
        m.contains('bescom') ||
        m.contains('airtel') ||
        m.contains('jio') ||
        m.contains('bill')) {
      return 'Utilities';
    }
    return 'General';
  }
}
