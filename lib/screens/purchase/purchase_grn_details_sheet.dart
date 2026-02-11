import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'purchase_grn_form_screen.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final res = await Supabase.instance.client
          .from('purchase_grn_items')
          .select('*, item:items(name)')
          .eq('grn_id', widget.grn['id']);
      
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

  @override
  Widget build(BuildContext context) {
    final grnNumber = widget.grn['grn_number'] ?? '#---';
    final vendorName = widget.grn['vendor']?['name'] ?? 'Unknown Vendor';
    final date = DateTime.tryParse(widget.grn['date'] ?? '') ?? DateTime.now();

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
                    _buildHeader(context, grnNumber, vendorName),
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
                     if (widget.grn['notes'] != null && widget.grn['notes'].toString().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text("Notes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      const SizedBox(height: 8),
                      Text(widget.grn['notes'], style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                           Navigator.pop(context);
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseGrnFormScreen(grn: widget.grn)));
                           if (result == true) widget.onRefresh();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("Edit GRN", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                          child: _buildActionButton(Icons.print_outlined, "Print", () {
                            PrintService.printDocument(Map<String, dynamic>.from(widget.grn), 'purchase_grn');
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
                            final path = await PrintService.downloadDocument(Map<String, dynamic>.from(widget.grn), 'purchase_grn');
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
                          await PrintService.shareDocument(context, Map<String, dynamic>.from(widget.grn), 'purchase_grn');
                        } catch (e) {
                          if (mounted) {
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
  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
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
