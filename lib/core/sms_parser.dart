import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';

class SmsExpenseParser {
  // Pattern A: Credits
  static final List<RegExp> _creditPatterns = [
    RegExp(
      r'(?:(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*)\s*(?:is|has\s+been)?\s*credited\s+(?:with|by|for)?\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)|(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:is|has\s+been)?\s*credited\s+(?:to\s+)?(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*))',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:received|deposited)\s+(?:payment\s+of\s+)?(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)(?:\s+(?:in|to)\s+(?:your\s+)?a\/c\s*([xX*]*\d*))?',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:received|deposited)\s+(?:in|to)\s+(?:your\s+)?a\/c\s*([xX*]*\d*)',
      caseSensitive: false,
    ),
  ];

  // Pattern B: Debits
  static final List<RegExp> _debitPatterns = [
    RegExp(
      r'(?:(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*)\s*(?:is|has\s+been)?\s*debited\s+(?:for|with|by)?\s*(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)|(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:is|has\s+been)?\s*debited\s+(?:from\s+)?(?:your\s+)?a\/c\s*(?:no\.?)?\s*([xX*]*\d*))',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:spent|paid|transferred|sent|withdrawn)\s+(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)(?:\s+(?:from|using)\s+(?:your\s+)?(?:card|a\/c)\s*([xX*]*\d*))?',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s*(?:spent|paid|transferred|withdrawn|debited)\s+(?:from|on)\s+(?:your\s+)?(?:card|a\/c)\s*([xX*]*\d*)',
      caseSensitive: false,
    ),
    RegExp(
      r'txn\s+(?:of\s+)?(?:Rs\.?|INR|₹)\s*([\d,]+\.?\d*)\s+done\s+on\s+(?:card|a\/c)\s*([xX*]*\d*)',
      caseSensitive: false,
    ),
  ];

  // Extraction patterns for merchant/payee
  // static final List<RegExp> _merchantExtractors = [
  //   RegExp(r'(?:to\s+vpa|vpa)\s+([A-Za-z0-9@._\-]+)', caseSensitive: false),
  //   RegExp(
  //       r"(?:paid\s+to|transferred\s+to|transfer\s+to|sent\s+to)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
  //       caseSensitive: false),
  //   RegExp(
  //       r"(?:at|towards|for)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
  //       caseSensitive: false),
  //   RegExp(
  //       r"info:\s*([A-Za-z0-9\s&'\.\-_\/]+?)(?=\s+(?:avl|bal|val|available|\.|$))",
  //       caseSensitive: false),
  //   RegExp(
  //       r"(?:to)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
  //       caseSensitive: false),
  // ];
  static final List<RegExp> _merchantExtractors = [
    // 1. Add this pattern for "linked to <VPA>" (HDFC style)
    RegExp(
      r"(?:linked\s+to)\s+([A-Za-z0-9\._\-]+@?[A-Za-z0-9\._\-]*)(?=\s+(?:is|was|credited|debited|on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
      caseSensitive: false,
    ),

    // Existing extractors...
    RegExp(r'(?:to\s+vpa|vpa)\s+([A-Za-z0-9@._\-]+)', caseSensitive: false),
    RegExp(
        r"(?:paid\s+to|transferred\s+to|transfer\s+to|sent\s+to)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
        caseSensitive: false),
    RegExp(
        r"(?:at|towards|for)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
        caseSensitive: false),
    RegExp(
        r"info:\s*([A-Za-z0-9\s&'\.\-_\/]+?)(?=\s+(?:avl|bal|val|available|\.|$))",
        caseSensitive: false),
    RegExp(
        r"(?:to)\s+([A-Za-z0-9\s&'\.\-_]+?)(?=\s+(?:on|via|ref|upi|avl|bal|val|card|a\/c|\.|$))",
        caseSensitive: false),
  ];

  static Expense? parse(String sender, String body) {
    final cleanBody = body.replaceAll('\n', ' ').trim();

    // 1. Check Credits First
    for (final pattern in _creditPatterns) {
      final match = pattern.firstMatch(cleanBody);
      if (match != null) {
        String account = '';
        String amountStr = '0';

        if (match.groupCount >= 4 &&
            (match.group(2) != null || match.group(3) != null)) {
          account = match.group(1) ?? match.group(4) ?? '';
          amountStr = match.group(2) ?? match.group(3) ?? '0';
        } else if (match.groupCount >= 2 && match.group(1) != null) {
          amountStr = match.group(1)!;
          account = match.group(2) ?? '';
        } else if (match.groupCount >= 1 && match.group(1) != null) {
          amountStr = match.group(1)!;
        }

        final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
        if (amount > 0) {
          final merchant =
              _extractMerchant(cleanBody) ?? 'UPI Transfer / Deposit';
          return Expense(
            id: const Uuid().v4(),
            title: merchant.startsWith('From ') ? merchant : 'From $merchant',
            amount: amount,
            category: 'Income',
            type: TransactionType.credit,
            source: SourceType.sms,
            accountLast4: account.replaceAll(RegExp(r'[^\d]'), ''),
            date: DateTime.now(),
          );
        }
      }
    }

    // 2. Check Debits
    for (final pattern in _debitPatterns) {
      final match = pattern.firstMatch(cleanBody);
      if (match != null) {
        String account = '';
        String amountStr = '0';

        if (match.groupCount >= 4 &&
            (match.group(2) != null || match.group(3) != null)) {
          account = match.group(1) ?? match.group(4) ?? '';
          amountStr = match.group(2) ?? match.group(3) ?? '0';
        } else if (match.groupCount >= 2 && match.group(1) != null) {
          amountStr = match.group(1)!;
          account = match.group(2) ?? '';
        } else if (match.groupCount >= 1 && match.group(1) != null) {
          amountStr = match.group(1)!;
        }

        final amount = double.tryParse(amountStr.replaceAll(',', '')) ?? 0.0;
        if (amount > 0) {
          final rawMerchant = _extractMerchant(cleanBody) ?? 'Bank Outflow';
          final cleanTitle = _cleanMerchant(rawMerchant);
          final category = categorizeExpense(cleanTitle, cleanBody);

          return Expense(
            id: const Uuid().v4(),
            title: cleanTitle,
            amount: amount,
            category: category,
            type: TransactionType.debit,
            source: SourceType.sms,
            accountLast4: account.replaceAll(RegExp(r'[^\d]'), ''),
            date: DateTime.now(),
          );
        }
      }
    }

    return null;
  }

  static String? _extractMerchant(String text) {
    for (final reg in _merchantExtractors) {
      final match = reg.firstMatch(text);
      if (match != null) {
        final candidate = match.group(1)?.trim();
        if (candidate != null &&
            candidate.isNotEmpty &&
            !candidate.toLowerCase().startsWith('linked') &&
            !candidate.toLowerCase().startsWith('mobile') &&
            !candidate.toLowerCase().startsWith('your')) {
          return candidate;
        }
      }
    }
    return null;
  }

  // static String _cleanMerchant(String raw) {
  //   var clean = raw
  //       .replaceAll(
  //           RegExp(r'(UPI|Ref|No|on|at|to|via|using|card|a\/c|val)',
  //               caseSensitive: false),
  //           ' ')
  //       .replaceAll(RegExp(r'[\/\\*#;:]+'), ' ')
  //       .replaceAll(RegExp(r'\s+'), ' ')
  //       .trim();

  //   if (clean.contains('@')) {
  //     clean = clean.split('@').first.trim();
  //   }

  //   if (clean.isEmpty || clean.length < 2) return 'Online Transfer';
  //   return clean.toUpperCase();
  // }
  static String _cleanMerchant(String raw) {
    var clean = raw
        .replaceAll(
            RegExp(r'(UPI|Ref|No|on|at|to|via|using|card|a\/c|val)',
                caseSensitive: false),
            ' ')
        // Included dot (.) and other trailing symbols to be removed
        .replaceAll(RegExp(r'[\/\\*#;:.] overlay?'), ' ')
        .replaceAll(RegExp(r'[\/\\*#;:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.contains('@')) {
      clean = clean.split('@').first.trim();
    }
    if (clean.endsWith('.')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    if (clean.isEmpty || clean.length < 2) return 'Online Transfer';
    return clean.toUpperCase();
  }

  // static bool _hasAny(String text, List<String> keywords) {
  //   for (final kw in keywords) {
  //     // Use word boundaries so "store" doesn't match inside "random_store" unexpectedly
  //     final pattern =
  //         RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
  //     if (pattern.hasMatch(text)) return true;
  //   }
  //   return false;
  // }
  static bool _hasAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.toLowerCase().contains(kw.toLowerCase())) return true;
    }
    return false;
  }

  /// Categorizes an expense based on the merchant name and the full SMS text context
  static String categorizeExpense(String merchant, [String fullText = '']) {
    final combined = '$merchant $fullText'.toLowerCase();

    // Food & Dining
    if (_hasAny(combined, [
      'swiggy',
      'zomato',
      'blinkit',
      'zepto',
      'instamart',
      'mcdonald',
      'kfc',
      'dominos',
      'pizza',
      'burger',
      'biryani',
      'starbucks',
      'cafe',
      'coffee',
      'tea',
      'bakery',
      'dine',
      'dining',
      'restaurant',
      'eats',
      'chai',
      'eatclub',
      'subway',
      'haldiram',
      'barbeque',
      'food',
      'kitchen',
      'bakes',
      'cake',
      'sweet',
      'bar',
      'pub',
      'brewery',
      'grill',
      'tiffin',
      'canteen'
    ])) {
      return 'Food & Dining';
    }

    // Travel & Fuel
    if (_hasAny(combined, [
      'uber',
      'ola',
      'rapido',
      'petrol',
      'fuel',
      'hpcl',
      'bpcl',
      'ioc',
      'iocl',
      'shell',
      'indian oil',
      'bharat petroleum',
      'hindustan petroleum',
      'irctc',
      'railway',
      'train',
      'metro',
      'fastag',
      'toll',
      'parking',
      'flight',
      'indigo',
      'spicejet',
      'airindia',
      'akasa',
      'vistara',
      'redbus',
      'abhibus',
      'taxi',
      'cab',
      'auto',
      'makemytrip',
      'easemytrip',
      'yulu',
      'zoomcar',
      'transit'
    ])) {
      return 'Travel & Fuel';
    }

    // Entertainment
    if (_hasAny(combined, [
      'district',
      'netflix',
      'spotify',
      'hotstar',
      'disney',
      'prime video',
      'prime',
      'pvr',
      'inox',
      'cinepolis',
      'bookmyshow',
      'youtube',
      'sony liv',
      'zee5',
      'gaana',
      'wynk',
      'steam',
      'playstation',
      'xbox',
      'gaming',
      'cinema',
      'theatre',
      'movie',
      'club',
      'amusement',
      'concert',
      'event'
    ])) {
      return 'Entertainment';
    }

    // Utilities & Bills
    if (_hasAny(combined, [
      'airtel',
      'jio',
      'vi ',
      'vodafone',
      'bescom',
      'tneb',
      'msedcl',
      'bsnl',
      'tata play',
      'tata sky',
      'dish tv',
      'dth',
      'broadband',
      'wifi',
      'act fibernet',
      'fiber',
      'electricity',
      'electric',
      'water bill',
      'gas bill',
      'indane',
      'hp gas',
      'bharat gas',
      'lpg',
      'pipe gas',
      'recharge',
      'billdesk',
      'bbps',
      'postpaid',
      'prepaid',
      'utility',
      'insurance',
      'lic',
      'policy',
      'maintenance'
    ])) {
      return 'Utilities & Bills';
    }

    // Investments & SIP
    if (_hasAny(combined, [
      'zerodha',
      'groww',
      'upstox',
      'coin',
      'kuvera',
      'mutual fund',
      'sip',
      'kite',
      'angelone',
      '5paisa',
      'indmoney',
      'smallcase',
      'nse',
      'bse',
      'navi',
      'etmoney',
      'investment',
      'ppfas',
      'equity',
      'share',
      'broker',
      'securities',
      'sovereign gold',
      'ppf',
      'nps'
    ])) {
      return 'Investments & SIP';
    }

    // Shopping
    if (_hasAny(combined, [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa',
      'tata cliq',
      'croma',
      'reliance digital',
      'reliance retail',
      'dmart',
      'bigbasket',
      'supermarket',
      'hypermarket',
      'store',
      'retail',
      'mart',
      'mall',
      'ikea',
      'zara',
      'h&m',
      'decathlon',
      'uniqlo',
      'lenskart',
      'pharmacy',
      'apollo pharmacy',
      'medplus',
      '1mg',
      'pharmeasy',
      'clothes',
      'apparel',
      'electronics',
      'shopping'
    ])) {
      return 'Shopping';
    }

    return 'General';
  }

  // static bool _hasAny(String text, List<String> keywords) {
  //   for (final kw in keywords) {
  //     if (text.contains(kw)) return true;
  //   }
  //   return false;
  // }
}
