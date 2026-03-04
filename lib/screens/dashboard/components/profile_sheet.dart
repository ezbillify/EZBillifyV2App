import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/theme_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/auth_models.dart';
import '../../settings/my_profile_screen.dart';
import '../../settings/company_profile_screen.dart';
import '../../settings/security_settings_screen.dart';
import '../../login_screen.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:upgrader/upgrader.dart';
import 'package:in_app_update/in_app_update.dart';
import 'dart:io' show Platform;

void showProfileSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends ConsumerWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final user = state.currentUser;
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  _buildProfileHeader(context, user),
                  const SizedBox(height: 32),
                  // Mock Update Banner
                  _buildUpdateBanner(context),
                  const SizedBox(height: 24),
                  _buildThemeSelector(context),
                  const SizedBox(height: 32),
                  _buildSheetItem(
                    context,
                    Icons.person_outline_rounded,
                    "Account Settings",
                    "Manage your profile details",
                    onTap: () {
                      if (user == null) return;
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (c) => MyProfileScreen(user: user)));
                    },
                  ),
                  _buildSheetItem(
                    context,
                    Icons.business_rounded,
                    "Company Profile",
                    "Update business information",
                    onTap: () {
                      if (user?.companyId == null) return;
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (c) => CompanyProfileScreen(companyId: user!.companyId!)));
                    },
                  ),
                  _buildSheetItem(
                    context,
                    Icons.security_rounded,
                    "Privacy & Security",
                    "Password and access control",
                    onTap: () {
                      if (user == null) return;
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (c) => SecuritySettingsScreen(user: user)));
                    },
                  ),
                  _buildSheetItem(
                    context,
                    Icons.notifications_none_rounded,
                    "Notifications",
                    "Preference management",
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: context.dividerColor)),
                  _buildSheetItem(
                    context,
                    Icons.help_outline_rounded,
                    "Help & Support",
                    "Get assistance from our team",
                    onTap: () async {
                      Navigator.pop(context);
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'support@ezbillify.com',
                        query: 'subject=EZBillify Support Request&body=Hi Support team,',
                      );
                      if (!await launchUrl(emailUri)) {
                        /* 
                           No context.mounted check needed here since the snackbar already
                           needs the context from build, but to be totally safe in async callbacks 
                           we can use a static scaffold key or assume context is mounted if no pop.
                         */
                        if (context.mounted) {
                          StatusService.show(context, "Could not open email app.");
                        }
                      }
                    },
                  ),
                  _buildSheetItem(
                    context,
                    Icons.logout_rounded,
                    "Sign Out",
                    "Safely exit your account",
                    isDestructive: true,
                    onTap: () {
                      _showSignOutConfirmation(context, ref);
                    },
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.hasData ? 'v${snapshot.data!.version} (${snapshot.data!.buildNumber})' : '';
                      return Center(
                        child: Text(
                          'EZBillify $version',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: textSecondary.withOpacity(0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppUser? user) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Center(
            child: Text(
              (user?.name ?? "U")[0].toUpperCase(),
              style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(user?.name ?? "Super Admin", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
        Text(user?.email ?? "admin@ezbillify.com", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                (user?.role.name ?? "Owner").toUpperCase(),
                style: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final themeService = ref.watch(themeServiceProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("APPEARANCE", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    context,
                    label: "Light",
                    icon: Icons.light_mode_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.light,
                    onTap: () => themeService.setThemeMode(AppThemeMode.light),
                    activeColor: Colors.white,
                    activeTextColor: AppColors.primaryBlue,
                  ),
                  _buildThemeOption(
                    context,
                    label: "Dark",
                    icon: Icons.dark_mode_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.dark,
                    onTap: () => themeService.setThemeMode(AppThemeMode.dark),
                    activeColor: AppColors.darkSurface,
                    activeTextColor: Colors.white,
                  ),
                  _buildThemeOption(
                    context,
                    label: "System",
                    icon: Icons.settings_brightness_rounded,
                    isSelected: themeService.themeMode == AppThemeMode.system,
                    onTap: () => themeService.setThemeMode(AppThemeMode.system),
                    activeColor: context.isDark ? AppColors.darkSurface : Colors.white,
                    activeTextColor: context.isDark ? Colors.white : AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    return FutureBuilder(
      future: Upgrader.sharedInstance.initialize(),
      builder: (context, snapshot) {
        // Keep testing UI as true for verification. 
        // NOTE: Standard upgrader is used for checking, but we use native plugins for official modals.
        final bool isTestingUI = false; 
        final bool hasUpdate = isTestingUI || Upgrader.sharedInstance.isUpdateAvailable();
        
        if (!hasUpdate) return const SizedBox.shrink();

        final updateVersion = isTestingUI ? "2.1.0" : Upgrader.sharedInstance.currentAppStoreVersion ?? "a new version";

        return FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.04),
              border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.flash_on_rounded, color: Colors.redAccent, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Update Recommended",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Tap to install version $updateVersion",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () async {
                      if (Platform.isAndroid) {
                        try {
                          // Official Android "Google Play" Modal
                          final updateInfo = await InAppUpdate.checkForUpdate();
                          if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
                            await InAppUpdate.performImmediateUpdate();
                          }
                        } catch (e) {
                          Upgrader.sharedInstance.sendUserToAppStore();
                        }
                      } else {
                        // Official iOS "App Store" Modal/Overlay
                        // Note: On iOS, this uses the upgrader's logic which targets the secure App Store.
                        // To get the EXACT "Overlay" behavior like Zomato, we trigger the native StoreKit.
                        Upgrader.sharedInstance.sendUserToAppStore();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "INSTALL",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
    required Color activeTextColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? activeTextColor : context.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeTextColor : context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetItem(BuildContext context, IconData icon, String title, String subtitle, {bool isDestructive = false, VoidCallback? onTap}) {
    final color = isDestructive ? AppColors.error : context.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.error : context.textSecondary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDestructive ? AppColors.error : context.textSecondary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                  Text(subtitle, style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textSecondary.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutConfirmation(BuildContext context, WidgetRef ref) {
    final surfaceColor = context.surfaceBg;
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final isDark = context.isDark;

    showDialog(
      context: context,
      builder: (context) => ZoomIn(
        duration: const Duration(milliseconds: 300),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 42),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
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
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to log out? You will need to sign in again to access your dashboard.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
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
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final nav = Navigator.of(context, rootNavigator: true);
                          await AuthService().signOut();
                          nav.pushAndRemoveUntil(
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
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                          ),
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
