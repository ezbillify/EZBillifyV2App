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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      final updatedQuotation = await Supabase.instance.client
          .from('sales_quotations')
          .select('*, branch:branches(name), customer:customers(name)')
          .eq('id', _quotation['id'])
          .single();
      
      if (mounted) {
        setState(() {
          _quotation = updatedQuotation;
        });
        await _fetchItems();
        widget.onRefresh(); // Notify list screen
      }
    } catch (e) {
      debugPrint("Error refreshing quotation: $e");
    }
  }

  Future<void> _archiveQuotation() async {
    final confirm = await _showConfirmDialog(
      title: "Archive Quotation",
      message: "Are you sure you want to archive this quotation? It will be moved to the archive section.",
      confirmLabel: "Archive",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('sales_quotations')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', _quotation['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quotation archived successfully")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error archiving quotation: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _restoreQuotation() async {
    try {
      await Supabase.instance.client
          .from('sales_quotations')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', _quotation['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quotation restored successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring quotation: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteQuotation() async {
    final confirm = await _showConfirmDialog(
      title: "Delete Permanently",
      message: "WARNING: This action cannot be undone. Are you sure you want to delete this quotation forever?",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('sales_quotations')
          .delete()
          .eq('id', _quotation['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quotation deleted permanently"), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting quotation: $e"), backgroundColor: Colors.red));
    }
  }

  Future<bool?> _showConfirmDialog({required String title, required String message, required String confirmLabel, bool isDestructive = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDestructive ? Colors.red : AppColors.primaryBlue).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: isDestructive ? Colors.red : AppColors.primaryBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: context.borderColor),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDestructive ? Colors.red : AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        elevation: 16,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildWorkflowTimeline(),
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

  Widget _buildWorkflowTimeline() {
    final status = _quotation['status']?.toString().toLowerCase() ?? 'draft';
    final isConverted = status == 'converted';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildTimelineStep("Quote", true, true),
              _buildTimelineDivider(isConverted),
              _buildTimelineStep("Order", isConverted, isConverted),
              _buildTimelineDivider(false),
              _buildTimelineStep("Invoice", false, false),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConverted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 14,
                color: isConverted ? Colors.green : AppColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                isConverted 
                  ? "Conversion Complete" 
                  : status == 'rejected' ? "Quotation Rejected" : "Ready for Conversion",
                style: TextStyle(
                  fontFamily: 'Outfit', 
                  fontSize: 12, 
                  color: isConverted ? Colors.green : status == 'rejected' ? Colors.red : context.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String label, bool isReached, bool isDone) {
    final color = isDone ? Colors.green : isReached ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.3);
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              color: isDone ? Colors.green.withOpacity(0.1) : Colors.transparent,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : (isReached ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 11,
              fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
              color: isReached ? context.textPrimary : context.textSecondary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDivider(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : context.borderColor,
        borderRadius: BorderRadius.circular(1),
      ),
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
      children: _items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor.withOpacity(0.5)),
            ),
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
          ),
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
    final status = _quotation['status']?.toString().toLowerCase() ?? 'draft';
    if (status == 'converted') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Next Steps"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildConversionRow(
                Icons.shopping_bag_outlined,
                "Convert to Sales Order",
                "Create a formal order for these items",
                () {
                  Navigator.pop(context);
                  _convertToSalesOrder();
                },
              ),
              const Divider(height: 24),
              _buildConversionRow(
                Icons.receipt_long_outlined,
                "Convert to Invoice",
                "Generate final bill and request payment",
                () {
                  Navigator.pop(context);
                  _convertToInvoice();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversionRow(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                Text(subtitle, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.edit_outlined, "Edit", () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => QuotationFormScreen(quotation: _quotation)));
              if (result == true) {
                _refreshData();
              }
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
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        if (_quotation['is_active'] != false)
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              Icons.archive_outlined, 
              "Archive Quotation", 
              _archiveQuotation,
              isDestructive: true,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  Icons.unarchive_outlined, 
                  "Restore", 
                  _restoreQuotation,
                  color: Colors.green.withOpacity(0.1),
                  textColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  Icons.delete_forever_outlined, 
                  "Delete Forever", 
                  _deleteQuotation,
                  color: Colors.red.withOpacity(0.1),
                  textColor: Colors.red,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _convertToInvoice() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => InvoiceFormScreen(
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
    
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _convertToSalesOrder() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => SalesOrderFormScreen(
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

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap, {bool filled = false, bool isDestructive = false, Color? color, Color? textColor}) {
    final bgColor = color ?? (filled ? AppColors.primaryBlue : (isDestructive ? Colors.orange.withOpacity(0.1) : context.cardBg));
    final fgColor = textColor ?? (filled ? Colors.white : (isDestructive ? Colors.orange : context.textPrimary));

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: (filled || isDestructive || color != null) ? Colors.transparent : context.borderColor)),
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
