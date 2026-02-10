import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme_service.dart';

class ItemFormScreen extends StatefulWidget {
  final Map<String, dynamic>? item; // If null, create new
  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Data State
  String _name = '';
  String _sku = '';
  String _type = 'product';
  String? _categoryId;
  String _uom = 'pcs';
  double _salesPrice = 0.0;
  double _purchasePrice = 0.0;
  double _mrp = 0.0;
  double _minStock = 0.0;
  double _openingStock = 0.0;
  String? _taxRateId;
  String _hsnCode = '';
  List<String> _barcodes = [];

  // Dropdown Options
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _taxRates = [];

  @override
  void initState() {
    super.initState();
    _fetchDropdowns();
    if (widget.item != null) {
      _loadItemData();
    }
  }

  void _loadItemData() {
    final item = widget.item!;
    _name = item['name'] ?? '';
    _sku = item['sku'] ?? '';
    _type = item['type'] ?? 'product';
    _categoryId = item['category_id'];
    _uom = item['uom'] ?? 'pcs';
    _salesPrice = (item['default_sales_price'] ?? 0).toDouble();
    _purchasePrice = (item['default_purchase_price'] ?? 0).toDouble();
    _mrp = (item['mrp'] ?? 0).toDouble();
    _minStock = (item['min_stock_level'] ?? 0).toDouble();
    _openingStock = (item['total_stock'] ?? 0).toDouble(); // Usually readonly
    _taxRateId = item['tax_rate_id'];
    _hsnCode = item['hsn_code'] ?? '';
    _barcodes = List<String>.from(item['barcodes'] ?? []);
  }

  Future<void> _fetchDropdowns() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      final companyId = profile['company_id'];

      final results = await Future.wait([
        Supabase.instance.client.from('categories').select().eq('company_id', companyId).eq('is_active', true),
        Supabase.instance.client.from('units').select().eq('company_id', companyId).eq('is_active', true),
        Supabase.instance.client.from('tax_rates').select().eq('company_id', companyId).eq('is_active', true),
      ]);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(results[0]);
        _units = List<Map<String, dynamic>>.from(results[1]);
        _taxRates = List<Map<String, dynamic>>.from(results[2]);
        
        // Default UOM if not editing
        if (widget.item == null && _units.isNotEmpty) {
           // Maybe set first? Or let it be 'pcs' or select manually
        }
      });
    } catch (e) {
      debugPrint("Error fetching dropdowns: $e");
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user!.id)
          .single();
      final companyId = profile['company_id'];

      final data = {
        'company_id': companyId,
        'name': _name,
        'sku': _sku, // Handle auto-generate if empty?
        'type': _type,
        'category_id': _categoryId,
        'uom': _uom,
        'default_sales_price': _salesPrice,
        'default_purchase_price': _purchasePrice,
        'mrp': _mrp,
        'min_stock_level': _minStock,
        // Only update total stock if new? Or separate stock transaction?
        // Usually total_stock should be updated via transactions, but for MVP/Initial creation, allowing direct set might be okay.
        // For update, we shouldn't overwrite total_stock directly unless strictly needed.
        if (widget.item == null) 'total_stock': _openingStock, 
        'tax_rate_id': _taxRateId,
        'hsn_code': _hsnCode,
        'barcodes': _barcodes,
        'is_active': true,
      };

      if (widget.item != null) {
        await Supabase.instance.client.from('items').update(data).eq('id', widget.item!['id']);
      } else {
        await Supabase.instance.client.from('items').insert(data);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving item: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item != null ? "Edit Item" : "New Item", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _saveItem,
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text("Save", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Basic Details"),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: "Item Name", hintText: "e.g. Milk 1L"),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _sku,
                      decoration: const InputDecoration(labelText: "SKU / Code", hintText: "Auto if empty"),
                      onSaved: (v) => _sku = v ?? '',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: "Type"),
                      items: const [
                        DropdownMenuItem(value: 'product', child: Text("Product")),
                        DropdownMenuItem(value: 'service', child: Text("Service")),
                        DropdownMenuItem(value: 'raw_material', child: Text("Raw Material")),
                      ],
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categories.any((c) => c['id'] == _categoryId) ? _categoryId : null,
                      decoration: const InputDecoration(labelText: "Category"),
                      items: _categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _units.any((u) => u['code'] == _uom) ? _uom : null, // Assuming UOM stored as code? Or ID?
                      // Web interface used code (string) but backend might use ID?
                      // Wait, web item interface says `uom: string`. UnitList uses code as key.
                      // Let's assume it stores the code string like 'pcs'.
                      // If `_units` has `code` field.
                      decoration: const InputDecoration(labelText: "Unit"),
                      items: _units.map((u) => DropdownMenuItem(value: u['code'].toString(), child: Text(u['name']))).toList(),
                      onChanged: (v) => setState(() => _uom = v!),
                      validator: (v) => v == null ? "Required" : null,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle("Pricing & Tax"),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _salesPrice.toString(),
                      decoration: const InputDecoration(labelText: "Sales Price", prefixText: "₹"),
                      keyboardType: TypeError().runtimeType == double ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => double.tryParse(v!) == null ? "Invalid" : null,
                      onSaved: (v) => _salesPrice = double.parse(v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _mrp.toString(),
                      decoration: const InputDecoration(labelText: "MRP", prefixText: "₹"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSaved: (v) => _mrp = double.tryParse(v!) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _purchasePrice.toString(),
                      decoration: const InputDecoration(labelText: "Purchase Price", prefixText: "₹"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSaved: (v) => _purchasePrice = double.tryParse(v!) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _taxRates.any((t) => t['id'] == _taxRateId) ? _taxRateId : null,
                      decoration: const InputDecoration(labelText: "Tax Rate"),
                      items: _taxRates.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text("${t['name']} (${t['rate']}%)"))).toList(),
                      onChanged: (v) => setState(() => _taxRateId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _hsnCode,
                decoration: const InputDecoration(labelText: "HSN / SAC Code"),
                onSaved: (v) => _hsnCode = v ?? '',
              ),

              const SizedBox(height: 32),
              _buildSectionTitle("Inventory Control"),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _minStock.toString(),
                      decoration: const InputDecoration(labelText: "Low Stock Alert Level"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSaved: (v) => _minStock = double.tryParse(v!) ?? 0,
                    ),
                  ),
                  if (widget.item == null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: _openingStock.toString(),
                        decoration: const InputDecoration(labelText: "Opening Stock"),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onSaved: (v) => _openingStock = double.tryParse(v!) ?? 0,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),
              _buildSectionTitle("Barcodes"),
              // Simple comma separated input for now
              TextFormField(
                initialValue: _barcodes.join(', '),
                decoration: const InputDecoration(
                  labelText: "Barcodes (Comma separated)", 
                  hintText: "12345678, 87654321",
                  suffixIcon: Icon(Icons.qr_code_scanner_rounded),
                ),
                onSaved: (v) {
                  if (v != null && v.isNotEmpty) {
                    _barcodes = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  } else {
                    _barcodes = [];
                  }
                },
              ),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, letterSpacing: 1.2),
      ),
    );
  }
}
