import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../services/print_service.dart';
import '../../core/theme_service.dart';

class PdfPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docType;
  final String fileName;

  const PdfPreviewScreen({
    super.key,
    required this.data,
    required this.docType,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "$docType Preview".toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: context.surfaceBg,
        foregroundColor: context.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // If they want to share, printing already provides sharing in the previewer
        ],
      ),
      body: PdfPreview(
        build: (format) => PrintService.generatePdfBytesForPreview(data, docType),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true,
        canChangeOrientation: false,
        pdfFileName: "$fileName.pdf",
        loadingWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 20),
              Text(
                "Generating PDF...",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
