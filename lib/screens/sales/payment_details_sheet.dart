import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import '../../services/print_service.dart';

class PaymentDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onRefresh;

  const PaymentDetailsSheet({super.key, required this.payment, required this.onRefresh});

  @override
  State<PaymentDetailsSheet> createState() => _PaymentDetailsSheetState();
}

class _PaymentDetailsSheetState extends State<PaymentDetailsSheet> {
  late Map<String, dynamic> _payment;
  bool _loading = false;
  List<Map<String, dynamic>> _allocations = [];

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    _fetchAllocations();
  }

  Future<void> _fetchAllocations() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('sales_payment_allocations')
          .select('*, invoice:sales_invoices(invoice_number, total_amount)')
          .eq('payment_id', _payment['id']);
      
      if (mounted) {
        setState(() {
          _allocations = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching allocations: $e");
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
                  _buildSectionHeader("Allocated To Invoices"),
                  const SizedBox(height: 16),
                  _buildAllocationsList(),
                  const SizedBox(height: 32),
                  _buildNotes(),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_payment['payment_number'] ?? '#---', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(_payment['customer']?['name'] ?? 'Unknown Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
          child: Text("RECEIVED", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final dateStr = _payment['date']?.toString() ?? _payment['payment_date']?.toString() ?? _payment['created_at']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard("Payment Date", DateFormat('dd MMM, yyyy').format(date), Icons.calendar_today_rounded),
            const SizedBox(width: 16),
            _buildStatCard("Amount Received", "₹${(_payment['amount'] ?? 0).toStringAsFixed(2)}", Icons.payments_rounded),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard("Payment Mode", _payment['payment_mode'] ?? 'Cash', Icons.account_balance_wallet_rounded),
            const SizedBox(width: 16),
            _buildStatCard("Reference #", _payment['reference_number'] ?? 'N/A', Icons.tag_rounded),
          ],
        ),
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
              Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllocationsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_allocations.isEmpty) return Center(child: Text("No allocations found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)));
    
    return Column(
      children: _allocations.map((a) => Padding(
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
                      Text(a['invoice']?['invoice_number'] ?? 'Invoice', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("Total: ₹${a['invoice']?['total_amount'] ?? 0}", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${(a['amount'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                    Text("Allocated", style: TextStyle(fontSize: 10, color: context.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildNotes() {
    if (_payment['notes'] == null || _payment['notes'].toString().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Notes"),
        const SizedBox(height: 8),
        Text(_payment['notes'], style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.print_outlined, "Print Receipt", () {
              final printData = Map<String, dynamic>.from(_payment);
              printData['items'] = _allocations.map((a) => {
                'item': {'name': a['invoice']?['invoice_number']},
                'quantity': 1,
                'unit_price': a['amount'],
              }).toList();
              PrintService.printDocument(printData, 'payment');
            }, filled: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildActionButton(Icons.file_download_outlined, "Download", () async {
              final printData = Map<String, dynamic>.from(_payment);
              printData['items'] = _allocations.map((a) => {
                'item': {'name': a['invoice']?['invoice_number']},
                'quantity': 1,
                'unit_price': a['amount'],
              }).toList();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...'), duration: Duration(seconds: 1)));
              final path = await PrintService.downloadDocument(printData, 'payment');
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved successfully'), backgroundColor: Colors.green));
              }
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildActionButton(Icons.share_outlined, "Share", () async {
              final printData = Map<String, dynamic>.from(_payment);
              printData['items'] = _allocations.map((a) => {
                'item': {'name': a['invoice']?['invoice_number']},
                'quantity': 1,
                'unit_price': a['amount'],
              }).toList();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing share...'), duration: Duration(seconds: 1)));
              try {
                await PrintService.shareDocument(context, printData, 'payment');
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

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary));
  }
}
