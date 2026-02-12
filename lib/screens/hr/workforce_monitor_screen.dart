import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

class WorkforceMonitorScreen extends StatefulWidget {
  const WorkforceMonitorScreen({super.key});

  @override
  State<WorkforceMonitorScreen> createState() => _WorkforceMonitorScreenState();
}

class _WorkforceMonitorScreenState extends State<WorkforceMonitorScreen> {
  final _hrService = HrService();
  final _authService = AuthService();
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _companyId;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _initMonitor();
  }

  Future<void> _initMonitor() async {
    final user = await _authService.getCurrentUser();
    _companyId = user?.companyId;
    
    if (_companyId != null) {
      await _fetchInitialData();
      _subscribe();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final users = await _hrService.getWorkforceUsers(_companyId!);
      // Fetch active tasks manually if needed, or rely on realtime? 
      // For now, let's fetch active requests if API exists or query directly.
      // I didn't add fetchRequests to HrService. I'll add a quick query here.
      final requests = await Supabase.instance.client
          .from('workforce_requests')
          .select('*, worker:managed_by(name), branch:branch_id(name)')
          .eq('company_id', _companyId!)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _users = users;
          _requests = List<Map<String, dynamic>>.from(requests);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Monitor Init Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _subscription = Supabase.instance.client.channel('public:workforce_monitor')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workforce_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: _companyId!,
          ),
          callback: (payload) {
             _fetchInitialData(); // Lazy refresh on change
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Workforce Monitor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8, 
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text("LIVE", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 10, color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Active Workforce (${_users.length})", Icons.people, isDark),
                  const SizedBox(height: 12),
                  _buildUsersList(isDark),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Task Stream (${_requests.length})", Icons.explore, isDark),
                  const SizedBox(height: 12),
                  _buildRequestsList(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildUsersList(bool isDark) {
    if (_users.isEmpty) return const Text("No active workforce members.");
    
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = _users[index];
          final isOnline = user['is_online'] ?? false;
          return Container(
            width: 90,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isOnline ? Colors.green.withOpacity(0.3) : Colors.transparent),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      child: Text(user['name']?[0] ?? '?', style: TextStyle(fontWeight: FontWeight.bold, color: isOnline ? Colors.green : Colors.grey)),
                    ),
                    if (isOnline)
                      Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  user['name'] ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                Text(
                  isOnline ? "Online" : "Offline",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: isOnline ? Colors.green : Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(bool isDark) {
    if (_requests.isEmpty) {
      return Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 40, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text("No active tasks", style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        final status = req['status'] ?? 'pending';
        Color statusColor = Colors.orange;
        if (status == 'scanning') statusColor = Colors.green;
        if (status == 'processing') statusColor = Colors.blue;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? AppColors.darkSurface : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text((req['document_type'] ?? 'Task').toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(status.toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  req['document_number'] ?? 'Doc #',
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                ),
                Text(
                  "Customer: ${req['customer_name'] ?? 'N/A'}",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      req['worker']?['name'] ?? 'Unassigned',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const Spacer(),
                    Icon(Icons.store, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      req['branch']?['name'] ?? 'Global',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
