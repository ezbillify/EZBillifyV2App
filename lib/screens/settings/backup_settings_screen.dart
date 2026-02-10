import 'package:flutter/material.dart';
import '../../core/theme_service.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access theme helpers directly or via context if you have extensions
    // Assuming context extensions from theme_service based on other files
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Backup & Data",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Backup & Data Settings",
              style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Configure automated backups and data retention policies.",
              style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid), // Dashed border is complex in flutter without package, solid is fine for now or implementation of CustomPainter
                borderRadius: BorderRadius.circular(12),
                color: isDark ? Colors.grey[900] : Colors.grey[50],
              ),
              child: Column(
                children: [
                   Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(
                    "Backups coming soon...",
                    style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[500], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
