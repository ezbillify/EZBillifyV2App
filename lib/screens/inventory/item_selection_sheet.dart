import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import 'item_form_sheet.dart';

class ItemSelectionSheet extends StatefulWidget {
  const ItemSelectionSheet({super.key});

  @override
  State<ItemSelectionSheet> createState() => _ItemSelectionSheetState();
}

class _ItemSelectionSheetState extends State<ItemSelectionSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user!.id)
          .single();
      
      var query = Supabase.instance.client
          .from('items')
          .select('*, tax_rate:tax_rates(rate)')
          .eq('company_id', profile['company_id']);

      if (_query.isNotEmpty) {
        query = query.ilike('name', '%$_query%');
      }

      final res = await query.order('name');
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)),
          ),
          // Premium High-Fidelity Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: "Search anything...",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 24),
                    suffixIcon: _query.isNotEmpty ? IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14)
                      ),
                      onPressed: () {
                        setState(() { _query = ""; _searchController.clear(); });
                        _fetchItems();
                      },
                    ) : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onChanged: (v) {
                    _query = v;
                    _fetchItems();
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: context.textSecondary.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text("No items found", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, color: context.textSecondary.withOpacity(0.5))),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final res = await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const ItemFormSheet(),
                            );
                            if (res == true) _fetchItems();
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text("Create New Item", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        tileColor: context.cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: context.borderColor)),
                        title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                        subtitle: Text("Price: ₹${item['default_sales_price'] ?? item['mrp'] ?? 0} | Stock: ${item['total_stock'] ?? 0}", style: TextStyle(color: context.textSecondary)),
                        trailing: const Icon(Icons.add_circle_outline, color: AppColors.primaryBlue),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
