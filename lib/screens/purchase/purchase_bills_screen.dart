import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'vendors_screen.dart';
import 'purchase_bill_form_screen.dart';
import 'purchase_bill_details_sheet.dart';
import '../../services/purchase_refresh_service.dart';

class PurchaseBillsScreen extends StatefulWidget {
  final bool showAppBar;
  const PurchaseBillsScreen({super.key, this.showAppBar = true});

  @override
  State<PurchaseBillsScreen> createState() => _PurchaseBillsScreenState();
}

class _PurchaseBillsScreenState extends State<PurchaseBillsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _bills = [];
  String _filterStatus = 'all';
  String _searchQuery = '';
  String _sortBy = 'created_at';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _cachedCompanyId;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _initBills();
    PurchaseRefreshService.refreshNotifier.addListener(_fetchBills);
  }

  Future<void> _initBills() async {
    // 100ms stagger for purchase bill tab
    await Future.delayed(const Duration(milliseconds: 100));
    await _fetchBills();
    if (mounted) _setupRealtime();
  }

  void _setupRealtime() {
    final companyId = _cachedCompanyId;
    if (companyId == null) return;
    
    _realtimeChannel = Supabase.instance.client
        .channel('public:purchase_bills:company_id=eq.$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_bills',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (payload) => _fetchBills(),
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
    PurchaseRefreshService.refreshNotifier.removeListener(_fetchBills);
    super.dispose();
  }
  
  Future<void> _fetchBills() async {
    if (_bills.isEmpty && mounted) setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
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
          if (mounted) setState(() => _loading = false);
          return;
        }
        companyId = profile['company_id'];
        _cachedCompanyId = companyId;
      }
      
      var query = Supabase.instance.client
          .from('purchase_bills')
          .select('*, vendor:vendors(name)')
          .eq('company_id', companyId);
          
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.or('bill_number.ilike.%$_searchQuery%');
      }
      
      final response = await query.order(_sortBy, ascending: _sortAscending);
      
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
      
      if (_searchQuery.isNotEmpty) {
        results = results.where((o) {
          final billMatch = (o['bill_number'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
          final vendorMatch = (o['vendor']?['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
          return billMatch || vendorMatch;
        }).toList();
      }
      
      if (mounted) {
        setState(() {
          _bills = results;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching bills: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid': return Colors.green;
      case 'partial': return Colors.orange;
      case 'overdue': return Colors.red;
      case 'draft': return Colors.grey;
      case 'open': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseBillFormScreen()));
          if (result == true) _fetchBills();
          // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Create bill coming soon")));
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Create Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchBills,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearchAndFilters(),
            _buildBillList(),
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
      title: Text("Purchase Invoices", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.sort_rounded, color: context.textPrimary),
          onSelected: (val) {
            setState(() {
              if (val == 'newest') { _sortBy = 'created_at'; _sortAscending = false; }
              else if (val == 'oldest') { _sortBy = 'created_at'; _sortAscending = true; }
              else if (val == 'amount_high') { _sortBy = 'total_amount'; _sortAscending = false; }
              else if (val == 'amount_low') { _sortBy = 'total_amount'; _sortAscending = true; }
            });
            _fetchBills();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'newest', child: Text('Newest First')),
            const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
            const PopupMenuItem(value: 'amount_high', child: Text('Amount: High to Low')),
            const PopupMenuItem(value: 'amount_low', child: Text('Amount: Low to High')),
          ],
        ),
        IconButton(
          icon: Icon(Icons.store_outlined, color: context.textPrimary),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VendorsScreen())),
          tooltip: "Manage Vendors",
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
                    hintText: "Search bill # or vendor...",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15),
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
                            _fetchBills();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchBills();
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
                _buildFilterChip('All Bills', 'all'),
                _buildFilterChip('Open', 'open'),
                _buildFilterChip('Paid', 'paid'),
                _buildFilterChip('Overdue', 'overdue'),
                _buildFilterChip('Draft', 'draft'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBillList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_bills.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_rounded, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No invoices found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
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
            final bill = _bills[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildBillCard(bill),
            );
          },
          childCount: _bills.length,
        ),
      ),
    );
  }

  Widget _buildBillCard(Map<String, dynamic> bill) {
    final status = bill['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);
    final date = DateTime.tryParse(bill['date']?.toString() ?? '') ?? 
                 DateTime.tryParse(bill['created_at']?.toString() ?? '') ?? 
                 DateTime.now();
    final vendorName = (bill['vendor'] != null && bill['vendor']['name'] != null) 
        ? bill['vendor']['name'].toString() 
        : 'Unknown Vendor';

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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            builder: (context) => PurchaseBillDetailsSheet(
              bill: bill,
              onRefresh: _fetchBills,
            ),
          );
          _fetchBills();
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
                    child: Text(bill['bill_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
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
                    child: Icon(Icons.store_rounded, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendorName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                        Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${NumberFormat('#,##,###.00').format(bill['total_amount'] ?? 0)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      // Helper logic for due amount if not present directly
                      if (status.toLowerCase() != 'paid')
                        Text("Due", style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
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
          _fetchBills();
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
}
