
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:ui';
import '../../core/theme_service.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  static const int _pageSize = 20;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _stockRecords = [];
  String _searchQuery = '';
  RealtimeChannel? _channel;
  String? _companyId;
  String? _userId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchTimer;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = 'All Branches'

  @override
  void initState() {
    super.initState();
    _initData();
    _searchFocusNode.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && !_loading) {
        _fetchStockData(isLoadMore: true);
      }
    }
  }

  void _onSearchChanged(String v) {
    if (_searchTimer?.isActive ?? false) _searchTimer!.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = v;
          _fetchStockData();
        });
      }
    });
  }

  Future<void> _initData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      _companyId = profile['company_id'];

    // Fetch Branches
    try {
      final branchesRes = await Supabase.instance.client
          .from('branches')
          .select('id, name')
          .eq('company_id', _companyId!)
          .order('name');
      _branches = List<Map<String, dynamic>>.from(branchesRes);
    } catch (e) {
      debugPrint("Stock Hub: Branches fetch error: $e");
    }
      _fetchStockData();

      _channel = Supabase.instance.client
          .channel('inventory_stock_realtime_v2')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory_stock',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: _companyId,
            ),
            callback: (payload) => _fetchStockData(),
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error initializing stock realtime: $e");
    }
  }

  Future<void> _fetchStockData({bool isLoadMore = false}) async {
    if (_companyId == null) return;
    
    if (isLoadMore) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _stockRecords = [];
        _hasMore = true;
      });
    }

    try {
      final from = _stockRecords.length;
      final to = from + _pageSize - 1;

      final String selectStr = _searchQuery.isNotEmpty 
          ? '*, item:items!inner(*, category:categories(name)), branch:branches(name)'
          : '*, item:items(*, category:categories(name)), branch:branches(name)';

      var query = Supabase.instance.client
          .from('inventory_stock')
          .select(selectStr)
          .eq('company_id', _companyId!);
          
      if (_selectedBranchId != null) {
        query = query.eq('branch_id', _selectedBranchId!);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$_searchQuery%,sku.ilike.%$_searchQuery%', referencedTable: 'item');
      }

      final response = await query
          .order('id', ascending: true)
          .range(from, to);
      final List<Map<String, dynamic>> newRecords = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _stockRecords.addAll(newRecords);
          _loading = false;
          _loadingMore = false;
          _hasMore = newRecords.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stock data: $e");
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          _buildSearchBar(),
          _loading 
            ? const SliverToBoxAdapter(child: LinearProgressIndicator())
            : _stockRecords.isEmpty 
              ? const SliverFillRemaining(child: Center(child: Text("No stock records found")))
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                         if (index >= _stockRecords.length) {
                           return Padding(
                             padding: const EdgeInsets.symmetric(vertical: 32),
                             child: Center(child: _hasMore ? const CircularProgressIndicator() : const Text("End of list", style: TextStyle(color: Colors.grey, fontSize: 12))),
                           );
                         }
                         return _buildStockCard(_stockRecords[index]);
                      },
                      childCount: _stockRecords.length + 1,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Stock Activity", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
          InkWell(
            onTap: _showBranchSelector,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, size: 12, color: AppColors.primaryBlue),
                const SizedBox(width: 4),
                Text(
                  _branches.firstWhere((b) => b['id'] == _selectedBranchId, orElse: () => {'name': 'All Branches'})['name'],
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.primaryBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            color: _searchFocusNode.hasFocus ? AppColors.primaryBlue.withOpacity(0.04) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.borderColor,
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: "Search item name in stock...",
                hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15),
                prefixIcon: Icon(Icons.search_rounded, color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> record) {
    final item = record['item'];
    if (item == null) return const SizedBox();
    
    final stock = (record['quantity'] ?? 0).toDouble();
    final minStock = (item['min_stock_level'] ?? 0).toDouble();
    final isLow = stock <= minStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () => _showAdjustmentSheet(record),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unknown Item',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                         Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 10, color: AppColors.primaryBlue),
                              const SizedBox(width: 4),
                              Text(record['branch']?['name'] ?? 'General', style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (item['sku'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: context.borderColor.withOpacity(0.5), borderRadius: BorderRadius.circular(6)),
                            child: Text(item['sku'], style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$stock ${item['uom'] ?? 'pcs'}",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : context.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLow ? "Low Stock" : "In Stock",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: isLow ? Colors.orange : Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdjustmentSheet(Map<String, dynamic> record) {
    bool isAdding = true;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final item = record['item'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: context.surfaceBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.warehouse_rounded, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Adjust Stock", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("${item['name']} - ${record['branch']?['name']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _buildModeBtn("STOCK IN", Icons.add_circle_outline_rounded, Colors.green, isAdding, () => setModalState(() => isAdding = true)),
                      const SizedBox(width: 16),
                      _buildModeBtn("STOCK OUT", Icons.remove_circle_outline_rounded, Colors.red, !isAdding, () => setModalState(() => isAdding = false)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Quantity",
                      labelStyle: TextStyle(fontFamily: 'Outfit', fontSize: 14),
                      suffixText: item['uom'] ?? '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: context.cardBg,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: "Reason (Optional)",
                      labelStyle: TextStyle(fontFamily: 'Outfit', fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: context.cardBg,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        final val = double.tryParse(amountController.text);
                        if (val == null || val <= 0) return;
                        
                        _handleStockUpdate(record, isAdding ? val : -val, reasonController.text);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAdding ? Colors.green : Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text("Confirm Adjustment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleStockUpdate(Map<String, dynamic> record, double change, String reason) async {
    try {
      final currentQty = (record['quantity'] ?? 0).toDouble();
      final newQty = currentQty + change;
      if (newQty < 0) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action failed: Insufficient stock")));
         return;
      }

      await Supabase.instance.client
          .from('inventory_stock')
          .update({'quantity': newQty, 'last_updated': DateTime.now().toIso8601String()})
          .eq('id', record['id']);

      await Supabase.instance.client.from('inventory_transactions').insert({
        'company_id': _companyId,
        'item_id': record['item_id'],
        'branch_id': record['branch_id'],
        'transaction_type': 'adjustment',
        'quantity_change': change,
        'new_balance': newQty,
        'unit_cost': record['average_cost'] ?? 0,
        'reference_type': 'manual_adjustment',
        'notes': reason.isEmpty ? 'Manual Adjustment' : reason,
        'created_by': _userId,
      });
      
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint("Update failed: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildModeBtn(String label, IconData icon, Color color, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : context.borderColor, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : context.textSecondary, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontFamily: 'Outfit', color: selected ? color : context.textSecondary, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  void _showBranchSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: context.surfaceBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.location_on_rounded, color: AppColors.primaryBlue, size: 20)),
                const SizedBox(width: 16),
                const Text("Select Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildBranchTile(null, "All Branches"),
                  ..._branches.map((b) => _buildBranchTile(b['id'], b['name'])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchTile(String? id, String name) {
    bool isSelected = _selectedBranchId == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedBranchId = id;
          _loading = true;
          _stockRecords = [];
          _hasMore = true;
        });
        Navigator.pop(context);
        _fetchStockData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.transparent),
        ),
        child: Row(
          children: [
            Text(name, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }
}
