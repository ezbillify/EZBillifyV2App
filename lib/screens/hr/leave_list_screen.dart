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
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                      child: DataTable(
                        columnSpacing: 20,
                        headingRowColor: MaterialStateProperty.all(isDark ? Colors.white10 : Colors.grey[100]),
                        columns: const [
                          DataColumn(label: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _leaves.map((l) => DataRow(
                          cells: [
                             DataCell(
                               Row(
                                 children: [
                                   CircleAvatar(
                                     radius: 12,
                                     backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                                     child: Text(l.employeeName?[0] ?? '?', style: TextStyle(fontSize: 10, color: AppColors.primaryBlue)),
                                   ),
                                   const SizedBox(width: 8),
                                   Text(l.employeeName ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w500)),
                                 ],
                               )
                            ),
                            DataCell(Text(l.leaveType.toUpperCase())),
                            DataCell(Text("${l.startDate}\n${l.endDate}", style: const TextStyle(fontSize: 12))),
                             DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(l.reason ?? '-', overflow: TextOverflow.ellipsis),
                              )
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(l.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(l.status.toUpperCase(), style: TextStyle(color: _getStatusColor(l.status), fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ),
                            DataCell(
                              l.status == 'pending' 
                              ? Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () => _updateStatus(l.id!, 'approved'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () => _updateStatus(l.id!, 'rejected'),
                                    ),
                                  ],
                                )
                              : const Text('-'),
                            ),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
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
           Text("No leave requests found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
        ],
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
