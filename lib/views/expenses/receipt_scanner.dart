// lib/views/expenses/receipt_scanner.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/receipt_ocr_parser.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  File? _imageFile;
  bool _isProcessing = false;
  ParsedReceiptData? _parsedData;

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Shopping';
  DateTime _selectedDate = DateTime.now();

  Future<void> _captureImage(ImageSource source) async {
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final categoryProvider = context.read<CategoryProvider>();

      final parsed = ReceiptOcrParser.parse(recognizedText, categoryProvider);

      setState(() {
        _parsedData = parsed;
        _titleController.text = parsed.merchantName;
        _amountController.text =
            parsed.amount > 0 ? parsed.amount.toStringAsFixed(2) : '';
        _selectedCategory = parsed.category;
        _selectedDate = parsed.date;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse receipt text: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textRecognizer.close();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _saveExpense() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid title and amount.')),
      );
      return;
    }

    final newExpense = Expense(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      category: _selectedCategory,
      type: TransactionType.debit,
      source: SourceType.manual,
      date: _selectedDate,
    );

    context.read<ExpenseProvider>().addExpense(newExpense);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = categoryProvider.categories.map((c) => c.name).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt OCR Scanner',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Preview or Action Picker
            if (_imageFile != null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  image: DecorationImage(
                      image: FileImage(_imageFile!), fit: BoxFit.cover),
                ),
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 20),
                    onPressed: () => _captureImage(ImageSource.camera),
                  ),
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.document_scanner_rounded,
                        size: 56, color: Color(0xFF1E3A8A)),
                    const SizedBox(height: 12),
                    const Text('Scan Bill / Physical Receipt',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                        'Auto-extracts merchant, bill amount, and date using ML',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _captureImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Camera'),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _captureImage(ImageSource.gallery),
                          icon:
                              const Icon(Icons.photo_library_rounded, size: 18),
                          label: const Text('Gallery'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Running on-device OCR recognition...',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_parsedData != null) ...[
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Verified Scanned Details',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                            labelText: 'Merchant / Store Name',
                            prefixIcon: Icon(Icons.storefront_rounded)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Total Bill Amount (₹)',
                            prefixIcon: Icon(Icons.currency_rupee_rounded)),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : categories.first,
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategory = val!),
                        decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_rounded)),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded,
                            color: Color(0xFF1E3A8A)),
                        title: Text(
                            'Bill Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
                        trailing: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null)
                              setState(() => _selectedDate = picked);
                          },
                          child: const Text('Change'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saveExpense,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
                child: const Text('Confirm & Log Expense',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
