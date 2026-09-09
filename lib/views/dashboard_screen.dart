import 'package:fintor/core/sms_parser.dart';
import 'package:fintor/views/expenses/receipt_scanner.dart';
import 'package:fintor/views/widgets/edit_expense_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import 'auth/auth_screen.dart';
import 'widgets/add_expense_dialog.dart';
import 'expenses/csv_import_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedMonth = DateTime.now();
  String _selectedFilter = 'All'; // 'All', 'Debit', 'Credit', 'SMS'
  int _touchedChartIndex = -1;
  bool _isSmsSyncEnabled = false;

  final currencyFormatter =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadSmsSyncPreference();
  }

  // Inside _DashboardScreenState in lib/views/dashboard_screen.dart:
  Future<void> _loadSmsSyncPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final enabled = prefs.getBool('sms_sync_enabled') ?? false;
    setState(() {
      _isSmsSyncEnabled = enabled;
    });

    // If enabled previously, activate the foreground receiver listener
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

    // Notify native Android whether to process incoming SMS in the background
    const platform = MethodChannel('com.fintor.app/sms');
    await platform.invokeMethod('setSmsSyncEnabled', {'enabled': value});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    // Filter transactions by selected month & year
    final monthExpenses = provider.expenses.where((e) {
      return e.date.year == _selectedMonth.year &&
          e.date.month == _selectedMonth.month;
    }).toList();

    // Filter by transaction type
    final filteredExpenses = monthExpenses.where((e) {
      if (_selectedFilter == 'Debit') return e.type == TransactionType.debit;
      if (_selectedFilter == 'Credit') return e.type == TransactionType.credit;
      if (_selectedFilter == 'SMS') return e.source == SourceType.sms;
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

    // Compute category breakdown for the selected month
    final Map<String, double> categoryBreakdown = {};
    for (var e in monthExpenses.where((e) => e.type == TransactionType.debit)) {
      categoryBreakdown[e.category] =
          (categoryBreakdown[e.category] ?? 0.0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Color(0xFF1E3A8A), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Fintor',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // In AppBar actions of lib/views/dashboard_screen.dart:
          IconButton(
            icon: Icon(
              _isSmsSyncEnabled
                  ? Icons.sync_rounded
                  : Icons.sync_disabled_rounded,
              color: _isSmsSyncEnabled ? Colors.green.shade600 : Colors.grey,
            ),
            tooltip: _isSmsSyncEnabled
                ? 'Background SMS Sync Active'
                : 'Enable Background SMS Sync',
            onPressed: () => _toggleSmsSync(!_isSmsSyncEnabled),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Bank CSV',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CsvImportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export Statement',
            onPressed: () => _showExportSheet(
                context, monthExpenses, monthlyDebit, monthlyCredit),
          ),
          // Inside DashboardScreen AppBar actions:
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Receipt OCR',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
            ),
          ),
          // Test button inside Dashboard actions:
          // IconButton(
          //   icon: const Icon(Icons.bug_report),
          //   onPressed: () {
          //     const testSms =
          //         "Your A/c No.XXXX is credited with Rs.500.00 on 06-09-2026 07:50 PM and A/c linked to xxxx@okaxis is debited (UPI Ref No. xxxxxxx).Current AVBL bal is Rs.xxxxxxx - TMB";
          //     final exp = SmsExpenseParser.parse("TMBLTD", testSms);
          //     if (exp != null) {
          //       context.read<ExpenseProvider>().addExpense(exp);
          //     }
          //   },
          // ),
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            tooltip: 'Log Out',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadLocalExpenses();
          await provider.syncPendingExpenses();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Month Selector Bar
              _buildMonthSelector(),
              const SizedBox(height: 16),

              // 2. High-Level Metrics (Stats Cards)
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'Total Spent',
                      value: currencyFormatter.format(monthlyDebit),
                      icon: Icons.arrow_outward_rounded,
                      color: Colors.red.shade600,
                      bgColor: Colors.red.shade50,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Total Income',
                      value: currencyFormatter.format(monthlyCredit),
                      icon: Icons.south_west_rounded,
                      color: Colors.green.shade700,
                      bgColor: Colors.green.shade50,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      title: 'Net Savings',
                      value: currencyFormatter.format(netSavings),
                      icon: Icons.savings_outlined,
                      color: netSavings >= 0
                          ? const Color(0xFF1E3A8A)
                          : Colors.orange.shade800,
                      bgColor: const Color(0xFFEFF6FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Overall Monthly Limit Progress Bar
              _BudgetProgressBar(
                spent: monthlyDebit,
                budget: provider.monthlyBudget,
                formatter: currencyFormatter,
                onEditBudget: () => _showEditBudgetDialog(context, provider),
              ),
              const SizedBox(height: 20),

              // 4. Category Spending Distribution Chart
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
                  _buildFilterDropdown(),
                ],
              ),
              const SizedBox(height: 8),

              // 6. Transaction List / Table Replacement
              if (filteredExpenses.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredExpenses.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final item = filteredExpenses[index];
                    return _TransactionListTile(
                      expense: item,
                      formatter: currencyFormatter,
                      onDelete: () => provider.deleteExpense(item.id),
                    );
                  },
                ),
              const SizedBox(
                  height:
                      140), // Padding for FloatingActionButton & Floating Nav Bar
            ],
          ),
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Spend',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // --- SUB-WIDGET BUILDERS ---

  Widget _buildMonthSelector() {
    final dateFormat = DateFormat('MMMM yyyy');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () {
                setState(() {
                  _selectedMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                });
              },
            ),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(_selectedMonth),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () {
                setState(() {
                  _selectedMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isDense: true,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All Types')),
            DropdownMenuItem(value: 'Debit', child: Text('Expenses Only')),
            DropdownMenuItem(value: 'Credit', child: Text('Income Only')),
            DropdownMenuItem(value: 'SMS', child: Text('Auto SMS Only')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedFilter = val);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'No transactions found for this period',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF334155)),
              ),
              const SizedBox(height: 4),
              Text(
                'Add an expense manually, import CSV, or wait for SMS sync.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
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
        title: const Text('Set Monthly Budget Limit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Budget (₹)',
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of Fintor? You will need to log in again to sync your transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Export Financial Statement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF2F2),
                  child: Icon(Icons.picture_as_pdf, color: Colors.red),
                ),
                title: const Text('Export as PDF Document',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Formal ledger with summaries & category split'),
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
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF0FDF4),
                  child: Icon(Icons.table_chart, color: Colors.green),
                ),
                title: const Text('Export as CSV Spreadsheet',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Raw ledger compatible with Excel / Google Sheets'),
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double spent;
  final double budget;
  final NumberFormat formatter;
  final VoidCallback onEditBudget;

  const _BudgetProgressBar({
    required this.spent,
    required this.budget,
    required this.formatter,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (spent / (budget > 0 ? budget : 1)).clamp(0.0, 1.0);
    final isExceeded = spent > budget;

    Color barColor = const Color(0xFF1E3A8A);
    if (ratio > 0.8) barColor = Colors.orange.shade700;
    if (isExceeded) barColor = Colors.red.shade600;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isExceeded ? Colors.red.shade200 : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Monthly Limit',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onEditBudget,
                      child: Icon(Icons.edit,
                          size: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                Text(
                  '${formatter.format(spent)} / ${formatter.format(budget)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isExceeded
                        ? Colors.red.shade700
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      ),
    );
  }
}

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
      const Color(0xFF64748B),
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                          ? '${((amount / totalSpent) * 100).toStringAsFixed(0)}%'
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
            const SizedBox(height: 12),
            // Legends Grid
            Wrap(
              spacing: 12,
              runSpacing: 6,
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
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('$category (${formatter.format(amount)})',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF475569))),
                  ],
                );
              }),
            ),
          ],
        ),
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
        color: Colors.red.shade600,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (_) => EditExpenseDialog(expense: expense),
          ),
          onLongPress: () async {
            final shouldDelete = await _confirmDelete(context);
            if (shouldDelete == true) onDelete();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      isDebit ? Colors.red.shade50 : Colors.green.shade50,
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              expense.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (expense.accountLast4 != null) ...[
                            const Text(' • ',
                                style: TextStyle(color: Color(0xFF94A3B8))),
                            Text(
                              'A/c *${expense.accountLast4}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                          const Text(' • ',
                              style: TextStyle(color: Color(0xFF94A3B8))),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color:
                        isDebit ? Colors.red.shade700 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// class _TransactionListTile extends StatelessWidget {
//   final Expense expense;
//   final NumberFormat formatter;
//   final VoidCallback onDelete;

//   const _TransactionListTile({
//     required this.expense,
//     required this.formatter,
//     required this.onDelete,
//   });

//   void _confirmDelete(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Delete Transaction?'),
//         content: Text(
//             'Are you sure you want to delete "${expense.title}" for ${formatter.format(expense.amount)}?'),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
//           FilledButton(
//             style: FilledButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () {
//               Navigator.pop(ctx);
//               onDelete();
//             },
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDebit = expense.type == TransactionType.debit;
//     final dateFormat = DateFormat('dd MMM, hh:mm a');

//     return InkWell(
//       onTap: () => showDialog(
//         context: context,
//         builder: (_) => EditExpenseDialog(expense: expense),
//       ),
//       onLongPress: () => _confirmDelete(context),
//       child: Container(
//         color: Colors.white,
//         child: ListTile(
//           contentPadding:
//               const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
//           leading: CircleAvatar(
//             radius: 20,
//             backgroundColor:
//                 isDebit ? Colors.red.shade50 : Colors.green.shade50,
//             child: Icon(
//               expense.source == SourceType.sms
//                   ? Icons.sms_outlined
//                   : expense.source == SourceType.csv
//                       ? Icons.description_outlined
//                       : Icons.edit_outlined,
//               color: isDebit ? Colors.red.shade600 : Colors.green.shade700,
//               size: 18,
//             ),
//           ),
//           title: Text(
//             expense.title,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//                 color: Color(0xFF0F172A)),
//           ),
//           subtitle: Row(
//             children: [
//               Flexible(
//                 child: Text(
//                   expense.category,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                       fontSize: 11,
//                       color: Color(0xFF64748B),
//                       fontWeight: FontWeight.w500),
//                 ),
//               ),
//               if (expense.accountLast4 != null) ...[
//                 const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
//                 Text('A/c *${expense.accountLast4}',
//                     style: const TextStyle(
//                         fontSize: 11, color: Color(0xFF64748B))),
//               ],
//               const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
//               Text(dateFormat.format(expense.date),
//                   style:
//                       const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
//             ],
//           ),
//           trailing: Text(
//             '${isDebit ? '-' : '+'} ${formatter.format(expense.amount)}',
//             style: TextStyle(
//               fontWeight: FontWeight.w700,
//               fontSize: 14,
//               color: isDebit ? Colors.red.shade700 : Colors.green.shade700,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
