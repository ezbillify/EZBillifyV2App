import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class BrandingSettingsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const BrandingSettingsScreen({super.key, required this.companyId});

  @override
  ConsumerState<BrandingSettingsScreen> createState() => _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState extends ConsumerState<BrandingSettingsScreen> with SingleTickerProviderStateMixin {
  final _settingsService = SettingsService();
  final _picker = ImagePicker();
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingMain = false;
  bool _isUploadingThermal = false;

  Map<String, dynamic> _branding = {};
  String? _mainLogoUrl;
  String? _thermalLogoUrl;
  late TextEditingController _footerController;

  final List<Color> _presetColors = [
    const Color(0xFF2563EB), // Blue
    const Color(0xFF7C3AED), // Purple
    const Color(0xFF10B981), // Emerald
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF0F172A), // Slate
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _footerController = TextEditingController();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final data = await _settingsService.getBrandingSettings(widget.companyId);
      if (mounted) {
        setState(() {
          _branding = data['branding'] ?? {
            'primary_color': '#2563EB',
            'footer_text': '',
            'sale': {'primary': {'template': 'modern', 'paper': 'a4'}},
            'pos': {'primary': {'template': 'thermal_v2', 'paper': '80mm'}},
          };
          _mainLogoUrl = data['logo_url'];
          _thermalLogoUrl = data['thermal_logo_url'];
          _footerController.text = _branding['footer_text'] ?? '';
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

  Future<void> _pickLogo(bool isMain) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (image == null) return;

    setState(() {
      if (isMain) _isUploadingMain = true; else _isUploadingThermal = true;
    });

    try {
      final url = await _settingsService.uploadLogo(widget.companyId, image.path, image.name);
      await _settingsService.updateBrandingSettings(widget.companyId, {
        isMain ? 'logo_url' : 'thermal_logo_url': url
      });

      if (mounted) {
        setState(() {
          if (isMain) {
            _mainLogoUrl = url;
            _isUploadingMain = false;
          } else {
            _thermalLogoUrl = url;
            _isUploadingThermal = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        StatusService.show(context, 'Upload Error: $e');
        setState(() {
          if (isMain) _isUploadingMain = false; else _isUploadingThermal = false;
        });
      }
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);
    _branding['footer_text'] = _footerController.text;
    try {
      await _settingsService.updateBrandingSettings(widget.companyId, {
        'branding': _branding,
      });
      if (!mounted) return;
      StatusService.show(context, 'Branding updated!');
    } catch (e) {
      if (mounted) StatusService.show(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme
    ref.watch(themeServiceProvider);
    
    if (_isLoading) return Scaffold(backgroundColor: context.scaffoldBg, body: const Center(child: CircularProgressIndicator()));

    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final surfaceBg = context.surfaceBg;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("Branding", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            Center(child: Padding(padding: const EdgeInsets.only(right: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textSecondary))))
          else
            TextButton(
              onPressed: _saveAll,
              child: const Text("Save", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryBlue,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: "GENERAL"),
            Tab(text: "SALES"),
            Tab(text: "POS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          _buildDocumentTab('sale', 'Standard Invoice'),
          _buildDocumentTab('pos', 'Thermal Receipt'),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Identity"),
          Row(
            children: [
              _buildLogoCard("PDF Logo", _mainLogoUrl, _isUploadingMain, () => _pickLogo(true)),
              const SizedBox(width: 16),
              _buildLogoCard("Thermal Logo", _thermalLogoUrl, _isUploadingThermal, () => _pickLogo(false)),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader("Appearance"),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Brand Color", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _presetColors.map((color) {
                    final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                    final isSelected = _branding['primary_color'] == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _branding['primary_color'] = hex),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                          boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 48),
                Text("Footer Message", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _footerController,
                  style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
                  decoration: InputDecoration(
                    hintText: "Thank you for your business!",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTab(String key, String label) {
    final config = _branding[key]?['primary'] ?? {'template': 'modern', 'paper': key == 'pos' ? '80mm' : 'a4'};
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("$label Settings"),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)),
            child: Column(
              children: [
                _buildPickerTile("Layout", config['template'], 
                  key == 'pos' ? ['thermal_v2', 'thermal_v3'] : ['modern', 'gst_v3', 'classic'], 
                  (v) => setState(() {
                    _branding[key] ??= {'primary': {}};
                    _branding[key]['primary']['template'] = v;
                  })
                ),
                const Divider(height: 32),
                _buildPickerTile("Paper Size", config['paper'], 
                  key == 'pos' ? ['80mm', '58mm'] : ['a4', 'a5'], 
                  (v) => setState(() {
                    _branding[key] ??= {'primary': {}};
                    _branding[key]['primary']['paper'] = v;
                  })
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text("Preview will appear here in the next update", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary, letterSpacing: 1.2)),
    );
  }

  Widget _buildLogoCard(String label, String? url, bool isLoading, VoidCallback onTap) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              height: 100,
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
              child: Stack(
                children: [
                  if (url != null)
                    Center(child: Padding(padding: const EdgeInsets.all(12), child: Image.network(url, fit: BoxFit.contain)))
                  else
                    Center(child: Icon(Icons.add_photo_alternate_rounded, color: textSecondary.withOpacity(0.5), size: 28)),
                  if (isLoading) Container(color: cardBg.withOpacity(0.7), child: const Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile(String title, String value, List<String> options, ValueChanged<String> onSelected) {
    return InkWell(
      onTap: () => _showSelectionSheet(title, options, value, onSelected),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: context.textPrimary)),
          Row(
            children: [
              Text(value.toString().toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
            ],
          ),
        ],
      ),
    );
  }

  void _showSelectionSheet(String title, List<String> options, String currentValue, ValueChanged<String> onSelected) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text("Select $title", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Customize your document settings", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        ...options.map((opt) {
                          final isSelected = opt == currentValue;
                          return ListTile(
                            onTap: () {
                              onSelected(opt);
                              Navigator.pop(context);
                            },
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(opt.toString().toUpperCase().replaceAll('_', ' '), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
                            trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24) : null,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
