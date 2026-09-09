import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  String? _fileName;
  List<Expense> _previewExpenses = [];
  bool _isProcessing = false;

  Future<void> _pickAndParseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _isProcessing = true;
      _fileName = result.files.single.name;
    });

    final file = File(result.files.single.path!);
    final input = await file.readAsString();
    final fields = const CsvToListConverter().convert(input, eol: '\n');

    if (fields.length < 2) {
      setState(() => _isProcessing = false);
      return;
    }

    final headers =
        fields.first.map((h) => h.toString().toLowerCase().trim()).toList();
    final dateIdx = headers.indexWhere((h) => h.contains('date'));
    final descIdx = headers.indexWhere((h) =>
        h.contains('desc') || h.contains('narr') || h.contains('particular'));
    final debitIdx = headers
        .indexWhere((h) => h.contains('debit') || h.contains('withdrawal'));
    final creditIdx = headers
        .indexWhere((h) => h.contains('credit') || h.contains('deposit'));
    final amountIdx = headers.indexWhere((h) => h.contains('amount'));

    final List<Expense> parsed = [];

    for (int i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.isEmpty || row.length <= 1) continue;

      final desc = descIdx != -1 && descIdx < row.length
          ? row[descIdx].toString()
          : 'CSV Transaction';
      double debitVal = 0.0;
      double creditVal = 0.0;

      if (debitIdx != -1 && debitIdx < row.length) {
        debitVal = double.tryParse(
                row[debitIdx].toString().replaceAll(',', '').trim()) ??
            0.0;
      }
      if (creditIdx != -1 && creditIdx < row.length) {
        creditVal = double.tryParse(
                row[creditIdx].toString().replaceAll(',', '').trim()) ??
            0.0;
      }
      if (amountIdx != -1 &&
          amountIdx < row.length &&
          debitVal == 0 &&
          creditVal == 0) {
        final val = double.tryParse(
                row[amountIdx].toString().replaceAll(',', '').trim()) ??
            0.0;
        if (val < 0) {
          debitVal = val.abs();
        } else {
          creditVal = val;
        }
      }

      if (debitVal > 0) {
        parsed.add(Expense(
          id: const Uuid().v4(),
          title: desc.trim().isNotEmpty ? desc.trim() : 'Debit Transfer',
          amount: debitVal,
          category: 'Bank Import',
          type: TransactionType.debit,
          source: SourceType.csv,
          date: DateTime.now(),
        ));
      } else if (creditVal > 0) {
        parsed.add(Expense(
          id: const Uuid().v4(),
          title: desc.trim().isNotEmpty ? desc.trim() : 'Credit Transfer',
          amount: creditVal,
          category: 'Income',
          type: TransactionType.credit,
          source: SourceType.csv,
          date: DateTime.now(),
        ));
      }
    }

    setState(() {
      _previewExpenses = parsed;
      _isProcessing = false;
    });
  }

  Future<void> _commitImport() async {
    final provider = context.read<ExpenseProvider>();
    for (final exp in _previewExpenses) {
      await provider.addExpense(exp);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Successfully imported ${_previewExpenses.length} transactions!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Bank Statement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _isProcessing ? null : _pickAndParseCsv,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.blueAccent.shade200, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50.withOpacity(0.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file_rounded,
                        size: 48, color: Colors.blueAccent),
                    const SizedBox(height: 8),
                    Text(
                      _fileName ?? 'Tap to select Bank Statement (.CSV)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                        'Auto-detects HDFC, SBI, ICICI, Axis statement formats',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_previewExpenses.isNotEmpty) ...[
              Text('Previewing ${_previewExpenses.length} Records',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _previewExpenses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = _previewExpenses[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.type == TransactionType.debit
                            ? Icons.arrow_outward
                            : Icons.arrow_downward,
                        color: e.type == TransactionType.debit
                            ? Colors.red
                            : Colors.green,
                      ),
                      title: Text(e.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text('₹${e.amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _commitImport,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child:
                    Text('Confirm & Import ${_previewExpenses.length} Items'),
              ),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }
}
