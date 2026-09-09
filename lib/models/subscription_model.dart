// lib/models/subscription_model.dart
class Subscription {
  final String id;
  final String name;
  final double amount;
  final String category;
  final DateTime nextBillingDate;
  final String frequency; // 'Monthly' or 'Yearly'
  final bool isAutoDetected;

  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.nextBillingDate,
    this.frequency = 'Monthly',
    this.isAutoDetected = false,
  });
}
