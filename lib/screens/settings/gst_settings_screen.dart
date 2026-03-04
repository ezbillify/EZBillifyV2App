import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class GSTSettingsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const GSTSettingsScreen({super.key, required this.companyId});

  @override
  ConsumerState<GSTSettingsScreen> createState() => _GSTSettingsScreenState();
}

class _GSTSettingsScreenState extends ConsumerState<GSTSettingsScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isComposition = false;
  bool _enableReverseCharge = false;
  bool _enableEinvoice = false;
  bool _enableEwaybill = false;
  late TextEditingController _hsnController;

  @override
  void initState() {
    super.initState();
    _hsnController = TextEditingController();
    _loadGSTData();
  }

  Future<void> _loadGSTData() async {
    try {
      final data = await _settingsService.getGSTSettings(widget.companyId);
      if (mounted) {
        setState(() {
          _isComposition = data['is_composition'] ?? false;
          _enableReverseCharge = data['enable_reverse_charge'] ?? false;
          _enableEinvoice = data['enable_einvoice'] ?? false;
          _enableEwaybill = data['enable_ewaybill'] ?? false;
          _hsnController.text = data['default_hsn'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StatusService.show(context, 'Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePolicy() async {
    setState(() => _isSaving = true);
    try {
      await _settingsService.updateGSTSettings(widget.companyId, {
        'is_composition': _isComposition,
        'enable_reverse_charge': _enableReverseCharge,
        'enable_einvoice': _enableEinvoice,
        'enable_ewaybill': _enableEwaybill,
        'default_hsn': _hsnController.text,
      });
      if (!mounted) return;
      StatusService.show(context, 'GST Policy updated!');
    } catch (e) {
      if (mounted) StatusService.show(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme to rebuild on changes
    ref.watch(themeServiceProvider);
    
    if (_isLoading) return Scaffold(backgroundColor: context.scaffoldBg, body: const Center(child: CircularProgressIndicator()));

    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final surfaceBg = context.surfaceBg;
    final scaffoldBg = context.scaffoldBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("GST Compliance", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePolicy,
            child: _isSaving 
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textSecondary))
              : const Text("Save Policy", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildPolicySection("General Policy", [
              _buildSwitchTile(
                "Composition Scheme",
                "Is your company registered under Composition?",
                _isComposition,
                (v) => setState(() => _isComposition = v),
              ),
              _buildSwitchTile(
                "Reverse Charge (RCM)",
                "Enable RCM calculations on purchases.",
                _enableReverseCharge,
                (v) => setState(() => _enableReverseCharge = v),
              ),
              const SizedBox(height: 20),
              _buildHSNField(),
            ]),
            const SizedBox(height: 24),
            _buildPolicySection("E-Invoicing & Automation", [
              _buildSwitchTile(
                "Enable E-Invoicing",
                "Generate IRN generation features.",
                _enableEinvoice,
                (v) => setState(() => _enableEinvoice = v),
              ),
              _buildSwitchTile(
                "Enable E-Way Bill",
                "Auto-generate E-Way bills for consignments.",
                _enableEwaybill,
                (v) => setState(() => _enableEwaybill = v),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryBlue.withOpacity(0.15) : const Color(0xFFEFF6FF), 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: isDark ? AppColors.primaryBlue.withOpacity(0.3) : const Color(0xFFBFDBFE))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: isDark ? AppColors.secondaryBlue : const Color(0xFF1D4ED8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Managing GSTINs?", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isDark ? AppColors.secondaryBlue : const Color(0xFF1E3A8A))),
                const SizedBox(height: 4),
                Text(
                  "GST numbers are linked to branches. To update GSTINs, please visit the Branches section.",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: isDark ? context.textSecondary : const Color(0xFF1D4ED8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg, 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: context.borderColor)
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text(subtitle, style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primaryBlue),
        ],
      ),
    );
  }

  Widget _buildHSNField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Default HSN / SAC Code", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: _hsnController,
          style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary),
          decoration: InputDecoration(
            hintText: "e.g. 9983",
            hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
          ),
        ),
      ],
    );
  }
}
