import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import '../../services/settings_service.dart';

class VendorFormScreen extends StatefulWidget {
  final Map<String, dynamic>? vendor;
  final bool isSheet;
  const VendorFormScreen({super.key, this.vendor, this.isSheet = false});

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _loading = false;
  
  // Basic Info
  String _name = '';
  String _contactPerson = '';
  String _phone = '';
  String _email = '';
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  String _paymentTerms = 'Net 30';

  // Address
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  String _country = 'India';

  @override
  void initState() {
    super.initState();
    if (widget.vendor != null) {
      _loadVendorData();
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    super.dispose();
  }

  void _loadVendorData() {
    final v = widget.vendor!;
    _name = v['name'] ?? '';
    _contactPerson = v['contact_person'] ?? '';
    _phone = v['phone'] ?? '';
    _email = v['email'] ?? '';
    _gstinController.text = v['gstin'] ?? '';
    _panController.text = v['pan'] ?? '';
    _paymentTerms = v['payment_terms'] ?? 'Net 30';
    
    if (v['address'] != null) {
      final addr = v['address'];
      _streetController.text = addr['line1'] ?? addr['street'] ?? '';
      _cityController.text = addr['city'] ?? '';
      _stateController.text = addr['state'] ?? '';
      _pincodeController.text = (addr['pincode'] ?? addr['postal_code'] ?? '').toString();
      _country = addr['country'] ?? 'India';
    }
  }

  Future<void> _fetchPincodeDetails(String pincode) async {
    if (pincode.length != 6) return;
    
    final details = await _settingsService.fetchAddressFromPincode(pincode);
    if (details != null && mounted) {
      setState(() {
        _cityController.text = details['city'] ?? '';
        _stateController.text = details['state'] ?? '';
      });
    }
  }

  Future<void> _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user!.id)
          .single();
      final companyId = profile['company_id'];

      final address = {
        'line1': _streetController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'country': _country,
      };

      final vendorData = {
        'company_id': companyId,
        'name': _name,
        'contact_person': _contactPerson,
        'phone': _phone,
        'email': _email,
        'gstin': _gstinController.text,
        'pan': _panController.text,
        'payment_terms': _paymentTerms,
        'address': address
      };

      if (widget.vendor != null) {
        await Supabase.instance.client.from('vendors').update(vendorData).eq('id', widget.vendor!['id']);
      } else {
        await Supabase.instance.client.from('vendors').insert(vendorData);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vendor saved successfully!"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      debugPrint("Error saving vendor: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSheet) {
      return _buildContent(context);
    }
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(child: _buildContent(context)),
    );
  }

  Widget _buildContent(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: widget.isSheet ? const BorderRadius.vertical(top: Radius.circular(32)) : null,
        ),
        child: Column(
          children: [
            if (widget.isSheet) ...[
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      widget.vendor != null ? "Edit Vendor" : "New Vendor",
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 22),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!widget.isSheet)
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(widget.vendor != null ? "Edit Vendor" : "New Vendor", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                iconTheme: IconThemeData(color: context.textPrimary),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("BASIC INFORMATION"),
                      const SizedBox(height: 16),
                      _buildFormCard([
                        _buildTextField("Business Name", onSave: (v) => _name = v!, icon: Icons.business_rounded, isRequired: true, initialValue: _name),
                        const SizedBox(height: 20),
                        _buildTextField("Contact Person", onSave: (v) => _contactPerson = v!, icon: Icons.person_rounded, initialValue: _contactPerson),
                         const SizedBox(height: 20),
                        _buildTextField("Phone Number", onSave: (v) => _phone = v!, icon: Icons.phone_rounded, keyboard: TextInputType.phone, initialValue: _phone, isRequired: true),
                        const SizedBox(height: 20),
                        _buildTextField("Email Address", onSave: (v) => _email = v!, icon: Icons.mail_rounded, keyboard: TextInputType.emailAddress, initialValue: _email),
                      ]),
                      
                      const SizedBox(height: 32),
                      _buildSectionHeader("TAX & TERMS"),
                      const SizedBox(height: 16),
                      _buildFormCard([
                        _buildTextField(
                          "GSTIN Number", 
                          onSave: (v) {}, 
                          icon: Icons.verified_user_rounded, 
                          controller: _gstinController, 
                          isGstin: true,
                          onChanged: (v) {
                            if (v.length == 15 && v.toUpperCase() != "URP") {
                              _panController.text = v.substring(2, 12).toUpperCase();
                            }
                          }
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          "PAN Number", 
                          onSave: (v) {}, 
                          icon: Icons.credit_card_rounded, 
                          controller: _panController, 
                          isPan: true
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          "Payment Terms",
                          key: ValueKey(_paymentTerms),
                          initialValue: _paymentTerms,
                          onSave: (v) => _paymentTerms = v ?? "Net 30",
                          icon: Icons.payments_rounded,
                          readOnly: true,
                          onTap: _showPaymentTermsSheet,
                        ),
                      ]),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader("ADDRESS"),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _streetController.clear();
                                _cityController.clear();
                                _stateController.clear();
                                _pincodeController.clear();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text("Clear", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildFormCard([
                        _buildTextField("Street Address", onSave: (v) {}, controller: _streetController, icon: Icons.location_on_rounded, maxLines: 2),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                "PIN Code", 
                                onSave: (v) {}, 
                                controller: _pincodeController, 
                                keyboard: TextInputType.number,
                                isPincode: true,
                                onChanged: (v) => _fetchPincodeDetails(v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Country", onSave: (v) => _country = v!, initialValue: _country)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("City", onSave: (v) {}, controller: _cityController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("State", onSave: (v) {}, controller: _stateController)),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveVendor,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 8,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: _loading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text(widget.vendor != null ? "Update Vendor" : "Create Vendor", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(children: children),
    );
  }

  void _showPaymentTermsSheet() {
    final terms = ["Net 15", "Net 30", "Net 45", "Net 60", "Due on Receipt"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Payment Terms", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              ...terms.map((term) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(term, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, color: context.textPrimary)),
                trailing: _paymentTerms == term ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _paymentTerms = term);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {Key? key, required Function(String?) onSave, String? initialValue, IconData? icon, bool isRequired = false, TextInputType? keyboard, int maxLines = 1, TextEditingController? controller, Function(String)? onChanged, bool isGstin = false, bool isPan = false, bool isPincode = false, bool readOnly = false, VoidCallback? onTap}) {
    return TextFormField(
      key: key,
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _inputDecoration(label, icon: icon),
      textCapitalization: (isGstin || isPan) ? TextCapitalization.characters : TextCapitalization.none,
      autocorrect: !(isGstin || isPan),
      enableSuggestions: !(isGstin || isPan),
      inputFormatters: [
        if (keyboard == TextInputType.phone) ...[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        if (isPincode) ...[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        if (isGstin) ...[
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(15),
        ],
        if (isPan) ...[
          UpperCaseTextFormatter(),
          LengthLimitingTextInputFormatter(10),
        ],
      ],
      validator: (v) {
        if (isRequired && (v == null || v.isEmpty)) return "Required";
        if (v != null && v.isNotEmpty) {
          if (keyboard == TextInputType.phone) {
            final digits = v.replaceAll(RegExp(r'\D'), '');
            if (digits.length != 10) return "Must be exactly 10 digits";
          }
          if (keyboard == TextInputType.emailAddress) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(v)) return "Invalid email format";
          }
          if (isGstin) {
            final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
            if (v.toUpperCase() != "URP" && !gstRegex.hasMatch(v.toUpperCase())) {
              return "Invalid GSTIN format (e.g. 22AAAAA0000A1Z5)";
            }
          }
          if (isPan) {
            final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
            if (!panRegex.hasMatch(v.toUpperCase())) {
              return "Invalid PAN format (e.g. ABCDE1234F)";
            }
          }
        }
        return null;
      },
      onSaved: onSave,
      onChanged: onChanged,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: context.textSecondary.withOpacity(0.5)) : null,
      labelStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary),
      floatingLabelStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: context.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
