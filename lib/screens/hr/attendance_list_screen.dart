import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';

import 'attendance_sheets.dart';

class AttendanceListScreen extends StatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  State<AttendanceListScreen> createState() => _AttendanceListScreenState();
}

class _AttendanceListScreenState extends State<AttendanceListScreen> with SingleTickerProviderStateMixin {
  final _hrService = HrService();
  final _authService = AuthService();
  
  late TabController _tabController;
  List<AttendanceRecord> _records = [];
  bool _loading = true;
  String? _companyId;
  
  // Filters
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      _companyId = user?.companyId;
      if (_companyId != null) {
        // Fetch for current view
        // If "Today" tab (index 0), use today's date
        // If "History" tab (index 1), use range (but API currently supports single date or range?)
        // The service method I wrote supports single date filter. I should update it or iterate?
        // Actually the service method `getAttendance` takes `date` (single). 
        // I need to update service to support range or just fetch "all" and filter in memory if small, or add range support.
        // Let's stick to single date for "Today" and maybe just update service for range.
        
        // Wait, I only added `date` parameter in `getAttendance`. Let me quickly check or assume I'll update it.
        // For now, let's load for _startDate. 
        final list = await _hrService.getAttendance(
          _companyId!, 
          date: _tabController.index == 0 ? DateTime.now() : null, // If null, it fetches all? Yes, and filter by range in UI or backend
        );
        
        if (mounted) {
           setState(() {
             _records = list;
             // If History tab, filter by range locally for now as simpler step
             if (_tabController.index == 1) {
               _records = _records.where((r) {
                 final d = DateTime.parse(r.date);
                 return d.isAfter(_startDate.subtract(const Duration(days: 1))) && 
                        d.isBefore(_endDate.add(const Duration(days: 1)));
               }).toList();
             }
           });
        }
      }
    } catch (_) {
      // Handle error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAdjustSheet(AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: AttendanceAdjustSheet(record: record, onSuccess: _loadData),
      )
    );
  }

  void _openDeviationSheet(AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: AttendanceDeviationSheet(record: record, onSuccess: _loadData),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Attendance", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryBlue,
          tabs: const [
            Tab(text: "Today's Live"),
            Tab(text: "History Logs"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked.start;
                  _endDate = picked.end;
                  _tabController.animateTo(1); // Switch to history
                });
                _loadData();
              }
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : _records.isEmpty
              ? Center(child: Text("No records found", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
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
                          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Check In', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Check Out', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _records.map((r) => DataRow(
                          cells: [
                            DataCell(
                               Row(
                                 children: [
                                   CircleAvatar(
                                     radius: 12,
                                     backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                                     child: Text(r.employeeName?[0] ?? '?', style: TextStyle(fontSize: 10, color: AppColors.primaryBlue)),
                                   ),
                                   const SizedBox(width: 8),
                                   Text(r.employeeName ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w500)),
                                 ],
                               )
                            ),
                            DataCell(Text(DateFormat('MMM dd').format(DateTime.parse(r.date)))),
                            DataCell(Text(r.checkIn != null ? DateFormat('HH:mm').format(r.checkIn!) : '--:--')),
                            DataCell(Text(r.checkOut != null ? DateFormat('HH:mm').format(r.checkOut!) : '--:--')),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(r.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(r.status.toUpperCase(), style: TextStyle(color: _getStatusColor(r.status), fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            ),
                            DataCell(
                              PopupMenuButton(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (v) {
                                  if (v == 'adjust') _openAdjustSheet(r);
                                  if (v == 'deviation') _openDeviationSheet(r);
                                },
                                itemBuilder: (c) => [
                                  const PopupMenuItem(value: 'adjust', child: Text("Adjust Time")),
                                  const PopupMenuItem(value: 'deviation', child: Text("Log Deviation")),
                                ]
                              )
                            ),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'present') return Colors.green;
    if (status == 'late') return Colors.orange;
    if (status == 'absent') return Colors.red;
    return Colors.grey;
  }
}
