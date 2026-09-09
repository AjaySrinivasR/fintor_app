import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';

class EditExpenseSheet extends StatefulWidget {
  final Expense expense;

  const EditExpenseSheet({super.key, required this.expense});

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late TransactionType _selectedType;
  late DateTime _selectedDate;

  final List<String> _categories = [
    'Food & Dining',
    'Groceries',
    'Shopping',
    'Travel & Fuel',
    'Utilities',
    'Entertainment',
    'Health',
    'General',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _amountController =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(0));
    _selectedCategory = _categories.contains(widget.expense.category)
        ? widget.expense.category
        : 'General';
    _selectedType = widget.expense.type;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Transaction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Type Toggle (Debit / Credit)
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.debit,
                label: Text('Expense (Debit)'),
                icon: Icon(Icons.arrow_outward_rounded, color: Colors.red),
              ),
              ButtonSegment(
                value: TransactionType.credit,
                label: Text('Income (Credit)'),
                icon: Icon(Icons.south_west_rounded, color: Colors.green),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (set) =>
                setState(() => _selectedType = set.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Merchant or Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: _categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategory = val);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
            trailing: TextButton(
              onPressed: _pickDate,
              child: const Text('Change Date'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text.trim());
                if (amount == null || amount <= 0) return;

                final updated = Expense(
                  id: widget.expense.id,
                  title: _titleController.text.trim().isEmpty
                      ? widget.expense.title
                      : _titleController.text.trim(),
                  amount: amount,
                  category: _selectedCategory,
                  type: _selectedType,
                  source: widget.expense.source,
                  accountLast4: widget.expense.accountLast4,
                  date: _selectedDate,
                );

                context.read<ExpenseProvider>().updateExpense(updated);
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
