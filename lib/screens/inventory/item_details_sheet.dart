import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import 'item_form_sheet.dart';

class ItemDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRefresh;

  const ItemDetailsSheet({
    super.key,
    required this.item,
    required this.onRefresh,
  });

  @override
  State<ItemDetailsSheet> createState() => _ItemDetailsSheetState();
}

class _ItemDetailsSheetState extends State<ItemDetailsSheet> {
  late Map<String, dynamic> _item;
  bool _loading = false;
  List<Map<String, dynamic>> _recentStockHistory = [];

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _fetchExtendedDetails();
  }

  Future<void> _fetchExtendedDetails() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      final companyId = profile['company_id'];

      // 1. Fetch latest item data
      final latestItem = await Supabase.instance.client
          .from('items')
          .select('*, category:categories(name), tax_rate:tax_rates(rate)')
          .eq('id', _item['id'])
          .single();
      
      // 2. Fetch real stock from inventory_stock (since total_stock can be out of sync)
      final stockRes = await Supabase.instance.client
          .from('inventory_stock')
          .select('quantity')
          .eq('company_id', companyId)
          .eq('item_id', _item['id']);
      
      double calculatedStock = 0;
      for (var row in List<Map<String, dynamic>>.from(stockRes)) {
        calculatedStock += (row['quantity'] ?? 0).toDouble();
      }

      // 3. Fetch recent stock history
      final history = await Supabase.instance.client
          .from('inventory_transactions')
          .select('*, branch:branches(name)')
          .eq('item_id', _item['id'])
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _item = latestItem;
          // Merge calculated stock back into item for display
          _item['total_stock'] = calculatedStock;
          _recentStockHistory = List<Map<String, dynamic>>.from(history);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching item details: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _editItem() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemFormSheet(item: _item),
    );
    _fetchExtendedDetails();
    widget.onRefresh();
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _buildQuickStats(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Product Information"),
                    const SizedBox(height: 16),
                    _buildInfoGrid(),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Recent Stock History"),
                    const SizedBox(height: 16),
                    _buildStockHistoryList(),
                    const SizedBox(height: 40),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _item['name'] ?? 'Unknown Item',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  _item['category']?['name'] ?? 'Uncategorized',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _editItem,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_rounded, color: AppColors.primaryBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final stock = (_item['total_stock'] ?? 0).toDouble();
    final minStock = (_item['min_stock_level'] ?? 0).toDouble();
    final isLow = stock <= minStock;

    return Row(
      children: [
        _buildStatCard(
          "Current Stock",
          "${stock % 1 == 0 ? stock.toInt() : stock} ${_item['uom'] ?? 'pcs'}",
          isLow ? Colors.red : Colors.green,
          isLow ? Icons.warning_rounded : Icons.check_circle_rounded,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
            "Sales Price (Incl.)",
            "₹${((_item['default_sales_price'] ?? 0) * (1 + (_item['tax_rate']?['rate'] ?? 0) / 100)).toStringAsFixed(2)}",
            AppColors.primaryBlue,
            Icons.sell_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
            Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: context.textPrimary,
      ),
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.qr_code_rounded, "SKU", _item['sku'] ?? 'N/A'),
          const Divider(height: 24),
          _buildInfoRow(Icons.label_outline_rounded, "Type", _item['type']?.toString().toUpperCase() ?? 'PRODUCT'),
          const Divider(height: 24),
          _buildInfoRow(Icons.shopping_cart_outlined, "Purchase Price (Incl.)", "₹${((_item['default_purchase_price'] ?? 0) * (1 + (_item['tax_rate']?['rate'] ?? 0) / 100)).toStringAsFixed(2)}"),
          const Divider(height: 24),
          _buildInfoRow(Icons.percent_rounded, "Tax Rate", "${(_item['tax_rate']?['rate'] ?? 0)}%"),
          const Divider(height: 24),
          _buildInfoRow(Icons.receipt_long_rounded, "HSN Code", _item['hsn_code'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.textSecondary.withOpacity(0.6)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary)),
      ],
    );
  }

  Widget _buildStockHistoryList() {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    if (_recentStockHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
        ),
        child: Center(child: Text("No stock transactions found", style: TextStyle(color: context.textSecondary, fontSize: 14))),
      );
    }

    return Column(
      children: _recentStockHistory.map((tx) {
        final date = DateTime.parse(tx['created_at']);
        final change = (tx['quantity_change'] ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (change >= 0 ? Colors.green : Colors.red).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  change >= 0 ? Icons.add_rounded : Icons.remove_rounded,
                  color: change >= 0 ? Colors.green : Colors.red,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['reference_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'ADJUSTMENT',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(date),
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                "${change > 0 ? '+' : ''}$change",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: change >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
