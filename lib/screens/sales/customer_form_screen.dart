import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../core/theme_service.dart';
import '../../services/settings_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? customer;
  final bool isSheet;
  const CustomerFormScreen({super.key, this.customer, this.isSheet = false});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _loading = false;
  
  // Basic Info
  String _name = '';
  String _companyName = '';
  String _customerType = 'B2C';
  String _email = '';
  String _phone = '';
  final _gstinController = TextEditingController();
  final _panController = TextEditingController();
  
  // Billing Address
  final _billingStreetController = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingPincodeController = TextEditingController();
  String _billingCountry = 'India';

  // Shipping Address
  bool _sameAsBilling = true;
  final _shippingStreetController = TextEditingController();
  final _shippingCityController = TextEditingController();
  final _shippingStateController = TextEditingController();
  final _shippingPincodeController = TextEditingController();
  String _shippingCountry = 'India';

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _loadCustomerData();
    }
  }

  @override
  void dispose() {
    _billingStreetController.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPincodeController.dispose();
    _gstinController.dispose();
    _panController.dispose();
    _shippingStreetController.dispose();
    _shippingCityController.dispose();
    _shippingStateController.dispose();
    _shippingPincodeController.dispose();
    super.dispose();
  }

  void _loadCustomerData() {
    final c = widget.customer!;
    _name = c['name'] ?? '';
    _customerType = c['customer_type'] ?? 'B2C';
    if (_customerType == 'B2B') _companyName = _name;
    _email = c['email'] ?? '';
    _phone = c['phone'] ?? '';
    _gstinController.text = c['gstin'] ?? '';
    _panController.text = c['pan'] ?? '';
    
    if (c['billing_address'] != null) {
      final addr = c['billing_address'];
      _billingStreetController.text = addr['line1'] ?? addr['street'] ?? '';
      _billingCityController.text = addr['city'] ?? '';
      _billingStateController.text = addr['state'] ?? '';
      _billingPincodeController.text = (addr['pincode'] ?? addr['postal_code'] ?? '').toString();
      _billingCountry = addr['country'] ?? 'India';
    }

    if (c['shipping_addresses'] != null || c['shipping_address'] != null) {
      final addr = c['shipping_addresses'] ?? c['shipping_address'];
      _shippingStreetController.text = addr['line1'] ?? addr['street'] ?? '';
      _shippingCityController.text = addr['city'] ?? '';
      _shippingStateController.text = addr['state'] ?? '';
      _shippingPincodeController.text = (addr['pincode'] ?? addr['postal_code'] ?? '').toString();
      _shippingCountry = addr['country'] ?? 'India';
      _sameAsBilling = false;
    }
  }

  Future<void> _fetchPincodeDetails(String pincode, bool isBilling) async {
    if (pincode.length != 6) return;
    
    final details = await _settingsService.fetchAddressFromPincode(pincode);
    if (details != null && mounted) {
      setState(() {
        if (isBilling) {
          _billingCityController.text = details['city'] ?? '';
          _billingStateController.text = details['state'] ?? '';
          if (_sameAsBilling) {
            _shippingCityController.text = _billingCityController.text;
            _shippingStateController.text = _billingStateController.text;
          }
        } else {
          _shippingCityController.text = details['city'] ?? '';
          _shippingStateController.text = details['state'] ?? '';
        }
      });
    }
  }

  Future<void> _saveCustomer() async {
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
      
      final billingAddress = {
        'line1': _billingStreetController.text,
        'city': _billingCityController.text,
        'state': _billingStateController.text,
        'pincode': _billingPincodeController.text,
        'country': _billingCountry,
      };

      final shippingAddress = _sameAsBilling ? billingAddress : {
        'line1': _shippingStreetController.text,
        'city': _shippingCityController.text,
        'state': _shippingStateController.text,
        'pincode': _shippingPincodeController.text,
        'country': _shippingCountry,
      };

      final data = {
        'company_id': companyId,
        'name': _customerType == 'B2B' ? _companyName : _name,
        'customer_type': _customerType,
        'email': _email,
        'phone': _phone,
        'gstin': _gstinController.text,
        'pan': _panController.text,
        'billing_address': billingAddress,
        'shipping_addresses': shippingAddress,
      };

      if (widget.customer != null) {
        await Supabase.instance.client.from('customers').update(data).eq('id', widget.customer!['id']);
      } else {
        await Supabase.instance.client.from('customers').insert(data);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving customer: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      widget.customer != null ? "Edit Customer" : "New Customer",
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
                title: Text(widget.customer != null ? "Edit Customer" : "New Customer", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
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
                        _buildTypeToggle(),
                        const SizedBox(height: 24),
                        if (_customerType == 'B2B') ...[
                          _buildTextField("Business Name", onSave: (v) => _companyName = v!, icon: Icons.business_rounded, isRequired: true, initialValue: _companyName),
                          const SizedBox(height: 20),
                        ],
                        _buildTextField(_customerType == 'B2B' ? "Contact Person" : "Customer Name", onSave: (v) => _name = v!, icon: Icons.person_rounded, isRequired: true, initialValue: _name),
                        const SizedBox(height: 20),
                        _buildTextField("Phone Number", onSave: (v) => _phone = v!, icon: Icons.phone_rounded, keyboard: TextInputType.phone, initialValue: _phone, isRequired: true),
                        const SizedBox(height: 20),
                        _buildTextField("Email Address", onSave: (v) => _email = v!, icon: Icons.mail_rounded, keyboard: TextInputType.emailAddress, initialValue: _email),
                        if (_customerType == 'B2B') ...[
                          const SizedBox(height: 20),
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
                        ],
                      ]),
                      
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader("BILLING ADDRESS"),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _billingStreetController.clear();
                                _billingCityController.clear();
                                _billingStateController.clear();
                                _billingPincodeController.clear();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text("Clear", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAddressFields(isBilling: true),

                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _buildSectionHeader("SHIPPING ADDRESS"),
                          const Spacer(),
                          Row(
                            children: [
                              const Text("Same as billing", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Color(0xFF64748B))),
                              Switch.adaptive(
                                value: _sameAsBilling,
                                activeColor: AppColors.primaryBlue,
                                onChanged: (v) {
                                  setState(() {
                                    _sameAsBilling = v;
                                    if (v) {
                                      _shippingStreetController.text = _billingStreetController.text;
                                      _shippingCityController.text = _billingCityController.text;
                                      _shippingStateController.text = _billingStateController.text;
                                      _shippingPincodeController.text = _billingPincodeController.text;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_sameAsBilling) _buildAddressFields(isBilling: false),
                      if (_sameAsBilling) 
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 20, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Shipping address is currently synced with the billing address.",
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                  onPressed: _loading ? null : _saveCustomer,
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
                    : Text(widget.customer != null ? "Update Customer" : "Create Customer", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressFields({required bool isBilling}) {
    final street = isBilling ? _billingStreetController : _shippingStreetController;
    final city = isBilling ? _billingCityController : _shippingCityController;
    final state = isBilling ? _billingStateController : _shippingStateController;
    final pincode = isBilling ? _billingPincodeController : _shippingPincodeController;

    return _buildFormCard([
      _buildTextField("Street Address", onSave: (v) {}, controller: street, icon: Icons.location_on_rounded, maxLines: 2),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              "PIN Code", 
              onSave: (v) {}, 
              controller: pincode, 
              keyboard: TextInputType.number,
              isPincode: true,
              onChanged: (v) {
                _fetchPincodeDetails(v, isBilling);
                if (isBilling && _sameAsBilling) {
                  _shippingPincodeController.text = v;
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: _buildTextField("Country", onSave: (v) => isBilling ? _billingCountry = v! : _shippingCountry = v!, initialValue: isBilling ? _billingCountry : _shippingCountry)),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: _buildTextField("City", onSave: (v) {}, controller: city)),
          const SizedBox(width: 16),
          Expanded(child: _buildTextField("State", onSave: (v) {}, controller: state)),
        ],
      ),
    ]);
  }

  Widget _buildTypeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Customer Type",
          style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Container(
          height: 54,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutExpo,
                alignment: _customerType == 'B2C' ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: (MediaQuery.of(context).size.width - 96) / 2,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _customerType = 'B2C');
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Text(
                            "Consumer (B2C)",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _customerType == 'B2C' ? Colors.white : context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _customerType = 'B2B');
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Text(
                            "Business (B2B)",
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _customerType == 'B2B' ? Colors.white : context.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildTextField(String label, {required Function(String?) onSave, String? initialValue, IconData? icon, bool isRequired = false, TextInputType? keyboard, int maxLines = 1, TextEditingController? controller, Function(String)? onChanged, bool isGstin = false, bool isPan = false, bool isPincode = false}) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
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
      onChanged: (v) {
        onChanged?.call(v);
        if (isBillingField(controller) && _sameAsBilling) {
          syncToShipping(controller, v);
        }
      },
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500),
    );
  }

  bool isBillingField(TextEditingController? controller) {
    return controller == _billingStreetController || 
           controller == _billingCityController || 
           controller == _billingStateController || 
           controller == _billingPincodeController;
  }

  void syncToShipping(TextEditingController? billingController, String value) {
    if (billingController == _billingStreetController) _shippingStreetController.text = value;
    if (billingController == _billingCityController) _shippingCityController.text = value;
    if (billingController == _billingStateController) _shippingStateController.text = value;
    if (billingController == _billingPincodeController) _shippingPincodeController.text = value;
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
