import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';

class EditExpenseDialog extends StatefulWidget {
  final Expense expense;
  const EditExpenseDialog({super.key, required this.expense});

  @override
  State<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<EditExpenseDialog> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late String _selectedCategory;
  late TransactionType _selectedType;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _amountController =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _selectedCategory = widget.expense.category;
    _selectedType = widget.expense.type;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context
        .watch<CategoryProvider>()
        .categories
        .map((c) => c.name)
        .toList();
    if (!categories.contains(_selectedCategory)) {
      categories.add(_selectedCategory);
    }

    return AlertDialog(
      title: const Text('Edit Transaction',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Title / Merchant',
                  prefixIcon: Icon(Icons.storefront)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val!),
              decoration: const InputDecoration(
                  labelText: 'Category', prefixIcon: Icon(Icons.category)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.debit, label: Text('Expense')),
                ButtonSegment(
                    value: TransactionType.credit, label: Text('Income')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) =>
                  setState(() => _selectedType = set.first),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate)),
              trailing: TextButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null && mounted) {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDate),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  }
                },
                child: const Text('Change'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            final amount =
                double.tryParse(_amountController.text.trim()) ?? 0.0;

            if (title.isNotEmpty && amount > 0) {
              final updated = Expense(
                id: widget.expense.id,
                title: title,
                amount: amount,
                category: _selectedCategory,
                type: _selectedType,
                source: widget.expense.source,
                accountLast4: widget.expense.accountLast4,
                date: _selectedDate,
              );

              context.read<ExpenseProvider>().editExpense(updated);
              Navigator.pop(context);
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
