import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'delivery_challan_form_screen.dart';
import '../../services/print_service.dart';

class ChallanDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> challan;
  final VoidCallback onRefresh;

  const ChallanDetailsSheet({super.key, required this.challan, required this.onRefresh});

  @override
  State<ChallanDetailsSheet> createState() => _ChallanDetailsSheetState();
}

class _ChallanDetailsSheetState extends State<ChallanDetailsSheet> {
  late Map<String, dynamic> _challan;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _challan = widget.challan;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('sales_dc_items')
          .select('*, item:items(name, sku, hsn_code)')
          .eq('dc_id', _challan['id']);
      
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
        elevation: 8,
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
                    _buildLogisticsStats(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Items Dispatched"),
                    const SizedBox(height: 16),
                    _buildItemsList(),
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
    );
  }

  Widget _buildHeader() {
    final status = _challan['status'] ?? 'draft';
    final statusColor = _getStatusColor(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_challan['dc_number'] ?? _challan['challan_number'] ?? '#---', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(_challan['customer']?['name'] ?? 'Unknown Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
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

  Widget _buildLogisticsStats() {
    final dateStr = _challan['challan_date']?.toString() ?? _challan['created_at']?.toString() ?? _challan['date']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    final shipping = _challan['shipping_details'] ?? {};
    final vehicleNo = shipping['vehicle_no'] ?? _challan['vehicle_number'] ?? 'N/A';
    final transportMode = shipping['mode'] ?? _challan['transport_mode'] ?? 'Road';

    return Column(
      children: [
        Row(
          children: [
            _buildStatCard("Challan Date", DateFormat('dd MMM, yyyy').format(date), Icons.calendar_today_rounded),
            const SizedBox(width: 16),
            _buildStatCard("Vehicle #", vehicleNo, Icons.commute),
          ],
        ),
        const SizedBox(height: 16),
         Row(
          children: [
            _buildStatCard("Transport", transportMode, Icons.local_shipping),
            const SizedBox(width: 16),
            Expanded(child: Container()), // Spacer
          ],
        ),
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
                      Text("Quantity: ${item['quantity']}", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }


  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.edit_outlined, "Edit", () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => DeliveryChallanFormScreen(challan: _challan)));
              if (result == true && mounted) {
                 Navigator.pop(context, true);
              }
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(Icons.print_outlined, "Print", () {
              final printData = Map<String, dynamic>.from(_challan);
              printData['items'] = _items;
              PrintService.printDocument(printData, 'dc');
            })),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
              final printData = Map<String, dynamic>.from(_challan);
              printData['items'] = _items;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
              final path = await PrintService.downloadDocument(printData, 'dc');
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved successfully'), backgroundColor: Colors.green));
              }
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(Icons.share_outlined, "Share", () async {
              final printData = Map<String, dynamic>.from(_challan);
              printData['items'] = _items;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing share...'), duration: Duration(seconds: 1)));
              try {
                await PrintService.shareDocument(context, printData, 'dc');
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
      case 'delivered': return Colors.green;
      case 'shipped': return Colors.blue;
      case 'on hold': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'draft': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary));
  }
}
