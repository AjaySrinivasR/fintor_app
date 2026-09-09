enum TransactionType { debit, credit }

enum SourceType { sms, manual, csv }

class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final TransactionType type;
  final SourceType source;
  final String? accountLast4;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.type,
    this.source = SourceType.manual,
    this.accountLast4,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'type': type.name,
        'source': source.name,
        'accountLast4': accountLast4,
        'date': date.toIso8601String(),
      };
}
