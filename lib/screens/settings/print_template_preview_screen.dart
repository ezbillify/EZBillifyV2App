import 'package:flutter/material.dart';
import '../../core/theme_service.dart';
import '../../services/print_settings_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class PrintTemplatePreviewScreen extends StatefulWidget {
  const PrintTemplatePreviewScreen({super.key});

  @override
  State<PrintTemplatePreviewScreen> createState() => _PrintTemplatePreviewScreenState();
}

class _PrintTemplatePreviewScreenState extends State<PrintTemplatePreviewScreen> {
  String _selectedDocType = 'invoice';
  final Map<String, String> _docTypeLabels = {
    'invoice': 'Invoices',
    'order': 'Sales Orders',
    'quotation': 'Quotations',
    'dc': 'Delivery Challans',
    'payment': 'Payment Receipts',
    'credit_note': 'Credit Notes',
  };

  TemplateType? _activeTemplate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final type = await PrintSettingsService.getTemplate(_selectedDocType);
    setState(() {
      _activeTemplate = type;
    });
  }

  Future<void> _handleSelect(TemplateType type) async {
    await PrintSettingsService.setTemplate(_selectedDocType, type);
    setState(() {
      _activeTemplate = type;
    });
    if (mounted) {
      StatusService.show(context, "Template updated for ${_docTypeLabels[_selectedDocType]}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final scaffoldBg = context.scaffoldBg;
    final surfaceBg = context.surfaceBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("Print Layouts", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildDocTypeSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTemplateCard(
                    context,
                    TemplateType.a4Standard,
                    "Standard GST V3 (A4)",
                    "Recommended for desktop printing and professional PDF sharing. Includes full tax breakup, bank details, and terms.",
                    Icons.picture_as_pdf_rounded,
                    const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 20),
                  _buildTemplateCard(
                    context,
                    TemplateType.thermal80mm,
                    "Thermal Receipt (80mm)",
                    "Standard width for most thermal printers. Optimized for clear itemized billing and readable fonts.",
                    Icons.print_rounded,
                    AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 20),
                  _buildTemplateCard(
                    context,
                    TemplateType.thermal58mm,
                    "Compact Thermal (58mm)",
                    "Perfect for small mobile Bluetooth printers. Concise layout that saves paper while showing key details.",
                    Icons.horizontal_rule_rounded,
                    const Color(0xFF0D9488),
                  ),
                  const SizedBox(height: 20),
                  _buildTemplateCard(
                    context,
                    TemplateType.a5Modern,
                    "Modern Invoice (A5)",
                    "Clean, half-size layout for retail and service businesses wanting to save paper without losing professionalism.",
                    Icons.description_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocTypeSelector() {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _docTypeLabels.entries.map((entry) {
          final isSelected = _selectedDocType == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(entry.value, style: TextStyle(fontFamily: 'Outfit', color: isSelected ? Colors.white : context.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedDocType = entry.key);
                  _loadSettings();
                }
              },
              selectedColor: AppColors.primaryBlue,
              backgroundColor: context.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isSelected ? AppColors.primaryBlue : context.borderColor)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, TemplateType type, String title, String desc, IconData icon, Color color) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;
    final isActive = _activeTemplate == type;

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? AppColors.primaryBlue : borderColor, width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                      if (isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Text("ACTIVE", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(desc, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: borderColor),
                    ),
                    child: Text("Preview", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isActive ? null : () => _handleSelect(type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? Colors.grey : AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isActive ? "Selected" : "Set Active", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
