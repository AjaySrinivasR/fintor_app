// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import '../providers/category_provider.dart';

// class ParsedReceiptData {
//   final String merchantName;
//   final double amount;
//   final DateTime date;
//   final String category;
//   final String rawText;

//   ParsedReceiptData({
//     required this.merchantName,
//     required this.amount,
//     required this.date,
//     required this.category,
//     required this.rawText,
//   });
// }

// class ReceiptOcrParser {
//   static final RegExp _amountRegex = RegExp(
//     r'(?:total|grand\s*total|net\s*amount|bill\s*amount|amount\s*payable|paid\s*amount|balance|due)\s*[:=\s]*₹?\s*Rs\.?\s*([\d,]+\.?\d*)',
//     caseSensitive: false,
//   );

//   static final RegExp _fallbackAmountRegex = RegExp(
//     r'(?:₹|Rs\.?)\s*([\d,]+\.?\d{2})',
//     caseSensitive: false,
//   );

//   static final List<RegExp> _datePatterns = [
//     RegExp(
//         r'(\d{1,2})[\/\.-](\d{1,2})[\/\.-](\d{2,4})'), // 28/08/2026 or 28-08-26
//     RegExp(
//         r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{2,4})',
//         caseSensitive: false),
//   ];

//   static ParsedReceiptData parse(
//       RecognizedText recognizedText, CategoryProvider categoryProvider) {
//     final rawText = recognizedText.text;
//     final lines = recognizedText.blocks
//         .expand((b) => b.lines)
//         .map((l) => l.text.trim())
//         .where((t) => t.isNotEmpty)
//         .toList();

//     // 1. Extract Merchant Name (Scrub headers like "Tax Invoice", "Welcome", etc.)
//     String merchant = 'Retail Store';
//     final nonMerchantNoise = RegExp(
//         r'(tax\s*invoice|cash\s*memo|receipt|bill|welcome|order|table|pos|gstin)',
//         caseSensitive: false);
//     for (int i = 0; i < lines.length && i < 4; i++) {
//       if (!nonMerchantNoise.hasMatch(lines[i]) &&
//           lines[i].length > 2 &&
//           !RegExp(r'^\d+$').hasMatch(lines[i])) {
//         merchant = lines[i];
//         break;
//       }
//     }

//     // 2. Extract Total Amount
//     double amount = 0.0;
//     // Primary check: Lines containing keyword "Total"
//     for (final line in lines) {
//       final match = _amountRegex.firstMatch(line);
//       if (match != null) {
//         final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
//         if (val != null && val > amount) {
//           amount = val;
//         }
//       }
//     }

//     // Fallback check: Look for the highest currency figure on the receipt
//     if (amount == 0.0) {
//       final matches = _fallbackAmountRegex.allMatches(rawText);
//       for (final match in matches) {
//         final val = double.tryParse(match.group(1)!.replaceAll(',', ''));
//         if (val != null && val > amount) {
//           amount = val;
//         }
//       }
//     }

//     // 3. Extract Date
//     DateTime transactionDate = DateTime.now();
//     for (final line in lines) {
//       bool found = false;
//       for (final pattern in _datePatterns) {
//         final match = pattern.firstMatch(line);
//         if (match != null) {
//           // Attempt standard parsing
//           final parsedDate = _parseDateString(match.group(0)!);
//           if (parsedDate != null) {
//             transactionDate = parsedDate;
//             found = true;
//             break;
//           }
//         }
//       }
//       if (found) break;
//     }

//     return ParsedReceiptData(
//       merchantName: merchant.toUpperCase(),
//       amount: amount,
//       date: transactionDate,
//       category: categoryProvider.matchCategory(merchant),
//       rawText: rawText,
//     );
//   }

//   static DateTime? _parseDateString(String dateStr) {
//     try {
//       final parts = dateStr.split(RegExp(r'[\/\.-]'));
//       if (parts.length == 3) {
//         int day = int.parse(parts[0]);
//         int month = int.parse(parts[1]);
//         int year = int.parse(parts[2]);
//         if (year < 100) year += 2000;
//         return DateTime(year, month, day);
//       }
//     } catch (_) {}
//     return null;
//   }
// }
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedReceipt {
  final String merchant;
  final double amount;
  final DateTime date;
  final double confidenceScore;

  ParsedReceipt({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.confidenceScore,
  });
}

class ReceiptParser {
  static final RegExp _currencyRegex = RegExp(
    r'(?:(?:₹|INR|RS\.?|TOTAL|DUE|PAID|BAL)\s*)?([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2}))',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b',
  );

  static final Set<String> _blacklist = {
    'TAX INVOICE',
    'GSTIN',
    'CASH MEMO',
    'BILL',
    'RECEIPT',
    'INVOICE',
    'CUSTOMER COPY',
    'MERCHANT COPY',
    'WELCOME',
    'THANK YOU',
  };

  static ParsedReceipt parse(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return ParsedReceipt(
        merchant: 'Cash Expense',
        amount: 0.0,
        date: DateTime.now(),
        confidenceScore: 0.0,
      );
    }

    String extractedMerchant = 'Retail Store';
    double extractedAmount = 0.0;
    DateTime extractedDate = DateTime.now();

    // 1. Identify Merchant (Scan upper 25% vertical plane)
    final sortedByTop = List<TextBlock>.from(recognizedText.blocks)
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    for (final block in sortedByTop.take(4)) {
      final cleanText =
          block.text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
      final isExcluded = _blacklist.any(
        (term) => cleanText.toUpperCase().contains(term),
      );

      if (!isExcluded && cleanText.length > 2) {
        // Take the first prominent text line as merchant name
        extractedMerchant = block.lines.first.text.trim();
        break;
      }
    }

    // 2. Extract Settled Total (Keyword proximity + highest candidate matching)
    final candidateAmounts = <double>[];

    for (final block in recognizedText.blocks) {
      final upperBlock = block.text.toUpperCase();

      // Check for explicit total signifiers
      if (upperBlock.contains('TOTAL') ||
          upperBlock.contains('NET') ||
          upperBlock.contains('AMOUNT') ||
          upperBlock.contains('PAID') ||
          upperBlock.contains('BAL')) {
        for (final line in block.lines) {
          final matches = _currencyRegex.allMatches(line.text);
          for (final m in matches) {
            final raw = m.group(1)?.replaceAll(',', '');
            if (raw != null) {
              final val = double.tryParse(raw);
              if (val != null && val > 0 && val < 500000) {
                candidateAmounts.add(val);
              }
            }
          }
        }
      }

      // Check for transaction date
      final dateMatch = _dateRegex.firstMatch(block.text);
      if (dateMatch != null) {
        try {
          final d = int.parse(dateMatch.group(1)!);
          final m = int.parse(dateMatch.group(2)!);
          var y = int.parse(dateMatch.group(3)!);
          if (y < 100) y += 2000;
          if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            extractedDate = DateTime(y, m, d);
          }
        } catch (_) {}
      }
    }

    // Fallback: If no keyword-tied total was found, take the largest decimal token
    if (candidateAmounts.isEmpty) {
      for (final block in recognizedText.blocks) {
        final matches = _currencyRegex.allMatches(block.text);
        for (final m in matches) {
          final raw = m.group(1)?.replaceAll(',', '');
          if (raw != null) {
            final val = double.tryParse(raw);
            if (val != null && val > 0 && val < 500000) {
              candidateAmounts.add(val);
            }
          }
        }
      }
    }

    if (candidateAmounts.isNotEmpty) {
      extractedAmount = candidateAmounts.reduce(max);
    }

    return ParsedReceipt(
      merchant: extractedMerchant,
      amount: extractedAmount,
      date: extractedDate,
      confidenceScore: extractedAmount > 0 ? 0.90 : 0.40,
    );
  }
}
