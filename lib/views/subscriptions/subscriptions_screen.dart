import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/subscription_model.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final expProvider = context.watch<ExpenseProvider>();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy');

    final monthlyTotal = subProvider.monthlyCommitment;
    final annualTotal = monthlyTotal * 12;

    // Filter upcoming bills due in next 7 days
    final now = DateTime.now();
    final upcomingBills = subProvider.subscriptions.where((s) {
      final diff = s.nextBillingDate.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recurring Bills & Subscriptions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              DateFormat('MMMM yyyy').format(expProvider.selectedMonth),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'Auto-scan from SMS History',
            onPressed: () {
              subProvider.detectRecurringSubscriptions(expProvider.expenses);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E3A8A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text('Scanned transaction history for recurring bills.'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // 1. Monthly Burn Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.repeat_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Fixed Commitments',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        subProvider.detectRecurringSubscriptions(expProvider.expenses);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E3A8A),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: const Text('Auto-detected recurring bills from SMS.'),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.amberAccent),
                            SizedBox(width: 4),
                            Text(
                              'Auto-Detect',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  currency.format(monthlyTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'Total Monthly Recurring Commitment',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeroSubStat(
                        label: 'Annual Projection',
                        value: currency.format(annualTotal),
                      ),
                      Container(width: 1, height: 24, color: Colors.white24),
                      _buildHeroSubStat(
                        label: 'Active Subscriptions',
                        value: '${subProvider.subscriptions.length} active',
                      ),
                      Container(width: 1, height: 24, color: Colors.white24),
                      _buildHeroSubStat(
                        label: 'Due This Week',
                        value: '${upcomingBills.length} bills',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Due Soon Alert Section (if any)
          if (upcomingBills.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, size: 18, color: Color(0xFFE11D48)),
                const SizedBox(width: 6),
                const Text(
                  'Due in the Next 7 Days',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...upcomingBills.map((sub) {
              final daysLeft = sub.nextBillingDate.difference(now).inDays;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFE11D48), size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF881337)),
                          ),
                          Text(
                            'Renews ${dateFormat.format(sub.nextBillingDate)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9F1239)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(sub.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF881337)),
                        ),
                        Text(
                          daysLeft == 0 ? 'Due Today' : '$daysLeft days left',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // 3. Subscriptions List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tracked Subscriptions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
              Text(
                '${subProvider.subscriptions.length} items',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (subProvider.subscriptions.isEmpty)
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.repeat_on_rounded, size: 36, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Recurring Subscriptions Tracked',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap the wand icon at the top to auto-detect bills from SMS history, or add manual recurring commitments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showAddSubscriptionBottomSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Your First Bill'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...subProvider.subscriptions.map((sub) {
              final daysLeft = sub.nextBillingDate.difference(DateTime.now()).inDays;
              final isDueSoon = daysLeft >= 0 && daysLeft <= 3;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDueSoon ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                    width: isDueSoon ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconForSubscription(sub.name, sub.category),
                          color: const Color(0xFF1E3A8A),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sub.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (sub.isAutoDetected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.auto_awesome, size: 10, color: Colors.amber.shade800),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Auto',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  'Renews ${dateFormat.format(sub.nextBillingDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDueSoon ? Colors.red.shade700 : const Color(0xFF64748B),
                                    fontWeight: isDueSoon ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${daysLeft >= 0 ? '$daysLeft days left' : 'Due'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDueSoon ? Colors.red.shade700 : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(sub.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sub.frequency,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddSubscriptionBottomSheet(context),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Bill', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  static Widget _buildHeroSubStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  static IconData _getIconForSubscription(String name, String category) {
    final lower = '$name $category'.toLowerCase();
    if (lower.contains('netflix') || lower.contains('prime') || lower.contains('hotstar') || lower.contains('spotify') || lower.contains('youtube')) {
      return Icons.movie_filter_rounded;
    }
    if (lower.contains('wifi') || lower.contains('airtel') || lower.contains('jio') || lower.contains('broadband') || lower.contains('electric') || lower.contains('bill')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('sip') || lower.contains('invest') || lower.contains('mutual') || lower.contains('insurance') || lower.contains('lic')) {
      return Icons.trending_up_rounded;
    }
    if (lower.contains('gym') || lower.contains('fitness') || lower.contains('health')) {
      return Icons.fitness_center_rounded;
    }
    return Icons.credit_card_rounded;
  }

  void _showAddSubscriptionBottomSheet(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Utilities & Bills';
    String selectedFrequency = 'Monthly';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    final categoryProvider = context.read<CategoryProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Track Recurring Bill',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                  ),
                  const Text(
                    'Add recurring software, utility, or subscription commitments',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Subscription / Biller Name',
                      hintText: 'e.g. Netflix, Airtel Broadband, Gym',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Billing Amount (₹)',
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedFrequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: ['Monthly', 'Quarterly', 'Yearly', 'Weekly'].map((freq) {
                            return DropdownMenuItem(value: freq, child: Text(freq));
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedFrequency = val ?? 'Monthly'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: categoryProvider.categories.any((c) => c.name == selectedCategory)
                              ? selectedCategory
                              : categoryProvider.categories.first.name,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: categoryProvider.categories.map((c) {
                            return DropdownMenuItem(
                              value: c.name,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedCategory = val ?? selectedCategory),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Next Billing Date', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMMM yyyy').format(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_month_rounded, color: Color(0xFF1E3A8A)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final name = nameController.text.trim();
                        final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                        if (name.isNotEmpty && amount > 0) {
                          context.read<SubscriptionProvider>().addManualSubscription(
                                Subscription(
                                  id: const Uuid().v4(),
                                  name: name,
                                  amount: amount,
                                  category: selectedCategory,
                                  nextBillingDate: selectedDate,
                                  frequency: selectedFrequency,
                                ),
                              );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Save Subscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
