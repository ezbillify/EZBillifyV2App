import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../core/theme_service.dart';
import 'credit_note_form_screen.dart';
import '../../services/print_service.dart';

class CreditNoteDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> creditNote;
  final VoidCallback onRefresh;

  const CreditNoteDetailsSheet({super.key, required this.creditNote, required this.onRefresh});

  @override
  State<CreditNoteDetailsSheet> createState() => _CreditNoteDetailsSheetState();
}

class _CreditNoteDetailsSheetState extends State<CreditNoteDetailsSheet> {
  late Map<String, dynamic> _creditNote;
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _creditNote = widget.creditNote;
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('sales_credit_note_items')
          .select('*, item:items(name, sku)')
          .eq('cn_id', _creditNote['id']);
      
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
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildQuickStats(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Returned Items"),
                    const SizedBox(height: 16),
                    _buildItemsList(),
                    const SizedBox(height: 32),
                    _buildSummaryCard(),
                    const SizedBox(height: 32),
                    _buildReason(),
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
    final status = _creditNote['status'] ?? 'open';
    final statusColor = status.toLowerCase() == 'open' ? Colors.blue : Colors.green;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_creditNote['cn_number'] ?? _creditNote['credit_note_number'] ?? '#---', style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(_creditNote['customer']?['name'] ?? 'Unknown Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textSecondary)),
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
    final dateStr = _creditNote['date']?.toString() ?? _creditNote['credit_note_date']?.toString() ?? _creditNote['created_at']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    return Row(
      children: [
        _buildStatCard("CN Date", DateFormat('dd MMM, yyyy').format(date), Icons.calendar_today_rounded),
        const SizedBox(width: 16),
        _buildStatCard("Total Amount", "₹${(_creditNote['total_amount'] ?? 0).toStringAsFixed(2)}", Icons.account_balance_wallet_outlined),
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
            Icon(icon, color: Colors.red, size: 20),
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
    if (_items.isEmpty) return Center(child: Text("No items found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)));
    
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
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.1))),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "₹${(_creditNote['sub_total'] ?? _creditNote['subtotal'] ?? 0).toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Tax", "₹${(_creditNote['tax_total'] ?? _creditNote['total_tax'] ?? 0).toStringAsFixed(2)}"),
          const Divider(height: 24),
          _buildSummaryRow("Total Credit", "₹${(_creditNote['total_amount'] ?? 0).toStringAsFixed(2)}", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: isTotal ? context.textPrimary : context.textSecondary, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isTotal ? Colors.red : context.textPrimary, fontSize: isTotal ? 18 : 14)),
      ],
    );
  }

  Widget _buildReason() {
    if (_creditNote['reason'] == null || _creditNote['reason'].toString().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Reason"),
        const SizedBox(height: 8),
        Text(_creditNote['reason'], style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(child: _buildActionButton(Icons.edit_outlined, "Edit", () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (c) => CreditNoteFormScreen(creditNote: _creditNote)));
        })),
        const SizedBox(width: 12),
        Expanded(child: _buildActionButton(Icons.print_outlined, "Print", () {
          final printData = Map<String, dynamic>.from(_creditNote);
          printData['items'] = _items;
          PrintService.printDocument(printData, 'credit_note');
        })),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool filled = false}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? Colors.red : context.cardBg,
        foregroundColor: filled ? Colors.white : context.textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: filled ? Colors.red : context.borderColor)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary));
  }
}
