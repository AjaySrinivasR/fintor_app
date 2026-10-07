import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/forecasting_engine.dart';

class WealthPlannerCard extends StatelessWidget {
  final WealthPlanRecommendation plan;
  const WealthPlannerCard({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final bool isHealthyRunway = plan.emergencyRunwayMonths >= 3.0;
    final double totalInflow = plan.netInflow > 0 ? plan.netInflow : 1.0;
    final double needsPct = (plan.needsTotal / totalInflow).clamp(0.0, 1.0);
    final double wantsPct = (plan.wantsTotal / totalInflow).clamp(0.0, 1.0);
    final double surplusPct = (plan.surplus / totalInflow).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Runway Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF1E3A8A), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capital Runway & Plan',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '50/30/20 Wealth Strategy',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHealthyRunway ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHealthyRunway ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHealthyRunway ? Icons.verified_rounded : Icons.shield_outlined,
                        size: 13,
                        color: isHealthyRunway ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${plan.emergencyRunwayMonths.toStringAsFixed(1)} mo runway',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isHealthyRunway ? const Color(0xFF059669) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Macro 50/30/20 Visual Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inflow Partition (50 / 30 / 20)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      Text(
                        'Inflow: ${currency.format(plan.netInflow)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (needsPct > 0)
                            Expanded(
                              flex: (needsPct * 100).round().clamp(1, 100),
                              child: Container(color: const Color(0xFF3B82F6)),
                            ),
                          if (wantsPct > 0)
                            Expanded(
                              flex: (wantsPct * 100).round().clamp(1, 100),
                              child: Container(color: const Color(0xFFEC4899)),
                            ),
                          if (surplusPct > 0)
                            Expanded(
                              flex: (surplusPct * 100).round().clamp(1, 100),
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildMacroLegend(
                          label: 'Needs',
                          amount: currency.format(plan.needsTotal),
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                      Expanded(
                        child: _buildMacroLegend(
                          label: 'Wants',
                          amount: currency.format(plan.wantsTotal),
                          color: const Color(0xFFEC4899),
                        ),
                      ),
                      Expanded(
                        child: _buildMacroLegend(
                          label: 'Surplus',
                          amount: currency.format(plan.surplus),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // AI Recommendation Text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.strategyDescription,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Allocation Cards
            Row(
              children: [
                Expanded(
                  child: _AllocationBox(
                    label: 'Liquid & FD Buffer',
                    amount: currency.format(plan.guaranteedFdAllocation),
                    subtitle: 'Principal-Protected Yield',
                    icon: Icons.account_balance_rounded,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AllocationBox(
                    label: 'Wealth SIP Growth',
                    amount: currency.format(plan.sipAllocation),
                    subtitle: 'Index & Debt Compounding',
                    icon: Icons.trending_up_rounded,
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

  Widget _buildMacroLegend({required String label, required String amount, required Color color}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                amount,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllocationBox extends StatelessWidget {
  final String label;
  final String amount;
  final String subtitle;
  final IconData icon;
  final MaterialColor color;

  const _AllocationBox({
    required this.label,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: color.shade700),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color.shade900,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 9.5, color: color.shade700),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
