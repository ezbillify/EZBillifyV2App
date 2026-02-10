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
import 'sales_order_form_screen.dart';
import '../../services/numbering_service.dart';

class QuotationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? quotation; // Null for new
  const QuotationFormScreen({super.key, this.quotation});

  @override
  State<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends State<QuotationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _quotationDate = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  String _quotationNumber = "";
  String _status = "draft";
  
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
      
      if (widget.quotation == null) {
        // Fetch branches to select default if only one
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateQuotationNumber();
      } else {
        // Load existing quotation data
        _quotationNumber = widget.quotation!['quote_number'] ?? widget.quotation!['quotation_number'] ?? '';
        _branchId = widget.quotation!['branch_id']?.toString();
        _branchName = widget.quotation!['branch']?['name'];
        _customerId = widget.quotation!['customer_id']?.toString();
        _customerName = widget.quotation!['customer']?['name'];
        _quotationDate = DateTime.parse(widget.quotation!['date'] ?? widget.quotation!['quotation_date'] ?? DateTime.now().toIso8601String());
        _validUntil = DateTime.tryParse(widget.quotation!['expiry_date'] ?? widget.quotation!['valid_until'] ?? '') ?? DateTime.now().add(const Duration(days: 30));
        _status = widget.quotation!['status'] ?? 'draft';
        
        // Fetch items if not provided or just rely on what is passed (often just summary in list)
        // Usually we need to fetch items from separate table if not joined
        // Assuming joined for now or empty
        if (widget.quotation!['items'] != null) {
           _items = List<Map<String, dynamic>>.from(widget.quotation!['items']);
        } else {
           // Fetch items
           final items = await Supabase.instance.client.from('sales_quotation_items')
              .select('*, item:items(name, unit, default_sales_price, purchase_price, barcodes)')
              .eq('quotation_id', widget.quotation!['id']);
           
           _items = items.map((i) => {
             'item_id': i['item_id'],
             'name': i['item']['name'],
             'quantity': i['quantity'],
             'unit_price': i['unit_price'],
             'tax_rate': i['tax_rate'],
             'unit': i['item']['unit'],
             'purchase_price': i['item']['purchase_price'],
             //'barcodes': i['item']['barcodes']
           }).toList();
        }

        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateQuotationNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'SALES_QUOTATION',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _quotationNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble(); // Inclusive price
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final totalInclusive = qty * price;
      // Back calculate base price from inclusive price: Base = Total / (1 + Rate/100)
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
            Text(widget.quotation == null ? "New Quote" : "Edit Quote", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_quotationNumber.isEmpty ? "Generating ID..." : _quotationNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          if (widget.quotation != null)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'invoice') _convertToInvoice();
                else if (val == 'order') _convertToSalesOrder();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'invoice', child: Text("Convert to Invoice")),
                const PopupMenuItem(value: 'order', child: Text("Convert to Sales Order")),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          const SizedBox(width: 8),
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
    // Navigate to Invoice Form with pre-filled data
    // We pass a map that looks like an invoice but has no ID, so it's treated as "New" but pre-filled
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (c) => InvoiceFormScreen(
          invoice: {
            'customer_id': _customerId,
            'customer_name': _customerName,
            'branch_id': _branchId,
            'items': _items,
            'subtotal': _subtotal,
            'total_tax': _totalTax,
            'total_amount': _totalAmount,
            // Tag it as a conversion to perhaps update quotation status later
            'quotation_id': widget.quotation!['id'],
          },
        ),
      ),
    );
  }

  void _convertToSalesOrder() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (c) => SalesOrderFormScreen(
          order: {
            'customer_id': _customerId,
            'customer_name': _customerName,
            'branch_id': _branchId,
            'items': _items,
            'subtotal': _subtotal,
            'total_tax': _totalTax,
            'total_amount': _totalAmount,
            'quotation_id': widget.quotation!['id'],
          },
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
        _buildSectionTitle("Customer Details"),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectCustomer,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_pin_rounded, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_customerName ?? "Select Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _customerName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
                      if (_customerName != null) Text("Click to change customer", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Dates & Info"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Quote Date", DateFormat('dd MMM, yyyy').format(_quotationDate), Icons.calendar_today_rounded, () => _selectDate(true)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Valid Until", DateFormat('dd MMM, yyyy').format(_validUntil), Icons.event_repeat_rounded, () => _selectDate(false)),
            ),
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
            _buildSectionTitle("Line Items"),
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
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text("No items added yet", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5))),
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
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['name'] ?? 'Item Name', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    Text("Price: ₹${item['unit_price']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              IconButton(onPressed: () => _removeItem(index), icon: Icon(Icons.delete_outline_rounded, color: Colors.red[300], size: 20)),
            ],
          ),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "₹${_subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 12),
          _buildSummaryRow("Total Tax", "₹${_totalTax.toStringAsFixed(2)}"),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          _buildSummaryRow("Grand Total", "₹${_totalAmount.toStringAsFixed(2)}", isTotal: true),
        ],
      ),
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
                Text("Total Amount", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                Text("₹${_totalAmount.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 54,
            width: 160,
            child: ElevatedButton(
              onPressed: _loading ? null : _saveQuotation,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("Save Quote", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary));
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

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: isTotal ? context.textPrimary : context.textSecondary, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isTotal ? AppColors.primaryBlue : context.textPrimary, fontSize: isTotal ? 20 : 14)),
      ],
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

  // Action Methods
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
        _generateQuotationNumber(); // Regenerate number for the new branch
      }),
      currentValue: _branchName,
    );
  }

  Future<void> _selectCustomer() async {
    // Navigate to customer picker (similar to Selection sheet but for CUSTOMERS)
    final results = await Supabase.instance.client.from('customers').select().eq('company_id', _companyId!);
    if(!mounted) return;
    
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Customer",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (c) => c['name'],
      onSelect: (c) => setState(() { _customerId = c['id'].toString(); _customerName = c['name']; }),
      currentValue: _customerName,
      badgeMapper: (c) => c['customer_type'] ?? 'B2C',
      badgeColorMapper: (c) => (c['customer_type'] == 'B2B') ? Colors.purple : Colors.blue,
    );
  }

  Future<void> _addItem() async {
     // Item selection sheet
    final results = await Supabase.instance.client.from('items').select('*, tax_rate:tax_rates(rate)').eq('company_id', _companyId!);
    if(!mounted) return;

    _showSelectionSheet<Map<String, dynamic>>(
      title: "Add Items",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (i) {
        final price = (i['default_sales_price'] ?? 0).toDouble();
        final rate = (i['tax_rate']?['rate'] ?? 0).toDouble();
        final inclusive = price * (1 + rate / 100);
        return "${i['name']} (₹${inclusive.toStringAsFixed(2)})";
      },
      barcodeMapper: (i) {
        final barcodes = List<String>.from(i['barcodes'] ?? []);
        return "${i['sku'] ?? ''} ${barcodes.join(' ')}";
      },
      isMultiple: true,
      onSelectMultiple: (selectedList) {
        setState(() {
          final consolidated = <String, Map<String, dynamic>>{};
          final qtyMap = <String, int>{};

          for (var item in selectedList) {
            final id = item['id'];
            if (!consolidated.containsKey(id)) {
              consolidated[id] = item;
            }
            qtyMap[id] = (qtyMap[id] ?? 0) + 1;
          }

          for (var id in consolidated.keys) {
            final item = consolidated[id]!;
            final qty = qtyMap[id]!;
            final mrp = (item['default_sales_price'] ?? 0).toDouble();
            final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
            final inclusivePrice = mrp * (1 + rate / 100);
            
            final existingIndex = _items.indexWhere((element) => element['item_id'] == id);
            if (existingIndex != -1) {
               _items[existingIndex]['quantity'] = (_items[existingIndex]['quantity'] as num) + qty;
               _items[existingIndex]['unit_price'] = inclusivePrice; 
            } else {
               _items.add({
                 'item_id': id,
                 'name': item['name'],
                 'quantity': qty,
                 'unit_price': inclusivePrice,
                 'tax_rate': rate,
                 'unit': item['unit'],
                 'purchase_price': (item['purchase_price'] ?? 0).toDouble(),
               });
            }
          }
        });
        _calculateTotals();
      },
      showScanner: true,
      itemContentBuilder: (context, item, count, onAdd, onRemove) {
        final mrp = (item['default_sales_price'] ?? 0).toDouble(); // Assuming default_sales_price is MRP for now or generic
        final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
        final inclusive = mrp * (1 + rate / 100);
        final purchase = (item['purchase_price'] ?? 0).toDouble();
        final unit = item['unit'] ?? 'unt';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: count > 0 ? AppColors.primaryBlue : context.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                   Container(
                     width: 48,
                     height: 48,
                     decoration: BoxDecoration(
                       color: AppColors.primaryBlue.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryBlue),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           item['name'],
                           style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
                           maxLines: 1, overflow: TextOverflow.ellipsis
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Text("MRP: ₹${mrp.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500)),
                             const SizedBox(width: 8),
                             Text("Rate (Incl. Tax): ₹${inclusive.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text("Pur: ₹${purchase.toStringAsFixed(2)} • $unit", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary.withOpacity(0.7))),
                       ],
                     ),
                   ),
                   const SizedBox(width: 12),
                   if (count > 0)
                     Container(
                       decoration: BoxDecoration(
                         color: context.surfaceBg,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: context.borderColor),
                       ),
                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           InkWell(
                             onTap: onRemove,
                             child: const Icon(Icons.remove, size: 20),
                           ),
                           SizedBox(
                             width: 32,
                             child: Text("$count", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                           ),
                            InkWell(
                             onTap: onAdd,
                             child: const Icon(Icons.add, size: 20),
                           ),
                         ],
                       ),
                     )
                   else
                     Container(
                       padding: const EdgeInsets.all(8),
                       decoration: BoxDecoration(
                         color: AppColors.primaryBlue.withOpacity(0.1),
                         shape: BoxShape.circle,
                       ),
                       child: const Icon(Icons.add, color: AppColors.primaryBlue, size: 24),
                     ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
    _calculateTotals();
  }

  Future<void> _selectDate(bool isQuoteDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isQuoteDate ? _quotationDate : _validUntil,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isQuoteDate) {
          _quotationDate = picked;
          if (_validUntil.isBefore(_quotationDate)) _validUntil = _quotationDate.add(const Duration(days: 30));
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _saveQuotation() async {
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer"))); return; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one item"))); return; }
    
    setState(() => _loading = true);
    try {
      final quotationData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'quote_number': _quotationNumber,
        'date': _quotationDate.toIso8601String(),
        'expiry_date': _validUntil.toIso8601String(),
        'sub_total': _subtotal,
        'tax_total': _totalTax,
        'total_amount': _totalAmount,
        'status': _status,
      };

      if (widget.quotation == null) {
        // Consume actual number on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'SALES_QUOTATION',
          branchId: _branchId,
          previewOnly: false,
        );
        quotationData['quote_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_quotations').insert(quotationData).select().single();
        for (var item in _items) {
           await Supabase.instance.client.from('sales_quotation_items').insert({
             'quotation_id': inserted['id'],
             'item_id': item['item_id'],
             'quantity': item['quantity'],
             'unit_price': item['unit_price'],
             'tax_rate': item['tax_rate'],
             'company_id': _companyId,
           });
        }
      } else {
        // Update logic (omitted for brevity in first pass)
        await Supabase.instance.client.from('sales_quotations').update(quotationData).eq('id', widget.quotation!['id']);
        // Delete old items and re-insert (common simple approach for document edits)
        await Supabase.instance.client.from('sales_quotation_items').delete().eq('quotation_id', widget.quotation!['id']);
        for (var item in _items) {
           await Supabase.instance.client.from('sales_quotation_items').insert({
             'quotation_id': widget.quotation!['id'],
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
      debugPrint("Error saving quotation: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }

  // Reuse the selection sheet pattern
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
  }) {
    String searchQuery = "";
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
                  sheetController.animateTo(
                    0.95, 
                    duration: const Duration(milliseconds: 300), 
                    curve: Curves.easeInOut
                  );
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
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
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
                            if (isMultiple)
                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: TextField(
                            controller: searchController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: "Search...",
                              hintStyle: TextStyle(color: context.textSecondary.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.search, color: context.textSecondary),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                              suffixIcon: showScanner ? IconButton(
                                icon: const Icon(Icons.qr_code_scanner_rounded),
                                onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (c) => MobileScanner(
                                      onDetect: (capture) {
                                         final List<Barcode> barcodes = capture.barcodes;
                                         for (final barcode in barcodes) {
                                            if (barcode.rawValue != null) {
                                               setModalState(() { searchQuery = barcode.rawValue!; searchController.text = searchQuery; });
                                               Navigator.pop(c);
                                               break;
                                            }
                                         }
                                      },
                                    )));
                                },
                              ) : null,
                            ),
                            onChanged: (v) => setModalState(() => searchQuery = v),
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
                            final isSelected = selectedItems.contains(item);
                            final selectionCount = selectedItems.where((e) => e == item).length;
                            
                            // Check quantity map if using multiple
                            int qty = 0;
                            // This depends on T being dynamic or Map.
                            if (itemContentBuilder != null && item is Map<String, dynamic>) {
                               // Find quantity in selectedItems
                               qty = selectedItems.where((e) => (e as Map)['id'] == item['id']).length;
                            }
                            
                            if (itemContentBuilder != null) {
                               return itemContentBuilder(context, item, qty, () {
                                 setModalState(() {
                                    selectedItems.add(item);
                                    if(onSelectMultiple != null) onSelectMultiple(selectedItems); // Live update? No, usually on close. But here we might want local state.
                                    // Actually, we should call setModalState to update the UI
                                 });
                               }, () {
                                 if (qty > 0) {
                                    setModalState(() {
                                      selectedItems.remove(item);
                                    });
                                 }
                               });
                            }

                            return ListTile(
                              title: Text(labelMapper(item)),
                              onTap: () {
                                if (isMultiple) {
                                  setModalState(() {
                                    if (isSelected) selectedItems.remove(item); else selectedItems.add(item);
                                  });
                                } else {
                                  onSelect?.call(item);
                                  Navigator.pop(context);
                                }
                              },
                              trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
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
                    child: SafeArea(
                      child: ElevatedButton(
                        onPressed: () {
                          onSelectMultiple?.call(selectedItems);
                          Navigator.pop(context);
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
        }
      ),
    );
  }
}
