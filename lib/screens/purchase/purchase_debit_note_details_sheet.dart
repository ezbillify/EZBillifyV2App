
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'purchase_debit_note_form_screen.dart';
import '../../services/print_service.dart';


class PurchaseDebitNoteDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> debitNote;
  final VoidCallback onRefresh;

  const PurchaseDebitNoteDetailsSheet({super.key, required this.debitNote, required this.onRefresh});

  @override
  State<PurchaseDebitNoteDetailsSheet> createState() => _PurchaseDebitNoteDetailsSheetState();
}

class _PurchaseDebitNoteDetailsSheetState extends State<PurchaseDebitNoteDetailsSheet> {
  List<Map<String, dynamic>> _items = [];
  late Map<String, dynamic> _debitNote;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _debitNote = widget.debitNote;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final res = await Supabase.instance.client
          .from('purchase_debit_note_items')
          .select('*, item:items(name)')
          .eq('debit_note_id', _debitNote['id']);
      
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching debit note items: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      final updatedDN = await Supabase.instance.client
          .from('purchase_debit_notes')
          .select('*, vendor:vendors(name)')
          .eq('id', _debitNote['id'])
          .single();
      
      if (mounted) {
        setState(() {
          _debitNote = updatedDN;
        });
        await _fetchItems();
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint("Error refreshing debit note: $e");
    }
  }

  Future<void> _archiveDN() async {
    final confirm = await _showConfirmDialog(
      title: "Archive Debit Note",
      message: "Are you sure you want to archive this debit note? It will be moved to the archive section.",
      confirmLabel: "Archive",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_debit_notes')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', _debitNote['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        StatusService.show(context, "Debit Note archived successfully");
      }
    } catch (e) {
      if (mounted) StatusService.show(context, "Error archiving debit note: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _restoreDN() async {
    try {
      await Supabase.instance.client
          .from('purchase_debit_notes')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', _debitNote['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        StatusService.show(context, "Debit Note restored successfully", backgroundColor: Colors.green);
      }
    } catch (e) {
      if (mounted) StatusService.show(context, "Error restoring debit note: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _deleteDN() async {
    final confirm = await _showConfirmDialog(
      title: "Delete Permanently",
      message: "WARNING: This action cannot be undone. Are you sure you want to delete this debit note forever?",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_debit_notes')
          .delete()
          .eq('id', _debitNote['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        StatusService.show(context, "Debit Note deleted permanently", backgroundColor: Colors.black);
      }
    } catch (e) {
      if (mounted) StatusService.show(context, "Error deleting debit note: $e", backgroundColor: Colors.red);
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
    final noteNumber = _debitNote['dn_number'] ?? _debitNote['debit_note_number'] ?? '#---';
    final vendorName = _debitNote['vendor']?['name'] ?? 'Unknown Vendor';
    final date = DateTime.tryParse(_debitNote['date'] ?? '') ?? DateTime.now();
    final total = (_debitNote['total_amount'] ?? 0).toDouble();
    final reason = _debitNote['reason'] ?? 'Return';

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
                    _buildHeader(context, noteNumber, vendorName, reason),
                    const SizedBox(height: 32),
                    _buildQuickStats(context, date, total),
                    const SizedBox(height: 32),
                    Text("Items", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
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
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
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
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 32),
                     Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.1))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Debit", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                          Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(Icons.edit_outlined, "Edit Debit Note", () async {
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseDebitNoteFormScreen(debitNote: _debitNote)));
                           if (result == true) {
                             Navigator.pop(context);
                             widget.onRefresh();
                           }
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(Icons.print_outlined, "Print", () {
                            PrintService.printDocument(Map<String, dynamic>.from(_debitNote), 'purchase_debit_note', context);
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
                            StatusService.show(context, 'Generating PDF...', isLoading: true);
                            final path = await PrintService.downloadDocument(Map<String, dynamic>.from(_debitNote), 'purchase_debit_note');
                            if (path != null && mounted) {
                              StatusService.show(context, 'PDF saved successfully', backgroundColor: Colors.green);
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(Icons.share_outlined, "Share Note", () async {
                        StatusService.show(context, 'Preparing share...', isLoading: true);
                        try {
                          await PrintService.shareDocument(context, Map<String, dynamic>.from(_debitNote), 'purchase_debit_note');
                        } catch (e) {
                          if (mounted) {
                            StatusService.show(context, 'Failed to share: ${e.toString()}', backgroundColor: Colors.red);
                          }
                        }
                      }),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    if (_debitNote['is_active'] != false)
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          Icons.archive_outlined, 
                          "Archive Debit Note", 
                          _archiveDN,
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
                              _restoreDN,
                              color: Colors.green.withOpacity(0.1),
                              textColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              Icons.delete_forever_outlined, 
                              "Delete Forever", 
                              _deleteDN,
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

  Widget _buildHeader(BuildContext context, String number, String vendor, String reason) {
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
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.2))),
          child: Text(reason.toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, DateTime date, double total) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_today_rounded, color: Colors.red, size: 20),
                const SizedBox(height: 12),
                Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Date", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
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
                const Icon(Icons.money_off_rounded, color: Colors.red, size: 20),
                const SizedBox(height: 12),
                Text("₹${total.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Total Debit", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: (filled || isDestructive || color != null) ? Colors.transparent : context.borderColor)),
      ),
    );
  }
}
