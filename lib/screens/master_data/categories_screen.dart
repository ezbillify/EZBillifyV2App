import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _categories = [];
  
  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // We need company_id. Assuming we can get it from a provider or query.
      // For now, let's fetch the user profile again or assume we have it.
      // Better: Fetch user profile locally or pass it. 
      // To keep it simple, I'll fetch the profile to get company_id.
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      final companyId = profile['company_id'];
      
      final response = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCategory(String name, String type, String description) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
          
      await Supabase.instance.client.from('categories').insert({
        'company_id': profile['company_id'],
        'name': name,
        'type': type,
        'description': description,
        'is_active': true,
      });
      
      _fetchCategories();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error adding category: $e");
      if (mounted) StatusService.show(context, "Error: $e");
    }
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    try {
      // Optimistic update
      setState(() {
        final index = _categories.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _categories[index]['is_active'] = !currentValue;
        }
      });
      
      await Supabase.instance.client
          .from('categories')
          .update({'is_active': !currentValue})
          .eq('id', id);
    } catch (e) {
      _fetchCategories(); // Revert on error
    }
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await Supabase.instance.client.from('categories').delete().eq('id', id);
      _fetchCategories();
    } catch (e) {
      debugPrint("Error deleting: $e");
      if (mounted) StatusService.show(context, "Failed to delete. Item might be in use.");
    }
  }

  void _showAddSheet() {
    String name = '';
    String type = 'product';
    String description = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("New Category", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Category Name",
                  hintText: "e.g. Raw Material",
                ),
                onChanged: (v) => name = v,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "Type"),
                items: const [
                  DropdownMenuItem(value: 'product', child: Text("Product")),
                  DropdownMenuItem(value: 'service', child: Text("Service")),
                  DropdownMenuItem(value: 'asset', child: Text("Asset")),
                  DropdownMenuItem(value: 'expense', child: Text("Expense")),
                ],
                onChanged: (v) => type = v!,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: "Description (Optional)",
                  hintText: "Add details...",
                ),
                onChanged: (v) => description = v,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _addCategory(name, type, description),
                  child: const Text("Save Category"),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Categories", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _showAddSheet, icon: const Icon(Icons.add_rounded, color: AppColors.primaryBlue)),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : _categories.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.category_outlined, size: 64, color: Colors.grey[300]),
                   const SizedBox(height: 16),
                   Text("No categories found", style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[500])),
                   TextButton(onPressed: _showAddSheet, child: const Text("Create First Category")),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _categories[index];
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getTypeColor(item['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.label_outline_rounded, color: _getTypeColor(item['type']), size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (item['type'] as String).toUpperCase(),
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                  ),
                                ),
                                if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['description'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (v) => _toggleActive(item['id'], isActive),
                        activeColor: AppColors.primaryBlue,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20),
                        onPressed: () => _deleteCategory(item['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'service': return Colors.purple;
      case 'asset': return Colors.orange;
      case 'expense': return Colors.red;
      default: return Colors.blue;
    }
  }
}
