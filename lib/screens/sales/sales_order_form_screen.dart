import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../inventory/item_form_sheet.dart';
import 'scanner_modal_content.dart';
import 'invoice_form_screen.dart';
import 'delivery_challan_form_screen.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';
import '../../widgets/calendar_sheet.dart';
import '../../services/sales_refresh_service.dart';

class SalesOrderFormScreen extends StatefulWidget {
  final Map<String, dynamic>? order; // Null for new
  const SalesOrderFormScreen({super.key, this.order});

  @override
  State<SalesOrderFormScreen> createState() => _SalesOrderFormScreenState();
}

class _SalesOrderFormScreenState extends State<SalesOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _internalUserId;
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _orderDate = DateTime.now();
  DateTime _expectedDelivery = DateTime.now().add(const Duration(days: 7));
  String _orderNumber = "";
  String _status = "pending";
  String? _quotationId;
  
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
      _internalUserId = profile['id'];
      
      final isEdit = widget.order != null && widget.order!['id'] != null;

      if (isEdit) {
        // FETCH EVERYTHING FRESH FOR EDIT
        final orderId = widget.order!['id'];
        final order = await Supabase.instance.client
            .from('sales_orders')
            .select('*, branch:branches(name), customer:customers(name)')
            .eq('id', orderId)
            .single();
            
        _orderNumber = order['so_number'] ?? order['order_number'] ?? '';
        _branchId = order['branch_id']?.toString();
        _branchName = order['branch']?['name'];
        _customerId = order['customer_id']?.toString();
        _customerName = order['customer']?['name'];
        _orderDate = DateTime.tryParse(order['date'] ?? order['order_date'] ?? '') ?? DateTime.now();
        _expectedDelivery = DateTime.tryParse(order['delivery_date'] ?? order['expected_delivery'] ?? '') ?? DateTime.now().add(const Duration(days: 7));
        _status = order['status'] ?? 'pending';
        
        // Fetch items
        final itemsRes = await Supabase.instance.client.from('sales_order_items')
            .select('*, item:items(name, uom, default_sales_price, default_purchase_price)')
            .eq('so_id', orderId);
        
        _items = List<Map<String, dynamic>>.from(itemsRes.map((i) {
          final qty = i['quantity'];
          final up = i['unit_price'];
          final tr = i['tax_rate'];
          final pp = i['item']?['default_purchase_price'];

          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': i['item']?['name'] ?? i['description'] ?? 'Item',
            'quantity': (qty is num) ? qty.toDouble() : (double.tryParse(qty?.toString() ?? '0') ?? 0),
            'unit_price': (up is num) ? up.toDouble() : (double.tryParse(up?.toString() ?? '0') ?? 0.0),
            'tax_rate': (tr is num) ? tr.toDouble() : (double.tryParse(tr?.toString() ?? '0') ?? 0.0),
            'unit': i['item']?['uom'],
            'purchase_price': (pp is num) ? pp.toDouble() : (double.tryParse(pp?.toString() ?? '0') ?? 0.0),
          };
        }));

        _calculateTotals();
      } else {
        // NEW ORDER
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateOrderNumber();

        // Handle pre-filled data (e.g. from Quotation)
        if (widget.order != null) {
           _customerId = widget.order!['customer_id']?.toString();
           _customerName = widget.order!['customer_name'] ?? widget.order!['customer']?['name'];
           
           if (widget.order!['items'] != null) {
              final rawItems = List<dynamic>.from(widget.order!['items']);
              _items = rawItems.map((it) {
                final qty = it['quantity'];
                final up = it['unit_price'];
                final tr = it['tax_rate'];
                final pp = it['purchase_price'];

                return {
                  'item_id': it['item_id'],
                  'name': it['name'] ?? it['item']?['name'] ?? 'Item',
                  'quantity': (qty is num) ? qty.toDouble() : (double.tryParse(qty?.toString() ?? '0') ?? 0),
                  'unit_price': (up is num) ? up.toDouble() : (double.tryParse(up?.toString() ?? '0') ?? 0.0),
                  'tax_rate': (tr is num) ? tr.toDouble() : (double.tryParse(tr?.toString() ?? '0') ?? 0.0),
                  'unit': it['unit'] ?? it['item']?['uom'],
                  'purchase_price': (pp is num) ? pp.toDouble() : (double.tryParse(pp?.toString() ?? '0') ?? 0.0),
                };
              }).toList();
           }
           
           if (widget.order!['branch_id'] != null) {
              _branchId = widget.order!['branch_id'].toString();
              final bMatch = branches.firstWhere((b) => b['id'].toString() == _branchId, orElse: () => {});
              if (bMatch.isNotEmpty) _branchName = bMatch['name'];
           }
           _quotationId = widget.order!['quotation_id']?.toString();
           _quotationId = widget.order!['quotation_id']?.toString();
           _calculateTotals();
        }
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateOrderNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'SALES_ORDER',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _orderNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble(); 
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final totalInclusive = qty * price;
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;
      
      // Essential for Printing - Populate per-item totals
      item['total_amount'] = double.parse(totalInclusive.toStringAsFixed(2));
      item['tax_amount'] = double.parse(lineTax.toStringAsFixed(2));

      sub += lineSub;
      tax += lineTax;
    }
    setState(() {
      _subtotal = double.parse(sub.toStringAsFixed(2));
      _totalTax = double.parse(tax.toStringAsFixed(2));
      _totalAmount = double.parse((sub + tax).toStringAsFixed(2));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.order == null ? "New Sales Order" : "Edit Order", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_orderNumber.isEmpty ? "Generating ID..." : _orderNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          if (widget.order != null)
             PopupMenuButton<String>(
               onSelected: (val) {
                 if (val == 'invoice') _convertToInvoice();
                 else if (val == 'challan') _convertToChallan();
               },
               itemBuilder: (context) => [
                 const PopupMenuItem(value: 'invoice', child: Text("Convert to Invoice")),
                 const PopupMenuItem(value: 'challan', child: Text("Create Delivery Challan")),
               ],
               icon: const Icon(Icons.more_vert_rounded),
             )
        ]
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

  void _convertToInvoice() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => InvoiceFormScreen(
      invoice: {
        'customer_id': _customerId,
        'customer_name': _customerName,
        'branch_id': _branchId,
        'items': _items,
        'order_id': widget.order!['id'],
      },
    )));
  }

  void _convertToChallan() {
    Navigator.push(context, MaterialPageRoute(builder: (c) => DeliveryChallanFormScreen(
      challan: {
        'customer_id': _customerId,
        'customer_name': _customerName,
        'branch_id': _branchId,
        'items': _items,
        'order_id': widget.order!['id'],
      },
    )));
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Branch"),
            InkWell(
              onTap: _selectBranch,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_rounded, size: 16, color: context.textSecondary),
                    const SizedBox(width: 8),
                    Text(_branchName ?? "Select Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Customer"),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectCustomer,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_pin_rounded, color: AppColors.primaryBlue, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Text(_customerName ?? "Select Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _customerName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary))),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _buildInfoCard("Order Date", DateFormat('dd MMM, yyyy').format(_orderDate), Icons.calendar_today_rounded, () => _selectDate(true))),
            const SizedBox(width: 16),
            Expanded(child: _buildInfoCard("Delivery Date", DateFormat('dd MMM, yyyy').format(_expectedDelivery), Icons.local_shipping_rounded, () => _selectDate(false))),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Order Items"),
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
            width: double.infinity, padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
            child: Column(children: [
              Icon(Icons.shopping_bag_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 12),
              Text("No items added yet", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5))),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length, separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
                child: Row(children: [
                   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                      InkWell(
                        onTap: () => _editItemPrice(index),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("₹${item['unit_price']}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, size: 10, color: AppColors.primaryBlue),
                            ],
                          ),
                        ),
                      ),
                   ])),
                   Row(children: [
                     IconButton(onPressed: () { if((item['quantity']??1) > 1) { setState(() { item['quantity']--; _calculateTotals(); }); } }, icon: const Icon(Icons.remove_circle_outline_rounded)),
                     Text("${item['quantity']}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                     IconButton(onPressed: () { setState(() { item['quantity']++; _calculateTotals(); }); }, icon: const Icon(Icons.add_circle_outline_rounded)),
                   ]),
                   IconButton(onPressed: () => setState(() { _items.removeAt(index); _calculateTotals(); }), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                ]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal"), Text("₹${_subtotal.toStringAsFixed(2)}")]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Tax"), Text("₹${_totalTax.toStringAsFixed(2)}")]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("₹${_totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.primaryBlue))]),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _loading ? null : _saveOrder,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: Text(widget.order == null ? "Place Order" : "Update Order", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        ),
      ),
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
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        decoration: BoxDecoration(color: context.surfaceBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
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

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary));
  }

  Widget _buildInfoCard(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: context.textSecondary)),
             const SizedBox(height: 6),
             Row(children: [Icon(icon, size: 14, color: AppColors.primaryBlue), const SizedBox(width: 8), Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary))]),
        ]),
      ),
    );
  }

  Future<void> _selectBranch() async {
    final results = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if (!mounted) return;
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Branch", items: List<Map<String, dynamic>>.from(results), labelMapper: (b) => b['name'],
      onSelect: (b) => setState(() { _branchId = b['id'].toString(); _branchName = b['name']; _generateOrderNumber(); }),
    );
  }

  Future<void> _selectCustomer() async {
    final results = await MasterDataService().getCustomers(_companyId!);
    if(!mounted) return;
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Customer", 
      items: List<Map<String, dynamic>>.from(results), 
      labelMapper: (c) => c['name'],
      onSelect: (c) => setState(() { _customerId = c['id'].toString(); _customerName = c['name']; }),
      currentValue: _customerName,
      onRefresh: () async {
        await MasterDataService().getCustomers(_companyId!, forceRefresh: true);
      },
    );
  }

  Future<void> _addItem() async {
     final results = await MasterDataService().getItems(_companyId!);
     if(!mounted) return;

     // Construct currentValues based on ALL items currently in the list
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
         final rate = (i['tax_rate']?['rate'] ?? 0).toDouble();
         final mrp = (i['default_sales_price'] ?? 0).toDouble();
         final inclusive = mrp * (1 + rate / 100);
         return "${i['name']} (₹${inclusive.toStringAsFixed(2)})";
       },
       barcodeMapper: (i) {
         final barcodes = List<String>.from(i['barcodes'] ?? []);
         return "${i['sku'] ?? ''} ${barcodes.join(' ')}";
       },
       isMultiple: true, 
       showScanner: true,
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

            // Sync using the same logic as Invoice Form
            _items.removeWhere((existing) => !qtyMap.containsKey(existing['item_id'].toString()));

            for (var itemEntry in _items) {
              final id = itemEntry['item_id'].toString();
              itemEntry['quantity'] = qtyMap[id];
              qtyMap.remove(id);
            }

            for (var id in qtyMap.keys) {
              final item = itemMap[id]!;
              final qty = qtyMap[id]!;
              final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
              final mrp = (item['default_sales_price'] ?? 0).toDouble();
              final inclusive = double.parse((mrp * (1 + rate / 100)).toStringAsFixed(2));
              
              _items.add({
                'item_id': item['id'],
                'name': item['name'],
                'quantity': qty,
                'unit_price': inclusive,
                'tax_rate': rate,
              });
            }
            _calculateTotals();
         });
       }
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
    bool showScanner = false,
    String Function(T)? barcodeMapper,
    Future<void> Function()? onRefresh,
  }) {
    String searchQuery = "";
    bool isRefreshing = false;
    final searchController = TextEditingController();
    final focusNode = FocusNode();
    final sheetController = DraggableScrollableController();
    List<T> selectedItems = currentValues != null ? List<T>.from(currentValues) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
                  decoration: BoxDecoration(color: context.surfaceBg),
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
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data synchronized! Please reopen to see changes.")));
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
                      const SizedBox(height: 16),
                      
                      // Premium High-Fidelity Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.cardBg,
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
                                hintText: "Search anything...",
                                hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.normal),
                                prefixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.search_rounded, 
                                    key: ValueKey(focusNode.hasFocus),
                                    color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.5), 
                                    size: 24
                                  ),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (searchQuery.isNotEmpty) 
                                      IconButton(
                                        icon: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.1), shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, size: 14)
                                        ), 
                                        onPressed: () => setModalState(() { searchQuery = ""; searchController.clear(); })
                                      ),
                                    if (showScanner) 
                                      IconButton(
                                        icon: Icon(Icons.barcode_reader, size: 22, color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary), 
                                        onPressed: () => _openScanner(
                                          allItems: items,
                                          selectedItems: selectedItems,
                                          onSelectionChanged: (l) => setModalState(() { selectedItems.clear(); selectedItems.addAll(l); }),
                                          onConfirm: () {
                                             if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); }
                                          },
                                          barcodeMapper: barcodeMapper!,
                                          labelMapper: labelMapper,
                                          isMultiple: isMultiple
                                        )
                                      ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              onChanged: (v) => setModalState(() => searchQuery = v),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // List
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          itemCount: filteredItems.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final label = labelMapper(item);
                            final count = selectedItems.where((e) => e == item).length;
                            final isSelected = count > 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: context.textPrimary)),
                                onTap: () {
                                  if (isMultiple) {
                                    setModalState(() => selectedItems.add(item));
                                  } else {
                                    onSelect?.call(item);
                                    Navigator.pop(context);
                                  }
                                },
                                trailing: isMultiple && isSelected 
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                                      child: Text("x$count", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ) 
                                  : (isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null),
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
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                           if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); }
                        },
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
        },
      ),
    );
  }

  Future<void> _selectDate(bool isOrderDate) async {
    final p = await showCustomCalendarSheet(
      context: context,
      initialDate: isOrderDate ? _orderDate : _expectedDelivery,
      title: isOrderDate ? "Select Order Date" : "Select Delivery Date",
      firstDate: isOrderDate ? DateTime(2000) : (_orderDate),
    );
    if (p != null) {
      setState(() { 
        if (isOrderDate) {
          _orderDate = p;
          // Auto update delivery date if it becomes before order date
          if (_expectedDelivery.isBefore(_orderDate)) {
             _expectedDelivery = _orderDate.add(const Duration(days: 7));
          }
        } else {
          _expectedDelivery = p; 
        }
      });
    }
  }

  Future<void> _saveOrder() async {
    if (_customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one item")));
      return;
    }
    
    if (_companyId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Company profile not loaded. Please try again.")));
       return;
    }
    
    setState(() => _loading = true);
    try {
      final orderData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'so_number': _orderNumber,
        'date': _orderDate.toIso8601String(),
        'delivery_date': _expectedDelivery.toIso8601String(),
        'sub_total': _subtotal,
        'tax_total': _totalTax,
        'total_amount': _totalAmount,
        'status': _status,
        'created_by': _internalUserId,
      };

      String orderId;
      final bool isNewOrder = widget.order == null || widget.order!['id'] == null;

      if (isNewOrder) {
        // NEW ORDER (Blank or Conversion)
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'SALES_ORDER',
          branchId: _branchId,
          previewOnly: false,
        );
        orderData['so_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_orders').insert(orderData).select().single();
        orderId = inserted['id'].toString();

        // If converted from quotation, update status
        if (_quotationId != null) {
          await Supabase.instance.client.from('sales_quotations').update({'status': 'converted'}).eq('id', _quotationId!);
        }
      } else {
        // UPDATE EXISTING
        orderId = widget.order!['id'].toString();
        await Supabase.instance.client.from('sales_orders').update(orderData).eq('id', orderId);
        // Clear old items
        await Supabase.instance.client.from('sales_order_items').delete().eq('so_id', orderId);
      }

      // Preparation for bulk items insert
      final List<Map<String, dynamic>> itemsToInsert = [];
      for (var item in _items) {
        if (item['item_id'] == null) continue; // Skip invalid items
        
        final qty = (item['quantity'] ?? 0).toDouble();
        final price = (item['unit_price'] ?? 0).toDouble();
        final taxRate = (item['tax_rate'] ?? 0).toDouble();
        
        final totalInclusive = qty * price;
        final lineSub = totalInclusive / (1 + (taxRate / 100));
        final lineTax = totalInclusive - lineSub;

        itemsToInsert.add({
          'so_id': orderId,
          'item_id': item['item_id'].toString(),
          'description': (item['name'] ?? 'Item').toString(),
          'quantity': qty,
          'unit_price': price,
          'tax_rate': taxRate,
          'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
          'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
        });
      }

      if (itemsToInsert.isNotEmpty) {
        await Supabase.instance.client.from('sales_order_items').insert(itemsToInsert);
      }

      if (mounted) {
        SalesRefreshService.triggerRefresh();
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error saving order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving order: ${e.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
       if (mounted) setState(() => _loading = false);
    }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
}
