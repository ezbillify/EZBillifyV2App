import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
// import 'package:animate_do/animate_do.dart';
import '../../services/numbering_service.dart';
import '../inventory/item_selection_sheet.dart'; // We'll need to reuse or adapt this
import 'vendors_screen.dart'; // To select vendors

class PurchaseBillFormScreen extends StatefulWidget {
  final Map<String, dynamic>? bill; // Null for new
  const PurchaseBillFormScreen({super.key, this.bill});

  @override
  State<PurchaseBillFormScreen> createState() => _PurchaseBillFormScreenState();
}

class _PurchaseBillFormScreenState extends State<PurchaseBillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _branchId;
  String? _branchName;
  String? _vendorId;
  String? _vendorName;
  DateTime _billDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _billNumber = "";
  String _referenceNumber = ""; // Vendor Bill Number
  
  // Line Items
  List<Map<String, dynamic>> _items = [];
  
  // Totals
  double _subtotal = 0;
  double _totalTax = 0;
  double _totalAmount = 0;

  // Record Payment State
  bool _recordPayment = false;
  double _paidAmount = 0;
  String _paymentMode = "Bank Transfer";
  String _paymentReference = "";
  final _paidAmountController = TextEditingController();

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
      
      final isEdit = widget.bill != null && widget.bill!['id'] != null;
      
      if (!isEdit) {
        // Fetch branches to select default if only one
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateBillNumber();
      } else {
        // Load existing bill data for EDIT
        _billNumber = widget.bill!['bill_number'];
        _branchId = widget.bill!['branch_id']?.toString();
        // _branchName = widget.bill!['branch']?['name']; // If joined
        _vendorId = widget.bill!['vendor_id']?.toString();
        _vendorName = widget.bill!['vendor']?['name'];
        _billDate = DateTime.parse(widget.bill!['date'] ?? widget.bill!['created_at']);
        _dueDate = DateTime.parse(widget.bill!['due_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String());
        _referenceNumber = widget.bill!['reference_number'] ?? '';
        
        // Fetch items if not provided
        if (widget.bill!['items'] == null) {
          final itemsData = await Supabase.instance.client.from('purchase_bill_items').select('*, item:items(name)').eq('bill_id', widget.bill!['id']);
           _items = List<Map<String, dynamic>>.from(itemsData.map((e) => {
             ...e,
             'name': e['item']['name'],
             'item_id': e['item_id'],
             'quantity': e['quantity'],
             'unit_price': e['unit_price'],
             'tax_rate': e['tax_rate']
           }));
        } else {
          _items = List<Map<String, dynamic>>.from(widget.bill!['items']);
        }
        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateBillNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    // Use NumberingService for PURCHASE_BILL if available, or fallback
    // Assuming numbering service supports 'PURCHASE_BILL' or similar
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_BILL', 
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _billNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final lineTotal = qty * price; 
      // Assuming unit_price is exclusive of tax for purchases usually, or inclusive?
      // Let's assume Exclusive for B2B purchases often, but logic depends on input.
      // Retaining logic from Sales: Base + Tax
      
      final lineTax = lineTotal * (taxRate / 100);
      
      sub += lineTotal;
      tax += lineTax;
    }
    setState(() {
      _subtotal = double.parse(sub.toStringAsFixed(2));
      _totalTax = double.parse(tax.toStringAsFixed(2));
      _totalAmount = double.parse((sub + tax).toStringAsFixed(2));
      
      if (_recordPayment) {
        _paidAmount = _totalAmount;
        _paidAmountController.text = _paidAmount.toStringAsFixed(2);
      }
    });
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
        // TODO: Auto-fill terms or address
      });
    }
  }

  void _addItem() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => const ItemSelectionSheet() // Reusing existing item selector
    );

    if (result != null) {
      // Result might be a list or single item
      final List<Map<String, dynamic>> newItems = (result is List) ? List.from(result) : [result];
      
      setState(() {
        for (var item in newItems) {
           _items.add({
             'item_id': item['id'],
             'name': item['name'],
             'quantity': 1.0,
             'unit_price': (item['purchase_price'] ?? 0.0).toDouble(), // Use purchase price
             'tax_rate': (item['gst_rate'] ?? 0.0).toDouble(),
           });
        }
        _calculateTotals();
      });
    }
  }
  
  void _editItem(int index) async {
    final item = _items[index];
    final priceController = TextEditingController(text: item['unit_price'].toString());
    final taxController = TextEditingController(text: item['tax_rate'].toString());
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Item: ${item['name']}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceController, decoration: const InputDecoration(labelText: "Unit Price"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            TextField(controller: taxController, decoration: const InputDecoration(labelText: "Tax Rate (%)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items[index]['unit_price'] = double.tryParse(priceController.text) ?? 0;
                _items[index]['tax_rate'] = double.tryParse(taxController.text) ?? 0;
                _calculateTotals();
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _calculateTotals();
    });
  }

  void _saveBill() async {
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor")));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one item")));
      return;
    }

    setState(() => _loading = true);
    try {
      // 1. Create Bill Header
      final billData = {
        'company_id': _companyId,
        'vendor_id': _vendorId,
        'bill_number': _billNumber,
        'reference_number': _referenceNumber,
        'date': _billDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'total_amount': _totalAmount,
        'paid_amount': _recordPayment ? _paidAmount : 0,
        'status': _recordPayment && _paidAmount >= _totalAmount ? 'paid' : (_recordPayment && _paidAmount > 0 ? 'partial' : 'open'),
        'stock_updated': false, // TODO: Handle GRN logic later
      };
      
      Map<String, dynamic> upsertedBill;
      
      if (widget.bill != null) {
        upsertedBill = await Supabase.instance.client.from('purchase_bills').update(billData).eq('id', widget.bill!['id']).select().single();
        // Delete old items for simplicity in update (or use upsert logic)
        await Supabase.instance.client.from('purchase_bill_items').delete().eq('bill_id', widget.bill!['id']);
      } else {
        // Get actual number
         _billNumber = await NumberingService.getNextDocumentNumber(companyId: _companyId!, documentType: 'PURCHASE_BILL', branchId: _branchId);
         billData['bill_number'] = _billNumber;
         upsertedBill = await Supabase.instance.client.from('purchase_bills').insert(billData).select().single();
      }
      
      final billId = upsertedBill['id'];

      // 2. Insert Items
      final itemsToInsert = _items.map((item) => {
        'bill_id': billId,
        'item_id': item['item_id'],
        'description': item['name'], // Store name as description
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'tax_rate': item['tax_rate'],
        'tax_amount': (item['quantity'] * item['unit_price'] * (item['tax_rate']/100)),
        'total_amount': (item['quantity'] * item['unit_price'] * (1 + item['tax_rate']/100)),
      }).toList();
      
      await Supabase.instance.client.from('purchase_bill_items').insert(itemsToInsert);

      // 3. Record Payment if enabled
      if (_recordPayment && _paidAmount > 0) {
        await Supabase.instance.client.from('purchase_payments').insert({
          'company_id': _companyId,
          'bill_id': billId,
          'payment_number': 'PAY-${DateTime.now().millisecondsSinceEpoch}', // Placeholder
          'vendor_id': _vendorId,
          'date': DateTime.now().toIso8601String(),
          'amount': _paidAmount,
          'mode': _paymentMode.toLowerCase().replaceAll(' ', '_'),
          'reference_id': _paymentReference,
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Bill Saved Successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving bill: $e"), backgroundColor: Colors.red));
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
        title: Text(widget.bill == null ? "New Purchase Bill" : "Edit Bill", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        backgroundColor: context.surfaceBg,
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
        _buildSectionTitle("Dates & Reference"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Bill Date", DateFormat('dd MMM, yyyy').format(_billDate), Icons.calendar_today_rounded, () async {
                final d = await showDatePicker(context: context, initialDate: _billDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _billDate = d);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Due Date", DateFormat('dd MMM, yyyy').format(_dueDate), Icons.event_available_rounded, () async {
                final d = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _dueDate = d);
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _referenceNumber,
          decoration: InputDecoration(
            labelText: "Vendor Bill Number",
            hintText: "Enter Reference #",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: context.cardBg,
          ),
          onChanged: (v) => _referenceNumber = v,
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
                 Icon(Icons.shopping_cart_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
      child: InkWell(
        onTap: () => _editItem(index),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Text("Price: ₹${item['unit_price']} (Tap to edit)", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue)),
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
    return Column(
      children: [
        Container(
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
        ),
        const SizedBox(height: 24),
        if (widget.bill == null) _buildPaymentToggleSection(),
      ],
    );
  }

  Widget _buildPaymentToggleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _recordPayment ? Colors.green.withOpacity(0.05) : context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _recordPayment ? Colors.green.withOpacity(0.2) : context.borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_recordPayment ? Icons.check_circle_rounded : Icons.payments_outlined, color: _recordPayment ? Colors.green : context.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Record Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    Text("Mark this bill as paid immediately", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _recordPayment,
                onChanged: (v) {
                  setState(() {
                    _recordPayment = v;
                    if (v) {
                      _paidAmount = _totalAmount;
                      _paidAmountController.text = _paidAmount.toStringAsFixed(2);
                    }
                  });
                },
                activeColor: Colors.green,
              ),
            ],
          ),
          if (_recordPayment) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
            TextFormField(
              controller: _paidAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Paid Amount",
                prefixText: "₹ ",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: context.scaffoldBg,
              ),
              onChanged: (v) => _paidAmount = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMode,
              decoration: InputDecoration(
                labelText: "Payment Mode",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: context.scaffoldBg,
              ),
              items: ["Cash", "Bank Transfer", "UPI", "Cheque", "Other"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMode = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: "Reference / Transaction ID",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: context.scaffoldBg,
              ),
              onChanged: (v) => _paymentReference = v,
            ),
          ]
        ],
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
              onPressed: _loading ? null : _saveBill,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("Save Bill", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
}
