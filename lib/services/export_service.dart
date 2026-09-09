// lib/services/export_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';

class ExportService {
  static Future<void> exportCsvStatement(List<Expense> expenses) async {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Title,Category,Type,Amount (INR),Source,Account');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final e in expenses) {
      buffer.writeln(
        '"${e.id}","${dateFormat.format(e.date)}","${e.title.replaceAll('"', '""')}","${e.category}","${e.type.name}",${e.amount},"${e.source.name}","${e.accountLast4 ?? 'NA'}"',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
        '${tempDir.path}/Fintor_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(file.path)],
        text: 'Fintor Financial Statement (CSV)');
  }

  static Future<void> exportPdfStatement({
    required List<Expense> expenses,
    required double totalSpent,
    required double totalIncome,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FINTOR FINANCIAL STATEMENT',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Generated: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Text('CONFIDENTIAL',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700)),
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 12),

          // Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Outflow (Debit)',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.red900)),
                      pw.SizedBox(height: 4),
                      pw.Text(currency.format(totalSpent),
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Total Inflow (Credit)',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.green900)),
                      pw.SizedBox(height: 4),
                      pw.Text(currency.format(totalIncome),
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Transactions Table
          pw.Text('Transaction Ledger',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Description', 'Category', 'Source', 'Amount'],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellHeight: 24,
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
            },
            data: expenses
                .map((e) => [
                      dateFormat.format(e.date),
                      e.title,
                      e.category,
                      e.source.name.toUpperCase(),
                      '${e.type == TransactionType.debit ? '-' : '+'} ${currency.format(e.amount)}',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Fintor_Statement_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
