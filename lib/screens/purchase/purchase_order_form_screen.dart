
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';
import '../sales/scanner_modal_content.dart';
import 'vendors_screen.dart';
import '../../widgets/calendar_sheet.dart';
import '../../services/purchase_refresh_service.dart';

class PurchaseOrderFormScreen extends StatefulWidget {
  final Map<String, dynamic>? order; // Null for new
  const PurchaseOrderFormScreen({super.key, this.order});

  @override
  State<PurchaseOrderFormScreen> createState() => _PurchaseOrderFormScreenState();
}

class _PurchaseOrderFormScreenState extends State<PurchaseOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _branchId;
  String? _branchName;
  String? _vendorId;
  String? _vendorName;
  DateTime _orderDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14));
  String _poNumber = "";
  String _notes = "";
  String _terms = "";
  
  // Line Items
  List<Map<String, dynamic>> _items = [];
  
  // Totals
  double _subtotal = 0;
  double _totalTax = 0;
  double _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('id, company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id'];
      
      final isEdit = widget.order != null && widget.order!['id'] != null;
      
      if (!isEdit) {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generatePoNumber();

        if (widget.order != null) {
          _vendorId = widget.order!['vendor_id']?.toString();
          _vendorName = widget.order!['vendor']?['name'] ?? widget.order!['vendor_name'];
          if (widget.order!['branch_id'] != null) {
            _branchId = widget.order!['branch_id'].toString();
          }
          if (widget.order!['items'] != null) {
            final rawItems = List<dynamic>.from(widget.order!['items']);
            _items = List<Map<String, dynamic>>.from(rawItems.map((it) {
              return <String, dynamic>{
                'item_id': it['item_id'],
                'name': it['name'] ?? it['item']?['name'] ?? it['description'] ?? 'Item',
                'quantity': (it['quantity'] is num) ? it['quantity'].toDouble() : double.tryParse(it['quantity']?.toString() ?? '0') ?? 0.0,
                'unit_price': (it['unit_price'] is num) ? it['unit_price'].toDouble() : double.tryParse(it['unit_price']?.toString() ?? '0') ?? 0.0,
                'tax_rate': (it['tax_rate'] is num) ? it['tax_rate'].toDouble() : double.tryParse(it['tax_rate']?.toString() ?? '0') ?? 0.0,
                'unit': it['unit'] ?? it['item']?['uom'],
              };
            }));
          }
          _calculateTotals();
        }
      } else {
        _poNumber = widget.order!['po_number'];
        _vendorId = widget.order!['vendor_id']?.toString();
        _vendorName = widget.order!['vendor']?['name'];
        _orderDate = DateTime.parse(widget.order!['date'] ?? widget.order!['created_at']);
        _deliveryDate = widget.order!['expected_delivery_date'] != null 
            ? DateTime.parse(widget.order!['expected_delivery_date']) 
            : DateTime.now().add(const Duration(days: 14));
        _notes = widget.order!['notes'] ?? "";
        _terms = widget.order!['terms_conditions'] ?? "";
        
        if (widget.order!['items'] == null) {
          final itemsData = await Supabase.instance.client.from('purchase_order_items').select('*, item:items(name)').eq('po_id', widget.order!['id']);
           _items = List<Map<String, dynamic>>.from(itemsData.map((e) {
             final priceExcl = (e['unit_price'] ?? 0).toDouble();
             final taxRate = (e['tax_rate'] ?? 0).toDouble();
             final priceIncl = priceExcl * (1 + taxRate / 100);
             
             return {
               ...e,
               'name': e['description'] ?? e['item']?['name'] ?? 'Item',
               'item_id': e['item_id'],
               'quantity': e['quantity'],
               'unit_price': double.parse(priceIncl.toStringAsFixed(2)),
               'tax_rate': taxRate,
               'unit': e['unit'] ?? 'unt',
             };
           }));
        } else {
          _items = List<Map<String, dynamic>>.from(widget.order!['items']);
        }
        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing PO: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generatePoNumber() async {
    if (_branchId == null || _companyId == null) return;
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_ORDER', 
      branchId: _branchId,
      previewOnly: true,
    );
    setState(() => _poNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final priceInclusive = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final totalInclusive = qty * priceInclusive;
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;
      
      sub += lineSub;
      tax += lineTax;
    }
    setState(() {
      _subtotal = double.parse(sub.toStringAsFixed(2));
      _totalTax = double.parse(tax.toStringAsFixed(2));
      _totalAmount = double.parse((sub + tax).toStringAsFixed(2));
    });
  }

  Future<void> _selectBranch() async {
    final results = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if (!mounted) return;

    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Branch",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (b) => b['name'],
      onSelect: (b) => setState(() {
        _branchId = b['id'].toString();
        _branchName = b['name'];
        _generatePoNumber();
      }),
      currentValue: _branchName,
    );
  }

  Future<void> _selectVendor() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (c) => const VendorsScreen(isSelecting: true))
    );
    
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _vendorId = result['id'];
        _vendorName = result['name'];
      });
    }
  }

  Future<void> _addItem() async {
    final results = await MasterDataService().getItems(_companyId!);
    if (!mounted) return;

    List<Map<String, dynamic>> currentValues = [];
    for (var i in _items) {
      final match = results.firstWhere((r) => r['id'] == i['item_id'], orElse: () => {});
      if (match.isNotEmpty) {
        final qty = (i['quantity'] ?? 1).toInt();
        for (int q = 0; q < qty; q++) {
          currentValues.add(match);
        }
      }
    }

    _showSelectionSheet<Map<String, dynamic>>(
      title: "Add Items",
      items: List<Map<String, dynamic>>.from(results),
      currentValues: currentValues,
      labelMapper: (i) {
        final price = (i['default_purchase_price'] ?? 0).toDouble();
        final rate = (i['tax_rate']?['rate'] ?? 0).toDouble();
        final inclusive = price * (1 + rate / 100);
        return "${i['name']} (₹${inclusive.toStringAsFixed(2)})";
      },
      barcodeMapper: (i) {
        final barcodes = List<String>.from(i['barcodes'] ?? []);
        return "${i['sku'] ?? ''} ${barcodes.join(' ')}";
      },
      isMultiple: true,
      onRefresh: () async {
        await MasterDataService().getItems(_companyId!, forceRefresh: true);
      },
      onSelectMultiple: (selectedList) {
        setState(() {
          final qtyMap = <String, int>{};
          final itemMap = <String, Map<String, dynamic>>{};
          
          for (var item in selectedList) {
            final id = item['id'].toString();
            qtyMap[id] = (qtyMap[id] ?? 0) + 1;
            itemMap[id] = item;
          }

          _items.removeWhere((existing) => !qtyMap.containsKey(existing['item_id'].toString()));

          for (var itemEntry in _items) {
            final id = itemEntry['item_id'].toString();
            itemEntry['quantity'] = qtyMap[id];
            qtyMap.remove(id); 
          }

          for (var id in qtyMap.keys) {
            final item = itemMap[id]!;
            final qty = qtyMap[id]!;
            final pur = (item['default_purchase_price'] ?? 0).toDouble();
            final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
            
            _items.add({
              'item_id': item['id'],
              'name': item['name'],
              'quantity': qty,
              'unit_price': pur,
              'tax_rate': rate,
              'unit': item['uom'],
            });
          }
        });
        _calculateTotals();
      },
      showScanner: true,
      itemContentBuilder: (context, item, count, onAdd, onRemove) {
        final purchasePrice = (item['default_purchase_price'] ?? 0).toDouble();
        final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
        final unit = item['uom'] ?? 'unt';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: count > 0 ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: count > 0 ? AppColors.primaryBlue : context.borderColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                     Container(
                       width: 48,
                       height: 48,
                       decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                       child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryBlue),
                     ),
                   const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text("₹${purchasePrice.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                              const SizedBox(width: 8),
                              Text("Stock: ${item['total_stock'] ?? 0}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: (item['total_stock'] ?? 0) <= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text("• $unit", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                            ],
                          ),
                          Text("${rate.toStringAsFixed(0)}% Tax Included", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary.withOpacity(0.7))),
                        ],
                      ),
                    ),
                   const SizedBox(width: 12),
                   if (count > 0)
                     Container(
                       decoration: BoxDecoration(color: context.surfaceBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           InkWell(onTap: onRemove, child: const Icon(Icons.remove, size: 20)),
                           SizedBox(width: 32, child: Text("$count", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                           InkWell(onTap: onAdd, child: const Icon(Icons.add, size: 20)),
                         ],
                       ),
                     )
                   else
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                       child: const Icon(Icons.add, color: AppColors.primaryBlue, size: 24),
                     ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    );
  }
  
  Future<void> _editItemPrice(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: item['unit_price'].toString());
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text("Edit Unit Price", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text(item['name'], style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary),
              decoration: InputDecoration(
                prefixText: "₹ ",
                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                labelText: "New Unit Price",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: context.cardBg,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  final newPrice = double.tryParse(controller.text) ?? item['unit_price'];
                  setState(() {
                    _items[index]['unit_price'] = newPrice;
                    _calculateTotals();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: const Text("Save Changes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _saveOrder() async {
    if (_vendorId == null) {
      StatusService.show(context, "Please select a vendor");
      return;
    }
    if (_items.isEmpty) {
      StatusService.show(context, "Please add at least one item");
      return;
    }

    setState(() => _loading = true);
    try {
      final poData = <String, dynamic>{
        'company_id': _companyId,
        'branch_id': _branchId,
        'vendor_id': _vendorId,
        'po_number': _poNumber,
        'date': _orderDate.toIso8601String(),
        'expected_delivery_date': _deliveryDate.toIso8601String(),
        'total_amount': _totalAmount,
        'status': 'draft', // Default to draft
        'notes': _notes,
        'terms_conditions': _terms,
      };
      
      Map<String, dynamic> upsertedPo;
      
      if (widget.order != null && widget.order!['id'] != null) {
        upsertedPo = await Supabase.instance.client.from('purchase_orders').update(poData).eq('id', widget.order!['id']).select().single();
        await Supabase.instance.client.from('purchase_order_items').delete().eq('po_id', widget.order!['id']);
      } else {
         _poNumber = await NumberingService.getNextDocumentNumber(companyId: _companyId!, documentType: 'PURCHASE_ORDER', branchId: _branchId);
         poData['po_number'] = _poNumber;
         upsertedPo = await Supabase.instance.client.from('purchase_orders').insert(poData).select().single();
      }
      
      final poId = upsertedPo['id'];
      final itemsToInsert = _items.map((item) {
        final rawQty = item['quantity'] ?? 0;
        final rawPrice = item['unit_price'] ?? 0;
        final rawTax = item['tax_rate'] ?? 0;
        
        final qty = (rawQty is num) ? rawQty.toDouble() : double.tryParse(rawQty.toString()) ?? 0.0;
        final priceInclusive = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()) ?? 0.0;
        final taxRate = (rawTax is num) ? rawTax.toDouble() : double.tryParse(rawTax.toString()) ?? 0.0;
        
        final totalInclusive = qty * priceInclusive;
        final lineSub = totalInclusive / (1 + (taxRate / 100));
        final lineTax = totalInclusive - lineSub;
        final unitPriceExcl = qty > 0 ? (lineSub / qty) : priceInclusive;

        return <String, dynamic>{
          'po_id': poId,
          'item_id': item['item_id'],
          'description': item['name'],
          'quantity': qty > 0 ? qty : 1, // Fallback safety
          'unit_price': double.tryParse(unitPriceExcl.toStringAsFixed(4)) ?? 0.0,
          'tax_rate': taxRate,
          'tax_amount': double.tryParse(lineTax.toStringAsFixed(2)) ?? 0.0,
          'total_amount': double.tryParse(totalInclusive.toStringAsFixed(2)) ?? 0.0,
        };
      }).toList();
      
      await Supabase.instance.client.from('purchase_order_items').insert(itemsToInsert);

      if (mounted) {
        PurchaseRefreshService.triggerRefresh();
        Navigator.pop(context, true);
        StatusService.show(context, "Purchase Order Saved Successfully");
      }
    } catch (e, stacktrace) {
      debugPrint("Detailed PO Save Error: $e");
      debugPrint("Stacktrace: $stacktrace");
      if (mounted) {
        StatusService.show(context, "Error saving PO: $e\nCheck console for details.", backgroundColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.order == null ? "New Purchase Order" : "Edit Order", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_poNumber.isEmpty ? "Generating ID..." : _poNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSection(),
                    const SizedBox(height: 32),
                    _buildItemsSection(),
                    const SizedBox(height: 32),
                    _buildSummarySection(),
                    const SizedBox(height: 32),
                    _buildNotesSection(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Branch"),
            if (widget.order == null)
               TextButton.icon(
                 onPressed: _selectBranch,
                 icon: const Icon(Icons.store_outlined, size: 18),
                 label: Text(_branchName ?? "Select", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
               )
            else
               Text(_branchName ?? "-", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Vendor Details"),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectVendor,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_vendorName ?? "Select Vendor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _vendorName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Dates"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Order Date", DateFormat('dd MMM, yyyy').format(_orderDate), Icons.calendar_today_rounded, () async {
                final d = await showCustomCalendarSheet(
                  context: context, 
                  initialDate: _orderDate, 
                  title: "Select Order Date"
                );
                if (d != null) setState(() => _orderDate = d);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Expected Delivery", DateFormat('dd MMM, yyyy').format(_deliveryDate), Icons.local_shipping_outlined, () async {
                final d = await showCustomCalendarSheet(
                  context: context, 
                  initialDate: _deliveryDate, 
                  title: "Select Delivery Date",
                  firstDate: _orderDate
                );
                if (d != null) setState(() => _deliveryDate = d);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Items"),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text("Add Item", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
             child: Column(
               children: [
                 Icon(Icons.shopping_bag_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
                 const SizedBox(height: 8),
                 Text("No items added", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
               ],
             ),
           )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildLineItemCard(item, index);
            },
          ),
      ],
    );
  }

  Widget _buildLineItemCard(Map<String, dynamic> item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
      child: InkWell(
        onTap: () => _editItemPrice(index),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'] ?? 'Item', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _editItemPrice(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Price: ₹${item['unit_price']}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, size: 12, color: AppColors.primaryBlue),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: () => _removeItem(index), icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQtySelector(index),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${((item['quantity'] ?? 0) * (item['unit_price'] ?? 0)).toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    Text("Tax: ${item['tax_rate']}%", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtySelector(int index) {
    final qty = _items[index]['quantity'] ?? 1;
    return Container(
      decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: () { if(qty > 1) { setState(() => _items[index]['quantity'] = qty - 1); _calculateTotals(); } }, icon: const Icon(Icons.remove_rounded, size: 18)),
          Text("$qty", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          IconButton(onPressed: () { setState(() => _items[index]['quantity'] = qty + 1); _calculateTotals(); }, icon: const Icon(Icons.add_rounded, size: 18)),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "₹${_subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Tax", "₹${_totalTax.toStringAsFixed(2)}"),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          _buildSummaryRow("Grand Total", "₹${_totalAmount.toStringAsFixed(2)}", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Notes & Terms"),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _notes,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "Internal Notes",
          ),
          onChanged: (v) => _notes = v,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _terms,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: "Terms & Conditions",
          ),
          onChanged: (v) => _terms = v,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: isTotal ? context.textPrimary : context.textSecondary, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isTotal ? AppColors.primaryBlue : context.textPrimary, fontSize: isTotal ? 20 : 14)),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                Text("₹${_totalAmount.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 54,
            width: 160,
            child: ElevatedButton(
              onPressed: _loading ? null : _saveOrder,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("Save Order", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(icon, size: 14, color: AppColors.primaryBlue),
                  const SizedBox(width: 6),
                  Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary)),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary));
  }

  void _openScanner<T>({
    required List<T> allItems,
    required List<T> selectedItems,
    required Function(List<T>) onSelectionChanged,
    required VoidCallback onConfirm,
    required String? Function(T) barcodeMapper,
    required String Function(T) labelMapper,
    required bool isMultiple,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => ScannerModalContent<T>(
        allItems: allItems,
        selectedItems: selectedItems,
        onSelectionChanged: onSelectionChanged,
        onConfirm: onConfirm,
        barcodeMapper: barcodeMapper,
        labelMapper: labelMapper,
        isMultiple: isMultiple,
      ),
    );
  }

  void _showSelectionSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelMapper,
    Function(T)? onSelect,
    Function(List<T>)? onSelectMultiple,
    bool isMultiple = false,
    String? currentValue,
    List<T>? currentValues,
    String? Function(T)? badgeMapper,
    Color Function(T)? badgeColorMapper,
    bool showScanner = false,
    bool isCompactSearch = false,
    String Function(T)? barcodeMapper,
    Widget Function(BuildContext, T, int count, VoidCallback onAdd, VoidCallback onRemove)? itemContentBuilder,
    Future<void> Function()? onRefresh,
  }) {
    String searchQuery = "";
    bool isRefreshing = false;
    final searchController = TextEditingController();
    final focusNode = FocusNode();
    List<T> selectedItems = currentValues != null ? List<T>.from(currentValues) : [];

    final sheetController = DraggableScrollableController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!focusNode.hasListeners) {
            focusNode.addListener(() { 
              if (context.mounted) {
                setModalState(() {});
                if (focusNode.hasFocus) {
                  sheetController.animateTo(0.95, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              }
            });
          }

          final List<T> filteredItems = items.where((item) {
            final label = labelMapper(item).toLowerCase();
            final barcode = barcodeMapper?.call(item)?.toLowerCase() ?? "";
            return label.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            controller: sheetController,
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Stack(
              children: [
                Container(
                  decoration: BoxDecoration(color: context.surfaceBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (onRefresh != null)
                                  isRefreshing 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : IconButton(
                                        onPressed: () async {
                                          setModalState(() => isRefreshing = true);
                                          await onRefresh();
                                          if (context.mounted) Navigator.pop(context);
                                          StatusService.show(context, "Data synchronized! Please reopen to see changes.");
                                        }, 
                                        icon: const Icon(Icons.sync_rounded, color: AppColors.primaryBlue)
                                      ),
                                if (isMultiple)
                                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                              ],
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: focusNode.hasFocus ? context.cardBg : context.cardBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: focusNode.hasFocus ? AppColors.primaryBlue : context.borderColor,
                              width: focusNode.hasFocus ? 2.0 : 1.5,
                            ),
                            boxShadow: [
                              if (focusNode.hasFocus) 
                                BoxShadow(color: AppColors.primaryBlue.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))
                              else
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: TextField(
                              focusNode: focusNode,
                              controller: searchController,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: false,
                                hintText: "Search anything...",
                                 border: InputBorder.none,
                                 enabledBorder: InputBorder.none,
                                 focusedBorder: InputBorder.none,
                                hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.normal),
                                prefixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(Icons.search_rounded, key: ValueKey(focusNode.hasFocus), color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.5), size: 24),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (searchQuery.isNotEmpty) 
                                      IconButton(
                                        icon: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14)), 
                                        onPressed: () => setModalState(() { searchQuery = ""; searchController.clear(); })
                                      ),
                                    if (showScanner) 
                                      IconButton(
                                        icon: Icon(Icons.barcode_reader, size: 22, color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary), 
                                        onPressed: () => _openScanner(
                                          allItems: items,
                                          selectedItems: selectedItems,
                                          onSelectionChanged: (l) => setModalState(() { selectedItems.clear(); selectedItems.addAll(l); }),
                                          onConfirm: () { if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); } },
                                          barcodeMapper: barcodeMapper!,
                                          labelMapper: labelMapper,
                                          isMultiple: isMultiple
                                        )
                                      ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              onChanged: (v) => setModalState(() => searchQuery = v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredItems.length,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final count = isMultiple ? selectedItems.where((e) => e == item).length : 0;
                            
                            void onIncrement() => setModalState(() => selectedItems.add(item));
                            void onDecrement() => setModalState(() => selectedItems.remove(item));

                            if (itemContentBuilder != null) {
                              return itemContentBuilder(context, item, count, onIncrement, onDecrement);
                            }

                            final label = labelMapper(item);
                            final isSelected = isMultiple ? count > 0 : label == currentValue;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    if (isMultiple) onIncrement();
                                    else { onSelect?.call(item); Navigator.pop(context); }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor.withOpacity(0.5), width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary))),
                                        if (count > 0) Text("x$count", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                        if (!isMultiple && isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMultiple && selectedItems.isNotEmpty)
                  Positioned(
                    bottom: 24, left: 24, right: 24,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () { if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); } },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_cart_outlined), 
                            const SizedBox(width: 12),
                            Text("Add ${selectedItems.toSet().length} Items", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      ),
    );
  }
}
