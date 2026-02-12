import 'package:flutter/material.dart';
import '../../models/leave_model.dart';
import '../../models/employee_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import 'package:intl/intl.dart';

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
    final initial = isStart ? DateTime.now() : (_start ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
          _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
          // Auto set end date if empty or before start
          if (_end == null || _end!.isBefore(_start!)) {
            _end = picked;
            _endDateController.text = _startDateController.text;
          }
        } else {
          _end = picked;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
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
              const Text(
                "Apply Leave",
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 20),
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
                    // Employee Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedEmployeeId,
                      items: _employees.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text("${e.firstName} ${e.lastName ?? ''}", style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedEmployeeId = v),
                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                      decoration: _inputDecoration("Select Employee", isDark),
                      hint: Text("Select Employee", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                    ),
                    const SizedBox(height: 16),
                    
                    // Leave Type
                    DropdownButtonFormField<String>(
                      value: _leaveType,
                      items: ['casual', 'sick', 'annual', 'unpaid', 'remote_work'].map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.toUpperCase().replaceAll('_', ' '), style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)),
                      )).toList(),
                      onChanged: (v) => setState(() => _leaveType = v!),
                      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                      decoration: _inputDecoration("Leave Type", isDark),
                    ),
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

  InputDecoration _inputDecoration(String label, bool isDark, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
      suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
    );
  }
}
