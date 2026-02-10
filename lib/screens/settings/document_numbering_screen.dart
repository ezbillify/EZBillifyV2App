import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';

class DocumentNumberingScreen extends ConsumerStatefulWidget {
  final String companyId;
  const DocumentNumberingScreen({super.key, required this.companyId});

  @override
  ConsumerState<DocumentNumberingScreen> createState() => _DocumentNumberingScreenState();
}

class _DocumentNumberingScreenState extends ConsumerState<DocumentNumberingScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sequences = [];
  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId; // null means 'All Branches'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final sequences = await _settingsService.getDocumentSequences(widget.companyId);
      final branches = await _settingsService.getBranches(widget.companyId);
      if (mounted) {
        setState(() {
          _sequences = sequences;
          _branches = branches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSequences {
    if (_selectedBranchId == null) return _sequences;
    return _sequences.where((s) => s['branch_id'] == _selectedBranchId).toList();
  }

  void _showBranchSelector() {
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
            minChildSize: 0.3,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      children: [
                        Text("Filter by Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Select a branch to view its numbering sequences", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        _buildBranchTile("All Branches", null, Icons.dashboard_customize_rounded),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: context.dividerColor)),
                        ..._branches.map((b) => _buildBranchTile(b['name'], b['id'], Icons.storefront_rounded)),
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

  Widget _buildBranchTile(String name, String? id, IconData icon) {
    final isSelected = _selectedBranchId == id;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    
    return InkWell(
      onTap: () {
        setState(() => _selectedBranchId = id);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : textSecondary, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontFamily: 'Outfit', 
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : textPrimary,
                ),
              ),
            ),
            if (isSelected) 
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    
    final selectedBranchName = _selectedBranchId == null 
        ? "All Branches" 
        : _branches.firstWhere((b) => b['id'] == _selectedBranchId, orElse: () => {'name': 'Selected Branch'})['name'];

    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final surfaceBg = context.surfaceBg;
    final scaffoldBg = context.scaffoldBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("Document Numbering", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textSecondary),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                decoration: BoxDecoration(
                  color: surfaceBg,
                  border: Border(bottom: BorderSide(color: context.borderColor)),
                ),
                child: InkWell(
                  onTap: _showBranchSelector,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 20, color: textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Selected Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary.withOpacity(0.7), letterSpacing: 0.5)),
                              Text(selectedBranchName, style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                            ],
                          ),
                        ),
                        Icon(Icons.unfold_more_rounded, color: textSecondary.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _filteredSequences.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pin_rounded, size: 64, color: textSecondary.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          Text("No sequences found", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textSecondary)),
                          if (_selectedBranchId != null)
                            TextButton(
                              onPressed: () => setState(() => _selectedBranchId = null),
                              child: const Text("Clear Filters", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _filteredSequences.length,
                      itemBuilder: (context, index) {
                        return _SequenceCard(
                          sequence: _filteredSequences[index],
                          onSave: _loadData,
                        );
                      },
                    ),
              ),
            ],
          ),
    );
  }
}

class _SequenceCard extends StatefulWidget {
  final Map<String, dynamic> sequence;
  final VoidCallback onSave;
  const _SequenceCard({required this.sequence, required this.onSave});

  @override
  State<_SequenceCard> createState() => _SequenceCardState();
}

class _SequenceCardState extends State<_SequenceCard> {
  final _settingsService = SettingsService();
  bool _isSaving = false;
  late TextEditingController _prefixController;
  late TextEditingController _suffixController;
  late TextEditingController _lastNoController;
  int _padding = 5;
  bool _resetYearly = true;

  @override
  void initState() {
    super.initState();
    _prefixController = TextEditingController(text: widget.sequence['prefix'] ?? '');
    _suffixController = TextEditingController(text: widget.sequence['suffix'] ?? '');
    _lastNoController = TextEditingController(text: (widget.sequence['current_value'] ?? 0).toString());
    _padding = widget.sequence['padding_zeros'] ?? 5;
    _resetYearly = widget.sequence['reset_yearly'] ?? true;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await _settingsService.updateDocumentSequence(widget.sequence['id'], {
        'prefix': _prefixController.text.toUpperCase(),
        'suffix': _suffixController.text,
        'padding_zeros': _padding,
        'reset_yearly': _resetYearly,
        'current_value': int.tryParse(_lastNoController.text) ?? 0,
      });
      widget.onSave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sequence updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPaddingSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.6,
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
                        Text("Select Padding", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Choose how many digits to pad your numbers", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        ...[3, 4, 5, 6].map((p) {
                          final isSelected = _padding == p;
                          return ListTile(
                            onTap: () {
                              setState(() => _padding = p);
                              Navigator.pop(context);
                            },
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text("$p Digits (${'0' * (p - 1)}1)", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
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

  @override
  Widget build(BuildContext context) {
    final docType = widget.sequence['document_type']?.toString().replaceAll('_', ' ') ?? 'DOCUMENT';
    final branchName = widget.sequence['branches']?['name'] ?? 'Global';
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(docType, branchName),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField("Prefix", _prefixController, "e.g. INV-"),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildField("Last Used No.", _lastNoController, "0", keyboardType: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPaddingSelector()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildField("Suffix", _suffixController, "e.g. /24-25"),
                const SizedBox(height: 16),
                _buildResetToggle(),
                const SizedBox(height: 24),
                _buildPreview(),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_rounded, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                Text(subtitle, style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {TextInputType keyboardType = TextInputType.text}) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Outfit', color: textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: context.isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildPaddingSelector() {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Padding", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showPaddingSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC), 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$_padding Digits", style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetToggle() {
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: CupertinoSwitch(
            value: _resetYearly,
            onChanged: (v) => setState(() => _resetYearly = v),
            activeColor: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text("Reset numbering every financial year", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary))),
      ],
    );
  }

  Widget _buildPreview() {
    final nextNo = (int.tryParse(_lastNoController.text) ?? 0) + 1;
    final preview = "${_prefixController.text}${nextNo.toString().padLeft(_padding, '0')}${_suffixController.text}";
    final textSecondary = context.textSecondary;
    
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.primaryBlue.withOpacity(0.1) : const Color(0xFFF1F5F9), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: context.isDark ? AppColors.primaryBlue.withOpacity(0.3) : const Color(0xFFE2E8F0))
      ),
      child: Column(
        children: [
          Text("NEXT DOCUMENT PREVIEW", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary.withOpacity(0.7), letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(preview, style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.textPrimary,
          foregroundColor: context.surfaceBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving 
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.surfaceBg))
          : const Text("Save Settings", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
    );
  }
}
