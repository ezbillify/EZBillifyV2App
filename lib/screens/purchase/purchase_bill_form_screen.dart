import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../widgets/calendar_sheet.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';
import '../sales/scanner_modal_content.dart';
import 'vendors_screen.dart';

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
  String? _internalUserId;
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
      _internalUserId = profile['id'];
      
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
            _items = List<Map<String, dynamic>>.from(itemsData.map((e) {
              final up = (e['unit_price'] ?? 0).toDouble();
              final tr = (e['tax_rate'] ?? 0).toDouble();
              return {
                ...e,
                'name': e['item']?['name'] ?? 'Item',
                'item_id': e['item_id'],
                'quantity': e['quantity'],
                'unit_price': up, // DB stores unit_price as TAX-INCLUSIVE in Web App. Do NOT multiply.
                'tax_rate': tr
              };
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
      documentType: 'PURCHASE_INVOICE', 
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _billNumber = nextNum);
  }

  void _calculateTotals() {
    double totalTax = 0;
    double grandTotal = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final priceInclusive = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final lineTotal = qty * priceInclusive;
      final taxVal = taxRate > 0 ? (lineTotal - (lineTotal / (1 + (taxRate / 100)))) : 0;
      
      grandTotal += lineTotal;
      totalTax += taxVal;
    }
    setState(() {
      _subtotal = double.parse((grandTotal - totalTax).toStringAsFixed(2));
      _totalTax = double.parse(totalTax.toStringAsFixed(2));
      _totalAmount = double.parse(grandTotal.toStringAsFixed(2));
      
      if (_recordPayment) {
        _paidAmount = _totalAmount;
        _paidAmountController.text = _paidAmount.toStringAsFixed(2);
      }
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
        _generateBillNumber();
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
        // TODO: Auto-fill terms or address
      });
    }
  }

  Future<void> _addItem() async {
    // Force refresh to get instantly up-to-date prices and stock levels
    final results = await MasterDataService().getItems(_companyId!, forceRefresh: true);
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
        final stock = i['total_stock'] ?? 0;
        return "${i['name']} (₹${price.toStringAsFixed(2)}) | Stock: $stock";
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
            final purIncl = (item['default_purchase_price'] ?? 0).toDouble();
            final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
            
            _items.add({
              'item_id': item['id'],
              'name': item['name'],
              'quantity': qty,
              'unit_price': purIncl,
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: count > 0 ? AppColors.primaryBlue : context.borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))]
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
        'branch_id': _branchId,
        'vendor_id': _vendorId,
        'reference_number': _referenceNumber,
        'date': _billDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'total_amount': double.parse(_totalAmount.toStringAsFixed(2)),
      };
      
      if (widget.bill == null) {
        final paid = _recordPayment ? _paidAmount : 0.0;
        billData['paid_amount'] = double.parse(paid.toStringAsFixed(2));
        billData['balance_due'] = double.parse((_totalAmount - paid).toStringAsFixed(2));
        billData['status'] = _recordPayment && paid >= _totalAmount ? 'paid' : (_recordPayment && paid > 0 ? 'partial' : 'open');
        billData['stock_updated'] = false; // TODO: Handle GRN logic later
      } else {
        final existingPaid = (widget.bill!['paid_amount'] ?? 0).toDouble();
        final newBalance = _totalAmount - existingPaid;
        billData['balance_due'] = double.parse(newBalance.toStringAsFixed(2));
        billData['status'] = newBalance <= 0 ? 'paid' : 'open';
      }
      
      Map<String, dynamic> upsertedBill;
      
      if (widget.bill != null) {
        upsertedBill = await Supabase.instance.client.from('purchase_bills').update(billData).eq('id', widget.bill!['id']).select().single();
        // Delete old items for simplicity in update (or use upsert logic)
        await Supabase.instance.client.from('purchase_bill_items').delete().eq('bill_id', widget.bill!['id']);
      } else {
        // Get actual number
         _billNumber = await NumberingService.getNextDocumentNumber(companyId: _companyId!, documentType: 'PURCHASE_INVOICE', branchId: _branchId);
         billData['bill_number'] = _billNumber;
         upsertedBill = await Supabase.instance.client.from('purchase_bills').insert(billData).select().single();
      }
      
      final billId = upsertedBill['id'];

      // 2. Insert Items
      final itemsToInsert = _items.map((item) {
        final qty = (item['quantity'] ?? 0).toDouble();
        final priceInclusive = (item['unit_price'] ?? 0).toDouble();
        final taxRate = (item['tax_rate'] ?? 0).toDouble();
        
        final totalInclusive = qty * priceInclusive;
        final taxVal = taxRate > 0 ? (totalInclusive - (totalInclusive / (1 + (taxRate / 100)))) : 0;

        return {
          'bill_id': billId,
          'item_id': item['item_id'],
          'description': item['name'],
          'quantity': qty,
          'unit_price': priceInclusive, // Match Web API: store directly as inclusive!
          'tax_rate': taxRate,
          'tax_amount': double.parse(taxVal.toStringAsFixed(2)),
          'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
        };
      }).toList();
      
      await Supabase.instance.client.from('purchase_bill_items').insert(itemsToInsert);

      // 3. Stock Integration (GRN)
      if (widget.bill == null || widget.bill!['stock_updated'] != true) {
        for (var item in itemsToInsert) {
          final String itemId = item['item_id'];
          final double qty = (item['quantity'] ?? 0).toDouble();
          final double priceIncl = (item['unit_price'] ?? 0).toDouble(); // Read precisely from inclusive field we just mapped
          
          await Supabase.instance.client.from('items').update({'default_purchase_price': priceIncl}).eq('id', itemId);

          final stockRes = await Supabase.instance.client.from('inventory_stock')
              .select().eq('company_id', _companyId!).eq('branch_id', _branchId!).eq('item_id', itemId).maybeSingle();
          
          double currentQty = 0;
          if (stockRes != null) {
            currentQty = (stockRes['quantity'] ?? 0).toDouble();
            await Supabase.instance.client.from('inventory_stock').update({
              'quantity': currentQty + qty, 
              'average_cost': priceIncl,
              'last_updated': DateTime.now().toIso8601String()
            }).eq('id', stockRes['id']);
          } else {
            await Supabase.instance.client.from('inventory_stock').insert({
              'company_id': _companyId, 
              'branch_id': _branchId, 
              'item_id': itemId, 
              'quantity': qty, 
              'average_cost': priceIncl, 
              'last_updated': DateTime.now().toIso8601String()
            });
          }

          await Supabase.instance.client.from('inventory_transactions').insert({
            'company_id': _companyId,
            'item_id': itemId,
            'branch_id': _branchId,
            'transaction_type': 'purchase',
            'quantity_change': qty,
            'new_balance': currentQty + qty,
            'unit_cost': priceIncl,
            'reference_id': billId,
            'reference_type': 'purchase_bill',
            'notes': 'Purchase Invoice GRN',
            'created_by': _internalUserId ?? Supabase.instance.client.auth.currentUser!.id,
          });
        }
        await Supabase.instance.client.from('purchase_bills').update({'stock_updated': true}).eq('id', billId);
      }

      // 3. Record Payment if enabled
      if (_recordPayment && _paidAmount > 0 && _companyId != null && _branchId != null) {
        final paymentNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'PURCHASE_PAYMENT',
          branchId: _branchId,
          previewOnly: false,
        );

        await Supabase.instance.client.from('purchase_payments').insert({
          'company_id': _companyId,
          'bill_id': billId,
          'payment_number': paymentNumber,
          'vendor_id': _vendorId,
          'date': DateTime.now().toIso8601String(),
          'amount': _paidAmount,
          'mode': _paymentMode.toLowerCase().replaceAll(' ', '_'),
          'reference_id': _paymentReference,
          'created_by': _internalUserId ?? Supabase.instance.client.auth.currentUser!.id,
          'is_active': true,
        });
      }

      if (mounted) {
        await MasterDataService().invalidateItems();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Invoice Saved Successfully")));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bill == null ? "New Purchase Invoice" : "Edit Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_billNumber.isEmpty ? "Generating ID..." : _billNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Branch"),
            if (widget.bill == null)
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
        _buildSectionTitle("Dates & Reference"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Bill Date", DateFormat('dd MMM, yyyy').format(_billDate), Icons.calendar_today_rounded, () async {
                final d = await showCustomCalendarSheet(context: context, initialDate: _billDate, title: "Select Bill Date");
                if (d != null) setState(() => _billDate = d);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Due Date", DateFormat('dd MMM, yyyy').format(_dueDate), Icons.event_available_rounded, () async {
                final d = await showCustomCalendarSheet(context: context, initialDate: _dueDate, title: "Select Due Date", firstDate: _billDate);
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
        onTap: () => _editItemPrice(index),
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
                                hintText: "Search anything...",
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
                              child: InkWell(
                                onTap: () {
                                  if (isMultiple) onIncrement();
                                  else { onSelect?.call(item); Navigator.pop(context); }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.normal, color: context.textPrimary))),
                                      if (count > 0) Text("x$count", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                      if (!isMultiple && isSelected) const Icon(Icons.check, color: AppColors.primaryBlue)
                                    ],
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
