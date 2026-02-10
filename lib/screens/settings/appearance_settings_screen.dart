import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_service.dart';
import '../../main.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeService = ref.watch(themeServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, 
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, 
            size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Appearance",
          style: TextStyle(fontFamily: 'Outfit', 
             
            fontWeight: FontWeight.bold, 
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Preview Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isDark 
                  ? const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDark ? "Dark Mode" : "Light Mode",
                          style: const TextStyle(fontFamily: 'Outfit', 
                            
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDark 
                            ? "Easy on your eyes in low light" 
                            : "Bright and clear for daylight use",
                          style: TextStyle(fontFamily: 'Outfit', 
                            
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            _buildSectionHeader("Choose Theme", isDark),
            const SizedBox(height: 16),
            
            // Theme Selection Cards
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                children: [
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    icon: Icons.light_mode_rounded,
                    title: "Light",
                    subtitle: "Classic bright appearance",
                    mode: AppThemeMode.light,
                    currentMode: themeService.themeMode,
                    isDark: isDark,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withOpacity(0.5)),
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    icon: Icons.dark_mode_rounded,
                    title: "Dark",
                    subtitle: "Reduced eye strain in low light",
                    mode: AppThemeMode.dark,
                    currentMode: themeService.themeMode,
                    isDark: isDark,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(height: 1, color: (isDark ? AppColors.darkBorder : AppColors.lightBorder).withOpacity(0.5)),
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    icon: Icons.brightness_auto_rounded,
                    title: "System",
                    subtitle: "Matches your device settings",
                    mode: AppThemeMode.system,
                    currentMode: themeService.themeMode,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryBlue : AppColors.primaryBlue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "System mode automatically switches between light and dark based on your device's display settings.",
                      style: TextStyle(fontFamily: 'Outfit', 
                        
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontFamily: 'Outfit', 
          
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required AppThemeMode currentMode,
    required bool isDark,
  }) {
    final isSelected = mode == currentMode;
    
    return InkWell(
      onTap: () {
        ref.read(themeServiceProvider).setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppColors.primaryBlue.withOpacity(0.1)
                  : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
                borderRadius: BorderRadius.circular(14),
                border: isSelected 
                  ? Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 2)
                  : null,
              ),
              child: Icon(
                icon,
                color: isSelected 
                  ? AppColors.primaryBlue 
                  : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontFamily: 'Outfit', 
                      
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontFamily: 'Outfit', 
                      
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
