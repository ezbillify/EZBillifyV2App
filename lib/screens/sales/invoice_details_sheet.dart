import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'invoice_form_screen.dart';
import 'payment_form_screen.dart';
import '../../services/print_service.dart';

class InvoiceDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onRefresh;

  const InvoiceDetailsSheet({super.key, required this.invoice, required this.onRefresh});

  @override
  State<InvoiceDetailsSheet> createState() => _InvoiceDetailsSheetState();
}

class _InvoiceDetailsSheetState extends State<InvoiceDetailsSheet> {
  late Map<String, dynamic> _invoice;
  bool _loading = false;
  bool _isSharing = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch Latest Invoice Status/Balance
      final latest = await Supabase.instance.client
          .from('sales_invoices')
          .select('*, customer:customers(name)')
          .eq('id', _invoice['id'])
          .single();
      
      // 2. Fetch Items
      final res = await Supabase.instance.client
          .from('sales_invoice_items')
          .select('*, item:items(name, sku, hsn_code)')
          .eq('invoice_id', _invoice['id']);
      
      if (mounted) {
        setState(() {
          _invoice = Map<String, dynamic>.from(latest);
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
        // Also update parent list
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint("Error refreshing invoice: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Material(
          color: Colors.transparent,
          child: Container(
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
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildQuickStats(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Line Items"),
                    const SizedBox(height: 16),
                    _buildItemsList(),
                    const SizedBox(height: 32),
                    _buildSummaryCard(),
                    const SizedBox(height: 40),
                    _buildActions(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final status = _invoice['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_invoice['invoice_number'] ?? '#---', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(_invoice['customer']?['name'] ?? 'Unknown Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.2))),
          child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final dateStr = _invoice['date']?.toString() ?? _invoice['invoice_date']?.toString() ?? _invoice['created_at']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    return Row(
      children: [
        _buildStatCard("Invoice Date", DateFormat('dd MMM, yyyy').format(date), Icons.calendar_today_rounded),
        const SizedBox(width: 16),
        _buildStatCard("Total Amount", "₹${_invoice['total_amount'] ?? 0}", Icons.payments_rounded),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryBlue, size: 20),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
            Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: _items.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.cardBg.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor.withOpacity(0.5))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['item']?['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("${item['quantity']} x ₹${item['unit_price']}", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ),
            Text("₹${(item['quantity'] * item['unit_price']).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "₹${(_invoice['sub_total'] ?? _invoice['subtotal'] ?? 0).toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Tax", "₹${(_invoice['tax_total'] ?? _invoice['total_tax'] ?? 0).toStringAsFixed(2)}"),
          const Divider(height: 24),
          _buildSummaryRow("Grand Total", "₹${(_invoice['total_amount'] ?? 0).toStringAsFixed(2)}", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: isTotal ? context.textPrimary : context.textSecondary, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isTotal ? AppColors.primaryBlue : context.textPrimary, fontSize: isTotal ? 18 : 14)),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        if (_invoice['status'] != 'paid')
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(Icons.payments_outlined, "Record Payment", () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PaymentFormScreen(
                initialInvoice: _invoice,
              )));
              if (result == true) {
                _refreshData();
              }
            }, filled: true),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(Icons.edit_outlined, "Edit", () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (c) => InvoiceFormScreen(invoice: _invoice)));
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(Icons.print_outlined, "Print", () {
                 final printData = Map<String, dynamic>.from(_invoice);
                 printData['items'] = _items;
                 PrintService.printDocument(printData, 'invoice');
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
                final printData = Map<String, dynamic>.from(_invoice);
                printData['items'] = _items;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
                final path = await PrintService.downloadDocument(printData, 'invoice');
                if (path != null && mounted) {
                  String msg = path == 'system_dialog' ? 'Opening Save dialog...' : 'PDF saved successfully';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
                }
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                Icons.share_outlined, 
                _isSharing ? "Sharing..." : "Share", 
                _isSharing ? null : () async {
                  HapticFeedback.selectionClick();
                  
                  setState(() => _isSharing = true);
                  
                  try {
                    final printData = Map<String, dynamic>.from(_invoice);
                    printData['items'] = _items;
                    
                    await PrintService.shareDocument(context, printData, 'invoice');
                  } catch (e, stack) {
                    debugPrint('EZ_DEBUG_UI ERROR: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSharing = false);
                    }
                  }
                }
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap, {bool filled = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? AppColors.primaryBlue : context.cardBg,
        foregroundColor: filled ? Colors.white : context.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: filled ? AppColors.primaryBlue : context.borderColor)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Colors.green;
      case 'partial': return Colors.orange;
      case 'overdue': return Colors.red;
      case 'draft': return Colors.grey;
      case 'sent': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary));
  }
}
