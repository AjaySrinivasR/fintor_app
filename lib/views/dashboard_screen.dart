import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import 'auth/auth_screen.dart';
import 'expenses/csv_import_screen.dart';
import 'expenses/receipt_scanner.dart';
import 'widgets/add_expense_dialog.dart';
import 'widgets/compass_icon.dart';
import 'widgets/edit_expense_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedFilter = 'All'; // 'All', 'Debit', 'Credit', 'SMS', 'CSV'
  int _touchedChartIndex = -1;
  bool _isSmsSyncEnabled = false;

  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadSmsSyncPreference();
  }

  Future<void> _loadSmsSyncPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final enabled = prefs.getBool('sms_sync_enabled') ?? false;
    setState(() {
      _isSmsSyncEnabled = enabled;
    });

    if (enabled) {
      context.read<ExpenseProvider>().initializeSmsListener();
    }
  }

  Future<void> _toggleSmsSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_sync_enabled', value);

    if (!mounted) return;
    setState(() {
      _isSmsSyncEnabled = value;
    });

    const platform = MethodChannel('com.fintor.app/sms');
    await platform.invokeMethod('setSmsSyncEnabled', {'enabled': value});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final selectedMonth = provider.selectedMonth;

    // Filter transactions by selected month & year
    final monthExpenses = provider.selectedMonthExpenses;

    // Filter by transaction type / source
    final filteredExpenses = monthExpenses.where((e) {
      if (_selectedFilter == 'Debit') return e.type == TransactionType.debit;
      if (_selectedFilter == 'Credit') return e.type == TransactionType.credit;
      if (_selectedFilter == 'SMS') return e.source == SourceType.sms;
      if (_selectedFilter == 'CSV') return e.source == SourceType.csv;
      return true;
    }).toList();

    // Compute month-specific metrics
    final monthlyDebit = monthExpenses
        .where((e) => e.type == TransactionType.debit)
        .fold(0.0, (sum, item) => sum + item.amount);

    final monthlyCredit = monthExpenses
        .where((e) => e.type == TransactionType.credit)
        .fold(0.0, (sum, item) => sum + item.amount);

    final netSavings = monthlyCredit - monthlyDebit;
    final savingsRate = monthlyCredit > 0
        ? ((netSavings / monthlyCredit) * 100).clamp(-100.0, 100.0)
        : 0.0;

    // Compute category breakdown for the selected month
    final Map<String, double> categoryBreakdown = {};
    for (var e in monthExpenses.where((e) => e.type == TransactionType.debit)) {
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0.0) + e.amount;
    }

    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const CompassIcon(color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Fintor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSmsSyncEnabled
                  ? Icons.sync_rounded
                  : Icons.sync_disabled_rounded,
              color: _isSmsSyncEnabled
                  ? const Color(0xFF059669)
                  : const Color(0xFF94A3B8),
            ),
            tooltip: _isSmsSyncEnabled
                ? 'Background SMS Sync Active'
                : 'Enable Background SMS Sync',
            onPressed: () => _toggleSmsSync(!_isSmsSyncEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined,
                color: Color(0xFF1E3A8A)),
            tooltip: 'Scan Receipt OCR',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined,
                color: Color(0xFF334155)),
            tooltip: 'Import Bank CSV',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CsvImportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFF334155)),
            tooltip: 'Export Statement',
            onPressed: () => _showExportSheet(
                context, monthExpenses, monthlyDebit, monthlyCredit),
          ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            tooltip: 'Log Out',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1E3A8A),
        backgroundColor: Colors.white,
        onRefresh: () async {
          await provider.loadLocalExpenses();
          await provider.syncPendingExpenses();
          await provider.drainOfflineSms();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // 1. Month Selector Bar
            _buildMonthSelector(provider, isCurrentMonth),
            const SizedBox(height: 16),

            // 2. High-Level Hero Cash Flow & Net Savings Card
            _buildCashFlowHero(
              monthlyDebit: monthlyDebit,
              monthlyCredit: monthlyCredit,
              netSavings: netSavings,
              savingsRate: savingsRate,
              budget: provider.monthlyBudget,
            ),
            const SizedBox(height: 14),

            // 3. Overall Monthly Budget Progress Bar
            _buildBudgetProgressBar(
              spent: monthlyDebit,
              budget: provider.monthlyBudget,
              onEditBudget: () => _showEditBudgetDialog(context, provider),
            ),
            const SizedBox(height: 20),

            // 4. Category Spending Distribution Chart (if debit expenses exist)
            if (categoryBreakdown.isNotEmpty) ...[
              _buildSectionHeader('Spending Distribution'),
              const SizedBox(height: 10),
              _CategoryChartCard(
                breakdown: categoryBreakdown,
                totalSpent: monthlyDebit,
                touchedIndex: _touchedChartIndex,
                onChartTouch: (index) =>
                    setState(() => _touchedChartIndex = index),
                formatter: currencyFormatter,
              ),
              const SizedBox(height: 20),
            ],

            // 5. Transaction Ledger & Filter Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                    'Transactions (${filteredExpenses.length})'),
                Text(
                  currencyFormatter.format(monthlyDebit),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Filter Chips Carousel
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('All (${monthExpenses.length})', 'All'),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    'Expenses (${monthExpenses.where((e) => e.type == TransactionType.debit).length})',
                    'Debit',
                    activeColor: Colors.red.shade600,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    'Income (${monthExpenses.where((e) => e.type == TransactionType.credit).length})',
                    'Credit',
                    activeColor: const Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    'SMS Auto (${monthExpenses.where((e) => e.source == SourceType.sms).length})',
                    'SMS',
                    icon: Icons.sms_outlined,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    'CSV (${monthExpenses.where((e) => e.source == SourceType.csv).length})',
                    'CSV',
                    icon: Icons.table_chart_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 6. Transaction Ledger Cards
            if (filteredExpenses.isEmpty)
              _buildEmptyState()
            else
              ...filteredExpenses.map((item) {
                return _TransactionListTile(
                  expense: item,
                  formatter: currencyFormatter,
                  onDelete: () => provider.deleteExpense(item.id),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const AddExpenseDialog(),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Spend',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildMonthSelector(ExpenseProvider provider, bool isCurrentMonth) {
    final dateFormat = DateFormat('MMMM yyyy');
    final selectedMonth = provider.selectedMonth;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded,
                color: Color(0xFF1E3A8A)),
            onPressed: () => provider.previousMonth(),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 16, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(selectedMonth),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (!isCurrentMonth) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => provider.resetToCurrentMonth(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF1E3A8A)),
            onPressed: () => provider.nextMonth(),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowHero({
    required double monthlyDebit,
    required double monthlyCredit,
    required double netSavings,
    required double savingsRate,
    required double budget,
  }) {
    final isPositive = netSavings >= 0;
    final totalFlow = monthlyCredit + monthlyDebit;
    final double incomeRatio =
        totalFlow > 0 ? (monthlyCredit / totalFlow).clamp(0.05, 0.95) : 0.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Status Pill
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.swap_vert_rounded,
                        size: 15,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Net Cash Flow',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPositive
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFECDD3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 13,
                        color: isPositive
                            ? const Color(0xFF059669)
                            : const Color(0xFFE11D48),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        monthlyCredit > 0
                            ? (isPositive
                                ? '+${savingsRate.toStringAsFixed(0)}% saved'
                                : '${savingsRate.abs().toStringAsFixed(0)}% deficit')
                            : (isPositive ? 'Surplus' : 'Deficit'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPositive
                              ? const Color(0xFF059669)
                              : const Color(0xFFE11D48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. Main Hero Net Amount
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              (isPositive && netSavings > 0 ? '+' : '') +
                  currencyFormatter.format(netSavings),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.8,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Proportional Cash Flow Bar (if activity exists)
          if (totalFlow > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 4,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (incomeRatio * 100).round().clamp(1, 99),
                        child: Container(color: const Color(0xFF059669)),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: ((1 - incomeRatio) * 100).round().clamp(1, 99),
                        child: Container(color: const Color(0xFFE11D48)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 14),

          // 4. Inflow & Outflow Docked Tray
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(21)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                // Inflow Column
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.south_west_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Inflow',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              currencyFormatter.format(monthlyCredit),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 14),

                // Outflow Column
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.north_east_rounded,
                          size: 14,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Outflow',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              currencyFormatter.format(monthlyDebit),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgressBar({
    required double spent,
    required double budget,
    required VoidCallback onEditBudget,
  }) {
    final ratio = (spent / (budget > 0 ? budget : 1)).clamp(0.0, 1.0);
    final isExceeded = spent > budget && budget > 0;

    Color barColor = const Color(0xFF1E3A8A);
    if (ratio > 0.8) barColor = Colors.orange.shade700;
    if (isExceeded) barColor = Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExceeded ? Colors.red.shade200 : const Color(0xFFE2E8F0),
          width: isExceeded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pie_chart_outline_rounded,
                        size: 16, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Monthly Limit',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A))),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onEditBudget,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          size: 13, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              Text(
                '${currencyFormatter.format(spent)} / ${currencyFormatter.format(budget)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isExceeded
                      ? Colors.red.shade700
                      : const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: barColor,
              backgroundColor: const Color(0xFFF1F5F9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildFilterPill(String label, String value,
      {Color? activeColor, IconData? icon}) {
    final isSelected = _selectedFilter == value;
    final color = activeColor ?? const Color(0xFF1E3A8A);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: isSelected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 36, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            const Text(
              'No transactions found',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              'Add an expense manually, scan a receipt, or wait for SMS sync.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context, ExpenseProvider provider) {
    final controller =
        TextEditingController(text: provider.monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Set Monthly Budget Limit',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total Monthly Limit',
            prefixText: '₹ ',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final budget = double.tryParse(controller.text.trim()) ??
                  provider.monthlyBudget;
              if (budget > 0) {
                provider.setBudget(budget);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Fintor? Your synced data is safely backed up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await AuthService.clearToken();
      if (context.mounted) {
        context.read<ExpenseProvider>().clearAuthToken();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showExportSheet(BuildContext context, List<Expense> expenses,
      double spent, double income) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
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
                'Export Financial Statement',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0F172A)),
              ),
              const Text(
                'Generate formatted transaction reports for taxes or personal backup',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.red, size: 22),
                ),
                title: const Text('Export as PDF Document',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Formal statement with category breakdowns & summaries',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  ExportService.exportPdfStatement(
                    expenses: expenses,
                    totalSpent: spent,
                    totalIncome: income,
                  );
                },
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_rounded,
                      color: Colors.green, size: 22),
                ),
                title: const Text('Export as CSV Spreadsheet',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text(
                    'Compatible with Microsoft Excel, Google Sheets, & Apple Numbers',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  ExportService.exportCsvStatement(expenses);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- REUSABLE COMPONENTS ---

class _CategoryChartCard extends StatelessWidget {
  final Map<String, double> breakdown;
  final double totalSpent;
  final int touchedIndex;
  final Function(int) onChartTouch;
  final NumberFormat formatter;

  const _CategoryChartCard({
    required this.breakdown,
    required this.totalSpent,
    required this.touchedIndex,
    required this.onChartTouch,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final categories = breakdown.keys.toList();
    final chartColors = [
      const Color(0xFF2563EB),
      const Color(0xFFF97316),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF0D9488),
      const Color(0xFF64748B),
    ];

    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      onChartTouch(-1);
                      return;
                    }
                    onChartTouch(
                        pieTouchResponse.touchedSection!.touchedSectionIndex);
                  },
                ),
                sectionsSpace: 3,
                centerSpaceRadius: 46,
                sections: List.generate(categories.length, (i) {
                  final isTouched = i == touchedIndex;
                  final category = categories[i];
                  final amount = breakdown[category]!;
                  final color = chartColors[i % chartColors.length];

                  return PieChartSectionData(
                    color: color,
                    value: amount,
                    title: isTouched
                        ? '${((amount / (totalSpent > 0 ? totalSpent : 1)) * 100).toStringAsFixed(0)}%'
                        : '',
                    radius: isTouched ? 34.0 : 28.0,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Legends Grid
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(categories.length, (i) {
              final category = categories[i];
              final amount = breakdown[category]!;
              final color = chartColors[i % chartColors.length];

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(
                    '$category (${formatter.format(amount)})',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569)),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TransactionListTile extends StatelessWidget {
  final Expense expense;
  final NumberFormat formatter;
  final VoidCallback onDelete;

  const _TransactionListTile({
    required this.expense,
    required this.formatter,
    required this.onDelete,
  });

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Transaction?'),
        content: Text(
          'Are you sure you want to delete "${expense.title}" for ${formatter.format(expense.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = expense.type == TransactionType.debit;
    final dateFormat = DateFormat('dd MMM, hh:mm a');

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showDialog(
              context: context,
              builder: (_) => EditExpenseDialog(expense: expense),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          isDebit ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      expense.source == SourceType.sms
                          ? Icons.sms_outlined
                          : expense.source == SourceType.csv
                              ? Icons.description_outlined
                              : Icons.edit_outlined,
                      color:
                          isDebit ? Colors.red.shade600 : Colors.green.shade700,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                expense.category,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (expense.accountLast4 != null &&
                                expense.accountLast4!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '*${expense.accountLast4}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              dateFormat.format(expense.date),
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isDebit ? '-' : '+'} ${formatter.format(expense.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDebit
                          ? Colors.red.shade700
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
