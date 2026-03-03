import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

class DashboardState {
  final bool loading;
  final AppUser? currentUser;
  final Map<String, dynamic> stats;
  final List<FlSpot> salesSpots;
  final List<FlSpot> purchaseSpots;
  final List<FlSpot> profitSpots;
  final List<String> chartXLabels;
  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId;
  final String selectedDateRange;

  DashboardState({
    this.loading = true,
    this.currentUser,
    this.stats = const {
      'total_sales': 0.0,
      'balance_due': 0.0,
      'active_customers': 0,
      'low_stock': 0,
    },
    this.salesSpots = const [],
    this.purchaseSpots = const [],
    this.profitSpots = const [],
    this.chartXLabels = const [],
    this.branches = const [],
    this.selectedBranchId,
    this.selectedDateRange = '7days',
  });

  DashboardState copyWith({
    bool? loading,
    AppUser? currentUser,
    Map<String, dynamic>? stats,
    List<FlSpot>? salesSpots,
    List<FlSpot>? purchaseSpots,
    List<FlSpot>? profitSpots,
    List<String>? chartXLabels,
    List<Map<String, dynamic>>? branches,
    String? selectedBranchId,
    bool clearBranch = false,
    String? selectedDateRange,
  }) {
    return DashboardState(
      loading: loading ?? this.loading,
      currentUser: currentUser ?? this.currentUser,
      stats: stats ?? this.stats,
      salesSpots: salesSpots ?? this.salesSpots,
      purchaseSpots: purchaseSpots ?? this.purchaseSpots,
      profitSpots: profitSpots ?? this.profitSpots,
      chartXLabels: chartXLabels ?? this.chartXLabels,
      branches: branches ?? this.branches,
      selectedBranchId: clearBranch ? null : (selectedBranchId ?? this.selectedBranchId),
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState());

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> loadDashboardData() async {
    state = state.copyWith(loading: true);
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return;

      final user = await AuthService().fetchUserProfile(authUser.id);
      if (user == null || user.companyId == null) {
        state = state.copyWith(loading: false, currentUser: user);
        return;
      }

      state = state.copyWith(currentUser: user);

      final range = _getDateRange(state.selectedDateRange);

      // Fetch Branches
      List<Map<String, dynamic>> branchesList = [];
      try {
        final branchesResponse = await _supabase
            .from('branches')
            .select('id, name, is_primary')
            .eq('company_id', user.companyId!)
            .order('is_primary', ascending: false)
            .order('name');

        branchesList = List<Map<String, dynamic>>.from(branchesResponse as List);

        if (branchesList.isEmpty) {
          final newBranch = await _supabase
              .from('branches')
              .insert({
                'company_id': user.companyId!,
                'name': 'Main Branch',
                'code': 'HO',
                'is_primary': true,
                'is_active': true,
              })
              .select('id, name, is_primary')
              .single();
          branchesList = [newBranch];
        }
      } catch (e) {
        print("DashboardProvider: Branch Error: $e");
      }

      // Parallel Data Fetching with graceful fallbacks
      final results = await Future.wait([
        _fetchSalesStats(user.companyId!, state.selectedBranchId, range['start']!, range['end']!).catchError((e) {
          print("DashboardProvider: Sales Stats Error: $e");
          return {'total_sales': 0.0, 'balance_due': 0.0};
        }),
        _fetchCustomerCount(user.companyId!, state.selectedBranchId).catchError((e) {
          print("DashboardProvider: Customer Count Error: $e");
          return 0;
        }),
        _fetchLowStockCount(user.companyId!, state.selectedBranchId).catchError((e) {
          print("DashboardProvider: Low Stock Count Error: $e");
          return 0;
        }),
        _fetchChartData(user.companyId!, state.selectedBranchId, state.selectedDateRange).catchError((e) {
          print("DashboardProvider: Chart Data Error: $e");
          return {'sales': <FlSpot>[], 'purchase': <FlSpot>[], 'profit': <FlSpot>[], 'labels': <String>[]};
        }),
      ]);

      final salesData = results[0] as Map<String, dynamic>;
      final chartData = results[3] as Map<String, dynamic>;

      state = state.copyWith(
        loading: false,
        branches: branchesList,
        stats: {
          'total_sales': salesData['total_sales'] ?? 0.0,
          'balance_due': salesData['balance_due'] ?? 0.0,
          'active_customers': results[1] as int,
          'low_stock': results[2] as int,
        },
        salesSpots: chartData['sales'] as List<FlSpot>? ?? [],
        purchaseSpots: chartData['purchase'] as List<FlSpot>? ?? [],
        profitSpots: chartData['profit'] as List<FlSpot>? ?? [],
        chartXLabels: chartData['labels'] as List<String>? ?? [],
      );
    } catch (e) {
      print("DashboardProvider: Global Error: $e");
      state = state.copyWith(loading: false);
    }
  }

  void setBranch(String? branchId) {
    if (branchId == null) {
      state = state.copyWith(clearBranch: true);
    } else {
      state = state.copyWith(selectedBranchId: branchId);
    }
    loadDashboardData();
  }

  void setDateRange(String range) {
    state = state.copyWith(selectedDateRange: range);
    loadDashboardData();
  }

  // --- Private Helpers ---

  Map<String, DateTime> _getDateRange(String range) {
    final now = DateTime.now().toUtc();
    final istNow = now.add(const Duration(hours: 5, minutes: 30));

    DateTime start = DateTime.utc(istNow.year, istNow.month, istNow.day, 0, 0, 0, 0);
    DateTime end = DateTime.utc(istNow.year, istNow.month, istNow.day, 23, 59, 59, 999);

    switch (range) {
      case 'today': break;
      case 'yesterday':
        start = DateTime.utc(istNow.year, istNow.month, istNow.day - 1, 0, 0, 0, 0);
        end = DateTime.utc(istNow.year, istNow.month, istNow.day - 1, 23, 59, 59, 999);
        break;
      case '30days':
        start = DateTime.utc(istNow.year, istNow.month, istNow.day - 30, 0, 0, 0, 0);
        break;
      case 'thisMonth':
        start = DateTime.utc(istNow.year, istNow.month, 1, 0, 0, 0, 0);
        break;
      case '7days':
      default:
        start = DateTime.utc(istNow.year, istNow.month, istNow.day - 7, 0, 0, 0, 0);
        break;
    }
    return {'start': start, 'end': end};
  }

  Future<List<Map<String, dynamic>>> _fetchAll({
    required String table,
    required String select,
    required Map<String, dynamic> filters,
    Map<String, dynamic>? rangeFilters,
    String? eqBranch,
  }) async {
    const pageSize = 1000;
    int page = 0;
    List<Map<String, dynamic>> allRecords = [];
    bool hasMore = true;

    while (hasMore) {
      var query = _supabase.from(table).select(select);
      for (final entry in filters.entries) query = query.eq(entry.key, entry.value);
      if (rangeFilters != null) {
        if (rangeFilters['gte'] != null) {
          final gte = rangeFilters['gte'] as Map<String, dynamic>;
          for (final e in gte.entries) query = query.gte(e.key, e.value);
        }
        if (rangeFilters['lte'] != null) {
          final lte = rangeFilters['lte'] as Map<String, dynamic>;
          for (final e in lte.entries) query = query.lte(e.key, e.value);
        }
      }
      if (eqBranch != null) query = query.eq('branch_id', eqBranch);

      final response = await query.range(page * pageSize, (page + 1) * pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(response as List);
      allRecords.addAll(rows);
      if (rows.length < pageSize) hasMore = false; else { page++; if (page > 50) break; }
    }
    return allRecords;
  }

  Future<Map<String, double>> _fetchSalesStats(String companyId, String? branchId, DateTime start, DateTime end) async {
    final rows = await _fetchAll(
      table: 'sales_invoices',
      select: 'total_amount, balance_due',
      filters: {'company_id': companyId},
      rangeFilters: {
        'gte': {'date': start.toIso8601String()},
        'lte': {'date': end.toIso8601String()},
      },
      eqBranch: branchId,
    );
    double total = 0; double balance = 0;
    for (var row in rows) {
      total += _parseNum(row['total_amount']);
      balance += _parseNum(row['balance_due']);
    }
    return {'total_sales': total, 'balance_due': balance};
  }

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<int> _fetchCustomerCount(String companyId, String? branchId) async {
    final rows = await _fetchAll(
      table: 'customers',
      select: 'id',
      filters: {'company_id': companyId, 'is_active': true},
      eqBranch: branchId,
    );
    return rows.length;
  }

  Future<Map<String, dynamic>> _fetchChartData(String companyId, String? branchId, String rangeLabel) async {
    final range = _getDateRange(rangeLabel);
    final start = range['start']!;
    final end = range['end']!;

    final results = await Future.wait([
      _fetchAll(
        table: 'sales_invoices',
        select: 'total_amount, date, created_at',
        filters: {'company_id': companyId},
        rangeFilters: {
          'gte': {'date': start.toIso8601String()},
          'lte': {'date': end.toIso8601String()},
        },
        eqBranch: branchId,
      ),
      _fetchAll(
        table: 'purchase_bills',
        select: 'total_amount, date, created_at',
        filters: {'company_id': companyId},
        rangeFilters: {
          'gte': {'date': start.toIso8601String()},
          'lte': {'date': end.toIso8601String()},
        },
        eqBranch: branchId,
      ),
    ]);

    final salesRows = results[0];
    final purchaseRows = results[1];
    List<FlSpot> salesSpots = [];
    List<FlSpot> purchaseSpots = [];
    List<FlSpot> profitSpots = [];
    List<String> labels = [];

    if (rangeLabel == 'today') {
      for (int i = 0; i < 24; i += 2) {
        labels.add("${i.toString().padLeft(2, '0')}:00");
        final s = salesRows.where((row) {
          final ts = row['created_at']?.toString() ?? row['date']?.toString();
          if (ts == null) return false;
          final dt = DateTime.parse(ts).toUtc().add(const Duration(hours: 5, minutes: 30));
          return dt.hour >= i && dt.hour < i + 2;
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        final p = purchaseRows.where((row) {
          final ts = row['created_at']?.toString() ?? row['date']?.toString();
          if (ts == null) return false;
          final dt = DateTime.parse(ts).toUtc().add(const Duration(hours: 5, minutes: 30));
          return dt.hour >= i && dt.hour < i + 2;
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        salesSpots.add(FlSpot(i / 2, s));
        purchaseSpots.add(FlSpot(i / 2, p));
        profitSpots.add(FlSpot(i / 2, s - p));
      }
    } else if (rangeLabel == '30days') {
      for (int i = 0; i < 5; i++) {
        final weekStart = start.add(Duration(days: i * 6));
        final weekEnd = i == 4 ? end : start.add(Duration(days: (i + 1) * 6));
        labels.add("W${i + 1}");
        final s = salesRows.where((row) {
          final val = row['date']?.toString() ?? row['created_at']?.toString();
          if (val == null) return false;
          final d = DateTime.parse(val);
          return d.isAfter(weekStart.subtract(const Duration(seconds: 1))) && d.isBefore(weekEnd.add(const Duration(seconds: 1)));
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        final p = purchaseRows.where((row) {
          final val = row['date']?.toString() ?? row['created_at']?.toString();
          if (val == null) return false;
          final d = DateTime.parse(val);
          return d.isAfter(weekStart.subtract(const Duration(seconds: 1))) && d.isBefore(weekEnd.add(const Duration(seconds: 1)));
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        salesSpots.add(FlSpot(i.toDouble(), s));
        purchaseSpots.add(FlSpot(i.toDouble(), p));
        profitSpots.add(FlSpot(i.toDouble(), s - p));
      }
    } else {
      int days = end.difference(start).inDays + 1;
      for (int i = 0; i < days; i++) {
        final currentDate = start.add(Duration(days: i));
        final prefix = currentDate.toIso8601String().substring(0, 10);
        labels.add(DateFormat('E').format(currentDate.add(const Duration(hours: 5, minutes: 30))).substring(0, 1));
        final s = salesRows.where((row) {
          final val = row['date']?.toString() ?? row['created_at']?.toString();
          return val != null && val.startsWith(prefix);
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        final p = purchaseRows.where((row) {
          final val = row['date']?.toString() ?? row['created_at']?.toString();
          return val != null && val.startsWith(prefix);
        }).fold(0.0, (sum, row) => sum + _parseNum(row['total_amount']));
        salesSpots.add(FlSpot(i.toDouble(), s));
        purchaseSpots.add(FlSpot(i.toDouble(), p));
        profitSpots.add(FlSpot(i.toDouble(), s - p));
      }
    }
    return {'sales': salesSpots, 'purchase': purchaseSpots, 'profit': profitSpots, 'labels': labels};
  }

  Future<int> _fetchLowStockCount(String companyId, String? branchId) async {
    final rows = await _fetchAll(
      table: 'items',
      select: 'id, min_stock_level, total_stock',
      filters: {'company_id': companyId},
      eqBranch: branchId,
    );
    int lowStockCount = 0;
    for (var item in rows) {
      if (_parseNum(item['total_stock']) <= _parseNum(item['min_stock_level'])) lowStockCount++;
    }
    return lowStockCount;
  }
}

final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
