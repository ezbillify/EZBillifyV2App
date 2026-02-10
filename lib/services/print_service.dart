import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'print_settings_service.dart';
// import 'package:intl/intl.dart'; - Not used yet

class PrintService {
  static Future<void> printDocument(Map<String, dynamic> data, String docType) async {
    // final template = await PrintSettingsService.getTemplate(docType); - Will be used for layout branching later
    
    // For now, only A4 is implemented as a placeholder
    final pdf = await _generateA4Standard(data, docType);
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${data['invoice_number'] ?? 'Document'}.pdf',
    );
  }

  static Future<pw.Document> _generateA4Standard(Map<String, dynamic> data, String docType) async {
    final pdf = pw.Document();
    
    // Load fonts from assets for offline support
    final fontData = await rootBundle.load("assets/fonts/Outfit-Regular.ttf");
    final boldFontData = await rootBundle.load("assets/fonts/Outfit-Bold.ttf");
    final font = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(boldFontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(docType.toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blue900)),
                      pw.Text("#${data['invoice_number'] ?? data['order_number'] ?? data['payment_number'] ?? '---'}", style: pw.TextStyle(font: font, fontSize: 14)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("EZBillify Demo", style: pw.TextStyle(font: boldFont, fontSize: 16)),
                      pw.Text("Date: ${data['date'] ?? data['invoice_date'] ?? '---'}", style: pw.TextStyle(font: font, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              
              // Bill To
              pw.Text("BILL TO:", style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.grey700)),
              pw.Text(data['customer']?['name'] ?? data['customer_name'] ?? 'Walk-in Customer', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 20),

              // Items Table Header
              pw.Container(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text("Item Detail", style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10))),
                    pw.Expanded(child: pw.Text("Qty", style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.center)),
                    pw.Expanded(child: pw.Text("Price", style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                    pw.Expanded(child: pw.Text("Total", style: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // Items List
              ...?((data['items'] as List?)?.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item['item']?['name'] ?? item['name'] ?? 'Item', style: pw.TextStyle(font: font, fontSize: 10))),
                      pw.Expanded(child: pw.Text("${item['quantity']}", style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.center)),
                      pw.Expanded(child: pw.Text("₹${item['unit_price'] ?? 0}", style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.right)),
                      pw.Expanded(child: pw.Text("₹${(item['quantity'] ?? 0) * (item['unit_price'] ?? 0)}", style: pw.TextStyle(font: boldFont, fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              })),

              pw.Divider(),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Subtotal: ₹${data['sub_total'] ?? data['subtotal'] ?? 0}", style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text("Tax: ₹${data['tax_total'] ?? data['total_tax'] ?? 0}", style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.SizedBox(height: 5),
                      pw.Text("Grand Total: ₹${data['total_amount'] ?? 0}", style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.Center(child: pw.Text("Thank you for your business!", style: pw.TextStyle(font: font, fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700))),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
