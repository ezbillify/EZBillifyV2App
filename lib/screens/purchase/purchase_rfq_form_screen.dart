
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import '../inventory/item_selection_sheet.dart';
import 'vendors_screen.dart';
import '../../widgets/calendar_sheet.dart';
import '../../services/master_data_service.dart';

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
        if (_branchId != null) {
          final b = await Supabase.instance.client.from('branches').select('name').eq('id', _branchId!).maybeSingle();
          if (b != null) _branchName = b['name'];
        }

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
      labelMapper: (i) => i['name'],
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
            itemEntry['quantity'] = qtyMap[id]?.toDouble() ?? 1.0;
            qtyMap.remove(id); 
          }

          for (var id in qtyMap.keys) {
            final item = itemMap[id]!;
            final qty = qtyMap[id]!;
            
            _items.add({
              'item_id': item['id'],
              'name': item['name'],
              'quantity': qty.toDouble(),
              'uom': item['uom'] ?? 'Unit',
            });
          }
        });
      },
      showScanner: true,
      itemContentBuilder: (context, item, count, onAdd, onRemove) {
        final unit = item['uom'] ?? 'Unit';

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
                             Text("Stock: ${item['total_stock'] ?? 0}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: (item['total_stock'] ?? 0) <= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                             const SizedBox(width: 8),
                             Text("• $unit", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                           ],
                         ),
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
    final searchController = TextEditingController();
    final focusNode = FocusNode();
    List<T> selectedItems = currentValues != null ? List<T>.from(currentValues) : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final List<T> filteredItems = items.where((item) {
            final label = labelMapper(item).toLowerCase();
            final barcode = barcodeMapper?.call(item)?.toLowerCase() ?? "";
            return label.contains(searchQuery.toLowerCase()) || barcode.contains(searchQuery.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
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
                      if (onRefresh != null)
                        IconButton(onPressed: () async { await onRefresh(); Navigator.pop(context); }, icon: const Icon(Icons.sync_rounded)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: searchController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      filled: false,
                      hintText: "Search...",
                                 border: InputBorder.none,
                                 enabledBorder: InputBorder.none,
                                 focusedBorder: InputBorder.none,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setModalState(() => searchQuery = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final count = selectedItems.where((e) => e == item).length;
                      if (itemContentBuilder != null) {
                        return itemContentBuilder(context, item, count, 
                          () => setModalState(() => selectedItems.add(item)),
                          () => setModalState(() => selectedItems.remove(item))
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: count > 0 ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              if (isMultiple) {
                                setModalState(() {
                                  if (selectedItems.contains(item)) selectedItems.remove(item);
                                  else selectedItems.add(item);
                                });
                              } else {
                                onSelect?.call(item);
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: count > 0 ? AppColors.primaryBlue : context.borderColor.withOpacity(0.5), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(labelMapper(item), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary))),
                                  if (isMultiple)
                                    Checkbox(
                                      value: selectedItems.contains(item),
                                      onChanged: (v) {
                                        setModalState(() {
                                          if (v == true) selectedItems.add(item);
                                          else selectedItems.remove(item);
                                        });
                                      },
                                      activeColor: AppColors.primaryBlue,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    )
                                  else if (count > 0)
                                    const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue)
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (isMultiple)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(width: double.infinity, height: 54, 
                      child: ElevatedButton(
                        onPressed: () { onSelectMultiple?.call(selectedItems); Navigator.pop(context); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text("Confirm Selection (${selectedItems.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    ),
                  ),
              ],
            ),
          );
        }
      ),
    );
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
      StatusService.show(context, "Please add at least one item");
      return;
    }
    // Vendor is optional for RFQ sometimes, but let's enforce or assume usually selected? 
    // Schema has vendor_id as nullable: vendor_id uuid references public.vendors(id),
    // Let's allow saving without vendor if it's a general RFQ, but usually we select one. 
    // I'll make it optional but warn? No, let's keep it consistent. Optional is fine.

    setState(() => _loading = true);
    try {
      final rfqData = <String, dynamic>{
        'company_id': _companyId,
        'branch_id': _branchId,
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
      final itemsToInsert = _items.map((item) => <String, dynamic>{
        'rfq_id': rfqId,
        'item_id': item['item_id'],
        'description': item['description'] ?? item['name'],
        'quantity': item['quantity'],
        'uom': item['uom'],
      }).toList();
      
      await Supabase.instance.client.from('purchase_rfq_items').insert(itemsToInsert);

      if (mounted) {
        Navigator.pop(context, true);
        StatusService.show(context, "RFQ Saved Successfully");
      }
    } catch (e) {
      if (mounted) {
        StatusService.show(context, "Error saving RFQ: $e", backgroundColor: Colors.red);
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
            Text(widget.rfq == null ? "New RFQ" : "Edit RFQ", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_rfqNumber.isEmpty ? "Generating ID..." : _rfqNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
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
        _buildSectionTitle("Branch"),
        const SizedBox(height: 12),
        _buildBranchSelector(),
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

  Widget _buildBranchSelector() {
    return InkWell(
      onTap: _selectBranch,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_branchName ?? "Select Branch", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _branchName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
              if (_branchName == null) Text("Tap to select branch", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBranch() async {
    final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if (!mounted) return;
    
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Branch",
      items: List<Map<String, dynamic>>.from(branches),
      labelMapper: (b) => b['name'],
      onSelect: (b) {
        setState(() {
          _branchId = b['id'].toString();
          _branchName = b['name'];
        });
        _generateRfqNumber();
      }
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
          decoration: const InputDecoration(
            labelText: "Additional Notes or Instructions",
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
