import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import 'items_screen.dart';
import 'stock_management_screen.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  bool _loading = true;
  int _totalItems = 0;
  int _lowStockCount = 0;
  double _totalInventoryValue = 0;
  int _outOfStockCount = 0;
  List<Map<String, dynamic>> _topCategories = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _recentTransactions = [];
  RealtimeChannel? _channel;
  String? _companyId;
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null = 'All Branches'

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initData() async {
    await _fetchDashboardData();
    
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

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
      debugPrint("Inventory Hub: Branches fetch error: $e");
    }

    _channel = Supabase.instance.client
        .channel('inventory_dashboard_pro_sync_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_stock',
          callback: (payload) => _fetchDashboardData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'items',
          callback: (payload) => _fetchDashboardData(),
        )
        .subscribe();
  }

  /// Paginated fetch helper — mirrors the web app's fetchAll() to avoid the
  /// Supabase 1000-row default limit silently truncating results.
  Future<List<Map<String, dynamic>>> _fetchAll({
    required String table,
    required String select,
    required String companyId,
    String? eqBranch,
  }) async {
    const pageSize = 1000;
    int page = 0;
    List<Map<String, dynamic>> allRecords = [];
    bool hasMore = true;

    while (hasMore) {
      var query = Supabase.instance.client
          .from(table)
          .select(select)
          .eq('company_id', companyId);

      if (eqBranch != null) query = query.eq('branch_id', eqBranch);

      final response = await query.range(page * pageSize, (page + 1) * pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response as List);

      allRecords.addAll(rows);

      if (rows.length < pageSize) {
        hasMore = false;
      } else {
        page++;
        if (page > 50) break; // Safety cap
      }
    }
    return allRecords;
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .maybeSingle();
      
      if (profile == null) {
        debugPrint("Inventory Hub: Profile not found for user ${user.id}");
        setState(() => _loading = false);
        return;
      }
      
      final companyId = profile['company_id'];
      debugPrint("Inventory Hub: Fetching data for company $companyId");

      // 1. Total Items & Out of Stock - Use exact counts for performance
      try {
        if (_selectedBranchId == null) {
          final totalRes = await Supabase.instance.client
              .from('items')
              .select('id')
              .eq('company_id', companyId)
              .count(CountOption.exact);
          _totalItems = totalRes.count ?? 0;

          final oosRes = await Supabase.instance.client
              .from('items')
              .select('id')
              .eq('company_id', companyId)
              .lte('total_stock', 0)
              .count(CountOption.exact);
          _outOfStockCount = oosRes.count ?? 0;
        } else {
          final totalRes = await Supabase.instance.client
              .from('inventory_stock')
              .select('id')
              .eq('company_id', companyId)
              .eq('branch_id', _selectedBranchId!)
              .count(CountOption.exact);
          _totalItems = totalRes.count ?? 0;

          final oosRes = await Supabase.instance.client
              .from('inventory_stock')
              .select('id')
              .eq('company_id', companyId)
              .eq('branch_id', _selectedBranchId!)
              .lte('quantity', 0)
              .count(CountOption.exact);
          _outOfStockCount = oosRes.count ?? 0;
        }
      } catch (e) {
        debugPrint("Inventory Hub: Count error: $e");
      }

      // 2. Critical Alerts Preview & Actual Count
      try {
        if (_selectedBranchId == null) {
          // Fetch ALL possible low stock items using paginated helper
          final allItems = await _fetchAll(
            table: 'items',
            select: 'name, total_stock, min_stock_level',
            companyId: companyId,
          );
          
          final filtered = allItems
              .where((i) => (i['total_stock'] ?? 0) < (i['min_stock_level'] ?? 1))
              .toList();
          
          _lowStockCount = filtered.length;
          _lowStockItems = filtered.take(3).toList();
        } else {
          final allStock = await _fetchAll(
            table: 'inventory_stock',
            select: 'quantity, item:items(name, min_stock_level)',
            companyId: companyId,
            eqBranch: _selectedBranchId,
          );
          
          final filtered = allStock
              .where((s) => (s['quantity'] ?? 0) < (s['item']?['min_stock_level'] ?? 1))
              .toList();

          _lowStockCount = filtered.length;
          _lowStockItems = filtered.take(3).map((s) => {
            'name': s['item']?['name'] ?? 'Unknown',
            'total_stock': s['quantity'],
            'min_stock_level': s['item']?['min_stock_level']
          }).toList();
        }
      } catch (e) {
        debugPrint("Inventory Hub: Alerts error: $e");
      }

      // 3. Recent Transactions - Just limit(5) is fine here
      try {
        var txQuery = Supabase.instance.client
            .from('inventory_transactions')
            .select('*, item:items(name)')
            .eq('company_id', companyId);
        
        if (_selectedBranchId != null) {
          txQuery = txQuery.eq('branch_id', _selectedBranchId!);
        }

        final txRes = await txQuery.order('created_at', ascending: false).limit(5);
        _recentTransactions = List<Map<String, dynamic>>.from(txRes);
      } catch (e) {
        debugPrint("Inventory Hub: TX error: $e");
      }

      // 4. Category Chart (Sampling for performance)
      try {
        if (_selectedBranchId == null) {
          // Don't fetch ALL for chart to avoid UI lag, 1000 items is a good statistical sample
          final sampleRes = await Supabase.instance.client
              .from('items')
              .select('category:categories(name)')
              .eq('company_id', companyId)
              .limit(1000);
              
          final Map<String, int> counts = {};
          for (var row in List<Map<String, dynamic>>.from(sampleRes)) {
              final name = row['category']?['name'] ?? 'Uncategorized';
              counts[name] = (counts[name] ?? 0) + 1;
          }
          _topCategories = counts.entries
              .map((e) => {'name': e.key, 'count': e.value})
              .toList();
        } else {
          final sampleRes = await Supabase.instance.client
              .from('inventory_stock')
              .select('item:items(category:categories(name))')
              .eq('company_id', companyId)
              .eq('branch_id', _selectedBranchId!)
              .limit(1000);
          
          final Map<String, int> counts = {};
          for (var row in List<Map<String, dynamic>>.from(sampleRes)) {
              final name = row['item']?['category']?['name'] ?? 'Others';
              counts[name] = (counts[name] ?? 0) + 1;
          }
          _topCategories = counts.entries
              .map((e) => {'name': e.key, 'count': e.value})
              .toList();
        }
        _topCategories.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
        _topCategories = _topCategories.take(5).toList();
      } catch (e) {
        debugPrint("Inventory Hub: Chart error: $e");
      }

      // 5. Precise Value Calculation (ALL records sum)
      try {
        final valRes = await _fetchAll(
          table: 'inventory_stock',
          select: 'quantity, average_cost',
          companyId: companyId,
          eqBranch: _selectedBranchId,
        );
        
        _totalInventoryValue = 0;
        for (var row in valRes) {
            final qty = (row['quantity'] ?? 0).toDouble();
            final cost = (row['average_cost'] ?? 0).toDouble();
            if (qty > 0 && cost > 0) {
              _totalInventoryValue += (qty * cost);
            }
        }
      } catch (e) {
        debugPrint("Inventory Hub: Value error: $e");
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint("Inventory Hub: Critical dashboard error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: _loading 
                ? const LinearProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickStats(),
                        const SizedBox(height: 32),
                        _buildSectionHeader("Inventory Insights"),
                        const SizedBox(height: 16),
                        _buildChartSection(),
                        const SizedBox(height: 32),
                        if (_recentTransactions.isNotEmpty) ...[
                          _buildSectionHeader("Recent Adjustments"),
                          const SizedBox(height: 16),
                          _buildRecentTransactions(),
                          const SizedBox(height: 32),
                        ],
                        _buildSectionHeader("Critical Alerts"),
                        const SizedBox(height: 16),
                        _buildLowStockPreview(),
                        const SizedBox(height: 32),
                        _buildSectionHeader("Operations"),
                        const SizedBox(height: 16),
                        _buildNavigationGrid(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      centerTitle: false,
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Inventory Hub", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 24)),
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
      actions: [
        IconButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk Import coming soon!"))),
          icon: Icon(Icons.cloud_upload_outlined, color: AppColors.primaryBlue),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w900, color: context.textSecondary.withOpacity(0.6), letterSpacing: 1.5),
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        _buildStatCard("Total Value", "₹${NumberFormat.compact().format(_totalInventoryValue)}", Icons.account_balance_wallet_rounded, Colors.green),
        _buildStatCard("Item Types", _totalItems.toString(), Icons.layers_rounded, AppColors.primaryBlue),
        _buildStatCard("Low Stock", _lowStockCount.toString(), Icons.warning_amber_rounded, Colors.orange),
        _buildStatCard("Out of Stock", _outOfStockCount.toString(), Icons.error_outline_rounded, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            label, 
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.bold), 
            maxLines: 1, 
            overflow: TextOverflow.ellipsis
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value, 
              style: TextStyle(fontFamily: 'Outfit', fontSize: 26, fontWeight: FontWeight.bold, color: context.textPrimary)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.borderColor),
      ),
      child: _topCategories.isEmpty
          ? const SizedBox(height: 100, child: Center(child: Text("No category data available")))
          : Row(
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 35,
                      sections: _topCategories.asMap().entries.map((entry) {
                        final colors = [AppColors.primaryBlue, Colors.green, Colors.orange, Colors.red, Colors.purple];
                        return PieChartSectionData(color: colors[entry.key % colors.length], value: entry.value['count'].toDouble(), title: '', radius: 15);
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _topCategories.asMap().entries.map((entry) {
                      final colors = [AppColors.primaryBlue, Colors.green, Colors.orange, Colors.red, Colors.purple];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[entry.key % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(entry.value['name'], style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 4),
                            Text(entry.value['count'].toString(), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      children: _recentTransactions.map((tx) {
        final change = (tx['quantity_change'] ?? 0).toDouble();
        final isPositive = change > 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(isPositive ? Icons.add_rounded : Icons.remove_rounded, color: isPositive ? Colors.green : Colors.red, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['item']?['name'] ?? 'Item', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(tx['notes'] ?? 'Adjustment', style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text("${isPositive ? '+' : ''}$change", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isPositive ? Colors.green : Colors.red)),
                   Text(DateFormat('hh:mm a').format(DateTime.parse(tx['created_at'])), style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLowStockPreview() {
    if (_lowStockItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
            const SizedBox(height: 12),
            const Text("All items well stocked!", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      );
    }

    return Column(
      children: _lowStockItems.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: context.borderColor)),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? '', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text("Stock: ${item['total_stock']} / Min: ${item['min_stock_level']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockManagementScreen())),
                child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                   child: const Text("RESTOCK", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationGrid() {
    return Column(
      children: [
        _buildNavAction("Inventory Master", "Product definitions and pricing", Icons.inventory_2_rounded, AppColors.primaryBlue, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ItemsScreen()))),
        const SizedBox(height: 12),
        _buildNavAction("Stock Operations", "Branch-wise stock & history", Icons.warehouse_rounded, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StockManagementScreen()))),
      ],
    );
  }

  Widget _buildNavAction(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
              Text(sub, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textSecondary.withOpacity(0.3)),
          ],
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
        });
        Navigator.pop(context);
        _fetchDashboardData();
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
