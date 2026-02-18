import 'package:flutter/material.dart';
import '../../models/employee_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import 'employee_form_sheet.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final _hrService = HrService();
  final _authService = AuthService();
  
  List<Employee> _employees = [];
  bool _loading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final user = await _authService.getCurrentUser();
      _companyId = user?.companyId;
      if (_companyId != null) {
        final list = await _hrService.getEmployees(_companyId!);
        if (mounted) setState(() => _employees = list);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSheet([Employee? employee]) {
     if (_companyId == null) return;
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: EmployeeFormSheet(
          employee: employee, 
          companyId: _companyId!, 
          onSuccess: _loadEmployees
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Employees", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Employee", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final employee = _employees[index];
                    return _buildEmployeeCard(employee, isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            "No employees found",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add your first employee to get started",
            style: TextStyle(fontFamily: 'Outfit', color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Employee employee, bool isDark) {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSheet(employee),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'employee_${employee.id}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    child: Text(
                      employee.firstName.isNotEmpty ? employee.firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontFamily: 'Outfit', 
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: AppColors.primaryBlue
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${employee.firstName} ${employee.lastName ?? ''}".trim(),
                        style: TextStyle(
                          fontFamily: 'Outfit', 
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee.designation ?? employee.role.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit', 
                          fontSize: 13, 
                          color: isDark ? Colors.white70 : Colors.black54
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.store, size: 14, color: isDark ? Colors.white54 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            employee.branchId != null ? 'Branch Assigned' : 'Global Staff',
                            style: TextStyle(
                              fontFamily: 'Outfit', 
                              fontSize: 12, 
                              color: isDark ? Colors.white54 : Colors.grey
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (employee.status == 'active' ? Colors.green : Colors.grey).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        employee.status.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Outfit', 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          color: employee.status == 'active' ? Colors.green : Colors.grey
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.black12),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
