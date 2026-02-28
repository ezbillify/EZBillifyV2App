import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'sales_order_form_screen.dart';
import 'customers_screen.dart';
import 'order_details_sheet.dart';
import '../../services/sales_refresh_service.dart';

class SalesOrdersScreen extends StatefulWidget {
  final bool showAppBar;
  const SalesOrdersScreen({super.key, this.showAppBar = true});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String _filterStatus = 'all';
  bool _showArchived = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  RealtimeChannel? _realtimeChannel;
  String? _cachedCompanyId;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _initOrders();
    SalesRefreshService.refreshNotifier.addListener(_fetchOrders);
  }

  Future<void> _initOrders() async {
    // Staggered delay to prevent DNS query burst across multiple tabs
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchOrders();
    if (mounted) _setupRealtime();
  }

  void _setupRealtime() async {
    final companyId = _cachedCompanyId;
    if (companyId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('public:sales_orders:company_id=eq.$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (payload) {
            _fetchOrders();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    SalesRefreshService.refreshNotifier.removeListener(_fetchOrders);
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (_orders.isEmpty && mounted) setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      final String companyId;
      if (_cachedCompanyId != null) {
        companyId = _cachedCompanyId!;
      } else {
        final profile = await Supabase.instance.client
            .from('users')
            .select('company_id')
            .eq('auth_id', user.id)
            .maybeSingle();

        if (profile == null || profile['company_id'] == null) {
          debugPrint("Sales Orders: Profile or Company ID not found for user ${user.id}");
          if (mounted) {
            setState(() {
              _orders = [];
              _loading = false;
            });
          }
          return;
        }
        companyId = profile['company_id'];
        _cachedCompanyId = companyId;
      }
      
      var query = Supabase.instance.client
          .from('sales_orders')
          .select('*, customer:customers(name)')
          .eq('company_id', companyId);
          
      if (_showArchived) {
        query = query.eq('is_active', false);
      } else {
        query = query.or('is_active.is.null,is_active.eq.true');
      }

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.or('so_number.ilike.%$_searchQuery%,customer:customers.name.ilike.%$_searchQuery%');
      }
      
      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (mounted) {
        setState(() {
          _orders = [];
          _loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': 
      case 'completed': return Colors.green;
      case 'pending': 
      case 'draft': return Colors.orange;
      case 'cancelled': 
      case 'rejected': return Colors.red;
      case 'shipped': return Colors.blue;
      case 'delivered': return Colors.teal;
      case 'partially_delivered': return Colors.indigo;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesOrderFormScreen()));
          if (result == true) _fetchOrders();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Create Order", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearchAndFilters(),
            _buildOrderList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      title: Text("Sales Orders", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
      actions: [
        IconButton(
          icon: Icon(Icons.people_alt_outlined, color: context.textPrimary),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomersScreen())),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _searchFocusNode.hasFocus ? AppColors.primaryBlue.withOpacity(0.04) : context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.2),
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
                    hintText: "Search order # or customer...",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15),
                    prefixIcon: Icon(
                      Icons.search_rounded, 
                      color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.4), 
                      size: 22
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primaryBlue), 
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _fetchOrders();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchOrders();
                  },
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All Orders', 'all'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Confirmed', 'confirmed'),
                _buildFilterChip('Shipped', 'shipped'),
                _buildFilterChip('Delivered', 'delivered'),
                _buildFilterChip('Cancelled', 'cancelled'),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: context.borderColor),
                const SizedBox(width: 12),
                _buildArchivedToggle(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_orders.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_bag_outlined, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No orders found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final order = _orders[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildOrderCard(order),
            );
          },
          childCount: _orders.length,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);
    final dateStr = order['date']?.toString() ?? order['order_date']?.toString() ?? order['created_at']?.toString() ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final customerName = (order['customer'] != null && order['customer']['name'] != null) 
        ? order['customer']['name'].toString() 
        : (order['customer_name'] ?? 'Unknown Customer').toString();

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
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            clipBehavior: Clip.antiAlias,
            useSafeArea: true,
            builder: (context) => OrderDetailsSheet(
              order: order,
              onRefresh: _fetchOrders,
            ),
          );
          _fetchOrders();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(order['so_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.business_rounded, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customerName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                        Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${NumberFormat('#,##,###.00').format(order['total_amount'] ?? 0)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) {
          setState(() => _filterStatus = value);
          _fetchOrders();
        },
        backgroundColor: context.cardBg,
        selectedColor: AppColors.primaryBlue.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryBlue : context.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Outfit',
          fontSize: 13,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
           side: BorderSide(color: isSelected ? AppColors.primaryBlue : context.borderColor),
        ),
      ),
    );
  }

  Widget _buildArchivedToggle() {
    return FilterChip(
      label: const Text("Show Archived"),
      selected: _showArchived,
      onSelected: (v) {
        setState(() => _showArchived = v);
        _fetchOrders();
      },
      backgroundColor: context.cardBg,
      selectedColor: Colors.red.withOpacity(0.1),
      labelStyle: TextStyle(
        color: _showArchived ? Colors.red : context.textSecondary,
        fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'Outfit',
        fontSize: 13,
      ),
      showCheckmark: false,
      avatar: Icon(Icons.archive_outlined, size: 16, color: _showArchived ? Colors.red : context.textSecondary),
      shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: BorderSide(color: _showArchived ? Colors.red : context.borderColor),
      ),
    );
  }
}
