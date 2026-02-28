import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'purchase_bill_form_screen.dart';
import 'purchase_payment_form_screen.dart';
import '../../services/print_service.dart';

class PurchaseBillDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> bill;
  final VoidCallback onRefresh;

  const PurchaseBillDetailsSheet({super.key, required this.bill, required this.onRefresh});

  @override
  State<PurchaseBillDetailsSheet> createState() => _PurchaseBillDetailsSheetState();
}

class _PurchaseBillDetailsSheetState extends State<PurchaseBillDetailsSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final res = await Supabase.instance.client
          .from('purchase_bill_items')
          .select('*, item:items(name)')
          .eq('bill_id', widget.bill['id']);
      
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching bill items: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _archiveBill() async {
    final confirm = await _showConfirmDialog(
      title: "Archive Bill",
      message: "Are you sure you want to archive this bill? It will be moved to the archive section.",
      confirmLabel: "Archive",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_bills')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', widget.bill['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill archived successfully")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error archiving bill: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _restoreBill() async {
    try {
      await Supabase.instance.client
          .from('purchase_bills')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', widget.bill['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill restored successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring bill: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteBill() async {
    final confirm = await _showConfirmDialog(
      title: "Delete Permanently",
      message: "WARNING: This action cannot be undone. Are you sure you want to delete this bill forever?",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_bills')
          .delete()
          .eq('id', widget.bill['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill deleted permanently"), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting bill: $e"), backgroundColor: Colors.red));
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
    final status = widget.bill['status'] ?? 'Draft';
    final vendorName = widget.bill['vendor']?['name'] ?? 'Unknown Vendor';
    final billNumber = widget.bill['bill_number'] ?? '#---';
    final date = DateTime.tryParse(widget.bill['date'] ?? '') ?? DateTime.now();
    final total = (widget.bill['total_amount'] ?? 0).toDouble();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
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
                    _buildHeader(context, billNumber, vendorName, status),
                    const SizedBox(height: 32),
                    _buildQuickStats(context, date, total, widget.bill['terms'] ?? 'Net 0'),
                    const SizedBox(height: 32),
                    Text("Line Items", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        children: _items.map((item) {
                          final qty = (item['quantity'] ?? 0).toDouble();
                          final price = (item['unit_price'] ?? 0).toDouble();
                          final lineTotal = qty * price;
                          final name = item['description'] ?? item['item']?['name'] ?? 'Item';
                          return Padding(
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
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text("$qty x ₹$price", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    Text("₹${lineTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 32),
                     Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Amount", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                          Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                    if (widget.bill['notes'] != null && widget.bill['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                         decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Notes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: context.textSecondary)),
                            const SizedBox(height: 4),
                            Text(widget.bill['notes'], style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                           Navigator.pop(context);
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillFormScreen(bill: widget.bill)));
                           if (result == true) widget.onRefresh();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("Edit Invoice", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    if ((widget.bill['status'] ?? '').toString().toLowerCase() != 'paid')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildActionButton(
                            Icons.add_card_rounded, 
                            "Record Payment", 
                            () async {
                              Navigator.pop(context);
                              final result = await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => PurchasePaymentFormScreen(prefilledBill: widget.bill),
                              );
                              if (result == true) widget.onRefresh();
                            },
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(Icons.print_outlined, "Print", () {
                            PrintService.printDocument(Map<String, dynamic>.from(widget.bill), 'purchase_bill');
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
                            final data = Map<String, dynamic>.from(widget.bill);
                            data['items'] = _items;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
                            final path = await PrintService.downloadDocument(data, 'purchase_bill');
                            if (path != null && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF saved successfully'), backgroundColor: Colors.green));
                            }
                          }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(
                        Icons.share_outlined, 
                        _isSharing ? "Sharing..." : "Share Invoice", 
                        _isSharing ? null : () async {
                          HapticFeedback.selectionClick();
                          setState(() => _isSharing = true);
                          try {
                            final data = Map<String, dynamic>.from(widget.bill);
                            data['items'] = _items;
                            await PrintService.shareDocument(context, data, 'purchase_bill');
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: ${e.toString()}'), backgroundColor: Colors.red));
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isSharing = false);
                            }
                          }
                        }
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    if (widget.bill['is_active'] != false)
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          Icons.archive_outlined, 
                          "Archive Bill", 
                          _archiveBill,
                          color: Colors.orange.withOpacity(0.1),
                          textColor: Colors.orange,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              Icons.unarchive_outlined, 
                              "Restore", 
                              _restoreBill,
                              color: Colors.green.withOpacity(0.1),
                              textColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              Icons.delete_forever_outlined, 
                              "Delete", 
                              _deleteBill,
                              color: Colors.red.withOpacity(0.1),
                              textColor: Colors.red,
                            ),
                          ),
                        ],
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

  Widget _buildHeader(BuildContext context, String number, String vendor, String status) {
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
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
          child: Text(status.toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, DateTime date, double total, String terms) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(height: 12),
                Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Invoice Date", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
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
                const Icon(Icons.payments_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(height: 12),
                Text("₹${total.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Total Amount", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
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
                const Icon(Icons.handshake_rounded, color: AppColors.primaryBlue, size: 20),
                const SizedBox(height: 12),
                Text(terms, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Terms", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildActionButton(IconData icon, String label, VoidCallback? onTap, {Color? color, Color? textColor}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? context.cardBg,
        foregroundColor: textColor ?? (color != null ? Colors.white : context.textPrimary),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color ?? context.borderColor)),
      ),
    );
  }
}
