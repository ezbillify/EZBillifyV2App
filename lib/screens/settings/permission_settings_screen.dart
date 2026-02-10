import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme_service.dart';

class PermissionSettingsScreen extends ConsumerStatefulWidget {
  const PermissionSettingsScreen({super.key});

  @override
  ConsumerState<PermissionSettingsScreen> createState() => _PermissionSettingsScreenState();
}

class _PermissionSettingsScreenState extends ConsumerState<PermissionSettingsScreen> {
  // Mock Data
  final List<Map<String, String>> _roles = [
    {'value': 'owner', 'label': 'Owner'},
    {'value': 'admin', 'label': 'Admin'},
    {'value': 'workforce', 'label': 'Workforce'},
    {'value': 'employee', 'label': 'Employee'},
  ];

  final Map<String, List<Map<String, dynamic>>> _permissions = {
    'Sales': [
      {'code': 'sales.view', 'description': 'View Sales Invoices'},
      {'code': 'sales.create', 'description': 'Create New Invoice'},
      {'code': 'sales.delete', 'description': 'Delete Invoice'},
    ],
    'Inventory': [
      {'code': 'items.view', 'description': 'View Items'},
      {'code': 'items.edit', 'description': 'Edit Items'},
      {'code': 'stock.adjust', 'description': 'Adjust Stock Levels'},
    ],
    'Settings': [
      {'code': 'settings.view', 'description': 'View Settings'},
      {'code': 'settings.edit', 'description': 'Edit Companies & Branches'},
    ],
  };

  // Mock Active Permissions Map: Role -> List of Codes
  final Map<String, List<String>> _roleMap = {
    'owner': ['sales.view', 'sales.create', 'sales.delete', 'items.view', 'items.edit', 'stock.adjust', 'settings.view', 'settings.edit'],
    'admin': ['sales.view', 'sales.create', 'items.view', 'items.edit', 'stock.adjust'],
    'employee': ['sales.view', 'sales.create', 'items.view'],
    'workforce': ['items.view', 'stock.adjust'],
  };

  String _selectedRole = 'employee';

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Permission Settings",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Role Selector (Horizontal List)
          SizedBox(
            height: 60,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _roles.length,
              separatorBuilder: (c, i) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isSelected = _selectedRole == role['value'];
                
                return ChoiceChip(
                  label: Text(
                    role['label']!,
                    style: TextStyle(
                      fontFamily: 'Outfit', 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedRole = role['value']!);
                  },
                );
              },
            ),
          ),
          
          if (_selectedRole == 'owner')
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Owner permissions cannot be modified.",
                      style: TextStyle(fontFamily: 'Outfit', color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Permissions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _permissions.keys.length,
              itemBuilder: (context, index) {
                final category = _permissions.keys.elementAt(index);
                final perms = _permissions[category]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Outfit', 
                          fontWeight: FontWeight.bold, 
                          color: AppColors.primaryBlue,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: perms.map((perm) {
                          final code = perm['code']!;
                          final isGranted = _roleMap[_selectedRole]?.contains(code) ?? false;
                          final isOwner = _selectedRole == 'owner';

                          return Column(
                            children: [
                              ListTile(
                                title: Text(
                                  perm['description'],
                                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
                                ),
                                subtitle: Text(
                                  code,
                                  style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.grey[500]),
                                ),
                                trailing: Switch(
                                  value: isGranted,
                                  onChanged: isOwner ? null : (val) {
                                    setState(() {
                                      if (val) {
                                        _roleMap[_selectedRole]?.add(code);
                                      } else {
                                        _roleMap[_selectedRole]?.remove(code);
                                      }
                                    });
                                  },
                                  activeColor: AppColors.primaryBlue,
                                ),
                              ),
                              if (perm != perms.last)
                                const Divider(height: 1, indent: 16, endIndent: 16),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
