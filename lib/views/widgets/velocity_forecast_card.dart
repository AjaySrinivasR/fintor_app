import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/forecasting_engine.dart';

class VelocityForecastCard extends StatelessWidget {
  final VelocityForecast forecast;
  const VelocityForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final ratio = forecast.budgetLimit > 0
        ? (forecast.projectedSpend / forecast.budgetLimit).clamp(0.0, 1.5)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: forecast.isOverrunPredicted
              ? Colors.red.shade200
              : const Color(0xFFE2E8F0),
          width: forecast.isOverrunPredicted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: forecast.isOverrunPredicted
                            ? Colors.red.shade50
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        forecast.isOverrunPredicted
                            ? Icons.trending_up_rounded
                            : Icons.speed_rounded,
                        color: forecast.isOverrunPredicted
                            ? Colors.red.shade700
                            : const Color(0xFF1E3A8A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        forecast.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: forecast.isOverrunPredicted
                      ? Colors.red.shade50
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: forecast.isOverrunPredicted
                        ? Colors.red.shade200
                        : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  forecast.isOverrunPredicted
                      ? '+${forecast.overrunPercentage.toStringAsFixed(0)}% Overrun'
                      : 'On Track',
                  style: TextStyle(
                    color: forecast.isOverrunPredicted
                        ? Colors.red.shade700
                        : const Color(0xFF059669),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pacing Metrics Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Burn Rate',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currency.format(forecast.dailyVelocity)}/d',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: forecast.isOverrunPredicted ? Colors.red.shade700 : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Safe Target',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${currency.format(forecast.safeDailySpend)}/d',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Month-End',
                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.format(forecast.projectedSpend),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: forecast.isOverrunPredicted ? Colors.red.shade700 : const Color(0xFF1E3A8A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Progress line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${currency.format(forecast.currentSpent)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                'Budget: ${currency.format(forecast.budgetLimit)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (ratio / 1.5).clamp(0.0, 1.0),
              minHeight: 6,
              color: forecast.isOverrunPredicted ? Colors.red.shade600 : const Color(0xFF1E3A8A),
              backgroundColor: const Color(0xFFE2E8F0),
            ),
          ),
        ],
      ),
    );
  }
}
