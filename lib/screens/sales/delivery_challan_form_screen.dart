
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/sales_refresh_service.dart';
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
  String? _soId;
  
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
           _soId = (widget.challan!['order_id'] ?? widget.challan!['so_id'])?.toString();
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
        _soId = (widget.challan!['so_id'] ?? widget.challan!['order_id'])?.toString();
        
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
          decoration: const InputDecoration(labelText: "Vehicle Number", prefixIcon: Icon(Icons.commute)),
          onChanged: (v) => _vehicleNumber = v,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _transportMode,
          decoration: const InputDecoration(labelText: "Transport Mode"),
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
      barcodeMapper: (c) => "", // Added missing required property or optional property to match signature safely. 
      onRefresh: () async {
        await MasterDataService().getCustomers(_companyId!, forceRefresh: true);
      },
    );
  }

  Future<void> _addItem() async {
     final results = await MasterDataService().getItems(_companyId!);
     if(!mounted) return;

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
       title: "Dispatch Items", 
       items: List<Map<String, dynamic>>.from(results), 
       currentValues: currentValues,
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

           // Sync existing items and remove unselected
           _items.removeWhere((existing) => !qtyMap.containsKey(existing['item_id'].toString()));

           // Update quantities for still existing
           for (var itemEntry in _items) {
             final id = itemEntry['item_id'].toString();
             itemEntry['quantity'] = qtyMap[id]?.toDouble() ?? 1.0;
             qtyMap.remove(id);
           }

           // Add new fully
           for (var id in qtyMap.keys) {
             final item = itemMap[id]!;
             final qty = qtyMap[id]!;
             final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
             final mrp = (item['default_sales_price'] ?? 0).toDouble();
             final inclusivePrice = double.parse((mrp * (1 + rate / 100)).toStringAsFixed(2));

             _items.add({
               'item_id': item['id'],
               'name': item['name'],
               'quantity': qty.toDouble(),
               'unit_price': inclusivePrice,
               'tax_rate': rate,
               'unit': item['uom'] ?? 'unt',
             });
           }
         });
       },
       itemContentBuilder: (context, item, count, onAdd, onRemove) {
        final salesPrice = (item['default_sales_price'] ?? 0).toDouble();
        final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
        final salesPriceInclTax = salesPrice * (1 + rate / 100);
        final itemMrp = salesPriceInclTax; // Defaulting MRP to tax inclusive sales price
        final unit = item['uom'] ?? 'unt';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: count > 0 ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: count > 0 ? AppColors.primaryBlue : context.borderColor.withOpacity(0.5), width: 1),
                ),
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
                         Wrap(
                           spacing: 8,
                           runSpacing: 4,
                           children: [
                             Text("MRP: ₹${itemMrp.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500)),
                             Text("Rate: ₹${salesPriceInclTax.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text("Pur: ₹${(item['default_purchase_price'] ?? 0).toStringAsFixed(2)} • $unit • ${rate.toStringAsFixed(0)}% Tax", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary.withOpacity(0.7))),
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
        ),
      );
    },
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
    Widget Function(BuildContext, T, int count, VoidCallback onAdd, VoidCallback onRemove)? itemContentBuilder,
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
                                          StatusService.show(context, "Data synchronized! Please reopen to see changes.");
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
                              filled: false,
                              hintText: "Search...",
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

                        if (itemContentBuilder != null) {
                          return itemContentBuilder(
                            context,
                            item,
                            count,
                            () {
                              if (isMultiple) {
                                setModalState(() => selectedItems.add(item));
                              } else {
                                onSelect?.call(item);
                                Navigator.pop(context);
                              }
                            },
                            () {
                              if (isMultiple && count > 0) {
                                setModalState(() => selectedItems.remove(item));
                              }
                            },
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            trailing: isMultiple && isSelected 
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                                  child: Text("x$count", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ) 
                              : (isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null),
                            onTap: () {
                              if (isMultiple) {
                                setModalState(() => selectedItems.add(item));
                              } else {
                                onSelect?.call(item);
                                Navigator.pop(context);
                              }
                            },
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
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
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
    if (_customerId == null) { StatusService.show(context, "Select customer"); return; }
    if (_items.isEmpty) { StatusService.show(context, "Add items"); return; }
    
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
        'so_id': _soId,
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
      SalesRefreshService.triggerRefresh();
      
      // Update source Order status
      if (_soId != null) {
        try {
          await Supabase.instance.client.from('sales_orders').update({'status': 'shipped'}).eq('id', _soId!);
        } catch (e) {
          debugPrint("Error updating order status: $e");
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
