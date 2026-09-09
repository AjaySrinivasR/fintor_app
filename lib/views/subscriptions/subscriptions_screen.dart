// lib/views/subscriptions/subscriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/subscription_model.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final expProvider = context.watch<ExpenseProvider>();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Bills & Subscriptions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded),
            tooltip: 'Auto-detect from SMS History',
            onPressed: () {
              subProvider.detectRecurringSubscriptions(expProvider.expenses);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Scanned transaction history for recurring bills.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monthly Burn Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fixed Monthly Commitment',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    currency.format(subProvider.monthlyCommitment),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${subProvider.subscriptions.length} active recurring subscriptions/bills',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Active Subscriptions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            if (subProvider.subscriptions.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No recurring subscriptions tracked yet.\nTap the wand icon above to auto-detect from SMS or add manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subProvider.subscriptions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final sub = subProvider.subscriptions[index];
                  final daysLeft =
                      sub.nextBillingDate.difference(DateTime.now()).inDays;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Icon(
                          sub.isAutoDetected
                              ? Icons.repeat_rounded
                              : Icons.credit_card_rounded,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                      title: Text(sub.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(
                        'Renews on ${dateFormat.format(sub.nextBillingDate)} (${daysLeft >= 0 ? '$daysLeft days left' : 'Due'})',
                        style: TextStyle(
                          fontSize: 12,
                          color: daysLeft <= 3
                              ? Colors.red.shade700
                              : const Color(0xFF64748B),
                          fontWeight: daysLeft <= 3
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(currency.format(sub.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(sub.frequency,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 140),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSubscriptionDialog(context),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Bill',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Utilities & Bills';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Recurring Bill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: 'Subscription / Biller Name')),
            TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount =
                  double.tryParse(amountController.text.trim()) ?? 0.0;
              if (name.isNotEmpty && amount > 0) {
                context.read<SubscriptionProvider>().addManualSubscription(
                      Subscription(
                        id: const Uuid().v4(),
                        name: name,
                        amount: amount,
                        category: category,
                        nextBillingDate:
                            DateTime.now().add(const Duration(days: 30)),
                        frequency: 'Monthly',
                      ),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
