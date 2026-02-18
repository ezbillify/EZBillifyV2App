import 'package:flutter/material.dart';
import '../../models/employee_model.dart';
import '../../services/hr_service.dart';
import '../../core/theme_service.dart';

class EmployeeFormSheet extends StatefulWidget {
  final Employee? employee;
  final String companyId;
  final VoidCallback onSuccess;

  const EmployeeFormSheet({
    super.key,
    this.employee,
    required this.companyId,
    required this.onSuccess,
  });

  @override
  State<EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<EmployeeFormSheet> {
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
  late String _gender;
  
  // Branch handling
  String? _selectedBranchId;
  String? _selectedBranchName; // To display in the field
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
    _gender = e?.gender ?? 'male';
    _selectedBranchId = e?.branchId;
    // _selectedBranchName will be set after loading branches
  }

  Future<void> _loadBranches() async {
    try {
      final list = await _hrService.getBranches(widget.companyId);
      if (mounted) {
        setState(() {
          _branches = list;
          _fetchingBranches = false;
          
          if (_selectedBranchId != null) {
            final b = list.firstWhere((element) => element['id'] == _selectedBranchId, orElse: () => {});
            if (b.isNotEmpty) {
              _selectedBranchName = b['name'];
            }
          }
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
        id: widget.employee?.id, 
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        secondaryPhone: _secondaryPhoneController.text.trim(),
        designation: _designationController.text.trim(),
        role: _role,
        status: _status,
        gender: _gender,
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
        isUser: widget.employee?.isUser,
        userId: widget.employee?.userId,
      );

      if (widget.employee == null) {
        await _hrService.createEmployee(employee, widget.companyId);
      } else {
        await _hrService.updateEmployee(employee);
      }

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                widget.employee == null ? "New Employee" : "Edit Employee",
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 20),
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
                    _buildSectionTitle("Personal Details", Icons.person, isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_firstNameController, "First Name", required: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_lastNameController, "Last Name")),
                      ],
                    ),
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
                    
                    Row(
                      children: [
                        Expanded(child: _buildSelectorField("Role", _role, ['employee', 'workforce', 'manager'], (v) => setState(() => _role = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSelectorField("Gender", _gender, ['male', 'female', 'other'], (v) => setState(() => _gender = v))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSelectorField("Status", _status, ['active', 'inactive', 'probation', 'terminated'], (v) => setState(() => _status = v)),
                    const SizedBox(height: 12),
                    
                    // Branch Selector
                    _buildBranchSelector(),

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
                    
                    const SizedBox(height: 30),
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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("SAVE DETAILS", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
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

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black12)),
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
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSelectorField(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
              children: items.map((item) => ListTile(
                title: Text(item.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                trailing: value == item ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                onTap: () {
                  onChanged(item);
                  Navigator.pop(c);
                },
              )).toList(),
            ),
          )
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.black54),
        ),
        child: Text(value.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _buildBranchSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_fetchingBranches) return const LinearProgressIndicator(minHeight: 2);
    
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
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text("Select Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        title: Text("All Branches (Global)", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                        trailing: _selectedBranchId == null ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                        onTap: () {
                          setState(() {
                             _selectedBranchId = null;
                             _selectedBranchName = "Global / All Branches";
                          });
                          Navigator.pop(c);
                        },
                      ),
                      ..._branches.map((b) => ListTile(
                        title: Text(b['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                        trailing: _selectedBranchId == b['id'] ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                        onTap: () {
                          setState(() {
                            _selectedBranchId = b['id'];
                            _selectedBranchName = b['name'];
                          });
                          Navigator.pop(c);
                        },
                      )),
                    ],
                  ),
                ),
              ],
            ),
          )
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Assigned Branch",
          labelStyle: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white60 : Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.black54),
        ),
        child: Text(_selectedBranchName ?? "Global / All Branches", style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black87)),
      ),
    );
  }
}
