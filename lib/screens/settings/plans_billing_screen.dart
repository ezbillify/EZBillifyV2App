import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlansBillingScreen extends ConsumerStatefulWidget {
  final String companyId;
  const PlansBillingScreen({super.key, required this.companyId});

  @override
  ConsumerState<PlansBillingScreen> createState() => _PlansBillingScreenState();
}

class _PlansBillingScreenState extends ConsumerState<PlansBillingScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  Map<String, dynamic>? _billingData;
  List<Map<String, dynamic>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _settingsService.getBillingData(widget.companyId);
      final inv = await _settingsService.getBillingInvoices(widget.companyId);
      if (mounted) {
        setState(() {
          _billingData = data;
          _invoices = inv;
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

  Future<void> _launchEZConnect(String path) async {
    final company = _billingData?['company'] ?? {};
    final plan = _billingData?['plan'] ?? {};
    
    const baseUrl = 'https://support.ezbillify.com';
    final targetPath = path == '/billing' ? '/ezbillify' : path;
    
    final uri = Uri.parse(baseUrl + targetPath).replace(queryParameters: {
      'company_id': widget.companyId,
      'email': company['billing_email'] ?? company['email'] ?? '',
      'current_plan': plan['code'] ?? '',
      'source': 'ezbillify_v2_app',
      'return_url': 'ezbillify://settings/billing',
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open billing portal.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    
    final isDark = context.isDark;
    final bgColor = context.scaffoldBg;
    final surfaceColor = context.surfaceBg;
    final cardColor = context.cardBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textTertiary;
    final borderColor = context.borderColor;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final plan = _billingData?['plan'] ?? {};
    final company = _billingData?['company'] ?? {};
    final usage = _billingData?['usage'] ?? {};

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Plans & Billing", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 20)),
            Text("Manage your subscription via EZConnect", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: textSecondary)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentPlanCard(plan, company, usage, isDark, cardColor, textPrimary, textSecondary, textTertiary, borderColor),
              const SizedBox(height: 24),
              _buildBillingDetailsCard(company, isDark, cardColor, textPrimary, textSecondary, borderColor),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Invoice History", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                  TextButton.icon(
                    onPressed: _fetchData, 
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text("Refresh", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInvoiceList(isDark, cardColor, textPrimary, textSecondary, textTertiary, borderColor),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(Map plan, Map company, Map usage, bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color textTertiary, Color borderColor) {
    final status = (company['status'] ?? 'active').toString().toLowerCase();
    final price = plan['price'] != null ? "₹${plan['price']}" : "₹0";
    final nextBilling = company['cycle_end'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(company['cycle_end'])) : null;
    final List features = plan['features'] ?? ['Core ERP Access', 'GST Compliance', 'E-Way Bill Support', 'Cloud Backups'];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryBlue.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(31)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(status.toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const Icon(Icons.bolt_rounded, color: Color(0xFFFCD34D), size: 20),
                  ],
                ),
                const SizedBox(height: 20),
                Text(plan['name'] ?? "Standard Plan", style: const TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price, style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(" / ${plan['interval'] ?? 'month'}", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.white.withOpacity(0.7))),
                    const Spacer(),
                    if (nextBilling != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("NEXT BILLING", style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.5))),
                          Text(nextBilling, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("INCLUDED FEATURES", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: textTertiary, letterSpacing: 1.1)),
                const SizedBox(height: 16),
                ...features.take(4).map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                      const SizedBox(width: 10),
                      Text(f.toString(), style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )).toList(),
                Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, color: borderColor)),
                Text("RESOURCE USAGE", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.w900, color: textTertiary, letterSpacing: 1.1)),
                const SizedBox(height: 20),
                _buildUsageBar("Users", usage['users']?['current'] ?? 0, usage['users']?['limit'] ?? 1, AppColors.primaryBlue, textPrimary, textSecondary, isDark),
                const SizedBox(height: 16),
                _buildUsageBar("Cloud Storage", usage['storage']?['current'] ?? 0, usage['storage']?['limit'] ?? 0.5, const Color(0xFF7C3AED), textPrimary, textSecondary, isDark, unit: "GB"),
                const SizedBox(height: 16),
                _buildUsageBar("API Requests", usage['apiCalls']?['current'] ?? 0, usage['apiCalls']?['limit'] ?? 1000, AppColors.warning, textPrimary, textSecondary, isDark),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _launchEZConnect('/ezbillify'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: borderColor),
                        ),
                        child: Text("Portal", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _launchEZConnect('/pricing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.primaryBlue : AppColors.lightTextPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                        ),
                        child: Text(status == 'trial' ? "Activate Plan" : "Upgrade Plan", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailsCard(Map company, bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, color: textSecondary, size: 20),
              const SizedBox(width: 12),
              Text("Billing Details", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow("Billing Email", company['billing_email'] ?? company['email'] ?? 'Not set', textPrimary, textSecondary),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: borderColor)),
          _buildInfoRow("Account Since", company['created_at'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(company['created_at'])) : 'N/A', textPrimary, textSecondary),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF166534) : const Color(0xFFDCFCE7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  "All payments are processed securely via SSL encrypted bridge.",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534), fontWeight: FontWeight.w500),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
      ],
    );
  }

  Widget _buildUsageBar(String label, num current, num limit, Color color, Color textPrimary, Color textSecondary, bool isDark, {String unit = ""}) {
    final bool isUnlimited = limit == -1;
    final percent = isUnlimited ? 1.0 : (limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0);
    final limitText = isUnlimited ? "Unlimited" : "$limit";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
            Text("$current / $limitText $unit", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: textPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent.toDouble(), 
            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightDivider, 
            valueColor: AlwaysStoppedAnimation<Color>(color), 
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList(bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color textTertiary, Color borderColor) {
    if (_invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        width: double.infinity,
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(32), border: Border.all(color: borderColor)),
        child: Column(
          children: [
            Icon(Icons.receipt_long_rounded, color: textTertiary, size: 48),
            const SizedBox(height: 16),
            Text("No Transaction History", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textSecondary)),
            Text("Your billing cycle history will appear here.", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: textTertiary)),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_invoices.length, (index) => _buildInvoiceCard(_invoices[index], isDark, cardColor, textPrimary, textSecondary, borderColor)),
    );
  }

  Widget _buildInvoiceCard(Map inv, bool isDark, Color cardColor, Color textPrimary, Color textSecondary, Color borderColor) {
    final dateStr = inv['issue_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(inv['issue_date'])) : 'Unknown Date';
    final amount = inv['amount'] != null ? "₹${inv['amount']}" : "₹0";
    final status = (inv['status'] ?? 'paid').toString().toLowerCase();
    final pdfUrl = inv['pdf_path'];
    
    Color statusColor = AppColors.success;
    if (status == 'pending') statusColor = AppColors.warning;
    if (status == 'failed') statusColor = AppColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? context.scaffoldBg : const Color(0xFFF1F5F9), 
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.file_present_rounded, color: textSecondary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv['invoice_number'] ?? "INV-XXXX", style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(dateStr, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 6),
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                  ),
                  if (pdfUrl != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication),
                      child: const Icon(Icons.download_rounded, size: 18, color: AppColors.primaryBlue),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
