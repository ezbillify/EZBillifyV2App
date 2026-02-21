import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../core/theme_service.dart';
import 'login_screen.dart';

import '../models/auth_models.dart';
import 'settings/company_profile_screen.dart';
import 'settings/gst_settings_screen.dart';
import 'settings/branch_management_screen.dart';
import 'settings/user_management_screen.dart';
import 'settings/financial_years_screen.dart';
import 'settings/document_numbering_screen.dart';
import 'settings/branding_settings_screen.dart';
import 'settings/plans_billing_screen.dart';
import 'settings/integrations_screen.dart';
import 'settings/print_template_preview_screen.dart';
import 'settings/printer_settings_screen.dart';
import 'settings/my_profile_screen.dart';
import 'settings/security_settings_screen.dart';
import 'settings/appearance_settings_screen.dart';
import 'settings/backup_settings_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/permission_settings_screen.dart';
import 'master_data/master_data_screen.dart';

class SettingsScreen extends ConsumerWidget {
  final AppUser? user;
  const SettingsScreen({super.key, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch theme to rebuild on changes
    ref.watch(themeServiceProvider);
    
    final isDark = context.isDark;
    final bgColor = context.scaffoldBg;
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textSecondary.withOpacity(0.7);
    final borderColor = context.borderColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Settings",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Account & Security", textTertiary),
            _buildSettingsCard([
              _buildSettingsTile(
                context: context,
                icon: Icons.person_outline_rounded,
                title: "My Profile",
                subtitle: "Update your personal details",
                color: Colors.blue,
                onTap: () {
                  if (user != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => MyProfileScreen(user: user!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.security_rounded,
                title: "Security Settings",
                subtitle: "Password & account protection",
                color: Colors.indigo,
                onTap: () {
                  if (user != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => SecuritySettingsScreen(user: user!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.palette_outlined,
                title: "Appearance",
                subtitle: "Light, Dark, or System theme",
                color: Colors.purple,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const AppearanceSettingsScreen(),
                  ));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.notifications_none_rounded,
                title: "Notifications",
                subtitle: "Email & app alert preferences",
                color: Colors.orange,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const NotificationSettingsScreen(),
                  ));
                },
              ),
            ], surfaceColor, borderColor),
            
            const SizedBox(height: 24),
            _buildSectionHeader("Business Configuration", textTertiary),
            _buildSettingsCard([
              _buildSettingsTile(
                context: context,
                icon: Icons.business_rounded,
                title: "Company Profile",
                subtitle: "Legal information & addresses",
                color: const Color(0xFF10B981),
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => CompanyProfileScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.account_balance_rounded,
                title: "GST Settings",
                subtitle: "GSTIN, registration & compliance",
                color: const Color(0xFF10B981),
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => GSTSettingsScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.dataset_linked_rounded,
                title: "Master Data",
                subtitle: "Categories, Units, taxes & bank info",
                color: Colors.blueAccent,
                onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => const MasterDataScreen(),
                    ));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.brush_outlined,
                title: "Branding & Templates",
                subtitle: "Logo, colors & print templates",
                color: Colors.pink,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => BrandingSettingsScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
            ], surfaceColor, borderColor),
 
            const SizedBox(height: 24),
            _buildSectionHeader("Organization & Staff", textTertiary),
            _buildSettingsCard([
              _buildSettingsTile(
                context: context,
                icon: Icons.account_tree_outlined,
                title: "Branches",
                subtitle: "Manage business locations",
                color: Colors.cyan,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => BranchManagementScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.people_outline_rounded,
                title: "Users Management",
                subtitle: "Invitations & role assignments",
                color: Colors.purple,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => UserManagementScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.shield_rounded,
                title: "Permissions",
                subtitle: "Role-based access control",
                color: Colors.blueGrey,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const PermissionSettingsScreen(),
                  ));
                },
              ),
            ], surfaceColor, borderColor),
 
            const SizedBox(height: 24),
            _buildSectionHeader("Documents & Finance", textTertiary),
            _buildSettingsCard([
              _buildSettingsTile(
                context: context,
                icon: Icons.format_list_numbered_rounded,
                title: "Document Numbering",
                subtitle: "Prefixes for invoices, POs & bills",
                color: Colors.teal,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => DocumentNumberingScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.calendar_today_rounded,
                title: "Financial Years",
                subtitle: "Manage accounting periods",
                color: Colors.deepOrange,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => FinancialYearsScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
            ], surfaceColor, borderColor),
 
            const SizedBox(height: 24),
            _buildSectionHeader("System & Growth", textTertiary),
            _buildSettingsCard([
              _buildSettingsTile(
                context: context,
                icon: Icons.extension_outlined,
                title: "Integrations",
                subtitle: "Payments, Tally & webhooks",
                color: Colors.indigoAccent,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => IntegrationsScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.credit_card_rounded,
                title: "Plans & Billing",
                subtitle: "Manage subscription & receipts",
                color: Colors.amber,
                onTap: () {
                  if (user?.companyId != null) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (c) => PlansBillingScreen(companyId: user!.companyId!),
                    ));
                  }
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.print_rounded,
                title: "Print Templates",
                subtitle: "Thermal & A4 preview modal",
                color: const Color(0xFF64748B),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const PrintTemplatePreviewScreen(),
                  ));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.print_rounded,
                title: "Thermal Printer",
                subtitle: "Connect & configure 58/80mm printer",
                color: const Color(0xFF334155),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const PrinterSettingsScreen(),
                  ));
                },
              ),
              _buildSettingsTile(
                context: context,
                icon: Icons.backup_rounded,
                title: "Backup & Data",
                subtitle: "Cloud backup configuration",
                color: const Color(0xFF0EA5E9),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (c) => const BackupSettingsScreen(),
                  ));
                },
              ),
            ], surfaceColor, borderColor),
 
            const SizedBox(height: 48),
            FadeInUp(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showSignOutConfirmation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.error.withOpacity(0.1) : const Color(0xFFFEF2F2),
                    foregroundColor: AppColors.error,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Sign Out",
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                "EZBillify V2 Mobile App\nVersion 1.0.0",
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: textTertiary, height: 1.5),
              ),
            ),
            const SizedBox(height: 100),
 
          ],
        ),
      ),
    );
  }
 
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.2),
      ),
    );
  }
 
  Widget _buildSettingsCard(List<Widget> children, Color surfaceColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final bool isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1, color: borderColor.withOpacity(0.5)),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
 
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isToggle = false,
    VoidCallback? onTap,
  }) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
 
    return InkWell(
      onTap: isToggle ? null : () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap();
        } else {
          debugPrint("Tapped $title");
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary),
                  ),
                ],
              ),
            ),
            if (isToggle)
              Switch.adaptive(
                value: false,
                onChanged: (v) {},
                activeColor: AppColors.primaryBlue,
              )
            else
              Icon(Icons.chevron_right_rounded, color: textSecondary.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
 
  void _showSignOutConfirmation(BuildContext context) {
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
 
    showDialog(
      context: context,
      builder: (context) => ZoomIn(
        duration: const Duration(milliseconds: 300),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Sign Out?",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to log out?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: context.borderColor),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(fontFamily: 'Outfit', color: textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await AuthService().signOut();
                          if (!context.mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (c) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Sign Out",
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
