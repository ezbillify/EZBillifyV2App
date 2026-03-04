import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import '../../services/master_data_service.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';
class ItemFormSheet extends StatefulWidget {
  final Map<String, dynamic>? item; // If null, create new
  const ItemFormSheet({super.key, this.item});

  @override
  State<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Data State
  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _salesPriceController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _mrpController;
  late TextEditingController _minStockController;
  late TextEditingController _openingStockController;
  late TextEditingController _hsnController;
  
  String _type = 'product';
  String? _categoryId;
  String _uom = 'pcs';
  String? _taxRateId;
  List<String> _barcodes = [];

  // Dropdown Options
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _taxRates = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?['name'] ?? '');
    _skuController = TextEditingController(text: widget.item?['sku'] ?? '');
    _salesPriceController = TextEditingController(text: (widget.item?['default_sales_price'] ?? 0).toString());
    _purchasePriceController = TextEditingController(text: (widget.item?['default_purchase_price'] ?? 0).toString());
    _mrpController = TextEditingController(text: (widget.item?['mrp'] ?? 0).toString());
    _minStockController = TextEditingController(text: (widget.item?['min_stock_level'] ?? 0).toString());
    _openingStockController = TextEditingController(text: (widget.item?['total_stock'] ?? 0).toString());
    _hsnController = TextEditingController(text: widget.item?['hsn_code'] ?? '');
    
    if (widget.item != null) {
      _type = widget.item!['type'] ?? 'product';
      _categoryId = widget.item!['category_id']?.toString();
      _uom = widget.item!['uom'] ?? 'pcs';
      _taxRateId = widget.item!['tax_rate_id']?.toString();
      _barcodes = List<String>.from(widget.item!['barcodes'] ?? []);
    }
    
    _fetchDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _salesPriceController.dispose();
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _minStockController.dispose();
    _openingStockController.dispose();
    _hsnController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdowns() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      final companyId = profile['company_id'];

      final results = await Future.wait([
        Supabase.instance.client.from('categories').select().eq('company_id', companyId).eq('is_active', true),
        Supabase.instance.client.from('units').select().eq('company_id', companyId).eq('is_active', true),
        Supabase.instance.client.from('tax_rates').select().eq('company_id', companyId).eq('is_active', true),
      ]);

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(results[0]);
          _units = List<Map<String, dynamic>>.from(results[1]);
          _taxRates = List<Map<String, dynamic>>.from(results[2]);
        });
      }
    } catch (e) {
      debugPrint("Error fetching dropdowns: $e");
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      final companyId = profile['company_id'];

      final data = {
        'company_id': companyId,
        'name': _nameController.text.trim(),
        'sku': _skuController.text.trim(),
        'type': _type,
        'category_id': _categoryId,
        'uom': _uom,
        'default_sales_price': double.tryParse(_salesPriceController.text) ?? 0,
        'default_purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'mrp': double.tryParse(_mrpController.text) ?? 0,
        'min_stock_level': double.tryParse(_minStockController.text) ?? 0,
        'hsn_code': _hsnController.text.trim(),
        'tax_rate_id': _taxRateId,
        'barcodes': _barcodes,
        'is_active': true,
      };

      if (widget.item != null) {
        await Supabase.instance.client.from('items').update(data).eq('id', widget.item!['id']);
      } else {
        // For new items, if opening stock is provided, it should ideally be handled via a transaction to inventory_stock.
        // For now, we omit total_stock from the items table as it's a calculated field.
        await Supabase.instance.client.from('items').insert(data);
      }
      
      if (mounted) {
        await MasterDataService().invalidateItems();
        StatusService.show(context, widget.item != null ? "Item updated!" : "Item created!", backgroundColor: AppColors.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error saving item: $e");
      String errorMessage = e.toString();
      if (errorMessage.contains("schema")) {
        errorMessage = "Database schema mismatch. Please contact support.";
      }
      if (mounted) StatusService.show(context, "Error: $errorMessage");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
            children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.item != null ? "Edit Item" : "New Item",
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: context.borderColor.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, size: 20, color: context.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.borderColor.withOpacity(0.5)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("Basic Details"),
                    const SizedBox(height: 16),
                    _buildTextField(_nameController, "Item Name", Icons.inventory_2_outlined, required: true),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_skuController, "SKU / Code", Icons.qr_code_outlined)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSelectionField(
                            "Type", 
                            _type.toUpperCase(), 
                            Icons.category_outlined,
                            () => _showSelectionSheet<String>(
                              "Item Type",
                              ['product', 'service', 'raw_material'],
                              (v) => v.toUpperCase(),
                              (v) => setState(() => _type = v),
                              _type,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSelectionField(
                            "Category", 
                            _categories.firstWhere((c) => c['id'].toString() == _categoryId, orElse: () => {'name': 'Select'})['name'],
                            Icons.label_important_outline_rounded,
                            () => _showSelectionSheet<Map<String, dynamic>>(
                              "Select Category",
                              _categories,
                              (c) => c['name'],
                              (c) => setState(() => _categoryId = c['id'].toString()),
                              _categoryId,
                              idRetriever: (c) => c['id'].toString(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSelectionField(
                            "Unit", 
                            _units.firstWhere((u) => u['code'] == _uom, orElse: () => {'name': 'Select'})['name'],
                            Icons.straighten_rounded,
                            () => _showSelectionSheet<Map<String, dynamic>>(
                              "Select Unit",
                              _units,
                              (u) => "${u['name']} (${u['code']})",
                              (u) => setState(() => _uom = u['code']),
                              _uom,
                              idRetriever: (u) => u['code'],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Pricing & Tax"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_salesPriceController, "Sales Price", Icons.sell_outlined, isNumber: true, prefix: "₹")),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_mrpController, "MRP", Icons.payments_outlined, isNumber: true, prefix: "₹")),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_purchasePriceController, "Purchase Price", Icons.shopping_bag_outlined, isNumber: true, prefix: "₹")),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSelectionField(
                            "Tax Rate", 
                            _taxRateId == null ? "None" : _taxRates.firstWhere((t) => t['id'].toString() == _taxRateId, orElse: () => {'name': 'Select'})['name'],
                            Icons.percent_rounded,
                            () => _showSelectionSheet<Map<String, dynamic>>(
                              "Select Tax Rate",
                              _taxRates,
                              (t) => "${t['name']} (${t['rate']}%)",
                              (t) => setState(() => _taxRateId = t['id'].toString()),
                              _taxRateId,
                              idRetriever: (t) => t['id'].toString(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Inventory Control"),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_minStockController, "Low Stock Alert", Icons.warning_amber_rounded, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: widget.item == null 
                            ? _buildTextField(_openingStockController, "Opening Stock", Icons.warehouse_outlined, isNumber: true)
                            : const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_hsnController, "HSN / SAC Code", Icons.receipt_long_outlined),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 8,
                          shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                        ),
                        child: _loading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : Text(widget.item != null ? "Update Item" : "Create Item", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: context.textSecondary.withOpacity(0.6)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, String? prefix, bool required = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixIcon: Icon(icon, size: 20, color: context.textSecondary.withOpacity(0.5)),
        labelStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary),
        floatingLabelStyle: const TextStyle(fontFamily: 'Outfit', color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: context.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required ? (v) => v!.isEmpty ? "Required" : null : null,
    );
  }

  Widget _buildSelectionField(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.textSecondary.withOpacity(0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary, fontFamily: 'Outfit')),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary, fontFamily: 'Outfit'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showSelectionSheet<T>(String title, List<T> items, String Function(T) labelMapper, Function(T) onSelect, String? currentValue, {String Function(T)? idRetriever}) {
    String searchQuery = "";
    final searchController = TextEditingController();
    final focusNode = FocusNode();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Add listener to focus node for animation
          focusNode.addListener(() {
            if (context.mounted) setModalState(() {});
          });

          final List<T> filteredItems = items.where((item) {
            final label = labelMapper(item).toLowerCase();
            return label.contains(searchQuery.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(color: context.surfaceBg),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: focusNode.hasFocus 
                          ? AppColors.primaryBlue 
                          : context.borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        focusNode: focusNode,
                        controller: searchController,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textPrimary),
                        cursorColor: AppColors.primaryBlue,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: "Search...",
                          hintStyle: TextStyle(
                            fontFamily: 'Outfit', 
                            color: context.textSecondary.withOpacity(0.4), 
                            fontSize: 15
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded, 
                            color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.4), 
                            size: 22
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          suffixIcon: searchQuery.isNotEmpty 
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primaryBlue), 
                                onPressed: () {
                                  setModalState(() {
                                    searchQuery = '';
                                    searchController.clear();
                                  });
                                }
                              ) 
                            : null,
                        ),
                        onChanged: (v) {
                          setModalState(() => searchQuery = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final label = labelMapper(item);
                        final id = idRetriever != null ? idRetriever(item) : item.toString();
                        final isSelected = id == currentValue;

                        return InkWell(
                          onTap: () {
                            onSelect(item);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
                                const Spacer(),
                                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
