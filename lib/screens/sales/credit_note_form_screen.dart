import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../inventory/item_form_sheet.dart';
import 'scanner_modal_content.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';

class CreditNoteFormScreen extends StatefulWidget {
  final Map<String, dynamic>? creditNote; // Null for new
  const CreditNoteFormScreen({super.key, this.creditNote});

  @override
  State<CreditNoteFormScreen> createState() => _CreditNoteFormScreenState();
}

class _CreditNoteFormScreenState extends State<CreditNoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _internalUserId;
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _creditNoteDate = DateTime.now();
  String _creditNoteNumber = "";
  String _reason = "";
  
  // Line Items (Returned)
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
      
      if (widget.creditNote == null) {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateCreditNoteNumber();
      } else {
        // Load existing Credit Note data
        _creditNoteNumber = widget.creditNote!['cn_number'] ?? widget.creditNote!['credit_note_number'] ?? '';
        _branchId = widget.creditNote!['branch_id']?.toString();
        _branchName = widget.creditNote!['branch']?['name'];
        _customerId = widget.creditNote!['customer_id']?.toString();
        _customerName = widget.creditNote!['customer']?['name'];
        _creditNoteDate = DateTime.parse(widget.creditNote!['date'] ?? widget.creditNote!['credit_note_date'] ?? DateTime.now().toIso8601String());
        _reason = widget.creditNote!['reason'] ?? "";
        
        // Fetch items
        final items = await Supabase.instance.client.from('sales_credit_note_items')
            .select('*, item:items(name, unit, default_sales_price, default_purchase_price)')
            .eq('cn_id', widget.creditNote!['id']);
        
        _items = items.map((i) => {
          'item_id': i['item_id'],
          'name': i['item']['name'],
          'quantity': i['quantity'],
          'unit_price': i['unit_price'],
          'tax_rate': i['tax_rate'],
          'unit': i['item']['unit'],
          'purchase_price': i['item']['default_purchase_price'],
        }).toList();

        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateCreditNoteNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'CREDIT_NOTE',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _creditNoteNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble(); // Inclusive
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final totalInclusive = qty * price;
      // Back calculate base
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;
      
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
            Text(widget.creditNote == null ? "New Credit Note" : "Edit Credit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_creditNoteNumber.isEmpty ? "Generating ID..." : _creditNoteNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
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
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.red),
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
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_pin_rounded, color: Colors.red, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Text(_customerName ?? "Select Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _customerName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary))),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoCard("Credit Note Date", DateFormat('dd MMM, yyyy').format(_creditNoteDate), Icons.calendar_today_rounded, () async {
           final p = await showDatePicker(context: context, initialDate: _creditNoteDate, firstDate: DateTime(2000), lastDate: DateTime.now());
           if(p!=null) setState(()=>_creditNoteDate=p);
        }),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _reason,
          style: const TextStyle(fontFamily: 'Outfit'),
          decoration: InputDecoration(
            labelText: "Reason for Return", 
            hintText: "e.g. Damaged goods, Wrong item sent",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), 
            filled: true, 
            fillColor: context.cardBg
          ),
          onChanged: (v) => _reason = v,
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionTitle("Returned Items"),
          TextButton.icon(
            onPressed: _addItem, 
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20), 
            label: const Text("Add Item", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.red))
          )
        ]),
        const SizedBox(height: 8),
        if (_items.isEmpty)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(32),
             decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.borderColor)),
             child: Column(children: [
                Icon(Icons.assignment_return_outlined, size: 48, color: context.textSecondary.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text("No returned items added", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5))),
             ]),
           )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
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
                   Row(
                     children: [
                       IconButton(onPressed: () { if((item['quantity']??1) > 1) { setState(() { item['quantity']--; _calculateTotals(); }); } }, icon: const Icon(Icons.remove_circle_outline_rounded, size: 22)),
                       Text("${item['quantity']}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                       IconButton(onPressed: () { setState(() { item['quantity']++; _calculateTotals(); }); }, icon: const Icon(Icons.add_circle_outline_rounded, size: 22)),
                     ],
                   ),
                   const SizedBox(width: 8),
                   IconButton(onPressed: () => setState(() { _items.removeAt(index); _calculateTotals(); }), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22)),
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
       decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.withOpacity(0.1))),
       child: Column(children: [
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal", style: TextStyle(fontFamily: 'Outfit')), Text("₹${_subtotal.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))]),
         const SizedBox(height: 8),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Tax", style: TextStyle(fontFamily: 'Outfit')), Text("₹${_totalTax.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))]),
         const Divider(height: 32),
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Refund Amount", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)), Text("₹${_totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 22, color: Colors.red))]),
       ]),
     );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _loading ? null : _saveCreditNote,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: const Text("Save & Issue Credit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        ),
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
                 Icon(icon, size: 14, color: Colors.red),
                 const SizedBox(width: 8),
                 Text(value, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary)),
               ],
             ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectBranch() async {
    final results = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if(!mounted) return;
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Branch", items: List<Map<String, dynamic>>.from(results), labelMapper: (b) => b['name'],
      onSelect: (b) => setState(() { _branchId = b['id'].toString(); _branchName = b['name']; _generateCreditNoteNumber(); }),
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
       title: "Add Items to Return",
       items: List<Map<String, dynamic>>.from(results),
       labelMapper: (i) {
         final rate = (i['tax_rate']?['rate'] ?? 0).toDouble();
         final mrp = (i['default_sales_price'] ?? 0).toDouble();
         final inclusive = mrp * (1 + rate / 100);
         return "${i['name']} (₹${inclusive.toStringAsFixed(2)})";
       },
       isMultiple: true,
       showScanner: true,
       onRefresh: () async {
         await MasterDataService().getItems(_companyId!, forceRefresh: true);
       },
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

            for(var id in consolidated.keys) {
               final item = consolidated[id]!;
               final qty = qtyMap[id]!;
               final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
               final mrp = (item['default_sales_price'] ?? 0).toDouble();
               final inclusive = double.parse((mrp * (1 + rate / 100)).toStringAsFixed(2));
               
               final existingIndex = _items.indexWhere((element) => element['item_id'] == id);
               if (existingIndex != -1) {
                  _items[existingIndex]['quantity'] = (_items[existingIndex]['quantity'] as num) + qty;
               } else {
                  _items.add({
                    'item_id': id,
                    'name': item['name'],
                    'quantity': qty,
                    'unit_price': inclusive,
                    'tax_rate': rate,
                    'unit': item['unit'],
                    'purchase_price': (item['purchase_price'] ?? 0).toDouble(),
                  });
               }
            }
            _calculateTotals();
         });
       },
       itemContentBuilder: (context, item, count, onAdd, onRemove) {
        final itemMrp = (item['mrp'] ?? 0).toDouble();
        final salesPrice = (item['default_sales_price'] ?? 0).toDouble();
        final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
        final salesPriceInclTax = salesPrice * (1 + rate / 100);
        final purchasePrice = (item['default_purchase_price'] ?? 0).toDouble();
        final unit = item['unit'] ?? 'unt';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.red.withOpacity(0.05) : context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: count > 0 ? Colors.red : context.borderColor),
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
                     decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                     child: const Icon(Icons.assignment_return_outlined, color: Colors.red),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(item['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                         Wrap(
                           spacing: 8,
                           runSpacing: 4,
                           children: [
                             Text("MRP: ₹${itemMrp.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500)),
                             Text("Rate: ₹${salesPriceInclTax.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text("Pur: ₹${purchasePrice.toStringAsFixed(2)} • $unit • ${rate.toStringAsFixed(0)}% Tax", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary.withOpacity(0.7))),
                       ],
                     ),
                   ),
                   if (count > 0)
                     Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20)),
                          Text("$count", style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Colors.red, size: 20)),
                        ],
                     )
                   else
                     const Icon(Icons.add_circle_outline_rounded, color: Colors.red, size: 28),
                ],
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
                  sheetController.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
              }
            });
          }

          final filteredItems = items.where((item) {
            final label = labelMapper(item).toLowerCase();
            final search = searchQuery.toLowerCase();
            final barcode = barcodeMapper?.call(item).toLowerCase() ?? "";
            return label.contains(search) || barcode.contains(search);
          }).toList();

          return DraggableScrollableSheet(
            controller: sheetController,
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                   // Header with Search
                   Container(
                     padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                     child: Column(
                       children: [
                         Container(width: 40, height: 4, decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
                         const SizedBox(height: 20),
                         Row(
                           children: [
                             Expanded(
                               child: AnimatedContainer(
                                 duration: const Duration(milliseconds: 200),
                                 height: 50,
                                 decoration: BoxDecoration(
                                   color: focusNode.hasFocus ? Colors.red.withOpacity(0.05) : context.cardBg,
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: focusNode.hasFocus ? Colors.red : context.borderColor),
                                 ),
                                 child: TextField(
                                   controller: searchController,
                                   focusNode: focusNode,
                                   decoration: InputDecoration(
                                     hintText: "Search...",
                                     prefixIcon: Icon(Icons.search, color: focusNode.hasFocus ? Colors.red : context.textSecondary),
                                     border: InputBorder.none,
                                     contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                   ),
                                   onChanged: (v) => setModalState(() => searchQuery = v),
                                 ),
                               ),
                             ),
                             if (showScanner) ...[
                               const SizedBox(width: 12),
                               InkWell(
                                 onTap: () => _openScanner<T>(
                                   allItems: filteredItems,
                                   selectedItems: selectedItems,
                                   onSelectionChanged: (newList) {
                                     setModalState(() {
                                       selectedItems.clear();
                                       selectedItems.addAll(newList);
                                     });
                                   },
                                   onConfirm: () {
                                     onSelectMultiple?.call(selectedItems);
                                     Navigator.pop(context); // Close selection sheet too
                                   },
                                   barcodeMapper: (item) {
                                      if (item is Map) {
                                        final barcodes = List<String>.from(item['barcodes'] ?? []);
                                        return barcodes.isNotEmpty ? barcodes.first : (item['sku']?.toString());
                                      }
                                      return null;
                                   },
                                   labelMapper: labelMapper,
                                   isMultiple: isMultiple,
                                 ),
                                 child: Container(
                                   height: 50, width: 50,
                                   decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                                   child: const Icon(Icons.barcode_reader, color: Colors.white),
                                 ),
                               ),
                             ]
                           ],
                         ),
                       ],
                     ),
                   ),
                   // List
                   Expanded(
                     child: ListView.builder(
                       controller: scrollController,
                       padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                       itemCount: filteredItems.length,
                       itemBuilder: (context, index) {
                         final item = filteredItems[index];
                         final label = labelMapper(item);
                         
                         if (itemContentBuilder != null) {
                           final count = selectedItems.where((i) => i == item).length;
                           return itemContentBuilder(context, item, count, () {
                             setModalState(() => selectedItems.add(item));
                           }, () {
                             setModalState(() => selectedItems.remove(item));
                           });
                         }

                         final isSelected = isMultiple ? selectedItems.contains(item) : currentValue == label;
                         return ListTile(
                           title: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                           trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.red) : null,
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
                   // Footer button for Multiple
                   if (isMultiple)
                     Padding(
                       padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                       child: SizedBox(
                         width: double.infinity,
                         height: 54,
                         child: ElevatedButton(
                           onPressed: selectedItems.isEmpty ? null : () {
                             onSelectMultiple?.call(selectedItems);
                             Navigator.pop(context);
                           },
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                           child: Text("Add Returned Items (${selectedItems.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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


  Future<void> _saveCreditNote() async {
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select customer"))); return; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add returned items"))); return; }
    
    setState(() => _loading = true);
    try {
       final cnData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'cn_number': _creditNoteNumber,
        'date': _creditNoteDate.toIso8601String(),
        'reason': _reason,
        'sub_total': _subtotal,
        'tax_total': _totalTax,
        'total_amount': _totalAmount,
        'status': 'open',
        'created_by': _internalUserId,
      };
      
      if (widget.creditNote == null) {
        // Consume actual number on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'CREDIT_NOTE',
          branchId: _branchId,
          previewOnly: false,
        );
        cnData['cn_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_credit_notes').insert(cnData).select().single();
        for (var item in _items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;
          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

             await Supabase.instance.client.from('sales_credit_note_items').insert({
               'cn_id': inserted['id'],
              'item_id': item['item_id'],
              'description': item['name'],
              'quantity': item['quantity'],
              'unit_price': item['unit_price'],
              'tax_rate': item['tax_rate'],
              'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
              'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
            });
        }
      } else {
        await Supabase.instance.client.from('sales_credit_notes').update(cnData).eq('id', widget.creditNote!['id']);
        await Supabase.instance.client.from('sales_credit_note_items').delete().eq('cn_id', widget.creditNote!['id']);
        for (var item in _items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;
          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

            await Supabase.instance.client.from('sales_credit_note_items').insert({
              'cn_id': widget.creditNote!['id'],
              'item_id': item['item_id'],
              'description': item['name'],
              'quantity': item['quantity'],
              'unit_price': item['unit_price'],
              'tax_rate': item['tax_rate'],
              'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
              'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
            });
        }
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving CN: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }
}
