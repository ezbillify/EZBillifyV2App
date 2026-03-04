import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = false;
  
  // Mock State matching Web
  final Map<String, Map<String, bool>> _settings = {
    'procurement': {'email': true, 'in_app': true},
    'sales': {'email': true, 'in_app': true},
    'inventory': {'email': true, 'in_app': true},
    'system': {'email': true, 'in_app': true},
  };

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'procurement',
      'label': 'Procurement & Purchasing',
      'icon': Icons.local_shipping_outlined,
      'color': Colors.blue,
      'bg': Colors.blue.withOpacity(0.1),
      'description': 'Purchase Orders, Vendor Approvals, and GRNs.'
    },
    {
      'id': 'sales',
      'label': 'Sales & Invoicing',
      'icon': Icons.shopping_cart_outlined,
      'color': Colors.green,
      'bg': Colors.green.withOpacity(0.1),
      'description': 'New orders, payments received, and invoice queries.'
    },
    {
      'id': 'inventory',
      'label': 'Inventory Alerts',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.amber,
      'bg': Colors.amber.withOpacity(0.1),
      'description': 'Low stock warnings, expiry alerts, and tolerance breaches.'
    },
    {
      'id': 'system',
      'label': 'System & Security',
      'icon': Icons.security_rounded,
      'color': Colors.grey,
      'bg': Colors.grey.withOpacity(0.1),
      'description': 'New user signups, password changes, and risky logins.'
    }
  ];

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isLoading = false);
      StatusService.show(context, 'Preferences Saved', backgroundColor: Colors.green);
    }
  }

  void _toggle(String catId, String channel) {
    setState(() {
      _settings[catId]![channel] = !_settings[catId]![channel]!;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveSettings,
            icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Icon(Icons.check_rounded, color: AppColors.primaryBlue),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _categories.length,
        separatorBuilder: (c, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final settings = _settings[cat['id']]!;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cat['bg'],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(cat['icon'], color: cat['color'], size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat['label'],
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cat['description'],
                            style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildToggle(
                        "Email", 
                        Icons.mail_outline_rounded, 
                        settings['email']!, 
                        (v) => _toggle(cat['id'], 'email')
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToggle(
                        "In-App", 
                        Icons.notifications_outlined, 
                        settings['in_app']!, 
                        (v) => _toggle(cat['id'], 'in_app')
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: value ? AppColors.primaryBlue.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value ? AppColors.primaryBlue.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: value ? AppColors.primaryBlue : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                color: value ? AppColors.primaryBlue : Colors.grey[700],
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 24,
              width: 40,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
