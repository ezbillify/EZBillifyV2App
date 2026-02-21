import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'purchase_payment_form_screen.dart';
import '../../services/print_service.dart';

class PurchasePaymentDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onRefresh;

  const PurchasePaymentDetailsSheet({super.key, required this.payment, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final vendorName = payment['vendor']?['name'] ?? 'Unknown Vendor';
    final paymentNumber = payment['payment_number'] ?? '#---';
    final date = DateTime.tryParse(payment['date'] ?? '') ?? DateTime.now();
    final amount = (payment['amount'] ?? 0).toDouble();
    final mode = payment['mode']?.toString().toUpperCase() ?? 'CASH';
    final billNumber = (payment['bill'] != null && payment['bill']['bill_number'] != null)
        ? payment['bill']['bill_number']
        : 'N/A';
    final notes = payment['notes']?.toString() ?? '';
    final reference = payment['reference_id']?.toString() ?? '';

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildHeader(context, paymentNumber, vendorName),
                    const SizedBox(height: 32),
                    _buildQuickStats(context, date, amount),
                    const SizedBox(height: 32),
                    Text("Payment Details", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: context.cardBg.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor.withOpacity(0.5))),
                      child: Column(
                        children: [
                          _buildDetailRow(context, "Payment Mode", mode),
                          const SizedBox(height: 12),
                          _buildDetailRow(context, "Against Bill", billNumber),
                          if (reference.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(context, "Reference", reference),
                          ],
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailRow(context, "Notes", notes),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.green.withOpacity(0.1))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Amount Paid", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                          Text("₹${NumberFormat('#,##,###.00').format(amount)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchasePaymentFormScreen(payment: payment)));
                          if (result == true) onRefresh();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("Edit Payment", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.cardBg,
                          foregroundColor: context.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.borderColor)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(context, Icons.print_outlined, "Print", () {
                            PrintService.printDocument(Map<String, dynamic>.from(payment), 'payment');
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(context, Icons.file_download_outlined, "Download", () async {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
                            final path = await PrintService.downloadDocument(Map<String, dynamic>.from(payment), 'payment');
                            if (path != null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved successfully'), backgroundColor: Colors.green));
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(context, Icons.share_outlined, "Share Receipt", () async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing share...'), duration: Duration(seconds: 1)));
                        try {
                          final data = Map<String, dynamic>.from(payment);
                          await PrintService.shareDocument(context, data, 'payment');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: ${e.toString()}'), backgroundColor: Colors.red));
                          }
                        }
                      }),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String number, String vendor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(number, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(vendor, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
          child: const Text("PAID", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, DateTime date, double amount) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.green, size: 20),
                const SizedBox(height: 12),
                Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Payment Date", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_rounded, color: Colors.green, size: 20),
                const SizedBox(height: 12),
                Text("₹${amount.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Amount", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
        Flexible(child: Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary), textAlign: TextAlign.end)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.cardBg,
        foregroundColor: context.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.borderColor)),
      ),
    );
  }
}
