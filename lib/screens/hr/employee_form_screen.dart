
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import '../../models/employee_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  final String companyId;

  const EmployeeFormScreen({
    super.key,
    this.employee,
    required this.companyId,
  });

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hrService = HrService();
  bool _loading = false;
  
  // Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _secondaryPhoneController;
  late TextEditingController _designationController;
  late TextEditingController _addressController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankIfscController;
  late TextEditingController _salaryBasicController;
  late TextEditingController _salaryAllowanceController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;

  late String _role;
  late String _status;
  
  // Branch handling
  String? _selectedBranchId;
  List<Map<String, dynamic>> _branches = [];
  bool _fetchingBranches = true;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadBranches();
  }

  void _initControllers() {
    final e = widget.employee;
    _firstNameController = TextEditingController(text: e?.firstName ?? '');
    _lastNameController = TextEditingController(text: e?.lastName ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _secondaryPhoneController = TextEditingController(text: e?.secondaryPhone ?? '');
    _designationController = TextEditingController(text: e?.designation ?? '');
    _addressController = TextEditingController(text: e?.address?.line1 ?? '');
    
    // Payroll & Financial
    _bankAccountController = TextEditingController(text: e?.bankDetails?.accountNumber ?? '');
    _bankNameController = TextEditingController(text: e?.bankDetails?.bankName ?? '');
    _bankIfscController = TextEditingController(text: e?.bankDetails?.ifsc ?? '');
    _salaryBasicController = TextEditingController(text: e?.salaryDetails?.basic ?? '');
    _salaryAllowanceController = TextEditingController(text: e?.salaryDetails?.allowance ?? '');
    
    // Emergency
    _emergencyNameController = TextEditingController(text: e?.emergencyContact?.name ?? '');
    _emergencyPhoneController = TextEditingController(text: e?.emergencyContact?.phone ?? '');
    
    _role = e?.role ?? 'employee';
    _status = e?.status ?? 'active';
    _selectedBranchId = e?.branchId;
  }

  Future<void> _loadBranches() async {
    try {
      final list = await _hrService.getBranches(widget.companyId);
      if (mounted) {
        setState(() {
          _branches = list;
          _fetchingBranches = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fetchingBranches = false);
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);

    try {
      final employee = Employee(
        id: widget.employee?.id, // Keep existing ID for update
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        secondaryPhone: _secondaryPhoneController.text.trim(),
        designation: _designationController.text.trim(),
        role: _role,
        status: _status,
        branchId: _selectedBranchId,
        address: Address(line1: _addressController.text.trim()),
        bankDetails: BankDetails(
          accountNumber: _bankAccountController.text.trim(),
          bankName: _bankNameController.text.trim(),
          ifsc: _bankIfscController.text.trim().toUpperCase(),
        ),
        salaryDetails: SalaryDetails(
          basic: _salaryBasicController.text.trim(),
          allowance: _salaryAllowanceController.text.trim(),
        ),
        emergencyContact: EmergencyContact(
          name: _emergencyNameController.text.trim(),
          phone: _emergencyPhoneController.text.trim(),
        ),
        // Pass extra fields if user update is needed
        isUser: widget.employee?.isUser,
        userId: widget.employee?.userId,
      );

      if (widget.employee == null) {
        await _hrService.createEmployee(employee, widget.companyId);
      } else {
        await _hrService.updateEmployee(employee);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        StatusService.show(context, "Error: $e");
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(widget.employee == null ? "New Employee" : "Edit Employee"),
        foregroundColor: isDark ? Colors.white : Colors.black,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _loading ? null : _saveEmployee,
          )
        ],
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator()) 
          : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle("Personal Details", Icons.person, isDark),
                const SizedBox(height: 16),
                _buildTextField(_firstNameController, "First Name", required: true),
                const SizedBox(height: 12),
                _buildTextField(_lastNameController, "Last Name"),
                const SizedBox(height: 12),
                _buildTextField(_emailController, "Email", type: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(_phoneController, "Phone", type: TextInputType.phone, required: true),
                const SizedBox(height: 12),
                _buildTextField(_addressController, "Address"),
                
                const SizedBox(height: 24),
                _buildSectionTitle("Employment", Icons.work, isDark),
                const SizedBox(height: 16),
                _buildTextField(_designationController, "Designation"),
                const SizedBox(height: 12),
                _buildDropdown("Role", _role, ['employee', 'workforce'], (v) => setState(() => _role = v!)),
                const SizedBox(height: 12),
                _buildDropdown("Status", _status, ['active', 'inactive', 'probation', 'terminated'], (v) => setState(() => _status = v!)),
                const SizedBox(height: 12),
                _buildBranchDropdown(),

                const SizedBox(height: 24),
                _buildSectionTitle("Payroll & Bank", Icons.payments, isDark),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_salaryBasicController, "Basic Salary", type: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_salaryAllowanceController, "Allowance", type: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(_bankNameController, "Bank Name"),
                const SizedBox(height: 12),
                _buildTextField(_bankAccountController, "Account Number", type: TextInputType.number),
                const SizedBox(height: 12),
                _buildTextField(_bankIfscController, "IFSC Code"),

                const SizedBox(height: 24),
                _buildSectionTitle("Emergency Contact", Icons.contact_emergency, isDark),
                const SizedBox(height: 16),
                _buildTextField(_emergencyNameController, "Contact Name"),
                const SizedBox(height: 12),
                _buildTextField(_emergencyPhoneController, "Contact Phone", type: TextInputType.phone),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveEmployee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE EMPLOYEE", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool required = false, TextInputType? type}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87),
      validator: required ? (v) => v == null || v.isEmpty ? "$label is required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)))).toList(),
    );
  }

  Widget _buildBranchDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_fetchingBranches) return const LinearProgressIndicator();
    
    return DropdownButtonFormField<String>(
      value: _selectedBranchId,
      hint: Text("Select Branch", style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54)),
      onChanged: (v) => setState(() => _selectedBranchId = v),
      dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
      decoration: InputDecoration(
        labelText: "Assigned Branch",
        labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
      ),
      items: [
         DropdownMenuItem(
          value: null, 
          child: Text("All Branches (Global)", style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87))
        ),
        ..._branches.map((b) => DropdownMenuItem(
          value: b['id'] as String,
          child: Text(b['name'], style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)),
        )),
      ],
    );
  }
}
