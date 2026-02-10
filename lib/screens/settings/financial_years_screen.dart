import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';

class FinancialYearsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const FinancialYearsScreen({super.key, required this.companyId});

  @override
  ConsumerState<FinancialYearsScreen> createState() => _FinancialYearsScreenState();
}

class _FinancialYearsScreenState extends ConsumerState<FinancialYearsScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _years = [];

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    try {
      final data = await _settingsService.getFinancialYears(widget.companyId);
      if (mounted) {
        setState(() {
          _years = data;
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

  @override
  Widget build(BuildContext context) {
    // Watch theme
    ref.watch(themeServiceProvider);
    
    final textPrimary = context.textPrimary;
    final scaffoldBg = context.scaffoldBg;
    final surfaceBg = context.surfaceBg;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        title: Text("Financial Years", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: _years.length,
            itemBuilder: (context, index) {
               final year = _years[index];
               return _buildYearCard(year);
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showYearDialog(),
        backgroundColor: AppColors.primaryBlue,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Year", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  void _showYearDialog() {
    final codeController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isActive = false;

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
          final isDark = context.isDark;

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => StatefulBuilder(
              builder: (context, setModalState) => Container(
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
                          Text("New Financial Year", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 8),
                          Text("Configure the fiscal period for your business", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primaryBlue.withOpacity(0.15) : const Color(0xFFEFF6FF), 
                              borderRadius: BorderRadius.circular(16), 
                              border: Border.all(color: isDark ? AppColors.primaryBlue.withOpacity(0.3) : const Color(0xFFDBEAFE))
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: isDark ? AppColors.secondaryBlue : AppColors.primaryBlue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text("Creating a new financial year will prepare the system for future transactions.", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: isDark ? textSecondary : const Color(0xFF1E40AF)))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatePickerField(
                                  "Start Date", 
                                  startDate, 
                                  (d) {
                                    setModalState(() {
                                      startDate = d;
                                      final nextYear = d.year + 1;
                                      endDate = DateTime(nextYear, 3, 31);
                                      codeController.text = "${d.year % 100}-${nextYear % 100}";
                                    });
                                  }
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDatePickerField(
                                  "End Date", 
                                  endDate, 
                                  (d) => setModalState(() => endDate = d)
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildDialogField("Fiscal Code", codeController, hint: "e.g. 24-25"),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.stars_rounded, color: isActive ? AppColors.primaryBlue : textSecondary.withOpacity(0.5)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Set as Active", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                                      Text("Default period for new entries", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: textSecondary)),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isActive, 
                                  onChanged: (v) => setModalState(() => isActive = v), 
                                  activeColor: AppColors.primaryBlue
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (codeController.text.isEmpty || startDate == null || endDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                                  return;
                                }
                                try {
                                  final data = {
                                    'code': codeController.text,
                                    'start_date': DateFormat('yyyy-MM-dd').format(startDate!),
                                    'end_date': DateFormat('yyyy-MM-dd').format(endDate!),
                                    'is_active': isActive,
                                    'is_locked': false,
                                    'company_id': widget.companyId,
                                  };
                                  
                                  await _settingsService.createFinancialYear(data);
                                  
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _loadYears();
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: const Text("Create Financial Year", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? selectedDate, ValueChanged<DateTime> onSelected) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) onSelected(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: selectedDate != null ? textPrimary : textSecondary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate) : "Select Date",
                    style: TextStyle(fontFamily: 'Outfit', 
                      fontSize: 14, 
                      color: selectedDate != null ? textPrimary : textSecondary.withOpacity(0.5),
                      fontWeight: selectedDate != null ? FontWeight.bold : FontWeight.normal
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, {String? hint}) {
    final textSecondary = context.textSecondary;
    final textPrimary = context.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.normal, color: textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: context.cardBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.borderColor)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildYearCard(Map<String, dynamic> year) {
    final bool isActive = year['is_active'] ?? false;
    final bool isLocked = year['is_locked'] ?? false;
    final String code = year['code'] ?? 'Unknown';
    final String start = year['start_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(year['start_date'])) : '-';
    final String end = year['end_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(year['end_date'])) : '-';
    
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isActive ? AppColors.primaryBlue.withOpacity(0.5) : borderColor),
        boxShadow: [
          if (isActive) BoxShadow(color: AppColors.primaryBlue.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryBlue.withOpacity(0.1) : context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: isActive ? AppColors.primaryBlue : textSecondary.withOpacity(0.5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("FY $code", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text("$start - $end", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: const Text("ACTIVE", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryBlue, letterSpacing: 1.1)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Icon(isLocked ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16, color: isLocked ? const Color(0xFFB45309) : textSecondary.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  isLocked ? "Period Locked" : "Period Open",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.w600, color: isLocked ? const Color(0xFFB45309) : textSecondary),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: isLocked, 
                  onChanged: (v) async {
                    HapticFeedback.lightImpact();
                    await _settingsService.updateFinancialYear(year['id'], {'is_locked': v});
                    _loadYears();
                  }, 
                  activeColor: const Color(0xFFB45309)
                ),
              ],
            ),
          ),
          if (!isActive)
            InkWell(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await _settingsService.setActiveFinancialYear(widget.companyId, year['id']);
                _loadYears();
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: const Center(
                  child: Text("Set as Active Period", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
