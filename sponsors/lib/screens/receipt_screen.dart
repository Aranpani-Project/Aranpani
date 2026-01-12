import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';

class ReceiptScreen extends StatelessWidget {
  final String title;
  final String amount;
  final String transactionId;
  final String method;
  final DateTime date;
  
  // --- NEW FIELD ADDED HERE ---
  final String donorName; 

  const ReceiptScreen({
    super.key,
    required this.title,
    required this.amount,
    required this.transactionId,
    required this.method,
    required this.date,
    
    // --- REQUIRED IN CONSTRUCTOR ---
    required this.donorName, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donation Receipt"),
        backgroundColor: AppTheme.primaryBrand,
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format, title),
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format, String title) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Temple Trust", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("RECEIPT", style: pw.TextStyle(fontSize: 24, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // --- DISPLAYING THE NAME HERE ---
                    _buildRow("Donor Name:", donorName), 
                    _buildRow("Donation For:", title),
                    _buildRow("Amount Paid:", "INR $amount"),
                    _buildRow("Date:", DateFormat('dd MMM yyyy, hh:mm a').format(date)),
                    _buildRow("Payment Method:", method.toUpperCase()),
                    pw.Divider(),
                    _buildRow("Transaction ID:", transactionId),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text("May the blessings be with you.", style: pw.TextStyle(fontSize: 18, fontStyle: pw.FontStyle.italic))),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text("Thank you for your generous support!", style: const pw.TextStyle(color: PdfColors.grey700))),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value),
        ],
      ),
    );
  }
}