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
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _orderDate = DateTime.now();
  DateTime _expectedDelivery = DateTime.now().add(const Duration(days: 7));
  String _orderNumber = "";
  String _status = "pending";
  String _referenceNumber = "";
  
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
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id'];
      
      final isEdit = widget.order != null && widget.order!['id'] != null;

      if (!isEdit) {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateOrderNumber();

        // Handle pre-filled data (e.g. from Quotation)
        if (widget.order != null) {
           _customerId = widget.order!['customer_id']?.toString();
           _customerName = widget.order!['customer_name'];
           _items = List<Map<String, dynamic>>.from(widget.order!['items'] ?? []);
           _calculateTotals();
        }
      } else {
        // Load existing order data
        _orderNumber = widget.order!['so_number'] ?? widget.order!['order_number'] ?? '';
        _branchId = widget.order!['branch_id']?.toString();
        _branchName = widget.order!['branch']?['name'];
        _customerId = widget.order!['customer_id']?.toString();
        _customerName = widget.order!['customer']?['name'];
        _orderDate = DateTime.parse(widget.order!['date'] ?? widget.order!['order_date'] ?? DateTime.now().toIso8601String());
        _expectedDelivery = DateTime.tryParse(widget.order!['delivery_date'] ?? widget.order!['expected_delivery'] ?? '') ?? DateTime.now().add(const Duration(days: 7));
        _status = widget.order!['status'] ?? 'pending';
        _referenceNumber = widget.order!['reference_number'] ?? "";
        
        // Fetch items
        final items = await Supabase.instance.client.from('sales_order_items')
            .select('*, item:items(name, unit, default_sales_price, purchase_price, barcodes)')
            .eq('order_id', widget.order!['id']);
        
        _items = items.map((i) => {
          'item_id': i['item_id'],
          'name': i['item']['name'],
          'quantity': i['quantity'],
          'unit_price': i['unit_price'],
          'tax_rate': i['tax_rate'],
          'unit': i['item']['unit'],
          'purchase_price': i['item']['purchase_price'],
        }).toList();

        _calculateTotals();
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
      
      sub += lineSub;
      tax += lineTax;
    }
    setState(() {
      _subtotal = sub;
      _totalTax = tax;
      _totalAmount = sub + tax;
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
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _referenceNumber,
          decoration: InputDecoration(labelText: "Reference # / PO #", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
          onChanged: (v) => _referenceNumber = v,
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
                      Text("₹${item['unit_price']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
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
    final results = await Supabase.instance.client.from('customers').select().eq('company_id', _companyId!);
    if(!mounted) return;
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Customer", items: List<Map<String, dynamic>>.from(results), labelMapper: (c) => c['name'],
      onSelect: (c) => setState(() { _customerId = c['id'].toString(); _customerName = c['name']; }),
    );
  }

  Future<void> _addItem() async {
     final results = await Supabase.instance.client.from('items').select('*, tax_rate:tax_rates(rate)').eq('company_id', _companyId!);
     if(!mounted) return;
     _showSelectionSheet<Map<String, dynamic>>(
       title: "Add Items", items: List<Map<String, dynamic>>.from(results), labelMapper: (i) => i['name'],
       isMultiple: true, showScanner: true,
       onSelectMultiple: (selectedList) {
         setState(() {
            for(var item in selectedList) {
               final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
               final mrp = (item['default_sales_price'] ?? 0).toDouble();
               final inclusive = mrp * (1 + rate / 100);
               _items.add({
                 'item_id': item['id'],
                 'name': item['name'],
                 'quantity': 1,
                 'unit_price': inclusive,
                 'tax_rate': rate,
               });
            }
            _calculateTotals();
         });
       }
     );
  }

  void _showSelectionSheet<T>({ required String title, required List<T> items, required String Function(T) labelMapper, Function(T)? onSelect, Function(List<T>)? onSelectMultiple, bool isMultiple = false, bool showScanner = false }) {
    // Reusing simple sheet for SO for now
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8, padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) => ListTile(title: Text(labelMapper(items[i])), onTap: () {
              if (isMultiple) onSelectMultiple?.call([items[i]]); else onSelect?.call(items[i]); Navigator.pop(context);
            }),
          ))
        ]),
      )
    );
  }

  Future<void> _selectDate(bool isOrderDate) async {
    final p = await showDatePicker(context: context, initialDate: isOrderDate ? _orderDate : _expectedDelivery, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (p != null) setState(() { if (isOrderDate) _orderDate = p; else _expectedDelivery = p; });
  }

  Future<void> _saveOrder() async {
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select customer"))); return; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add items"))); return; }
    
    setState(() => _loading = true);
    try {
      final orderData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'so_number': _orderNumber,
        'date': _orderDate.toIso8601String(),
        'delivery_date': _expectedDelivery.toIso8601String(),
        'reference_number': _referenceNumber,
        'sub_total': _subtotal,
        'tax_total': _totalTax,
        'total_amount': _totalAmount,
        'status': _status,
      };

      if (widget.order == null) {
        // Consume actual number on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'SALES_ORDER',
          branchId: _branchId,
          previewOnly: false,
        );
        orderData['so_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_orders').insert(orderData).select().single();
        for (var item in _items) {
           await Supabase.instance.client.from('sales_order_items').insert({
             'order_id': inserted['id'],
             'item_id': item['item_id'],
             'quantity': item['quantity'],
             'unit_price': item['unit_price'],
             'tax_rate': item['tax_rate'],
             'company_id': _companyId,
           });
        }
      } else {
        await Supabase.instance.client.from('sales_orders').update(orderData).eq('id', widget.order!['id']);
        await Supabase.instance.client.from('sales_order_items').delete().eq('order_id', widget.order!['id']);
        for (var item in _items) {
           await Supabase.instance.client.from('sales_order_items').insert({
             'order_id': widget.order!['id'],
             'item_id': item['item_id'],
             'quantity': item['quantity'],
             'unit_price': item['unit_price'],
             'tax_rate': item['tax_rate'],
             'company_id': _companyId,
           });
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving order: $e");
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }
}
