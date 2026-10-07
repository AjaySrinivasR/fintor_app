import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/expense_model.dart';
import '../../models/category_model.dart';

class SpendForecastingGraphCard extends StatefulWidget {
  final List<Expense> expenses;
  final double totalBudget;
  final Map<String, double> categoryBudgets;
  final List<CategoryItem> categories;
  final DateTime? selectedMonth;

  const SpendForecastingGraphCard({
    super.key,
    required this.expenses,
    required this.totalBudget,
    required this.categoryBudgets,
    required this.categories,
    this.selectedMonth,
  });

  @override
  State<SpendForecastingGraphCard> createState() => _SpendForecastingGraphCardState();
}

class _SpendForecastingGraphCardState extends State<SpendForecastingGraphCard> {
  String _selectedCategory = 'All'; // 'All' or specific category name

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final selectedMonth = widget.selectedMonth ?? DateTime.now();
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isPastMonth =
        selectedMonth.isBefore(DateTime(now.year, now.month));
    final daysInMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final currentDay = isPastMonth
        ? daysInMonth
        : (isCurrentMonth ? now.day.clamp(1, daysInMonth) : 1);
    final daysRemaining = isPastMonth
        ? 0
        : (isCurrentMonth ? max(1, daysInMonth - currentDay) : daysInMonth);

    // 1. Filter expenses for the selected month & selected category
    final monthDebitExpenses = widget.expenses.where((e) {
      final isMatchingMonth =
          e.date.year == selectedMonth.year && e.date.month == selectedMonth.month;
      final isDebit = e.type == TransactionType.debit;
      if (!isMatchingMonth || !isDebit) return false;
      if (_selectedCategory == 'All') return true;
      return e.category.toLowerCase() == _selectedCategory.toLowerCase();
    }).toList();

    // 2. Determine Budget limit for the selected scope
    final double budgetLimit = _selectedCategory == 'All'
        ? (widget.totalBudget > 0
            ? widget.totalBudget
            : widget.categoryBudgets.values.fold(0.0, (s, b) => s + b))
        : (widget.categoryBudgets[_selectedCategory] ?? 0.0);

    // 3. Compute day-by-day cumulative actual spend up to currentDay
    final Map<int, double> dailySpendMap = {};
    for (final exp in monthDebitExpenses) {
      final day = exp.date.day.clamp(1, daysInMonth);
      dailySpendMap[day] = (dailySpendMap[day] ?? 0.0) + exp.amount;
    }

    double runningTotal = 0.0;
    final List<FlSpot> actualSpots = [];
    actualSpots.add(const FlSpot(0, 0)); // Start from Day 0 at 0

    for (int d = 1; d <= currentDay; d++) {
      runningTotal += (dailySpendMap[d] ?? 0.0);
      actualSpots.add(FlSpot(d.toDouble(), runningTotal));
    }

    final double currentSpent = runningTotal;
    final double dailyBurnRate = currentDay > 0 ? (currentSpent / currentDay) : 0.0;
    final double projectedMonthEnd = isPastMonth
        ? currentSpent
        : (currentDay >= 4
            ? currentSpent + (dailyBurnRate * daysRemaining)
            : (budgetLimit > 0 ? budgetLimit : currentSpent));

    final double remainingBudget = max(0.0, budgetLimit - currentSpent);
    final double safeDailyPace = remainingBudget / daysRemaining;
    final bool isOverrun = budgetLimit > 0 && projectedMonthEnd > budgetLimit;
    final double overrunPct = budgetLimit > 0 && isOverrun
        ? ((projectedMonthEnd - budgetLimit) / budgetLimit) * 100
        : 0.0;

    // 4. Compute Forecast Extrapolation Line (from currentDay to daysInMonth)
    final List<FlSpot> forecastSpots = [];
    forecastSpots.add(FlSpot(currentDay.toDouble(), currentSpent));
    for (int d = currentDay + 1; d <= daysInMonth; d++) {
      final extrapolated = currentSpent + (dailyBurnRate * (d - currentDay));
      forecastSpots.add(FlSpot(d.toDouble(), extrapolated));
    }

    // 5. Compute Safe Budget Target Line (from 0 to daysInMonth)
    final List<FlSpot> budgetPaceSpots = [];
    if (budgetLimit > 0) {
      budgetPaceSpots.add(const FlSpot(0, 0));
      budgetPaceSpots.add(FlSpot(daysInMonth.toDouble(), budgetLimit));
    }

    // Determine max Y for graph scaling
    final double maxDataValue = [
      currentSpent,
      projectedMonthEnd,
      budgetLimit,
      5000.0,
    ].reduce(max);
    final double graphMaxY = (maxDataValue * 1.18).ceilToDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.03),
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
            // Header Row
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
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          color: Color(0xFF1E3A8A),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spend Trajectory & Forecast',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isPastMonth
                                  ? 'Final ledger • ${DateFormat('MMM yyyy').format(selectedMonth)}'
                                  : 'Extrapolated for ${DateFormat('MMM yyyy').format(selectedMonth)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isOverrun ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOverrun ? const Color(0xFFFECDD3) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverrun ? Icons.trending_up_rounded : Icons.check_circle_outline_rounded,
                        size: 12,
                        color: isOverrun ? const Color(0xFFE11D48) : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOverrun
                            ? '+${overrunPct.toStringAsFixed(0)}% Overrun'
                            : 'Pace Healthy',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOverrun ? const Color(0xFFE11D48) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryPill('All', 'All'),
                  ...widget.categories.map((cat) => _buildCategoryPill(cat.name, cat.name)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Metric Summary Dashboard Grid
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricColumn(
                      label: 'Projected Total',
                      value: currency.format(projectedMonthEnd),
                      sublabel: 'Day $daysInMonth est.',
                      valueColor: isOverrun ? const Color(0xFFE11D48) : const Color(0xFF0F172A),
                    ),
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricColumn(
                      label: 'Burn Velocity',
                      value: '${currency.format(dailyBurnRate)}/d',
                      sublabel: 'Current pace',
                      valueColor: const Color(0xFF1E3A8A),
                    ),
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricColumn(
                      label: 'Safe Daily Pace',
                      value: budgetLimit > 0 ? '${currency.format(safeDailyPace)}/d' : 'No Limit',
                      sublabel: '$daysRemaining days left',
                      valueColor: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Interactive Line Chart
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: graphMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: graphMaxY > 0 ? (graphMaxY / 4) : 1000,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xFFF1F5F9),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          if (value >= 100000) {
                            return Text(
                              '₹${(value / 100000).toStringAsFixed(1)}L',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            );
                          } else if (value >= 1000) {
                            return Text(
                              '₹${(value / 1000).toStringAsFixed(0)}k',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            );
                          }
                          return Text(
                            '₹${value.toInt()}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (day == 0 || day > daysInMonth) return const SizedBox.shrink();
                          return Text(
                            'D$day',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF0F172A),
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isActual = spot.barIndex == 0;
                          final isForecast = spot.barIndex == 1;
                          String prefix = isActual ? 'Actual: ' : (isForecast ? 'Forecast: ' : 'Budget Target: ');
                          return LineTooltipItem(
                            'Day ${spot.x.toInt()}\n$prefix${currency.format(spot.y)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    // 1. Actual Cumulative Spend (Solid Navy/Blue)
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF1E3A8A),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        checkToShowDot: (spot, barData) => spot == actualSpots.last,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF1E3A8A),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E3A8A).withOpacity(0.18),
                            const Color(0xFF1E3A8A).withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // 2. Projected Extrapolation Line (Dashed Rose / Teal)
                    if (forecastSpots.length > 1)
                      LineChartBarData(
                        spots: forecastSpots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        color: isOverrun ? const Color(0xFFE11D48) : const Color(0xFF0D9488),
                        barWidth: 2.5,
                        dashArray: [5, 4],
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      ),

                    // 3. Target Budget Pace Line (Dotted Slate)
                    if (budgetPaceSpots.isNotEmpty)
                      LineChartBarData(
                        spots: budgetPaceSpots,
                        isCurved: false,
                        color: const Color(0xFF94A3B8),
                        barWidth: 1.5,
                        dashArray: [3, 4],
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Legend indicators
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildLegendItem(
                  color: const Color(0xFF1E3A8A),
                  label: 'Actual (D1 - $currentDay)',
                  isDashed: false,
                ),
                _buildLegendItem(
                  color: isOverrun ? const Color(0xFFE11D48) : const Color(0xFF0D9488),
                  label: 'Projected Pace',
                  isDashed: true,
                ),
                if (budgetLimit > 0)
                  _buildLegendItem(
                    color: const Color(0xFF94A3B8),
                    label: 'Target Benchmark',
                    isDotted: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label, String value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required String sublabel,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 1),
        Text(
          sublabel,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isDashed = false,
    bool isDotted = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
