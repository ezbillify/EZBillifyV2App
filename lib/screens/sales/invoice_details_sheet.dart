import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'invoice_form_screen.dart';
import 'payment_form_screen.dart';
import '../../services/print_service.dart';
import '../../services/numbering_service.dart';
import '../../services/sales_refresh_service.dart';

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
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      final companyId = profile['company_id'];

      // 1. Fetch Latest Invoice Status/Balance - Include company_id check
      final latest = await Supabase.instance.client
          .from('sales_invoices')
          .select('*, customer:customers(name)')
          .eq('id', _invoice['id'])
          .eq('company_id', companyId)
          .single();
      
      // 2. Fetch Items
      final res = await Supabase.instance.client
          .from('sales_invoice_items')
          .select('*, item:items(name, sku, hsn_code)')
          .eq('invoice_id', _invoice['id']);
      
      // 3. Fetch Payments linked to this invoice via allocations
      final allocs = await Supabase.instance.client
          .from('sales_payment_allocations')
          .select('amount, payment:sales_payments(*)')
          .eq('invoice_id', _invoice['id']);
      
      if (mounted) {
        setState(() {
          _invoice = Map<String, dynamic>.from(latest);
          _items = List<Map<String, dynamic>>.from(res);
          _payments = (allocs as List).map((a) {
            final p = a['payment'] as Map<String, dynamic>;
            return {
              ...p,
              'allocated_amount': a['amount']
            };
          }).toList()..sort((a, b) => b['date'].compareTo(a['date']));
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

  Future<void> _archiveInvoice() async {
    final confirm = await _showConfirmDialog(
      title: "Archive Invoice",
      message: "Are you sure you want to archive this invoice? It will be moved to the archive section.",
      confirmLabel: "Archive",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('sales_invoices')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', _invoice['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice archived successfully")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error archiving invoice: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _restoreInvoice() async {
    try {
      await Supabase.instance.client
          .from('sales_invoices')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', _invoice['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice restored successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring invoice: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await _showConfirmDialog(
      title: "Delete Permanently",
      message: "WARNING: This action cannot be undone. Are you sure you want to delete this invoice forever?",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('sales_invoices')
          .delete()
          .eq('id', _invoice['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice deleted permanently"), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting invoice: $e"), backgroundColor: Colors.red));
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
                    if (_payments.isNotEmpty) ...[
                      _buildSectionHeader("Payment History"),
                      const SizedBox(height: 16),
                      _buildPaymentsList(),
                      const SizedBox(height: 32),
                    ],
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
        Material(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: statusColor)),
          ),
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
      child: Material(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor.withOpacity(0.5)),
          ),
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
      ),
    );
  }

  Widget _buildItemsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
    return Material(
      color: AppColors.primaryBlue.withOpacity(0.05),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            _buildSummaryRow("Subtotal", "₹${(_invoice['sub_total'] ?? _invoice['subtotal'] ?? 0).toStringAsFixed(2)}"),
            const SizedBox(height: 8),
            _buildSummaryRow("Total Tax", "₹${(_invoice['tax_total'] ?? _invoice['total_tax'] ?? 0).toStringAsFixed(2)}"),
            const Divider(height: 24),
            _buildSummaryRow("Grand Total", "₹${(_invoice['total_amount'] ?? 0).toStringAsFixed(2)}", isTotal: true),
          ],
        ),
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
            child: _buildActionButton(Icons.payments_outlined, "Record Payment", () => _showRecordPaymentModal(), filled: true),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(Icons.edit_outlined, "Edit", () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => InvoiceFormScreen(invoice: _invoice)));
                if (result == true) {
                  _refreshData();
                }
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
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        if (_invoice['is_active'] != false)
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              Icons.archive_outlined, 
              "Archive Invoice", 
              _archiveInvoice,
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
                  _restoreInvoice,
                  color: Colors.green.withOpacity(0.1),
                  textColor: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  Icons.delete_forever_outlined, 
                  "Delete Forever", 
                  _deleteInvoice,
                  color: Colors.red.withOpacity(0.1),
                  textColor: Colors.red,
                ),
              ),
            ],
          ),
      ],
    );
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

  Widget _buildPaymentsList() {
    return Column(
      children: _payments.map((p) => Padding(
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getPaymentIcon(p['payment_mode'] ?? 'Cash'), color: Colors.green, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['payment_number'] ?? 'Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text("${DateFormat('dd MMM, yyyy').format(DateTime.parse(p['date']))} • ${p['payment_mode']}", style: TextStyle(fontSize: 11, color: context.textSecondary)),
                    ],
                  ),
                ),
                Text("₹${p['allocated_amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  IconData _getPaymentIcon(String mode) {
    switch (mode) {
      case 'Cash': return Icons.payments_rounded;
      case 'UPI': return Icons.qr_code_scanner_rounded;
      case 'Card': return Icons.credit_card_rounded;
      case 'Bank Transfer': return Icons.account_balance_rounded;
      case 'Cheque': return Icons.history_edu_rounded;
      default: return Icons.more_horiz_rounded;
    }
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

  String _formatAmount(double val) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(2);
  }

  void _showRecordPaymentModal() {
    final balanceDueNow = (_invoice['balance_due'] ?? 0).toDouble();
    if (balanceDueNow <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invoice is already fully paid")));
      return;
    }

    List<Map<String, dynamic>> modalPayments = [
      {
        'mode': 'Cash', 
        'amount': balanceDueNow, 
        'controller': TextEditingController(text: _formatAmount(balanceDueNow))
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double totalAmount = (_invoice['total_amount'] ?? 0).toDouble();
          double currentNewPaid = modalPayments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
          double remainingBalance = balanceDueNow - currentNewPaid;

          return Container(
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Record Payment", style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TOTAL INVOICE VALUE", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue.withOpacity(0.5))),
                            const SizedBox(height: 4),
                            Text("₹${_formatAmount(totalAmount)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(remainingBalance > 0 ? "BALANCE DUE" : "REMAINING", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: remainingBalance > 0 ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5))),
                            const SizedBox(height: 4),
                            Text("₹${_formatAmount(remainingBalance.abs())}", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: remainingBalance > 0 ? Colors.red : Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Payments", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textSecondary)),
                  const SizedBox(height: 12),
                  ...modalPayments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _showModeSelectionSheet(context, (mode) => setModalState(() => p['mode'] = mode)),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(p['mode'], style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14))),
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primaryBlue),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: p['controller'],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: "₹ ",
                                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                filled: true,
                                fillColor: context.cardBg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
                              ),
                              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                              onChanged: (v) => setModalState(() {}),
                            ),
                          ),
                          if (modalPayments.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: IconButton(
                                onPressed: () => setModalState(() {
                                  modalPayments[idx]['controller'].dispose();
                                  modalPayments.removeAt(idx);
                                }), 
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red)
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        double currentBalance = balanceDueNow - modalPayments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
                        modalPayments.add({
                          'mode': 'UPI', 
                          'amount': currentBalance > 0 ? currentBalance : 0.0,
                          'controller': TextEditingController(text: _formatAmount(currentBalance > 0 ? currentBalance : 0.0))
                        });
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Text("Add Another Payment Mode", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalPayments = modalPayments.map((p) => {
                          'mode': p['mode'],
                          'amount': double.tryParse(p['controller'].text) ?? 0.0
                        }).where((p) => (p['amount'] as double) > 0).toList();
                        
                        if (finalPayments.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid payment amount")));
                          return;
                        }

                        Navigator.pop(context);
                        _recordPayment(finalPayments);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Confirm Payment",
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      for (var p in modalPayments) {
        p['controller'].dispose();
      }
    });
  }

  void _showModeSelectionSheet(BuildContext context, Function(String) onSelect) {
    final modes = ["Cash", "UPI", "Card", "Bank Transfer", "Cheque", "Other"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Select Payment Mode", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              ...modes.map((mode) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getPaymentIcon(mode), color: AppColors.primaryBlue, size: 20),
                ),
                title: Text(mode, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  onSelect(mode);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordPayment(List<Map<String, dynamic>> finalPayments) async {
    setState(() => _loading = true);
    try {
      final companyId = _invoice['company_id'];
      final branchId = _invoice['branch_id']?.toString();
      final internalUserId = Supabase.instance.client.auth.currentUser!.id; // fallback, usually from profile
      
      // Get real User ID from profile
      final userProfile = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('auth_id', internalUserId)
          .single();
      final userId = userProfile['id'];

      final totalAmt = finalPayments.fold(0.0, (sum, p) => sum + (p['amount'] as double));
      
      final pNum = await NumberingService.getNextDocumentNumber(
        companyId: companyId,
        documentType: 'SALES_PAYMENT',
        branchId: branchId,
        previewOnly: false,
      );

      final isMulti = finalPayments.length > 1;

      final payment = await Supabase.instance.client.from('sales_payments').insert({
        'company_id': companyId,
        'branch_id': branchId,
        'customer_id': _invoice['customer_id'],
        'payment_number': pNum,
        'date': DateTime.now().toIso8601String(),
        'amount': totalAmt,
        'payment_mode': isMulti ? 'Multi' : finalPayments[0]['mode'],
        'created_by': userId,
        'is_active': true,
        'payment_methods': finalPayments, // Store splits
      }).select().single();

      await Supabase.instance.client.from('sales_payment_allocations').insert({
        'payment_id': payment['id'],
        'invoice_id': _invoice['id'],
        'amount': totalAmt,
      });

      // Update Invoice
      final currentBalance = (_invoice['balance_due'] ?? 0).toDouble();
      final newBalance = currentBalance - totalAmt;
      final status = newBalance <= 0.5 ? 'paid' : (newBalance < (_invoice['total_amount'] ?? 0).toDouble() ? 'partial' : 'unpaid');

      await Supabase.instance.client.from('sales_invoices').update({
        'balance_due': newBalance < 0 ? 0 : newBalance,
        'status': status,
      }).eq('id', _invoice['id']);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment recorded successfully"), backgroundColor: Colors.green));
      _refreshData();
      SalesRefreshService.triggerRefresh();
    } catch (e) {
      debugPrint("Error recording payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _loading = false);
    }
  }
}
