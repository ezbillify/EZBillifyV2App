import 'package:flutter/material.dart';
import '../../models/leave_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

import 'leave_form_sheet.dart';

class LeaveListScreen extends StatefulWidget {
  const LeaveListScreen({super.key});

  @override
  State<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends State<LeaveListScreen> {
  final _hrService = HrService();
  final _authService = AuthService();
  
  List<Leave> _leaves = [];
  bool _loading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      _companyId = user?.companyId;
      if (_companyId != null) {
        final list = await _hrService.getLeaves(_companyId!);
        if (mounted) setState(() => _leaves = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openApplySheet() {
    if (_companyId == null) return;
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: LeaveFormSheet(companyId: _companyId!, onSuccess: _loadData),
      )
    );
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
        await _hrService.updateLeaveStatus(id, status);
        _loadData();
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Leave Requests", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplySheet,
        label: const Text("Apply Leave", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final leave = _leaves[index];
                    return _buildLeaveCard(leave, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Icon(Icons.beach_access, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
           const SizedBox(height: 16),
           Text("No leave requests found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Leave leave, bool isDark) {
    Color statusColor = _getStatusColor(leave.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  child: Text(
                    leave.employeeName?[0] ?? '?', 
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.employeeName ?? 'Unknown',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Text(
                        "${leave.startDate} - ${leave.endDate}",
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    leave.status.toUpperCase(),
                    style: TextStyle(fontFamily: 'Outfit', color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50], 
                borderRadius: BorderRadius.circular(8)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Icon(Icons.category, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                       const SizedBox(width: 6),
                       Text(leave.leaveType.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                     ],
                   ),
                   if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                     const SizedBox(height: 6),
                     Text(
                       '"${leave.reason}"', 
                       style: TextStyle(fontFamily: 'Outfit', fontStyle: FontStyle.italic, color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13)
                     ),
                   ]
                ],
              ),
            ),
            if (leave.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _updateStatus(leave.id!, 'rejected'),
                      child: const Text("Reject", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _updateStatus(leave.id!, 'approved'),
                      child: const Text("Approve", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    if (status == 'pending') return Colors.orange;
    return Colors.grey;
  }
}
