
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import 'item_details_sheet.dart';
import 'item_form_sheet.dart';

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
      
      final response = await query
          .order('name', ascending: true)
          .range(from, to);
      final List<Map<String, dynamic>> finalItems = List<Map<String, dynamic>>.from(response);

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
      }

      if (mounted) {
        setState(() {
          _items.addAll(finalItems);
          _loading = false;
          _loadingMore = false;
          _hasMore = finalItems.length == _pageSize;
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
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          _buildSearchBar(),
          _loading 
            ? const SliverToBoxAdapter(child: LinearProgressIndicator())
            : _items.isEmpty 
              ? const SliverFillRemaining(child: Center(child: Text("No items found")))
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _items.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: _hasMore ? const CircularProgressIndicator() : const Text("End of list", style: TextStyle(color: Colors.grey, fontSize: 12))),
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
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      title: Text("Items Master", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            builder: (context) => ItemDetailsSheet(
              item: item,
              onRefresh: _fetchItems,
            ),
          );
          _fetchItems();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? '', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text(item['category'] != null ? item['category']['name'] : 'Uncategorized', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: (item['total_stock'] ?? 0) <= (item['min_stock_level'] ?? 0) ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text("${item['total_stock'] ?? 0} ${item['uom'] ?? 'pcs'}", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: (item['total_stock'] ?? 0) <= (item['min_stock_level'] ?? 0) ? Colors.red : Colors.green)),
                    ),
                  ],
                ),
              ),
               Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    "₹${((item['default_sales_price'] ?? 0) * (1 + (item['tax_rate']?['rate'] ?? 0) / 100)).toStringAsFixed(2)}",
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                  ),
                  Text("Incl. Tax", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
