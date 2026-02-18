import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import '../inventory/item_selection_sheet.dart';
import 'vendors_screen.dart';
import '../../widgets/calendar_sheet.dart';

class PurchaseDebitNoteFormScreen extends StatefulWidget {
  final Map<String, dynamic>? debitNote; // Null for new
  const PurchaseDebitNoteFormScreen({super.key, this.debitNote});

  @override
  State<PurchaseDebitNoteFormScreen> createState() => _PurchaseDebitNoteFormScreenState();
}

class _PurchaseDebitNoteFormScreenState extends State<PurchaseDebitNoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _branchId;
  String? _branchName;
  String? _vendorId;
  String? _vendorName;
  String? _billId;
  String? _billNumber;
  
  DateTime _date = DateTime.now();
  String _debitNoteNumber = "";
  String _reason = "Return";
  String _notes = "";
  
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
      
      final isEdit = widget.debitNote != null && widget.debitNote!['id'] != null;
      
      if (!isEdit) {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateDebitNoteNumber();
      } else {
        _debitNoteNumber = widget.debitNote!['debit_note_number'];
        _vendorId = widget.debitNote!['vendor_id']?.toString();
        _vendorName = widget.debitNote!['vendor']?['name'];
        _billId = widget.debitNote!['bill_id']?.toString();
        
        if (_billId != null) {
          final bill = await Supabase.instance.client.from('purchase_bills').select('bill_number').eq('id', _billId!).single();
          _billNumber = bill['bill_number'];
        }

        _date = DateTime.parse(widget.debitNote!['date'] ?? widget.debitNote!['created_at']);
        _reason = widget.debitNote!['reason'] ?? "Return";
        _notes = widget.debitNote!['notes'] ?? "";
        
        if (widget.debitNote!['items'] == null) {
          final itemsData = await Supabase.instance.client.from('purchase_debit_note_items').select('*, item:items(name)').eq('debit_note_id', widget.debitNote!['id']);
           _items = List<Map<String, dynamic>>.from(itemsData.map((e) => {
             ...e,
             'name': e['item']['name'],
             'item_id': e['item_id'],
             'quantity': e['quantity'],
             'unit_price': e['unit_price'],
           }));
        } else {
          _items = List<Map<String, dynamic>>.from(widget.debitNote!['items']);
        }
        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing Debit Note: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateDebitNoteNumber() async {
    if (_branchId == null || _companyId == null) return;
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_DEBIT_NOTE', // Assuming this enum/type exists or will handle fallback
      branchId: _branchId,
      previewOnly: true,
    );
    setState(() => _debitNoteNumber = nextNum);
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
        _billId = null;
        _billNumber = null;
      });
    }
  }

  Future<void> _selectBill() async {
    if (_vendorId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor first")));
       return;
    }

    // Show passed bills for this vendor
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceBg,
      builder: (context) {
         return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client.from('purchase_bills')
            .select()
            .eq('vendor_id', _vendorId!)
            .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final bills = snapshot.data!;
            if (bills.isEmpty) return const Center(child: Text("No bills found for this vendor"));
            
            return ListView.builder(
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];
                return ListTile(
                  title: Text(bill['bill_number']),
                  subtitle: Text("Date: ${DateFormat('dd MMM').format(DateTime.parse(bill['date']))} - Amount: ${bill['total_amount']}"),
                  onTap: () async {
                    Navigator.pop(context); // Close sheet
                    setState(() {
                      _billId = bill['id'];
                      _billNumber = bill['bill_number'];
                    });
                  },
                );
              },
            );
          },
        );
      }
    );
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final lineTotal = qty * price;
      final lineTax = lineTotal * (taxRate / 100);
      
      sub += lineTotal;
      tax += lineTax;
    }
    setState(() {
      _subtotal = double.parse(sub.toStringAsFixed(2));
      _totalTax = double.parse(tax.toStringAsFixed(2));
      _totalAmount = double.parse((sub + tax).toStringAsFixed(2));
    });
  }

  void _addItem() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => const ItemSelectionSheet()
    );

    if (result != null) {
      final List<Map<String, dynamic>> newItems = (result is List) ? List.from(result) : [result];
      setState(() {
        for (var item in newItems) {
           _items.add({
             'item_id': item['id'],
             'name': item['name'],
             'quantity': 1.0,
             'unit_price': (item['purchase_price'] ?? 0.0).toDouble(),
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
    final taxController = TextEditingController(text: item['tax_rate']?.toString() ?? '0');
    
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

  void _saveDebitNote() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one item")));
      return;
    }
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor")));
      return;
    }

    setState(() => _loading = true);
    try {
      final noteData = {
        'company_id': _companyId,
        'vendor_id': _vendorId,
        'bill_id': _billId,
        'debit_note_number': _debitNoteNumber,
        'date': _date.toIso8601String(),
        'reason': _reason,
        'notes': _notes,
        'total_amount': _totalAmount,
      };
      
      Map<String, dynamic> upsertedNote;
      
      if (widget.debitNote != null) {
        upsertedNote = await Supabase.instance.client.from('purchase_debit_notes').update(noteData).eq('id', widget.debitNote!['id']).select().single();
        await Supabase.instance.client.from('purchase_debit_note_items').delete().eq('debit_note_id', widget.debitNote!['id']);
      } else {
         _debitNoteNumber = await NumberingService.getNextDocumentNumber(companyId: _companyId!, documentType: 'PURCHASE_DEBIT_NOTE', branchId: _branchId);
         noteData['debit_note_number'] = _debitNoteNumber;
         upsertedNote = await Supabase.instance.client.from('purchase_debit_notes').insert(noteData).select().single();
      }
      
      final noteId = upsertedNote['id'];
      final itemsToInsert = _items.map((item) => {
        'debit_note_id': noteId,
        'item_id': item['item_id'],
        'description': item['name'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
        'amount': (item['quantity'] * item['unit_price']),
      }).toList();
      
      await Supabase.instance.client.from('purchase_debit_note_items').insert(itemsToInsert);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Debit Note Saved Successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving Debit Note: $e"), backgroundColor: Colors.red));
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
        title: Text(widget.debitNote == null ? "New Debit Note" : "Edit Debit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
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
        _buildSectionTitle("Vendor & Bill (Optional)"),
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
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectBill,
          borderRadius: BorderRadius.circular(16),
          child: Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                   child: const Icon(Icons.receipt_long_rounded, color: Colors.red, size: 24),
                 ),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(_billNumber ?? "Link Original Bill (Optional)", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _billNumber == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
                     ],
                   ),
                 ),
                 Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
               ],
             ),
           ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Details"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Date", DateFormat('dd MMM, yyyy').format(_date), Icons.calendar_today_rounded, () async {
                final d = await showCustomCalendarSheet(
                   context: context, 
                   initialDate: _date, 
                   title: "Select Debit Note Date"
                );
                if (d != null) setState(() => _date = d);
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _reason,
                decoration: InputDecoration(
                  labelText: "Reason",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: context.cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                ),
                items: ["Return", "Damage", "Discount", "Correction", "Other"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _reason = v!),
              ),
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
            _buildSectionTitle("Returned Items / Services"),
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
                 Icon(Icons.assignment_return_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
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
        onTap: () => _editItem(index),
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
                      Text("Unit Price: ${item['unit_price']} (Tap to edit)", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
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
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.1))),
      child: Column(
        children: [
          _buildSummaryRow("Subtotal", "₹${_subtotal.toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          _buildSummaryRow("Total Tax", "₹${_totalTax.toStringAsFixed(2)}"),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          _buildSummaryRow("Debit Total", "₹${_totalAmount.toStringAsFixed(2)}", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Notes"),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _notes,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: "General Notes",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: context.cardBg,
          ),
          onChanged: (v) => _notes = v,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: isTotal ? context.textPrimary : context.textSecondary, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 14)),
        Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isTotal ? Colors.red : context.textPrimary, fontSize: isTotal ? 20 : 14)),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _saveDebitNote,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: const Text("Save Debit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        ),
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
