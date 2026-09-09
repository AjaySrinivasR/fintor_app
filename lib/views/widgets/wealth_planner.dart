// mobile/lib/views/dashboard/widgets/wealth_planner_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/forecasting_engine.dart';

class WealthPlannerCard extends StatelessWidget {
  final WealthPlanRecommendation plan;
  const WealthPlannerCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Color(0xFF1E3A8A), size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Guaranteed Wealth & Emergency Hub',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.strategyDescription,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF334155), height: 1.3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AllocationBox(
                    label: 'Guaranteed FD / RD',
                    amount: currency.format(plan.guaranteedFdAllocation),
                    subtitle: 'Principal-Safe Yield',
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AllocationBox(
                    label: 'Debt / Index SIP',
                    amount: currency.format(plan.sipAllocation),
                    subtitle: 'Non-speculative growth',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationBox extends StatelessWidget {
  final String label;
  final String amount;
  final String subtitle;
  final MaterialColor color;

  const _AllocationBox({
    required this.label,
    required this.amount,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color.shade800)),
          const SizedBox(height: 4),
          Text(amount,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color.shade900)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color.shade700)),
        ],
      ),
    );
  }
}
