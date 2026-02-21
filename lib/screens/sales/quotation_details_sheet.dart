import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'quotation_form_screen.dart';
import '../../services/print_service.dart';
import 'invoice_form_screen.dart';
import 'sales_order_form_screen.dart';

class QuotationDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> quotation;
  final VoidCallback onRefresh;

  const QuotationDetailsSheet({super.key, required this.quotation, required this.onRefresh});

  @override
  State<QuotationDetailsSheet> createState() => _QuotationDetailsSheetState();
}

class _QuotationDetailsSheetState extends State<QuotationDetailsSheet> {
  late Map<String, dynamic> _quotation;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _quotation = widget.quotation;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('sales_quotation_items')
          .select('*, item:items(name, uom, default_sales_price, default_purchase_price, hsn_code)')
          .eq('quote_id', _quotation['id']);
      
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error loading items: $e"),
          backgroundColor: Colors.red,
        ));
      }
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
                    const SizedBox(height: 32),
                    _buildConversions(),
                    const SizedBox(height: 32),
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
    final status = _quotation['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_quotation['quote_number'] ?? _quotation['quotation_number'] ?? '#---', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(_quotation['customer']?['name'] ?? 'Unknown Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
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
    final dateStr = _quotation['quotation_date']?.toString() ?? _quotation['created_at']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    return Row(
      children: [
        _buildStatCard("Quote Date", DateFormat('dd MMM, yyyy').format(date), Icons.calendar_today_rounded),
        const SizedBox(width: 16),
        _buildStatCard("Total Amount", "₹${_quotation['total_amount'] ?? 0}", Icons.payments_rounded),
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
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.2))
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
            const SizedBox(height: 8),
            Text("No items found", style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
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
          _buildSummaryRow("Subtotal", "₹${(_quotation['sub_total'] ?? _quotation['subtotal'] ?? 0).toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Tax", "₹${(_quotation['tax_total'] ?? _quotation['total_tax'] ?? 0).toStringAsFixed(2)}"),
          const Divider(height: 24),
          _buildSummaryRow("Grand Total", "₹${(_quotation['total_amount'] ?? 0).toStringAsFixed(2)}", isTotal: true),
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

  Widget _buildConversions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Conversions"),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(Icons.shopping_bag_outlined, "To Sales Order", () {
                Navigator.pop(context);
                _convertToSalesOrder();
              }, filled: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(Icons.receipt_long_outlined, "To Invoice", () {
                Navigator.pop(context);
                _convertToInvoice();
              }, filled: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.edit_outlined, "Edit", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => QuotationFormScreen(quotation: _quotation)));
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(Icons.print_outlined, "Print", () {
              final printData = Map<String, dynamic>.from(_quotation);
              printData['items'] = _items;
              PrintService.printDocument(printData, 'quotation');
            })),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
              final printData = Map<String, dynamic>.from(_quotation);
              printData['items'] = _items;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
              final path = await PrintService.downloadDocument(printData, 'quotation');
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved successfully'), backgroundColor: Colors.green));
              }
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(Icons.share_outlined, "Share", () async {
              final printData = Map<String, dynamic>.from(_quotation);
              printData['items'] = _items;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing share...'), duration: Duration(seconds: 1)));
              try {
                await PrintService.shareDocument(context, printData, 'quotation');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: ${e.toString()}'), backgroundColor: Colors.red));
                }
              }
            })),
          ],
        ),
      ],
    );
  }

  void _convertToInvoice() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => InvoiceFormScreen(
      invoice: {
        'customer_id': _quotation['customer_id'],
        'customer_name': _quotation['customer']?['name'] ?? _quotation['customer_name'],
        'branch_id': _quotation['branch_id'],
        'items': _items.map((i) {
          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': i['item']?['name'] ?? i['description'] ?? 'Item',
            'quantity': i['quantity'],
            'unit_price': (i['unit_price'] ?? 0).toDouble(),
            'tax_rate': (i['tax_rate'] ?? 0).toDouble(),
            'unit': i['item']?['uom'],
            'purchase_price': (i['item']?['default_purchase_price'] ?? 0).toDouble(),
          };
        }).toList(),
        'quotation_id': _quotation['id'],
      },
    )));
  }

  void _convertToSalesOrder() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => SalesOrderFormScreen(
      order: {
        'customer_id': _quotation['customer_id'],
        'customer_name': _quotation['customer']?['name'] ?? _quotation['customer_name'],
        'branch_id': _quotation['branch_id'],
        'items': _items.map((i) {
          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': i['item']?['name'] ?? i['description'] ?? 'Item',
            'quantity': i['quantity'],
            'unit_price': (i['unit_price'] ?? 0).toDouble(),
            'tax_rate': (i['tax_rate'] ?? 0).toDouble(),
            'unit': i['item']?['uom'],
            'purchase_price': (i['item']?['default_purchase_price'] ?? 0).toDouble(),
          };
        }).toList(),
        'quotation_id': _quotation['id'],
      },
    )));
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool filled = false}) {
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
      case 'converted': return Colors.green;
      case 'sent': return Colors.blue;
      case 'draft': return Colors.grey;
      case 'rejected': return Colors.red;
      default: return Colors.blue;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary));
  }
}
