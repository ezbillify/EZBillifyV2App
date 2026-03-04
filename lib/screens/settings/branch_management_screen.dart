import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class BranchManagementScreen extends ConsumerStatefulWidget {
  final String companyId;
  const BranchManagementScreen({super.key, required this.companyId});

  @override
  ConsumerState<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends ConsumerState<BranchManagementScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _branches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final data = await _settingsService.getBranches(widget.companyId);
      if (mounted) {
        setState(() {
          _branches = data;
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

  @override
  Widget build(BuildContext context) {
    // Watch theme to rebuild on changes
    ref.watch(themeServiceProvider);
    
    final textPrimary = context.textPrimary;
    final scaffoldBg = context.scaffoldBg;
    final surfaceBg = context.surfaceBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("Branches", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _branches.length,
            itemBuilder: (context, index) {
              final branch = _branches[index];
              return _buildBranchCard(branch);
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBranchDialog(),
        backgroundColor: textPrimary,
        icon: Icon(Icons.add_rounded, color: surfaceBg),
        label: Text("New Branch", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: surfaceBg)),
      ),
    );
  }

  void _showBranchDialog([Map? branch]) {
    final nameController = TextEditingController(text: branch?['name'] ?? '');
    final codeController = TextEditingController(text: branch?['code'] ?? '');
    final gstController = TextEditingController(text: branch?['gstin'] ?? '');
    final addressController = TextEditingController(text: branch?['address'] ?? '');
    final pincodeController = TextEditingController(text: branch?['pincode'] ?? '');
    final cityController = TextEditingController(text: branch?['city'] ?? '');
    String selectedState = branch?['state'] ?? 'Delhi';

    bool isFetchingAddr = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          ref.watch(themeServiceProvider);
          final textPrimary = context.textPrimary;
          final textSecondary = context.textSecondary;
          final surfaceBg = context.surfaceBg;
          final cardBg = context.cardBg;

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: surfaceBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      children: [
                        Text(branch == null ? "Add Branch" : "Edit Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                        const SizedBox(height: 8),
                        Text("Enter the details for your business location", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
                        const SizedBox(height: 32),
                        _buildDialogField("Branch Name", nameController),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDialogField("Branch Code", codeController)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDialogField("GSTIN", gstController, uppercase: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (context, setInternalState) => Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("PIN Code", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: pincodeController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      onChanged: (v) async {
                                        if (v.length == 6) {
                                          setInternalState(() => isFetchingAddr = true);
                                          try {
                                            final res = await _settingsService.fetchAddressFromPincode(v);
                                            if (res != null) {
                                              setInternalState(() {
                                                cityController.text = res['city'] ?? '';
                                                selectedState = res['state'] ?? 'Delhi';
                                              });
                                            }
                                          } finally {
                                            setInternalState(() => isFetchingAddr = false);
                                          }
                                        }
                                      },
                                      style: TextStyle(fontFamily: 'Outfit', color: textPrimary),
                                      decoration: InputDecoration(
                                        counterText: "",
                                        filled: true,
                                        fillColor: cardBg,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        suffixIcon: isFetchingAddr ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildDialogField("City", cityController)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text("State", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
                        const SizedBox(height: 8),
                        StatefulBuilder(
                          builder: (context, setInternalState) => _buildStatePicker(selectedState, (val) => setInternalState(() => selectedState = val)),
                        ),
                        const SizedBox(height: 16),
                        _buildDialogField("Detailed Address", addressController, maxLines: 2),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final data = {
                                'name': nameController.text,
                                'code': codeController.text,
                                'gstin': gstController.text.toUpperCase(),
                                'pincode': pincodeController.text,
                                'city': cityController.text,
                                'state': selectedState,
                                'address': addressController.text,
                                'company_id': widget.companyId,
                              };
                              try {
                                if (branch == null) {
                                  await _settingsService.createBranch(data);
                                } else {
                                  await _settingsService.updateBranch(branch['id'], data);
                                }
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                _loadBranches();
                              } catch (e) {
                                if (!context.mounted) return;
                                StatusService.show(context, 'Error: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: Text(branch == null ? "Create Branch" : "Update Branch", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 100),
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

  Widget _buildStatePicker(String current, ValueChanged<String> onSelected) {
    return InkWell(
      onTap: () => _showSelectionSheet("Select State", ['Maharashtra', 'Delhi', 'Karnataka', 'Gujarat', 'Tamil Nadu', 'Uttar Pradesh', 'West Bengal', 'Rajasthan', 'Telangana', 'Kerala'], current, onSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(current.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
            Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary),
          ],
        ),
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
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
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
                        Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        const SizedBox(height: 8),
                        Text("Choose the state for this business location", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        ...options.map((opt) {
                          final isSelected = opt == currentValue;
                          return ListTile(
                            onTap: () {
                              onSelected(opt);
                              Navigator.pop(context);
                            },
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            title: Text(opt.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
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

  Widget _buildDialogField(String label, TextEditingController controller, {bool uppercase = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: context.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
          style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }


  Widget _buildBranchCard(Map<String, dynamic> branch) {
    final bool isPrimary = branch['is_primary'] ?? false;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPrimary ? AppColors.primaryBlue.withOpacity(0.3) : borderColor),
      ),
      child: InkWell(
        onTap: () => _showBranchDialog(branch),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                height: 52, width: 52,
                decoration: BoxDecoration(
                  color: isPrimary ? AppColors.primaryBlue.withOpacity(0.1) : context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC), 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: Icon(isPrimary ? Icons.star_rounded : Icons.factory_rounded, color: isPrimary ? AppColors.primaryBlue : textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(branch['name'] ?? 'Unit', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    Text(branch['code'] ?? 'N/A', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text("PRIMARY", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryBlue)),
                ),
              Icon(Icons.chevron_right_rounded, color: textSecondary.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
