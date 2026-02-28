import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'purchase_grn_form_screen.dart';
import 'purchase_bill_form_screen.dart';
import '../../services/print_service.dart';

class PurchaseGrnDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> grn;
  final VoidCallback onRefresh;

  const PurchaseGrnDetailsSheet({super.key, required this.grn, required this.onRefresh});

  @override
  State<PurchaseGrnDetailsSheet> createState() => _PurchaseGrnDetailsSheetState();
}

class _PurchaseGrnDetailsSheetState extends State<PurchaseGrnDetailsSheet> {
  List<Map<String, dynamic>> _items = [];
  late Map<String, dynamic> _grn;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _grn = widget.grn;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final res = await Supabase.instance.client
          .from('purchase_grn_items')
          .select('*, item:items(name)')
          .eq('grn_id', _grn['id']);
      
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching GRN items: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      final updatedGRN = await Supabase.instance.client
          .from('purchase_grns')
          .select('*, vendor:vendors(name)')
          .eq('id', _grn['id'])
          .single();
      
      if (mounted) {
        setState(() {
          _grn = updatedGRN;
        });
        await _fetchItems();
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint("Error refreshing GRN: $e");
    }
  }

  Future<void> _archiveGRN() async {
    final confirm = await _showConfirmDialog(
      title: "Archive GRN",
      message: "Are you sure you want to archive this goods received note? It will be moved to the archive section.",
      confirmLabel: "Archive",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_grns')
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', _grn['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GRN archived successfully")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error archiving GRN: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _restoreGRN() async {
    try {
      await Supabase.instance.client
          .from('purchase_grns')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', _grn['id']);
      
      if (mounted) {
        _refreshData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GRN restored successfully"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error restoring GRN: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteGRN() async {
    final confirm = await _showConfirmDialog(
      title: "Delete Permanently",
      message: "WARNING: This action cannot be undone. Are you sure you want to delete this GRN forever?",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_grns')
          .delete()
          .eq('id', _grn['id']);
      
      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GRN deleted permanently"), backgroundColor: Colors.black));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting GRN: $e"), backgroundColor: Colors.red));
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
    final grnNumber = _grn['grn_number'] ?? '#---';
    final vendorName = _grn['vendor']?['name'] ?? 'Unknown Vendor';
    final date = DateTime.tryParse(_grn['date'] ?? '') ?? DateTime.now();

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
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
                    _buildHeader(context, grnNumber, vendorName, _grn['reference_number']),
                    const SizedBox(height: 32),
                    _buildQuickStats(context, date, _items.length),
                    const SizedBox(height: 32),
                    Text("Received Items", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        children: _items.map((item) {
                          final qty = (item['quantity'] ?? 0).toDouble();
                          final batch = item['batch_number'] ?? '-';
                          final name = item['description'] ?? item['item']?['name'] ?? 'Item';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: context.cardBg.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor.withOpacity(0.5))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text("Batch: $batch", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text("Qty: $qty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                     if (_grn['notes'] != null && _grn['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text("Notes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      const SizedBox(height: 8),
                      Text(_grn['notes'], style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
                    ],
                    const SizedBox(height: 32),
                    _buildConversions(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: _buildActionButton(Icons.edit_outlined, "Edit GRN", () async {
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseGrnFormScreen(grn: _grn)));
                           if (result == true) {
                             _refreshData();
                           }
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(Icons.print_outlined, "Print", () {
                            final data = Map<String, dynamic>.from(_grn);
                            data['items'] = _items;
                            PrintService.printDocument(data, 'purchase_grn');
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
                            final data = Map<String, dynamic>.from(_grn);
                            data['items'] = _items;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
                            final path = await PrintService.downloadDocument(data, 'purchase_grn');
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
                      child: _buildActionButton(Icons.share_outlined, "Share GRN", () async {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing share...'), duration: Duration(seconds: 1)));
                        try {
                          final data = Map<String, dynamic>.from(_grn);
                          data['items'] = _items;
                          await PrintService.shareDocument(context, data, 'purchase_grn');
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: ${e.toString()}'), backgroundColor: Colors.red));
                          }
                        }
                      }),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    if (_grn['is_active'] != false)
                      SizedBox(
                        width: double.infinity,
                        child: _buildActionButton(
                          Icons.archive_outlined, 
                          "Archive GRN", 
                          _archiveGRN,
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
                              _restoreGRN,
                              color: Colors.green.withOpacity(0.1),
                              textColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              Icons.delete_forever_outlined, 
                              "Delete Forever", 
                              _deleteGRN,
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

  Widget _buildHeader(BuildContext context, String number, String vendor, String? reference) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(number, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(vendor, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
              if (reference != null && reference.isNotEmpty)
                Text("Inv #: $reference", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
          child: const Text("RECEIVED", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, DateTime date, int itemCount) {
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
                Text("GRN Date", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
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
                const Icon(Icons.inventory_2_rounded, color: Colors.green, size: 20),
                const SizedBox(height: 12),
                Text(_loading ? "-" : "$itemCount Items", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text("Received", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
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

  Widget _buildConversions() {
    final status = _grn['status']?.toString().toLowerCase() ?? 'received';
    if (status == 'converted' || status == 'invoiced') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Next Steps", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.primary.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              _buildConversionRow(
                Icons.receipt_long_outlined,
                "Convert to Bill",
                "Generate final purchase bill",
                () {
                  Navigator.pop(context);
                  _convertToBill();
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
              color: context.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.primary, size: 24),
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

  void _convertToBill() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillFormScreen(
      bill: {
        'vendor_id': _grn['vendor_id'],
        'vendor_name': _grn['vendor']?['name'] ?? _grn['vendor_name'],
        'branch_id': _grn['branch_id'],
        'items': _items.map((i) {
          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': i['item']?['name'] ?? i['description'] ?? 'Item',
            'quantity': i['quantity'],
            'unit_price': (i['unit_price'] ?? 0).toDouble(),
            'tax_rate': (i['tax_rate'] ?? 0).toDouble(),
            'unit': i['item']?['uom'] ?? i['unit'],
          };
        }).toList(),
      },
    )));
    
    if (result == true && mounted) {
      widget.onRefresh();
    }
  }
}
