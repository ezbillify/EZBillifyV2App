import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _units = [];
  
  static const List<Map<String, String>> ALL_UNITS = [
    {'name': 'Pieces', 'code': 'pcs', 'category': 'Count'},
    {'name': 'Number', 'code': 'nos', 'category': 'Count'},
    {'name': 'Kilogram', 'code': 'kg', 'category': 'Weight'},
    {'name': 'Gram', 'code': 'g', 'category': 'Weight'},
    {'name': 'Metric Ton', 'code': 'mt', 'category': 'Weight'},
    {'name': 'Quintal', 'code': 'qtl', 'category': 'Weight'},
    {'name': 'Meter', 'code': 'm', 'category': 'Length'},
    {'name': 'Centimeter', 'code': 'cm', 'category': 'Length'},
    {'name': 'Millimeter', 'code': 'mm', 'category': 'Length'},
    {'name': 'Kilometer', 'code': 'km', 'category': 'Length'},
    {'name': 'Inch', 'code': 'in', 'category': 'Length'},
    {'name': 'Foot', 'code': 'ft', 'category': 'Length'},
    {'name': 'Yard', 'code': 'yd', 'category': 'Length'},
    {'name': 'Liter', 'code': 'l', 'category': 'Volume'},
    {'name': 'Milliliter', 'code': 'ml', 'category': 'Volume'},
    {'name': 'Cubic Meter', 'code': 'm3', 'category': 'Volume'},
    {'name': 'Gallon (US)', 'code': 'gal', 'category': 'Volume'},
    {'name': 'Box', 'code': 'box', 'category': 'Packaging'},
    {'name': 'Packet', 'code': 'pkt', 'category': 'Packaging'},
    {'name': 'Bag', 'code': 'bag', 'category': 'Packaging'},
    {'name': 'Carton', 'code': 'ctn', 'category': 'Packaging'},
    {'name': 'Case', 'code': 'cse', 'category': 'Packaging'},
    {'name': 'Dozen', 'code': 'doz', 'category': 'Count'},
    {'name': 'Gross', 'code': 'grs', 'category': 'Count'},
    {'name': 'Set', 'code': 'set', 'category': 'Count'},
    {'name': 'Pair', 'code': 'pr', 'category': 'Count'},
    {'name': 'Hour', 'code': 'hr', 'category': 'Time'},
    {'name': 'Day', 'code': 'day', 'category': 'Time'},
    {'name': 'Month', 'code': 'mo', 'category': 'Time'},
    {'name': 'Square Meter', 'code': 'm2', 'category': 'Area'},
    {'name': 'Square Foot', 'code': 'sqft', 'category': 'Area'},
    {'name': 'Square Yard', 'code': 'sqyd', 'category': 'Area'},
    {'name': 'Bundle', 'code': 'bdl', 'category': 'Packaging'},
    {'name': 'Bale', 'code': 'bal', 'category': 'Packaging'},
    {'name': 'Drum', 'code': 'drm', 'category': 'Packaging'},
    {'name': 'Sheet', 'code': 'sht', 'category': 'Count'},
    {'name': 'Bottle', 'code': 'btl', 'category': 'Packaging'},
    {'name': 'Can', 'code': 'can', 'category': 'Packaging'},
    {'name': 'Jar', 'code': 'jar', 'category': 'Packaging'},
    {'name': 'Unit', 'code': 'unt', 'category': 'Count'},
    {'name': 'Roll', 'code': 'rol', 'category': 'Packaging'},
    {'name': 'Tin', 'code': 'tin', 'category': 'Packaging'},
    {'name': 'Other', 'code': 'oth', 'category': 'Count'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      final companyId = profile['company_id'];
      
      final response = await Supabase.instance.client
          .from('units')
          .select()
          .eq('company_id', companyId)
          .order('name', ascending: true);
      
      if (mounted) {
        setState(() {
          _units = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching units: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addUnit(String name, String code) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
          
      // Check if unit already exists
      final existing = _units.indexWhere((u) => u['code'].toString().toLowerCase() == code.toLowerCase());
      if (existing != -1) {
        if (mounted) StatusService.show(context, "Unit with this code already exists.");
        return;
      }
          
      await Supabase.instance.client.from('units').insert({
        'company_id': profile['company_id'],
        'name': name,
        'code': code.toLowerCase(), // Store codes in lowercase to be safe/consistent
        'is_active': true,
      });
      
      _fetchUnits();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error adding unit: $e");
      if (mounted) StatusService.show(context, "Error: $e");
    }
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    try {
      setState(() {
        final index = _units.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _units[index]['is_active'] = !currentValue;
        }
      });
      
      await Supabase.instance.client
          .from('units')
          .update({'is_active': !currentValue})
          .eq('id', id);
    } catch (e) {
      _fetchUnits();
    }
  }

  Future<void> _deleteUnit(String id) async {
    try {
      await Supabase.instance.client.from('units').delete().eq('id', id);
      _fetchUnits();
    } catch (e) {
      debugPrint("Error deleting: $e");
      if (mounted) StatusService.show(context, "Failed to delete. Unit might be in use.");
    }
  }

  void _showAddSheet() {
    String? selectedCode;
    String name = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final availableUnits = ALL_UNITS; // Could filter here if we want to hide already added ones
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                   Padding(
                     padding: const EdgeInsets.all(24),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         const Text("Select Unit", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                         IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                       ],
                     ),
                   ),
                   Divider(height: 1, color: Theme.of(context).dividerColor),
                   Expanded(
                     child: ListView.separated(
                       padding: const EdgeInsets.all(16),
                       itemCount: availableUnits.length,
                       separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                       itemBuilder: (context, index) {
                         final unit = availableUnits[index];
                         final isSelected = selectedCode == unit['code'];
                         final isAlreadyAdded = _units.any((u) => u['code'].toString().toLowerCase() == unit['code']);
                         
                         return ListTile(
                           enabled: !isAlreadyAdded,
                           onTap: isAlreadyAdded ? null : () {
                             _addUnit(unit['name']!, unit['code']!);
                           },
                           title: Text(
                             unit['name']!,
                             style: TextStyle(
                               fontFamily: 'Outfit', 
                               fontWeight: FontWeight.bold,
                               color: isAlreadyAdded ? Colors.grey : null,
                             ),
                           ),
                           subtitle: Text(
                             "Code: ${unit['code']}",
                              style: const TextStyle(fontFamily: 'Outfit'), 
                           ),
                           trailing: isAlreadyAdded 
                              ? const Icon(Icons.check_circle_rounded, color: Colors.green)
                              : const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
                         );
                       },
                     ),
                   ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Units (UOM)", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showAddSheet, icon: const Icon(Icons.add_rounded, color: AppColors.primaryBlue)),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : _units.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.straighten_outlined, size: 64, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text("No units found", style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[500])),
                   TextButton(onPressed: _showAddSheet, child: const Text("Add Standard Units")),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _units.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _units[index];
                final isActive = item['is_active'] ?? true;
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                         width: 40, height: 40,
                         alignment: Alignment.center,
                         decoration: BoxDecoration(
                           color: AppColors.primaryBlue.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           (item['code'] as String).toUpperCase(),
                           style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue),
                         ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (v) => _toggleActive(item['id'], isActive),
                        activeColor: AppColors.primaryBlue,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20),
                        onPressed: () => _deleteUnit(item['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
