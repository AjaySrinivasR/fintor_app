import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Food & Dining';
  TransactionType _type = TransactionType.debit;

  final categories = [
    'Food & Dining',
    'Travel & Fuel',
    'Shopping',
    'Entertainment',
    'Utilities',
    'General',
    'Income'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Transaction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title / Merchant'),
            ),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => setState(() => _category = val!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.debit, label: Text('Expense')),
                ButtonSegment(
                    value: TransactionType.credit, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
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
              context.read<ExpenseProvider>().addExpense(
                    Expense(
                      id: const Uuid().v4(),
                      title: title,
                      amount: amount,
                      category: _category,
                      type: _type,
                      source: SourceType.manual,
                      date: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
