import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';
import '../core/theme_service.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'settings/user_management_screen.dart';
import 'settings/my_profile_screen.dart';
import 'settings/company_profile_screen.dart';
import 'settings/security_settings_screen.dart';
import 'inventory/inventory_dashboard_screen.dart';
import 'inventory/items_screen.dart';
import 'inventory/stock_management_screen.dart';
import 'sales/sales_invoices_screen.dart';
import 'sales/customers_screen.dart';
import 'master_data/master_data_screen.dart';
import 'settings/user_management_screen.dart';
import 'sales/sales_dashboard.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  AppUser? _currentUser;
  bool _showFloatingBar = true;
  Map<String, dynamic> _stats = {
    'total_sales': 0.0,
    'balance_due': 0.0,
    'active_customers': 0,
    'low_stock': 0,
  };
  List<FlSpot> _chartData = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null means 'All Branches'
  String _selectedDateRange = '7days';
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        if (mounted) _signOut();
        return;
      }

      final user = await AuthService().fetchUserProfile(authUser.id);
      if (user == null || user.companyId == null) {
        debugPrint("DASHBOARD: User or Company ID is null! User: ${user?.name}, CompanyID: ${user?.companyId}");
        if (mounted) {
          setState(() {
            _currentUser = user;
            _loading = false;
          });
        }
        return;
      }

      debugPrint("DASHBOARD: Loading data for Company: ${user.companyId}, Branch: $_selectedBranchId, Range: $_selectedDateRange");

      setState(() => _currentUser = user);
      
      final range = _getDateRange(_selectedDateRange);

      // Fetch Branches with individual try-catch and matching Web logic
      List<Map<String, dynamic>> branchesList = [];
      try {
        final branchesResponse = await Supabase.instance.client
            .from('branches')
            .select('id, name, is_primary')
            .eq('company_id', user.companyId!)
            .order('is_primary', ascending: false)
            .order('name');
        
        branchesList = List<Map<String, dynamic>>.from(branchesResponse as List);
        
        // SELF-HEAL: If no branches exist, auto-create "Main Branch"
        if (branchesList.isEmpty) {
          debugPrint("DASHBOARD: No branches found. Self-healing...");
          final newBranch = await Supabase.instance.client.from('branches').insert({
            'company_id': user.companyId!,
            'name': 'Main Branch',
            'code': 'HO',
            'is_primary': true,
            'is_active': true,
          }).select('id, name, is_primary').single();
          branchesList = [newBranch];
          debugPrint("DASHBOARD: Self-healing complete. Created Main Branch.");
        }
        
        debugPrint("DASHBOARD: Fetched ${branchesList.length} branches");
      } catch (be) {
        debugPrint("DASHBOARD: Branch Fetch/Heal Error: $be");
      }

      // Fetch Stats in parallel with detailed error catching for each
      final results = await Future.wait([
        _fetchSalesStats(user.companyId!, _selectedBranchId, range['start']!, range['end']!).catchError((e) {
          debugPrint("DASHBOARD: Sales Statistics Error: $e");
          return {'total_sales': 0.0, 'balance_due': 0.0};
        }),
        _fetchCustomerCount(user.companyId!, _selectedBranchId).catchError((e) {
          debugPrint("DASHBOARD: Customer Count Error: $e");
          return 0;
        }),
        _fetchLowStockCount(user.companyId!, _selectedBranchId).catchError((e) {
          debugPrint("DASHBOARD: Low Stock Count Error: $e");
          return 0;
        }),
        _fetchSalesChartData(user.companyId!, _selectedBranchId, _selectedDateRange).catchError((e) {
          debugPrint("DASHBOARD: Chart Data Error: $e");
          return <FlSpot>[];
        }),
      ]);

      if (mounted) {
        final salesData = results[0] as Map<String, double>;
        setState(() {
          _branches = branchesList.isEmpty ? [{'id': 'dummy', 'name': 'Main Store'}] : branchesList;
          _stats['total_sales'] = salesData['total_sales'] ?? 0.0;
          _stats['balance_due'] = salesData['balance_due'] ?? 0.0;
          _stats['active_customers'] = results[1] as int;
          _stats['low_stock'] = results[2] as int;
          _chartData = results[3] as List<FlSpot>;
          _loading = false;
        });
        debugPrint("DASHBOARD: Data Update Complete. Revenue: ${_stats['total_sales']}, Branches: ${_branches.length}");
      }
    } catch (e, stack) {
      debugPrint("DASHBOARD: Critical Execution Error: $e\n$stack");
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, DateTime> _getDateRange(String range) {
    final now = DateTime.now();
    DateTime start = now;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (range) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        end = DateTime(now.year, now.month, now.day, 23, 59, 59).subtract(const Duration(days: 1));
        break;
      case '30days':
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        break;
      case 'thisMonth':
        start = DateTime(now.year, now.month, 1);
        break;
      case '7days':
      default:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
    }
    return {'start': start, 'end': end};
  }

  Future<Map<String, double>> _fetchSalesStats(String companyId, String? branchId, DateTime start, DateTime end) async {
    var query = Supabase.instance.client
        .from('sales_invoices')
        .select('total_amount, balance_due')
        .eq('company_id', companyId)
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());
    
    if (branchId != null) query = query.eq('branch_id', branchId);

    final response = await query;

    double total = 0;
    double balance = 0;
    for (var row in (response as List)) {
      total += (row['total_amount'] as num).toDouble();
      balance += (row['balance_due'] as num).toDouble();
    }
    return {'total_sales': total, 'balance_due': balance};
  }

  Future<int> _fetchCustomerCount(String companyId, String? branchId) async {
    final response = await Supabase.instance.client
        .from('customers')
        .select('id')
        .eq('company_id', companyId)
        .eq('is_active', true);
    
    return (response as List).length;
  }

  Future<List<FlSpot>> _fetchSalesChartData(String companyId, String? branchId, String rangeLabel) async {
    try {
      final range = _getDateRange(rangeLabel);
      final start = range['start']!;
      final end = range['end']!;
      
      var query = Supabase.instance.client
          .from('sales_invoices')
          .select('total_amount, date')
          .eq('company_id', companyId)
          .gte('date', start.toIso8601String())
          .lte('date', end.toIso8601String());

      if (branchId != null) query = query.eq('branch_id', branchId);

      final response = await query.order('date', ascending: true);

      Map<String, double> dailyTotals = {};
      int days = end.difference(start).inDays + 1;
      
      for (int i = 0; i < days; i++) {
        final date = start.add(Duration(days: i));
        dailyTotals[DateFormat('MM-dd').format(date)] = 0.0;
      }

      for (var row in (response as List)) {
        final date = DateTime.parse(row['date']);
        final key = DateFormat('MM-dd').format(date);
        if (dailyTotals.containsKey(key)) {
          dailyTotals[key] = dailyTotals[key]! + (row['total_amount'] as num).toDouble();
        }
      }

      final sortedKeys = dailyTotals.keys.toList()..sort();
      List<FlSpot> spots = [];
      for (int i = 0; i < sortedKeys.length; i++) {
        spots.add(FlSpot(i.toDouble(), dailyTotals[sortedKeys[i]]!));
      }
      return spots;
    } catch (e) {
      debugPrint("Chart Fetch Error: $e");
      return [];
    }
  }

  Future<int> _fetchLowStockCount(String companyId, String? branchId) async {
    try {
      final response = await Supabase.instance.client
          .from('items')
          .select('id, min_stock_level, total_stock')
          .eq('company_id', companyId);

      final items = List<Map<String, dynamic>>.from(response as List);
      int lowStockCount = 0;

      for (var item in items) {
        final totalStock = (item['total_stock'] ?? 0).toDouble();
        final minStock = (item['min_stock_level'] ?? 0).toDouble();

        if (totalStock <= minStock) {
          lowStockCount++;
        }
      }

      return lowStockCount;
    } catch (e) {
      debugPrint("Low Stock Fetch Error: $e");
      return 0;
    }
  }

  void _signOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
  }

  void _showBranchSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    Text(
                      "Select Branch",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Filter analytics and stock by business location",
                      style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _buildBranchTile("Unified Dashboard", null, Icons.dashboard_customize_rounded),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.grey.withOpacity(0.05))),
                    ..._branches.map((b) => _buildBranchTile(b['name'], b['id'], Icons.storefront_rounded)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchTile(String name, String? id, IconData icon) {
    final isSelected = _selectedBranchId == id;
    return InkWell(
      onTap: () {
        setState(() => _selectedBranchId = id);
        Navigator.pop(context);
        _loadDashboardData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB) : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontFamily: 'Outfit', 
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (isSelected) 
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 24),
          ],
        ),
      ),
    );
  }

  void _showDateRangeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    Text(
                      "Time Period",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Compare performance across different dates",
                      style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    _buildDateRangeTile("Today", "today", Icons.today_rounded),
                    _buildDateRangeTile("Yesterday", "yesterday", Icons.history_rounded),
                    _buildDateRangeTile("Last 7 Days", "7days", Icons.date_range_rounded),
                    _buildDateRangeTile("Last 30 Days", "30days", Icons.calendar_month_rounded),
                    _buildDateRangeTile("This Month", "thisMonth", Icons.calendar_today_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeTile(String label, String value, IconData icon) {
    final isSelected = _selectedDateRange == value;
    return InkWell(
      onTap: () {
        setState(() => _selectedDateRange = value);
        Navigator.pop(context);
        _loadDashboardData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 18),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(fontFamily: 'Outfit', 
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            if (isSelected) 
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          // Watch theme to rebuild the sheet on changes
          ref.watch(themeServiceProvider);
          
          final surfaceColor = context.surfaceBg;
          final textSecondary = context.textSecondary;

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 32),
                        
                        // Theme Selector Section
                        _buildThemeSelector(),
                        const SizedBox(height: 32),
                        
                        _buildSheetItem(Icons.person_outline_rounded, "Account Settings", "Manage your profile details", onTap: () {
                          Navigator.pop(context);
                          if (_currentUser != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (c) => MyProfileScreen(user: _currentUser!),
                            ));
                          }
                        }),
                        _buildSheetItem(Icons.business_rounded, "Company Profile", "Update business information", onTap: () {
                          Navigator.pop(context);
                          if (_currentUser?.companyId != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (c) => CompanyProfileScreen(companyId: _currentUser!.companyId!),
                            ));
                          }
                        }),
                        _buildSheetItem(Icons.security_rounded, "Privacy & Security", "Password and access control", onTap: () {
                           Navigator.pop(context);
                           if (_currentUser != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (c) => SecuritySettingsScreen(user: _currentUser!),
                            ));
                          }
                        }),
                        _buildSheetItem(Icons.notifications_none_rounded, "Notifications", "Preference management"),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: context.dividerColor)),
                        _buildSheetItem(Icons.help_outline_rounded, "Help & Support", "Get assistance from our team"),
                        _buildSheetItem(Icons.logout_rounded, "Sign Out", "Safely exit your account", isDestructive: true, onTap: () {
                          _showSignOutConfirmation(context);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final themeService = ref.watch(themeServiceProvider);
        final isDark = context.isDark;
        final textSecondary = context.textSecondary;
        final borderColor = context.borderColor;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "APPEARANCE",
              style: TextStyle(fontFamily: 'Outfit', 
                
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    label: "Light",
                    icon: Icons.light_mode_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.light,
                    onTap: () => themeService.setThemeMode(AppThemeMode.light),
                    activeColor: Colors.white,
                    activeTextColor: AppColors.primaryBlue,
                  ),
                  _buildThemeOption(
                    label: "Dark",
                    icon: Icons.dark_mode_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.dark,
                    onTap: () => themeService.setThemeMode(AppThemeMode.dark),
                    activeColor: AppColors.darkSurface,
                    activeTextColor: Colors.white,
                  ),
                  _buildThemeOption(
                    label: "System",
                    icon: Icons.settings_brightness_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.system,
                    onTap: () => themeService.setThemeMode(AppThemeMode.system),
                    activeColor: isDark ? AppColors.darkSurface : Colors.white,
                    activeTextColor: isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color activeTextColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected 
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] 
              : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeTextColor : context.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontFamily: 'Outfit', 
                  
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTextColor : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context) {
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final isDark = context.isDark;

    showDialog(
      context: context,
      builder: (context) => ZoomIn(
        duration: const Duration(milliseconds: 300),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Sign Out?",
                  style: TextStyle(fontFamily: 'Outfit', 
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to log out? You will need to sign in again to access your dashboard.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Outfit', 
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: context.borderColor),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(fontFamily: 'Outfit', 
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close dialog
                          Navigator.pop(context); // Close sheet
                          _signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Sign Out",
                          style: TextStyle(fontFamily: 'Outfit', 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Center(
            child: Text(
              (_currentUser?.name ?? "U")[0].toUpperCase(),
              style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _currentUser?.name ?? "Super Admin",
          style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        Text(
          _currentUser?.email ?? "admin@ezbillify.com",
          style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (_currentUser?.role.name ?? "Owner").toUpperCase(),
                style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            if (_currentUser?.companyName != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentUser!.companyName!.toUpperCase(),
                  style: TextStyle(fontFamily: 'Outfit', color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSheetItem(IconData icon, String title, String subtitle, {bool isDestructive = false, VoidCallback? onTap}) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final color = isDestructive ? AppColors.error : textPrimary;
    
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.error : textSecondary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDestructive ? AppColors.error : textSecondary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  Text(subtitle, style: TextStyle(fontFamily: 'Outfit', color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      // The dashboard content is always the base
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : Stack(
            children: [
              _buildDashboardContents(),
              if (_showFloatingBar)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: _buildFloatingNavigation(),
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildFloatingNavigation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItemIconButton(Icons.dashboard_rounded, "Dashboard", isSelected: true),
          _buildNavItemIconButton(Icons.receipt_long_rounded, "Invoices", onTap: () => _navigateToScreen(const SalesDashboard(initialIndex: 0))),
          _buildQuickActionBtn(),
          _buildNavItemIconButton(Icons.people_alt_rounded, "Users", onTap: () {
            if (_currentUser?.companyId != null) {
              _navigateToScreen(UserManagementScreen(companyId: _currentUser!.companyId!));
            }
          }),
          _buildNavItemIconButton(Icons.search_rounded, "Inventory", onTap: () => _navigateToScreen(const InventoryDashboardScreen())),
        ],
      ),
    );
  }

  Widget _buildNavItemIconButton(IconData icon, String label, {VoidCallback? onTap, bool isSelected = false}) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (onTap != null) onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.4),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontFamily: 'Outfit', 
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF3B82F6) : Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDashboardContents() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(),
                    const SizedBox(height: 24),
                    _buildSalesChart(),
                    const SizedBox(height: 24),
                    _buildActionGrid(),
                    const SizedBox(height: 100), // Extra space for floating bar
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToScreen(Widget screen) {
    setState(() => _showFloatingBar = false);
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => screen)
    ).then((_) {
      if (mounted) {
        setState(() => _showFloatingBar = true);
      }
    });
  }

  Widget _buildAppBar() {
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return SliverAppBar(
      expandedHeight: 130.0,
      floating: false,
      pinned: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double expandedHeight = 130.0;
          final double kToolbarHeight = 70.0; // Increased from 56.0
          final double currentHeight = constraints.biggest.height;
          // Calculate t: 0.0 at collapsed, 1.0 at expanded
          final double t = ((currentHeight - kToolbarHeight) / (expandedHeight - kToolbarHeight)).clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: lerpDouble(10, 15, t)!,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logomain.png',
                            height: lerpDouble(22, 38, t),
                            width: lerpDouble(22, 38, t),
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: lerpDouble(8, 12, t)),
                          Text(
                            "EZBillify V2",
                            style: TextStyle(fontFamily: 'Outfit', 
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: lerpDouble(16, 22, t),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: lerpDouble(2, 6, t)!),
                        child: Text(
                          "Hello, ${_currentUser?.name?.split(' ').first ?? 'User'}",
                          style: TextStyle(fontFamily: 'Outfit', 
                            fontSize: lerpDouble(10, 16, t),
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showProfileSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(lerpDouble(0.1, 0.2, t)!),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: lerpDouble(16, 24, t),
                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                      child: Text(
                        (_currentUser?.name ?? "U")[0].toUpperCase(),
                        style: TextStyle(fontFamily: 'Outfit', 
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: lerpDouble(11, 16, t),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            background: Container(color: surfaceColor),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dashboard",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Live Business Intelligence",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary),
                    ),
                    Text(
                      "Real-time enterprise management.",
                      style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: GestureDetector(
                      onTap: () => _showDateRangeSelector(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              _selectedDateRange == 'today' ? 'Today' : 
                              _selectedDateRange == 'yesterday' ? 'Yesterday' :
                              _selectedDateRange == '7days' ? 'Last 7 Days' :
                              _selectedDateRange == '30days' ? 'Last 30 Days' : 'This Month',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: GestureDetector(
                      onTap: () => _showBranchSelector(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              _selectedBranchId == null 
                                  ? "All" 
                                  : (_branches.firstWhere((b) => b['id'] == _selectedBranchId, orElse: () => {'name': '...'})['name']),
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
        ),
        TextButton(
          onPressed: () {},
          child: Text("See all", style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          "Total Revenue", 
          "₹${(_stats['total_sales'] as double).toStringAsFixed(0)}", 
          Icons.payments_rounded, 
          const Color(0xFF2563EB),
        ),
        _buildMetricCard(
          "Receivables", 
          "₹${(_stats['balance_due'] as double).toStringAsFixed(0)}", 
          Icons.account_balance_wallet_rounded, 
          const Color(0xFF10B981),
        ),
        _buildMetricCard(
          "Customers", 
          "${_stats['active_customers']}", 
          Icons.people_rounded, 
          const Color(0xFF8B5CF6),
        ),
        _buildMetricCard(
          "Low Stock", 
          "${_stats['low_stock']}", 
          Icons.inventory_2_rounded, 
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildSalesChart() {
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 20, 16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (_chartData.isEmpty) return const Text("");
                  final now = DateTime.now();
                  final date = now.subtract(Duration(days: 6 - value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('E').format(date).toUpperCase(),
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5000,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    "₹${(value / 1000).toStringAsFixed(0)}k",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          lineBarsData: [
            LineChartBarData(
              spots: _chartData.isEmpty ? [const FlSpot(0, 0)] : _chartData,
              isCurved: true,
              color: const Color(0xFF2563EB),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2563EB).withOpacity(0.2),
                    const Color(0xFF2563EB).withOpacity(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return Column(
      children: [
        _buildBigAction(
          title: "Sales & Invoices",
          description: "Generate bills, manage returns & payments",
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
          onTap: () {
            // Switch to Invoices Tab (index 1)
            Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard()));
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          title: "Inventory Management",
          description: "Track products, stock levels & UOMs",
          icon: Icons.inventory_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (c) => const InventoryDashboardScreen(),
            ));
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          title: "Workforce Monitor",
          description: "Assign and track warehouse staff activities",
          icon: Icons.assignment_ind_rounded,
          color: const Color(0xFF10B981),
          onTap: () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Workforce Monitor - Coming Soon")));
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          title: "Reports & Analytics",
          description: "Financial summaries and business growth",
          icon: Icons.analytics_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reports - Coming Soon")));
          },
        ),
      ],
    );
  }

  Widget _buildBigAction({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn() {
    return Expanded(
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              _showQuickActionMenu(context);
            },
            borderRadius: BorderRadius.circular(29),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
          ),
        ),
      ),
    );
  }

  void _showQuickActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Global Actions",
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              ),
                              Text(
                                "Quickly access all business modules",
                                style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildOverlaySection(
                        "Sales", 
                        [
                          _buildActionIcon(Icons.people_alt_rounded, "Customers", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const CustomersScreen());
                          }),
                          _buildActionIcon(Icons.request_quote_rounded, "Quotations", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 1));
                          }),
                          _buildActionIcon(Icons.shopping_bag_rounded, "Sales Orders", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 2));
                          }),
                          _buildActionIcon(Icons.local_shipping_rounded, "Delivery Challans", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 3));
                          }),
                          _buildActionIcon(Icons.receipt_long_rounded, "Sales Invoices", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 0));
                          }),
                          _buildActionIcon(Icons.qr_code_2_rounded, "E-Invoicing", const Color(0xFF3B82F6), () {}),
                          _buildActionIcon(Icons.route_rounded, "E-Way Bills", const Color(0xFF3B82F6), () {}),
                          _buildActionIcon(Icons.payments_rounded, "Payments", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 4));
                          }),
                          _buildActionIcon(Icons.assignment_return_rounded, "Credit Notes", const Color(0xFF3B82F6), () {
                            _navigateToScreen(const SalesDashboard(initialIndex: 5));
                          }),
                        ]
                      ),
                      _buildOverlaySection(
                        "Purchase", 
                        [
                          _buildActionIcon(Icons.storefront_rounded, "Vendors", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.quiz_rounded, "RFQs", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.description_rounded, "Purchase Orders", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.inventory_rounded, "Goods Received (GRN)", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.receipt_rounded, "Purchase Bills", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.assignment_returned_rounded, "Debit Notes", const Color(0xFFF59E0B), () {}),
                          _buildActionIcon(Icons.account_balance_wallet_rounded, "Payments", const Color(0xFFF59E0B), () {}),
                        ]
                      ),
                       _buildOverlaySection(
                        "Inventory", 
                        [
                          _buildActionIcon(Icons.dashboard_rounded, "Dashboard", const Color(0xFF10B981), () {
                             _navigateToScreen(const InventoryDashboardScreen());
                           }),
                          _buildActionIcon(Icons.inventory_2_rounded, "Items", const Color(0xFF10B981), () {
                            _navigateToScreen(const ItemsScreen());
                          }),
                          _buildActionIcon(Icons.warehouse_rounded, "Stock", const Color(0xFF10B981), () {
                            _navigateToScreen(const StockManagementScreen());
                          }),
                        ]
                      ),
                      _buildOverlaySection(
                        "HR & Payroll", 
                        [
                          _buildActionIcon(Icons.engineering_rounded, "Workforce Monitor", const Color(0xFF8B5CF6), () {}),
                          _buildActionIcon(Icons.badge_rounded, "Employees", const Color(0xFF8B5CF6), () {}),
                          _buildActionIcon(Icons.schedule_rounded, "Shifts", const Color(0xFF8B5CF6), () {}),
                          _buildActionIcon(Icons.event_available_rounded, "Attendance", const Color(0xFF8B5CF6), () {}),
                          _buildActionIcon(Icons.beach_access_rounded, "Leaves", const Color(0xFF8B5CF6), () {}),
                          _buildActionIcon(Icons.settings_rounded, "Settings", const Color(0xFF8B5CF6), () {}),
                        ]
                      ),
                      _buildOverlaySection(
                        "Master Data", 
                        [
                          _buildActionIcon(Icons.category_rounded, "Categories", const Color(0xFF64748B), () {
                            _navigateToScreen(const MasterDataScreen()); 
                          }),
                          _buildActionIcon(Icons.straighten_rounded, "Units (UOM)", const Color(0xFF64748B), () {
                             _navigateToScreen(const MasterDataScreen());
                          }),
                          _buildActionIcon(Icons.account_balance_rounded, "Bank Accounts", const Color(0xFF64748B), () {
                             _navigateToScreen(const MasterDataScreen()); 
                          }),
                          _buildActionIcon(Icons.percent_rounded, "Tax Rates", const Color(0xFF64748B), () {
                             _navigateToScreen(const MasterDataScreen());
                          }),
                          _buildActionIcon(Icons.account_tree_rounded, "Chart of Accounts", const Color(0xFF64748B), () {}),
                          _buildActionIcon(Icons.access_time_filled_rounded, "Payment Terms", const Color(0xFF64748B), () {
                             _navigateToScreen(const MasterDataScreen());
                          }),
                          _buildActionIcon(Icons.currency_exchange_rounded, "Currencies", const Color(0xFF64748B), () {
                             _navigateToScreen(const MasterDataScreen());
                          }),
                        ]
                      ),
                      _buildOverlaySection(
                        "Others", 
                        [
                          _buildActionIcon(Icons.analytics_rounded, "Reports", const Color(0xFFEF4444), () {}),
                          _buildActionIcon(Icons.business_rounded, "Company Settings", const Color(0xFFEF4444), () {
                            if (_currentUser?.companyId != null) {
                              _navigateToScreen(CompanyProfileScreen(companyId: _currentUser!.companyId!));
                            }
                          }),
                          _buildActionIcon(Icons.settings_rounded, "App Settings", const Color(0xFFEF4444), () {
                             _navigateToScreen(SettingsScreen(user: _currentUser));
                          }),
                        ]
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlaySection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontFamily: 'Outfit', 
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: Color(0xFF94A3B8),
              letterSpacing: 1.2
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
          children: items,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context); // Close the modal first
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Outfit', 
                  fontSize: 11, 
                  fontWeight: FontWeight.w600, 
                  color: Color(0xFF475569)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
