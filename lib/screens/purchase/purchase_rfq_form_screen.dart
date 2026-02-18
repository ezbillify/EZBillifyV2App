import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import '../inventory/item_selection_sheet.dart';
import 'vendors_screen.dart';
import '../../widgets/calendar_sheet.dart';

class PurchaseRfqFormScreen extends StatefulWidget {
  final Map<String, dynamic>? rfq; // Null for new
  const PurchaseRfqFormScreen({super.key, this.rfq});

  @override
  State<PurchaseRfqFormScreen> createState() => _PurchaseRfqFormScreenState();
}

class _PurchaseRfqFormScreenState extends State<PurchaseRfqFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _branchId;
  String? _branchName;
  String? _vendorId;
  String? _vendorName;
  DateTime _rfqDate = DateTime.now();
  String _rfqNumber = "";
  String _notes = "";
  String _status = "draft";
  
  // Line Items
  List<Map<String, dynamic>> _items = [];

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
      
      final isEdit = widget.rfq != null && widget.rfq!['id'] != null;
      
      if (!isEdit) {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateRfqNumber();
      } else {
        _rfqNumber = widget.rfq!['rfq_number'];
        _status = widget.rfq!['status'] ?? 'draft';
        _vendorId = widget.rfq!['vendor_id']?.toString();
        _vendorName = widget.rfq!['vendor']?['name'];
        _rfqDate = DateTime.parse(widget.rfq!['date'] ?? widget.rfq!['created_at']);
        _notes = widget.rfq!['notes'] ?? "";
        
        if (widget.rfq!['items'] == null) {
          final itemsData = await Supabase.instance.client.from('purchase_rfq_items').select('*, item:items(name)').eq('rfq_id', widget.rfq!['id']);
           _items = List<Map<String, dynamic>>.from(itemsData.map((e) => {
             ...e,
             'name': e['item'] != null ? e['item']['name'] : e['description'], 
             'item_id': e['item_id'],
             'quantity': e['quantity'],
             'uom': e['uom']
           }));
        } else {
          _items = List<Map<String, dynamic>>.from(widget.rfq!['items']);
        }
      }
    } catch (e) {
      debugPrint("Error initializing RFQ: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateRfqNumber() async {
    if (_branchId == null || _companyId == null) return;
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_RFQ', 
      branchId: _branchId,
      previewOnly: true,
    );
    setState(() => _rfqNumber = nextNum);
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
             'uom': item['uom'] ?? 'Unit',
           });
        }
      });
    }
  }
  
  void _editItem(int index) async {
    final item = _items[index];
    final descController = TextEditingController(text: item['description'] ?? '');
    final uomController = TextEditingController(text: item['uom'] ?? 'Unit');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Item: ${item['name']}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Description / Notes")),
            const SizedBox(height: 12),
            TextField(controller: uomController, decoration: const InputDecoration(labelText: "Unit of Measure (UOM)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items[index]['description'] = descController.text;
                _items[index]['uom'] = uomController.text;
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
    });
  }

  void _saveRfq() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one item")));
      return;
    }
    // Vendor is optional for RFQ sometimes, but let's enforce or assume usually selected? 
    // Schema has vendor_id as nullable: vendor_id uuid references public.vendors(id),
    // Let's allow saving without vendor if it's a general RFQ, but usually we select one. 
    // I'll make it optional but warn? No, let's keep it consistent. Optional is fine.

    setState(() => _loading = true);
    try {
      final rfqData = {
        'company_id': _companyId,
        'vendor_id': _vendorId, // Can be null
        'rfq_number': _rfqNumber,
        'date': _rfqDate.toIso8601String(),
        'status': _status,
        'notes': _notes,
      };
      
      Map<String, dynamic> upsertedRfq;
      
      if (widget.rfq != null) {
        upsertedRfq = await Supabase.instance.client.from('purchase_rfqs').update(rfqData).eq('id', widget.rfq!['id']).select().single();
        await Supabase.instance.client.from('purchase_rfq_items').delete().eq('rfq_id', widget.rfq!['id']);
      } else {
         _rfqNumber = await NumberingService.getNextDocumentNumber(companyId: _companyId!, documentType: 'PURCHASE_RFQ', branchId: _branchId);
         rfqData['rfq_number'] = _rfqNumber;
         upsertedRfq = await Supabase.instance.client.from('purchase_rfqs').insert(rfqData).select().single();
      }
      
      final rfqId = upsertedRfq['id'];
      final itemsToInsert = _items.map((item) => {
        'rfq_id': rfqId,
        'item_id': item['item_id'],
        'description': item['description'] ?? item['name'],
        'quantity': item['quantity'],
        'uom': item['uom'],
      }).toList();
      
      await Supabase.instance.client.from('purchase_rfq_items').insert(itemsToInsert);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RFQ Saved Successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving RFQ: $e"), backgroundColor: Colors.red));
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
        title: Text(widget.rfq == null ? "New RFQ" : "Edit RFQ", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
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
        _buildSectionTitle("Vendor (Optional)"),
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
                      Text(_vendorName ?? "Select Vendor (Optional)", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _vendorName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
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
              child: _buildInfoCard("RFQ Date", DateFormat('dd MMM, yyyy').format(_rfqDate), Icons.calendar_today_rounded, () async {
                final d = await showCustomCalendarSheet(
                   context: context, 
                   initialDate: _rfqDate, 
                   title: "Select RFQ Date"
                );
                if (d != null) setState(() => _rfqDate = d);
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
            _buildSectionTitle("Requested Items"),
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
                 Icon(Icons.checklist_rtl_rounded, size: 48, color: context.textSecondary.withOpacity(0.2)),
                 const SizedBox(height: 8),
                 Text("No items queried", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
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
                      if (item['description'] != null && item['description'].isNotEmpty) Text(item['description'], style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                      Text("Tap to edit details", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: AppColors.primaryBlue)),
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
                const SizedBox(width: 16),
                Text(item['uom'] ?? 'Unit', style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
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
          IconButton(onPressed: () { if(qty > 1) { setState(() => _items[index]['quantity'] = qty - 1); } }, icon: const Icon(Icons.remove_rounded, size: 18)),
          Text("$qty", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          IconButton(onPressed: () { setState(() => _items[index]['quantity'] = qty + 1); }, icon: const Icon(Icons.add_rounded, size: 18)),
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
          maxLines: 3,
          decoration: InputDecoration(
            labelText: "Additional Notes or Instructions",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: context.cardBg,
          ),
          onChanged: (v) => _notes = v,
        ),
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
          onPressed: _loading ? null : _saveRfq,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: const Text("Save Request For Quotation", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
