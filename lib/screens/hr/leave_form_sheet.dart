import 'package:flutter/material.dart';
import '../../models/leave_model.dart';
import '../../models/employee_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class LeaveFormSheet extends StatefulWidget {
  final String companyId;
  final VoidCallback onSuccess;

  const LeaveFormSheet({super.key, required this.companyId, required this.onSuccess});

  @override
  State<LeaveFormSheet> createState() => _LeaveFormSheetState();
}

class _LeaveFormSheetState extends State<LeaveFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hrService = HrService();
  
  bool _loading = false;
  List<Employee> _employees = [];
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  String _leaveType = 'casual';
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  final _reasonController = TextEditingController();

  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    final list = await _hrService.getEmployees(widget.companyId);
    if (mounted) setState(() => _employees = list);
  }

  Future<void> _pickDate(bool isStart) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime focusedDay = isStart ? (_start ?? DateTime.now()) : (_end ?? DateTime.now());
    DateTime? tempSelectedDay = focusedDay;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(
                        isStart ? "Select Start Date" : "Select End Date",
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Done", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  TableCalendar(
                    firstDay: DateTime(2023),
                    lastDay: DateTime(2030),
                    focusedDay: focusedDay,
                    currentDay: DateTime.now(),
                    selectedDayPredicate: (day) => isSameDay(tempSelectedDay, day),
                    onDaySelected: (selectedDay, focused) {
                      setSheetState(() {
                        tempSelectedDay = selectedDay;
                        focusedDay = focused;
                      });
                      
                      // Auto-update parent state immediately for responsiveness
                      setState(() {
                         if (isStart) {
                           _start = selectedDay;
                           _startDateController.text = DateFormat('yyyy-MM-dd').format(selectedDay);
                           if (_end == null || _end!.isBefore(_start!)) {
                             _end = selectedDay;
                             _endDateController.text = _startDateController.text;
                           }
                         } else {
                           _end = selectedDay;
                           _endDateController.text = DateFormat('yyyy-MM-dd').format(selectedDay);
                         }                      
                      });
                    },
                    calendarStyle: CalendarStyle(
                       defaultTextStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
                       weekendTextStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white70 : Colors.black54),
                       selectedDecoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                       todayDecoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.3), shape: BoxShape.circle),
                       todayTextStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.white : Colors.black54),
                      rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.white : Colors.black54),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select an employee")));
      return;
    }

    setState(() => _loading = true);
    try {
      final leave = Leave(
        leaveType: _leaveType,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        reason: _reasonController.text.trim(),
        status: 'pending', // Default
        companyId: widget.companyId,
        employeeId: _selectedEmployeeId,
      );

      await _hrService.createLeave(leave);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
       padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        left: 20, 
        right: 20, 
        top: 20
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                "Apply Leave",
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black87),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Employee Selector (Sheet-in-Sheet)
                    _buildEmployeeSelector(isDark),
                    const SizedBox(height: 16),
                    
                    // Leave Type Selector (Sheet-in-Sheet)
                    _buildLeaveTypeSelector(isDark),
                    const SizedBox(height: 16),

                    // Dates
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(true),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _startDateController,
                                validator: (v) => v!.isEmpty ? "Required" : null,
                                style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
                                decoration: _inputDecoration("Start Date", isDark, icon: Icons.calendar_today),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(false),
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _endDateController,
                                validator: (v) => v!.isEmpty ? "Required" : null,
                                style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
                                decoration: _inputDecoration("End Date", isDark, icon: Icons.event),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reason
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
                      validator: (v) => v!.isEmpty ? "Please provide a reason" : null,
                      decoration: _inputDecoration("Reason", isDark),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading 
                           ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                           : const Text("SUBMIT REQUEST", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector(bool isDark) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (c) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text("Select Employee", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _employees.length,
                    itemBuilder: (ctx, i) {
                      final e = _employees[i];
                      final name = "${e.firstName} ${e.lastName ?? ''}".trim();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                          radius: 16,
                          child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                        trailing: _selectedEmployeeId == e.id ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                        onTap: () {
                          setState(() {
                            _selectedEmployeeId = e.id;
                            _selectedEmployeeName = name;
                          });
                          Navigator.pop(c);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        );
      },
      child: InputDecorator(
        decoration: _inputDecoration("Select Employee", isDark, icon: Icons.arrow_drop_down),
        child: Text(
          _selectedEmployeeName ?? "Select Employee", 
          style: TextStyle(fontFamily: 'Outfit', color: _selectedEmployeeName == null ? (isDark ? Colors.white54 : Colors.grey) : (isDark ? Colors.white : Colors.black87))
        ),
      ),
    );
  }

  Widget _buildLeaveTypeSelector(bool isDark) {
    final types = ['casual', 'sick', 'annual', 'unpaid', 'remote_work'];
    
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (c) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text("Select Leave Type", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: types.map((t) => ListTile(
                      title: Text(t.toUpperCase().replaceAll('_', ' '), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: _leaveType == t ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                      onTap: () {
                        setState(() => _leaveType = t);
                        Navigator.pop(c);
                      },
                    )).toList(),
                  ),
                ),
              ],
            ),
          )
        );
      },
      child: InputDecorator(
        decoration: _inputDecoration("Leave Type", isDark, icon: Icons.arrow_drop_down),
        child: Text(
          _leaveType.toUpperCase().replaceAll('_', ' '), 
          style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
      suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
