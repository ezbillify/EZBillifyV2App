import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import 'package:animate_do/animate_do.dart';
import '../inventory/item_form_sheet.dart';
import 'scanner_modal_content.dart';
import 'invoice_form_screen.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';
import '../../widgets/calendar_sheet.dart';

class DeliveryChallanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? challan; // Null for new
  const DeliveryChallanFormScreen({super.key, this.challan});

  @override
  State<DeliveryChallanFormScreen> createState() => _DeliveryChallanFormScreenState();
}

class _DeliveryChallanFormScreenState extends State<DeliveryChallanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _internalUserId;
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _challanDate = DateTime.now();
  String _challanNumber = "";
  String _status = "draft";
  String _vehicleNumber = "";
  String _transportMode = "Road";
  
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
      _internalUserId = profile['id'];
      
      if (widget.challan == null || widget.challan!['id'] == null) {
        // Handle potential pre-filled data (e.g. from Order)
        if (widget.challan != null) {
           _customerId = widget.challan!['customer_id']?.toString();
           _customerName = widget.challan!['customer_name'];
           _branchId = widget.challan!['branch_id']?.toString();
           _items = List<Map<String, dynamic>>.from(widget.challan!['items'] ?? []);
        }

        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty && _branchId == null) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        } else if (_branchId != null) {
          _branchName = branches.firstWhere((b) => b['id'].toString() == _branchId)['name'];
        }
        await _generateChallanNumber();
      } else {
        // Load existing challan
        _challanNumber = widget.challan!['dc_number'] ?? widget.challan!['challan_number'] ?? '';
        _branchId = widget.challan!['branch_id']?.toString();
        _branchName = widget.challan!['branch']?['name'];
        _customerId = widget.challan!['customer_id']?.toString();
        _customerName = widget.challan!['customer']?['name'];
        _challanDate = DateTime.parse(widget.challan!['date'] ?? widget.challan!['challan_date'] ?? DateTime.now().toIso8601String());
        _status = widget.challan!['status'] ?? 'draft';
        
        final shipping = widget.challan!['shipping_details'] ?? {};
        _vehicleNumber = shipping['vehicle_no'] ?? widget.challan!['vehicle_number'] ?? "";
        _transportMode = shipping['mode'] ?? widget.challan!['transport_mode'] ?? "Road";
        
        // Fetch items
        final items = await Supabase.instance.client.from('sales_dc_items')
            .select('*, item:items(name, uom, default_sales_price)')
            .eq('dc_id', widget.challan!['id']);
        
        _items = List<Map<String, dynamic>>.from(items.map((i) {
          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': i['item']?['name'] ?? 'Item',
            'quantity': (i['quantity'] is num) ? (i['quantity'] as num).toDouble() : (double.tryParse(i['quantity']?.toString() ?? '0') ?? 0),
            'unit_price': (i['item']?['default_sales_price'] is num) ? (i['item']['default_sales_price'] as num).toDouble() : 0.0,
            'unit': i['item']?['uom'],
          };
        }));
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateChallanNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'DELIVERY_CHALLAN',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _challanNumber = nextNum);
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
            Text(widget.challan == null || widget.challan!['id'] == null ? "New Delivery Challan" : "Edit Challan", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_challanNumber.isEmpty ? "Generating ID..." : _challanNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          if (widget.challan != null && widget.challan!['id'] != null)
             TextButton.icon(
               onPressed: _convertToInvoice,
               icon: const Icon(Icons.receipt_long, size: 16),
               label: const Text("Invoice"),
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
                    _buildLogisticsSection(),
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
        'challan_id': widget.challan!['id'],
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
        _buildInfoCard("Challan Date", DateFormat('dd MMM, yyyy').format(_challanDate), Icons.calendar_today_rounded, _selectDate),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionTitle("Items to Dispatch"),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_circle_outline_rounded, size: 20), label: const Text("Add Item"))
        ]),
        const SizedBox(height: 8),
        if (_items.isEmpty)
           Container(
             width: double.infinity, padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
             child: Column(children: [
                Icon(Icons.local_shipping_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text("Scan or add items to dispatch", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5))),
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
                   Expanded(child: Text(item['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary))),
                   Row(children: [
                     IconButton(onPressed: () { if((item['quantity']??1) > 1) setState(() => item['quantity']--); }, icon: const Icon(Icons.remove_circle_outline_rounded)),
                     Text("${item['quantity']}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                     IconButton(onPressed: () => setState(() => item['quantity']++), icon: const Icon(Icons.add_circle_outline_rounded)),
                   ]),
                   IconButton(onPressed: () => setState(() => _items.removeAt(index)), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                ]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLogisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Logistics Details"),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _vehicleNumber,
          decoration: InputDecoration(labelText: "Vehicle Number", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), prefixIcon: const Icon(Icons.commute), filled: true, fillColor: context.cardBg),
          onChanged: (v) => _vehicleNumber = v,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _transportMode,
          decoration: InputDecoration(labelText: "Transport Mode", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
          items: ["Road", "Rail", "Air", "Sea", "Hand Delivery"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => setState(() => _transportMode = v!),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity, height: 54,
        child: ElevatedButton(
          onPressed: _loading ? null : _saveChallan,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: Text(widget.challan == null || widget.challan!['id'] == null ? "Create Challan" : "Update Challan", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
        width: double.infinity,
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
      onSelect: (b) => setState(() { _branchId = b['id'].toString(); _branchName = b['name']; _generateChallanNumber(); }),
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
     _showSelectionSheet<Map<String, dynamic>>(
       title: "Dispatch Items", 
       items: List<Map<String, dynamic>>.from(results), 
       labelMapper: (i) {
         final price = (i['default_sales_price'] ?? 0).toDouble();
         return "${i['name']} (₹${price.toStringAsFixed(2)})";
       },
       isMultiple: true, 
       showScanner: true,
       onRefresh: () async {
         await MasterDataService().getItems(_companyId!, forceRefresh: true);
       },
       onSelectMultiple: (selectedList) {
         setState(() {
            for(var item in selectedList) {
               _items.add({
                 'item_id': item['id'],
                 'name': item['name'],
                 'quantity': 1,
                 'unit_price': double.parse(((item['default_sales_price'] ?? 0).toDouble()).toStringAsFixed(2)),
                 'unit': item['uom'],
               });
            }
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
    bool showScanner = false,
    String Function(T)? barcodeMapper,
    Future<void> Function()? onRefresh,
  }) {
    String searchQuery = "";
    bool isRefreshing = false;
    final searchController = TextEditingController();
    final focusNode = FocusNode();
    List<T> selectedItems = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<T> filteredItems = items.where((item) {
            final label = labelMapper(item).toLowerCase();
            return label.contains(searchQuery.toLowerCase());
          }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
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
                            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
                      child: TextField(
                        controller: searchController,
                        onChanged: (v) => setModalState(() => searchQuery = v),
                        decoration: InputDecoration(
                          hintText: "Search...",
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final label = labelMapper(item);
                        final isSelected = isMultiple ? selectedItems.contains(item) : currentValue == label;
                        return ListTile(
                          title: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null,
                          onTap: () {
                            if (isMultiple) {
                              setModalState(() => selectedItems.contains(item) ? selectedItems.remove(item) : selectedItems.add(item));
                            } else {
                              onSelect?.call(item);
                              Navigator.pop(context);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  if (isMultiple)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: selectedItems.isEmpty ? null : () {
                            onSelectMultiple?.call(selectedItems);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: Text("Add Selected (${selectedItems.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate() async {
    final p = await showCustomCalendarSheet(
      context: context,
      initialDate: _challanDate,
      title: "Select Challan Date",
    );
    if (p != null) setState(() => _challanDate = p);
  }

  Future<void> _saveChallan() async {
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select customer"))); return; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add items"))); return; }
    
    setState(() => _loading = true);
    try {
      final challanData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'dc_number': _challanNumber,
        'date': _challanDate.toIso8601String(),
        'shipping_details': {
          'vehicle_no': _vehicleNumber,
          'mode': _transportMode,
        },
        'status': _status,
        'created_by': _internalUserId,
      };

      if (widget.challan == null || widget.challan!['id'] == null) {
        // Consume actual number on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'DELIVERY_CHALLAN',
          branchId: _branchId,
          previewOnly: false,
        );
        challanData['dc_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_delivery_challans').insert(challanData).select().single();
        for (var item in _items) {
            await Supabase.instance.client.from('sales_dc_items').insert({
              'dc_id': inserted['id'],
              'item_id': item['item_id'],
              'quantity': item['quantity'],
            });
        }
      } else {
        await Supabase.instance.client.from('sales_delivery_challans').update(challanData).eq('id', widget.challan!['id']);
        await Supabase.instance.client.from('sales_dc_items').delete().eq('dc_id', widget.challan!['id']);
        for (var item in _items) {
            await Supabase.instance.client.from('sales_dc_items').insert({
              'dc_id': widget.challan!['id'],
              'item_id': item['item_id'],
              'quantity': item['quantity'],
            });
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving challan: $e");
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }
}
