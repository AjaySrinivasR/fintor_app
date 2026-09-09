// mobile/lib/views/dashboard/widgets/velocity_forecast_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/forecasting_engine.dart';

class VelocityForecastCard extends StatelessWidget {
  final VelocityForecast forecast;
  const VelocityForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: forecast.isOverrunPredicted
              ? Colors.red.shade200
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                forecast.category,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (forecast.isOverrunPredicted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${forecast.overrunPercentage.toStringAsFixed(0)}% Projected',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current: ${currency.format(forecast.currentSpent)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                  Text('Limit: ${currency.format(forecast.budgetLimit)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Paced Limit: ${currency.format(forecast.safeDailySpend)}/day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: forecast.isOverrunPredicted
                          ? Colors.orange.shade800
                          : Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Month End: ~${currency.format(forecast.projectedSpend)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: forecast.isOverrunPredicted
                          ? Colors.red.shade700
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
