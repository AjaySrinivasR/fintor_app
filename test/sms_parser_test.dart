// import 'package:flutter_test/flutter_test.dart';
// import 'package:fintor/core/sms_parser.dart';
// import 'package:fintor/models/expense_model.dart';

// void main() {
//   group('SmsExpenseParser Tests', () {
//     test('Correctly parses and categorizes Food & Dining (Swiggy)', () {
//       const sms = 'Your A/c XX1234 is debited for Rs. 450.00 on 04-Oct-26 to Swiggy UPI Ref 123456';
//       final exp = SmsExpenseParser.parse('HDFCBK', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 450.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Food & Dining');
//       expect(exp.accountLast4, '1234');
//     });

//     test('Correctly parses and categorizes Travel & Fuel (Uber)', () {
//       const sms = 'Rs. 280 debited from your a/c no. 5678 to VPA uber@axisbank on 04-10-26';
//       final exp = SmsExpenseParser.parse('AXISBK', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 280.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Travel & Fuel');
//     });

//     test('Correctly parses and categorizes Shopping (Amazon)', () {
//       const sms = 'Spent Rs. 1,499.00 using card 9012 at AMAZON PAY INDIA on 03-Oct-26';
//       final exp = SmsExpenseParser.parse('SBICRD', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 1499.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Shopping');
//     });

//     test('Correctly parses and categorizes Entertainment (Netflix)', () {
//       const sms = 'Your A/c no. 4321 is debited with INR 649.00 towards NETFLIX on 01-10-26';
//       final exp = SmsExpenseParser.parse('ICICIB', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 649.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Entertainment');
//     });

//     test('Correctly parses and categorizes Utilities & Bills (Airtel/Bescom)', () {
//       const sms = 'Paid Rs. 999 to Airtel Broadband bill using UPI';
//       final exp = SmsExpenseParser.parse('PAYTM', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 999.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Utilities & Bills');
//     });

//     test('Correctly parses and categorizes Investments & SIP (Zerodha)', () {
//       const sms = 'Transferred Rs 5,000.00 to Zerodha Broking from a/c 1122 for SIP';
//       final exp = SmsExpenseParser.parse('KOTAKB', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 5000.00);
//       expect(exp.type, TransactionType.debit);
//       expect(exp.category, 'Investments & SIP');
//     });

//     test('Correctly parses Credit SMS as Income', () {
//       const sms = 'Your A/c XX1234 is credited with Rs. 25,000.00 on 01-Oct-26 by Salary Transfer';
//       final exp = SmsExpenseParser.parse('HDFCBK', sms);

//       expect(exp, isNotNull);
//       expect(exp!.amount, 25000.00);
//       expect(exp.type, TransactionType.credit);
//       expect(exp.category, 'Income');
//     });
//   });
// }
import 'package:flutter_test/flutter_test.dart';
import 'package:fintor/core/sms_parser.dart';
import 'package:fintor/models/expense_model.dart';

void main() {
  group('SmsExpenseParser - Categorization & Extraction Tests', () {
    test(
        'Should parse debit SMS, extract merchant, and classify as Food & Dining',
        () {
      const sender = 'XX-HDFCBK';
      const sampleSms =
          'Rs. 450.00 debited from a/c 1234 on 04-Oct-26 at SWIGGY Ref 992810';

      final expense = SmsExpenseParser.parse(sender, sampleSms);

      expect(expense, isNotNull);
      expect(expense!.amount, equals(450.00));
      expect(expense.accountLast4, equals('1234'));
      expect(expense.title, equals('SWIGGY'));
      expect(expense.category, equals('Food & Dining'));
      expect(expense.type, equals(TransactionType.debit));
    });

    test(
        'Should parse HDFC UPI debit SMS with linked VPA and districtmovies merchant',
        () {
      const sender = 'XX-HDFCBK';
      const sampleSms =
          'Your A/c No.XXXX is debited with Rs.727.83 on 03-09-2026 01:35 PM '
          'and HDFC A/c linked to districtmovies.payu@hdfcbank is credited (UPI Ref No.XXXXXXXXXX)';

      final expense = SmsExpenseParser.parse(sender, sampleSms);

      expect(expense, isNotNull);
      expect(expense!.amount, equals(727.83));
      expect(expense.type, equals(TransactionType.debit));
      expect(expense.source, equals(SourceType.sms));

      // Cleaned merchant handle from "districtmovies.payu@hdfcbank"
      expect(expense.title, equals('DISTRICTMOVIES.PAYU'));

      // Categorizes based on "district" or "movie" keywords
      expect(expense.category, equals('Entertainment'));
    });

    test('Should classify expense directly using categorizeExpense()', () {
      final category =
          SmsExpenseParser.categorizeExpense('SWIGGY', 'UPI-SWIGGY-1293@icici');
      expect(category, equals('Food & Dining'));
    });

    test('Should extract and classify Travel & Fuel correctly', () {
      final category = SmsExpenseParser.categorizeExpense(
          'UBER', 'Paid Rs. 250 to Uber Rides');
      expect(category, equals('Travel & Fuel'));
    });

    test('Should fallback to General for unrecognized merchants', () {
      final category = SmsExpenseParser.categorizeExpense(
          'XYZ_MERCHANT', 'Paid Rs. 100 at local counter');
      expect(category, equals('General'));
    });
  });
}
