import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class CompanyProfileScreen extends StatefulWidget {
  final String companyId;
  const CompanyProfileScreen({super.key, required this.companyId});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _gstinController;
  late TextEditingController _panController;
  late TextEditingController _cinController;
  late TextEditingController _fssaiController;
  late TextEditingController _upiController;

  late TextEditingController _line1Controller;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  String _selectedState = 'Delhi';

  String _entityType = 'proprietorship';
  bool _isFetchingAddr = false;

  final List<String> _states = ['Maharashtra', 'Delhi', 'Karnataka', 'Gujarat', 'Tamil Nadu', 'Uttar Pradesh', 'West Bengal', 'Telangana', 'Rajasthan', 'Kerala'];
  final List<String> _entityTypes = ['proprietorship', 'partnership', 'pvt_ltd', 'public_ltd', 'llp'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _websiteController = TextEditingController();
    _gstinController = TextEditingController();
    _panController = TextEditingController();
    _cinController = TextEditingController();
    _fssaiController = TextEditingController();
    _upiController = TextEditingController();
    _line1Controller = TextEditingController();
    _cityController = TextEditingController();
    _pincodeController = TextEditingController();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    try {
      final data = await _settingsService.getCompanyProfile(widget.companyId);
      final addr = data['address'] != null && data['address'] is Map ? data['address'] : {};

      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _websiteController.text = data['website'] ?? '';
        _gstinController.text = data['gstin'] ?? '';
        _panController.text = data['pan'] ?? '';
        _cinController.text = data['cin'] ?? '';
        _fssaiController.text = data['fssai_lic_no'] ?? data['lic_no'] ?? data['fssai'] ?? '';
        _upiController.text = data['upi_id'] ?? data['upi'] ?? '';
        _entityType = data['entity_type'] ?? 'proprietorship';
        
        _line1Controller.text = addr['line1'] ?? '';
        _cityController.text = addr['city'] ?? '';
        _pincodeController.text = addr['pincode'] ?? '';
        _selectedState = addr['state'] ?? 'Delhi';

        _isLoading = false;
      });
    } catch (e) {
      StatusService.show(context, 'Error loading company data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await _settingsService.updateCompanyProfile(widget.companyId, {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'website': _websiteController.text,
        'gstin': _gstinController.text.toUpperCase(),
        'pan': _panController.text.toUpperCase(),
        'cin': _cinController.text.toUpperCase(),
        'fssai_lic_no': _fssaiController.text.toUpperCase(),
        'upi_id': _upiController.text,
        'entity_type': _entityType,
        'address': {
          'line1': _line1Controller.text,
          'city': _cityController.text,
          'state': _selectedState,
          'pincode': _pincodeController.text,
          'country': 'India',
        }
      });

      if (!mounted) return;
      StatusService.show(context, 'Profile updated successfully!', backgroundColor: AppColors.success);
    } catch (e) {
      StatusService.show(context, 'Error saving changes: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bgColor = context.scaffoldBg;
    final surfaceColor = context.surfaceBg;
    final cardColor = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textTertiary;
    final borderColor = context.borderColor;
    final inputFill = context.inputFill;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Company Profile", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text("Save", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Identity", textTertiary),
            _buildCard([
              _buildTextField("Company Name", _nameController, Icons.business_rounded, textPrimary, textSecondary, inputFill),
              _buildTextField("Display Email", _emailController, Icons.mail_outline_rounded, textPrimary, textSecondary, inputFill, keyboardType: TextInputType.emailAddress),
              _buildTextField("Support Phone", _phoneController, Icons.phone_outlined, textPrimary, textSecondary, inputFill, keyboardType: TextInputType.phone),
              _buildTextField("UPI ID (For Print QR)", _upiController, Icons.qr_code_2_rounded, textPrimary, textSecondary, inputFill),
            ], cardColor, borderColor),
            const SizedBox(height: 32),
            _buildSectionHeader("Legal & Compliance", textTertiary),
            _buildCard([
              _buildDropdownField("Entity Type", _entityType, _entityTypes, (val) => setState(() => _entityType = val), textPrimary, textSecondary, inputFill),
              _buildTextField(
                "GSTIN", 
                _gstinController, 
                Icons.receipt_long_rounded, 
                textPrimary, textSecondary, inputFill, uppercase: true,
                onChanged: (v) {
                  if (v.length == 15 && v.toUpperCase() != "URP") {
                    _panController.text = v.substring(2, 12).toUpperCase();
                  }
                }
              ),
              _buildTextField("FSSAI / License No.", _fssaiController, Icons.shield_rounded, textPrimary, textSecondary, inputFill, uppercase: true),
              Row(
                children: [
                  Expanded(child: _buildTextField("PAN", _panController, Icons.credit_card_rounded, textPrimary, textSecondary, inputFill, uppercase: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("CIN", _cinController, Icons.factory_rounded, textPrimary, textSecondary, inputFill, uppercase: true)),
                ],
              ),
            ], cardColor, borderColor),
            const SizedBox(height: 32),
            _buildSectionHeader("Official Address", textTertiary),
            _buildCard([
              Row(
                children: [
                   Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PIN Code", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
                          onChanged: (v) async {
                            if (v.length == 6) {
                              setState(() => _isFetchingAddr = true);
                              try {
                                final res = await _settingsService.fetchAddressFromPincode(v);
                                if (res != null) {
                                  setState(() {
                                    _cityController.text = res['city'] ?? '';
                                    _selectedState = res['state'] ?? 'Delhi';
                                  });
                                }
                              } finally {
                                setState(() => _isFetchingAddr = false);
                              }
                            }
                          },
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: inputFill,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixIcon: _isFetchingAddr ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("City", _cityController, Icons.location_city_rounded, textPrimary, textSecondary, inputFill)),
                ],
              ),
              const SizedBox(height: 16),
              _buildDropdownField("State", _selectedState, _states, (val) => setState(() => _selectedState = val), textPrimary, textSecondary, inputFill),
              const SizedBox(height: 16),
              _buildTextField("Address Line", _line1Controller, Icons.map_rounded, textPrimary, textSecondary, inputFill),
            ], cardColor, borderColor),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.2)),
    );
  }

  Widget _buildCard(List<Widget> children, Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, Color textPrimary, Color textSecondary, Color inputFill, {TextInputType keyboardType = TextInputType.text, bool uppercase = false, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
          const SizedBox(height: 8),
          TextField(
            onChanged: onChanged,
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
            style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
            inputFormatters: keyboardType == TextInputType.phone 
                ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: textSecondary, size: 20),
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> options, ValueChanged<String> onSelected, Color textPrimary, Color textSecondary, Color inputFill) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showSelectionSheet(label, options, value, onSelected),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(value.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                  Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectionSheet(String title, List<String> options, String currentValue, ValueChanged<String> onSelected) {
    final isDark = context.isDark;
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text("Select $title", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 8),
                    Text("Choose an option from the list below", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
                    const SizedBox(height: 24),
                    ...options.map((opt) {
                      final isSelected = opt == currentValue;
                      return ListTile(
                        onTap: () {
                          onSelected(opt);
                          Navigator.pop(context);
                        },
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(opt.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : textPrimary)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24) : null,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
