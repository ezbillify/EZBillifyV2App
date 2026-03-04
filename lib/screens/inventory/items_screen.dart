
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import 'item_details_sheet.dart';
import 'item_form_sheet.dart';
import 'package:intl/intl.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  static const int _pageSize = 20;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  List<Map<String, dynamic>> _items = [];
  String _searchQuery = '';
  String _sortOption = 'name_asc';
  String _filterStock = 'all'; // 'all', 'low', 'out'
  String? _companyId;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initData();
    _searchFocusNode.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && !_loading) {
        _fetchItems(isLoadMore: true);
      }
    }
  }

  Future<void> _initData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      _companyId = profile['company_id'];
      _fetchItems();
    } catch (e) {
      debugPrint("Error initializing items: $e");
    }
  }

  Future<void> _fetchItems({bool isLoadMore = false}) async {
    if (_companyId == null) return;
    
    if (isLoadMore) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _items = [];
        _hasMore = true;
      });
    }

    try {
      final from = _items.length;
      final to = from + _pageSize - 1;

      var query = Supabase.instance.client
          .from('items')
          .select('*, category:categories(name), tax_rate:tax_rates(rate)')
          .eq('company_id', _companyId!);
          
      if (_searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$_searchQuery%');
      }
      
      // We need to apply ordering and then cast to appropriate builder for range
      dynamic orderedQuery = query;
      if (_sortOption == 'name_asc') {
        orderedQuery = orderedQuery.order('name', ascending: true);
      } else if (_sortOption == 'name_desc') {
        orderedQuery = orderedQuery.order('name', ascending: false);
      } else if (_sortOption == 'price_asc') {
        orderedQuery = orderedQuery.order('default_sales_price', ascending: true);
      } else if (_sortOption == 'price_desc') {
        orderedQuery = orderedQuery.order('default_sales_price', ascending: false);
      }

      final response = await orderedQuery.range(from, to);
      var finalItems = List<Map<String, dynamic>>.from(response);

      // Resolve Real Stock (in case items.total_stock is out of sync)
      if (finalItems.isNotEmpty) {
        final itemIds = finalItems.map((i) => i['id']).toList();
        final stockRes = await Supabase.instance.client
            .from('inventory_stock')
            .select('item_id, quantity')
            .inFilter('item_id', itemIds);
        
        final Map<String, double> stockMap = {};
        for (var row in List<Map<String, dynamic>>.from(stockRes)) {
          final id = row['item_id'].toString();
          stockMap[id] = (stockMap[id] ?? 0) + (row['quantity'] ?? 0).toDouble();
        }

        for (var item in finalItems) {
          item['total_stock'] = stockMap[item['id'].toString()] ?? 0;
        }
        // Apply post-fetch stock filters if necessary
        if (_filterStock == 'low') {
          finalItems = finalItems.where((i) => (i['total_stock'] ?? 0) <= (i['min_stock_level'] ?? 0) && (i['total_stock'] ?? 0) > 0).toList();
        } else if (_filterStock == 'out') {
          finalItems = finalItems.where((i) => (i['total_stock'] ?? 0) <= 0).toList();
        }
      }

      if (mounted) {
        setState(() {
          _items.addAll(finalItems);
          _loading = false;
          _loadingMore = false;
          _hasMore = response.length == _pageSize; // Use response length, not filtered items length
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
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
      body: RefreshIndicator(
        onRefresh: () => _fetchItems(),
        color: AppColors.primaryBlue,
        backgroundColor: context.cardBg,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(),
            _buildSummaryHeader(),
            _buildSearchBar(),
            _loading 
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              : _items.isEmpty 
                ? SliverFillRemaining(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: context.textSecondary.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text("No items found", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, color: context.textSecondary.withOpacity(0.5))),
                      ],
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _items.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: _hasMore 
                                  ? const CircularProgressIndicator() 
                                  : Text("End of list", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 12))
                              ),
                            );
                          }
                          return _buildItemMasterCard(_items[index]);
                        },
                        childCount: _items.length + 1,
                      ),
                    ),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const ItemFormSheet(),
          );
          if (result == true) _fetchItems();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Item", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      leadingWidth: 40,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text("Items Master", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 24)),
      actions: [
        IconButton(
          onPressed: _showFilterSortSheet,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.borderColor)),
            child: Icon(Icons.tune_rounded, color: context.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showFilterSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.only(bottom: 24, left: 160)),
              Text("Sort & Filter", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 24),
              Text("Sort By", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: context.textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSortChip("A to Z", 'name_asc', setModalState),
                  _buildSortChip("Z to A", 'name_desc', setModalState),
                  _buildSortChip("Price: Low to High", 'price_asc', setModalState),
                  _buildSortChip("Price: High to Low", 'price_desc', setModalState),
                ],
              ),
              const SizedBox(height: 24),
              Text("Filter by Stock", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: context.textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip("All Items", 'all', setModalState),
                  _buildFilterChip("Low Stock", 'low', setModalState),
                  _buildFilterChip("Out of Stock", 'out', setModalState),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchItems();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Apply", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value, StateSetter setModalState) {
    final isSelected = _sortOption == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontFamily: 'Outfit', color: isSelected ? Colors.white : context.textPrimary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      backgroundColor: context.cardBg,
      selectedColor: AppColors.primaryBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.primaryBlue : context.borderColor)),
      showCheckmark: false,
      onSelected: (val) {
        setModalState(() => _sortOption = value);
      },
    );
  }

  Widget _buildFilterChip(String label, String value, StateSetter setModalState) {
    final isSelected = _filterStock == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontFamily: 'Outfit', color: isSelected ? Colors.white : context.textPrimary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      backgroundColor: context.cardBg,
      selectedColor: AppColors.primaryBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.primaryBlue : context.borderColor)),
      showCheckmark: false,
      onSelected: (val) {
        setModalState(() => _filterStock = value);
      },
    );
  }

  Widget _buildSummaryHeader() {    final totalItems = _items.length;
    final lowStockCount = _items.where((i) => (i['total_stock'] ?? 0) <= (i['min_stock_level'] ?? 0)).length;
    
    return SliverToBoxAdapter(
      child: Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _buildSummaryCard("Total Types", totalItems.toString(), Icons.layers_rounded, AppColors.primaryBlue),
            const SizedBox(width: 12),
            _buildSummaryCard("Low Stock", lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange),
            const SizedBox(width: 12),
            _buildSummaryCard("Total Value", "₹${NumberFormat.compact().format(_items.fold(0.0, (sum, i) => sum + ((i['total_stock'] ?? 0) * (i['default_sales_price'] ?? 0))))}", Icons.account_balance_wallet_rounded, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _searchFocusNode.hasFocus 
              ? AppColors.primaryBlue.withOpacity(0.04) 
              : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocusNode.hasFocus 
                ? AppColors.primaryBlue 
                : context.textSecondary.withOpacity(0.2),
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
              cursorColor: AppColors.primaryBlue,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: "Search item name or SKU...",
                hintStyle: TextStyle(
                  fontFamily: 'Outfit', 
                  color: context.textSecondary.withOpacity(0.4), 
                  fontSize: 15
                ),
                prefixIcon: Icon(
                  Icons.search_rounded, 
                  color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.4), 
                  size: 22
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primaryBlue), 
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _fetchItems();
                      }
                    ) 
                  : null,
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _fetchItems();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemMasterCard(Map<String, dynamic> item) {
    final bool isLowStock = (item['total_stock'] ?? 0) <= (item['min_stock_level'] ?? 0);
    final bool isOutOfStock = (item['total_stock'] ?? 0) <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => ItemDetailsSheet(item: item, onRefresh: _fetchItems),
          );
          _fetchItems();
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isOutOfStock ? Colors.red : isLowStock ? Colors.orange : AppColors.primaryBlue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isOutOfStock ? Icons.error_outline_rounded : isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                  color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '', 
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          item['category'] != null ? item['category']['name'] : 'Uncategorized', 
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary),
                        ),
                        if (item['sku'] != null && item['sku'].toString().isNotEmpty) ...[
                          Text(" • ", style: TextStyle(color: context.textSecondary.withOpacity(0.3))),
                          Text(item['sku'].toString(), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "${item['total_stock'] ?? 0} ${item['uom'] ?? 'pcs'}", 
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${((item['default_sales_price'] ?? 0) * (1 + (item['tax_rate']?['rate'] ?? 0) / 100)).toStringAsFixed(2)}",
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primaryBlue),
                  ),
                  Text("Incl. Tax", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary.withOpacity(0.5))),
                  const SizedBox(height: 12),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.textSecondary.withOpacity(0.2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
