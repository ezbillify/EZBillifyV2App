
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import 'package:animate_do/animate_do.dart';
import '../../widgets/calendar_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../inventory/item_form_sheet.dart';
import 'scanner_modal_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/invoice_provider.dart';
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';
import '../../services/print_service.dart';
import '../../services/sales_refresh_service.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? invoice; // Null for new
  const InvoiceFormScreen({super.key, this.invoice});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Removed local _items and _companyId in favor of state but need to keep _companyId and _internalUserId for init
  String? _companyId;
  String? _internalUserId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    Future.microtask(() => ref.read(invoiceProvider.notifier).setLoading(true));
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('id, company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id']!; // Keep companyId local as it's used in many queries
      _internalUserId = profile['id'];
      
      final isEdit = widget.invoice != null && widget.invoice!['id'] != null;
      
      if (isEdit) {
        final invId = widget.invoice!['id'];
        final inv = await Supabase.instance.client
            .from('sales_invoices')
            .select('*, branch:branches(name), customer:customers(name)')
            .eq('id', invId)
            .single();
            
        final itemsRes = await Supabase.instance.client.from('sales_invoice_items')
            .select('*, item:items(name, uom, default_sales_price, default_purchase_price)')
            .eq('invoice_id', invId);

        final mappedItems = List<Map<String, dynamic>>.from(itemsRes.map((i) {
          final qty = i['quantity'];
          final up = i['unit_price'];
          final tr = i['tax_rate'];
          final pp = i['item']?['default_purchase_price'];

          return <String, dynamic>{
            'item_id': i['item_id'],
            'name': (i['item'] != null && i['item']['name'] != null) ? i['item']['name'] : (i['description'] ?? 'Item'),
            'quantity': (qty is num) ? qty.toDouble() : (double.tryParse(qty?.toString() ?? '0') ?? 0),
            'unit_price': (up is num) ? up.toDouble() : (double.tryParse(up?.toString() ?? '0') ?? 0.0),
            'tax_rate': (tr is num) ? tr.toDouble() : (double.tryParse(tr?.toString() ?? '0') ?? 0.0),
            'unit': i['item']?['uom'],
            'purchase_price': (pp is num) ? pp.toDouble() : (double.tryParse(pp?.toString() ?? '0') ?? 0.0),
          };
        }));

        final allocations = await Supabase.instance.client
            .from('sales_payment_allocations')
            .select('amount')
            .eq('invoice_id', invId);
        final existingPaid = (allocations as List).fold(0.0, (sum, a) => sum + (a['amount'] ?? 0));
        
        ref.read(invoiceProvider.notifier).setInitialData(
          companyId: _companyId!,
          internalUserId: _internalUserId!,
          branchId: inv['branch_id']?.toString(),
          branchName: inv['branch']?['name'],
          customerId: inv['customer_id']?.toString(),
          customerName: inv['customer']?['name'] ?? inv['customer_name'],
          invoiceDate: DateTime.tryParse(inv['date'] ?? inv['invoice_date'] ?? '') ?? DateTime.now(),
          dueDate: DateTime.tryParse(inv['due_date'] ?? '') ?? DateTime.now(),
          invoiceNumber: inv['invoice_number'] ?? '',
          items: mappedItems,
          existingPaid: existingPaid,
        );
      } else {
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        String? bId;
        String? bName;
        if (branches.isNotEmpty) {
          bId = branches[0]['id'].toString();
          bName = branches[0]['name'];
        }

        List<Map<String, dynamic>> initialItems = [];
        String? cId;
        String? cName;
        String? qId;
        String? oId;
        String? chId;

        if (widget.invoice != null) {
           if (widget.invoice!['items'] != null) {
              final rawItems = List<dynamic>.from(widget.invoice!['items']);
              initialItems = List<Map<String, dynamic>>.from(rawItems.map((it) {
                final qty = it['quantity'];
                final up = it['unit_price'];
                final tr = it['tax_rate'];
                final pp = it['purchase_price'];

                return <String, dynamic>{
                  'item_id': it['item_id'],
                  'name': it['name'] ?? it['item']?['name'] ?? 'Item',
                  'quantity': (qty is num) ? qty.toDouble() : (double.tryParse(qty?.toString() ?? '0') ?? 0),
                  'unit_price': (up is num) ? up.toDouble() : (double.tryParse(up?.toString() ?? '0') ?? 0.0),
                  'tax_rate': (tr is num) ? tr.toDouble() : (double.tryParse(tr?.toString() ?? '0') ?? 0.0),
                  'unit': it['unit'] ?? it['item']?['uom'],
                  'purchase_price': (pp is num) ? pp.toDouble() : (double.tryParse(pp?.toString() ?? '0') ?? 0.0),
                };
              }));
           }
           cId = widget.invoice!['customer_id']?.toString();
           cName = widget.invoice!['customer_name'] ?? widget.invoice!['customer']?['name'];
           
           if (widget.invoice!['branch_id'] != null) {
              bId = widget.invoice!['branch_id'].toString();
              final bMatch = branches.firstWhere((b) => b['id'].toString() == bId, orElse: () => {});
              if (bMatch.isNotEmpty) bName = bMatch['name'];
           }
           qId = (widget.invoice!['quotation_id'] ?? widget.invoice!['quote_id'])?.toString();
           oId = (widget.invoice!['order_id'] ?? widget.invoice!['so_id'])?.toString();
           chId = (widget.invoice!['challan_id'] ?? widget.invoice!['dc_id'])?.toString();
        }

        ref.read(invoiceProvider.notifier).setInitialData(
          companyId: _companyId!,
          internalUserId: _internalUserId!,
          branchId: bId,
          branchName: bName,
          customerId: cId,
          customerName: cName,
          quotationId: qId,
          orderId: oId,
          dcId: chId,
          items: initialItems,
        );
        
        await _generateInvoiceNumber();
      }
    } catch (e) {
      debugPrint("Error initializing invoice form: $e");
      if (mounted) {
        StatusService.show(context, "Error loading invoice: $e", backgroundColor: Colors.red);
      }
    } finally {
      ref.read(invoiceProvider.notifier).setLoading(false);
    }
  }


  Future<void> _generateInvoiceNumber() async {
    final state = ref.read(invoiceProvider);
    if (state.branchId == null || state.companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: state.companyId!,
      documentType: 'SALES_INVOICE',
      branchId: state.branchId,
      previewOnly: true,
    );
    
    ref.read(invoiceProvider.notifier).updateHeader(invoiceNumber: nextNum);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(invoiceProvider);
    
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.invoice == null ? "New Invoice" : "Edit Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(state.invoiceNumber.isEmpty ? "Generating ID..." : state.invoiceNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: state.loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(child: _buildHeaderSection()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
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
                    ),
                  ),
                  if (state.items.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverToBoxAdapter(
                        child: Container(
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
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildLineItemCard(state.items[index], index),
                          ),
                          childCount: state.items.length,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(child: _buildSummarySection()),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final state = ref.watch(invoiceProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("DOCUMENT NUMBER", style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryBlue.withOpacity(0.5))),
                Text(state.invoiceNumber.isEmpty ? "#---" : state.invoiceNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.orange),
                const SizedBox(width: 4),
                Text("DRAFT", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: context.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    final state = ref.watch(invoiceProvider);
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
                    Text(state.branchName ?? "Select Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
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
                      Text(state.customerName ?? "Select Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: state.customerName == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
                      if (state.customerName != null) Text("Click to change customer", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle("Dates & Settings"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Invoice Date", DateFormat('dd MMM, yyyy').format(state.invoiceDate), Icons.calendar_today_rounded, () => _selectDate(true)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Due Date", DateFormat('dd MMM, yyyy').format(state.dueDate), Icons.event_available_rounded, () => _selectDate(false)),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildItemsSection() {
    final state = ref.watch(invoiceProvider);
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
        if (state.items.isEmpty)
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
            itemCount: state.items.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = state.items[index];
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
                            Text("Unit Price: ₹${item['unit_price']}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
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
    final state = ref.watch(invoiceProvider);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1))),
          child: Column(
            children: [
              _buildSummaryRow("Subtotal", "₹${state.subtotal.toStringAsFixed(2)}"),
              const SizedBox(height: 12),
              _buildSummaryRow("Total Tax", "₹${state.totalTax.toStringAsFixed(2)}"),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              _buildSummaryRow("Grand Total", "₹${state.totalAmount.toStringAsFixed(2)}", isTotal: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }


  Widget _buildBottomBar() {
    final state = ref.watch(invoiceProvider);
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
                Text("₹${state.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: (state.loading || state.items.isEmpty) ? null : () => _showPaymentModal(shouldPrint: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.cardBg,
              foregroundColor: context.textPrimary,
              elevation: 0,
              side: BorderSide(color: context.borderColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text("Save", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (state.loading || state.items.isEmpty) ? null : () => _showPaymentModal(shouldPrint: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text("Save & Print", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPaymentModal({required bool shouldPrint}) {
    final state = ref.read(invoiceProvider);
    if (state.customerId == null) {
      StatusService.show(context, "Please select a customer first");
      return;
    }
    
    // Helper to format amount for display/input
    String formatAmount(double val) {
      if (val % 1 == 0) return val.toInt().toString();
      return val.toStringAsFixed(2);
    }

    final balanceDueNow = state.totalAmount - state.existingPaid;
    
    List<Map<String, dynamic>> payments = [
      {
        'mode': 'Cash', 
        'amount': balanceDueNow > 0 ? balanceDueNow : 0.0, 
        'controller': TextEditingController(text: formatAmount(balanceDueNow > 0 ? balanceDueNow : 0.0))
      }
    ];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double currentNewPaid = payments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
          double remainingBalance = state.totalAmount - state.existingPaid - currentNewPaid;

          return Container(
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Payment Details", style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TOTAL INVOICE VALUE", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue.withOpacity(0.5))),
                            const SizedBox(height: 4),
                            Text("₹${formatAmount(state.totalAmount)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                          ],
                        ),
                        if (remainingBalance != 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(remainingBalance > 0 ? "BALANCE DUE" : "REMAINING", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: remainingBalance > 0 ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5))),
                              const SizedBox(height: 4),
                              Text("₹${formatAmount(remainingBalance.abs())}", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: remainingBalance > 0 ? Colors.red : Colors.green)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Payments", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textSecondary)),
                  const SizedBox(height: 12),
                  ...payments.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () => _showModeSelectionSheet(context, (mode) => setModalState(() => p['mode'] = mode)),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(p['mode'], style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14))),
                                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primaryBlue),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: p['controller'],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: "₹ ",
                                prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                hintText: "0.00",
                              ),
                              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                              onChanged: (v) => setModalState(() {}),
                            ),
                          ),
                          if (payments.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: IconButton(
                                onPressed: () => setModalState(() {
                                  payments[idx]['controller'].dispose();
                                  payments.removeAt(idx);
                                }), 
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red)
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        double currentBalance = state.totalAmount - state.existingPaid - payments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
                        payments.add({
                          'mode': 'UPI', 
                          'amount': currentBalance > 0 ? currentBalance : 0.0,
                          'controller': TextEditingController(text: formatAmount(currentBalance > 0 ? currentBalance : 0.0))
                        });
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Text("Add Another Payment Mode", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalPayments = payments.map((p) => {
                          'mode': p['mode'],
                          'amount': double.tryParse(p['controller'].text) ?? 0.0
                        }).where((p) => (p['amount'] as double) > 0).toList();
                        
                        Navigator.pop(context);
                        _saveInvoiceWithPayments(payments: finalPayments, shouldPrint: shouldPrint);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        shouldPrint ? "Confirm & Print" : "Confirm & Save",
                        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveInvoiceWithPayments(payments: [], shouldPrint: shouldPrint);
                      },
                      child: Text("Save without Payment", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      // Dispose controllers after modal is closed
      for (var p in payments) {
        p['controller'].dispose();
      }
    });
  }

  void _showModeSelectionSheet(BuildContext context, Function(String) onSelect) {
    final modes = ["Cash", "UPI", "Card", "Bank Transfer", "Cheque", "Other"];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Select Payment Mode", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 16),
              ...modes.map((mode) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(_getPaymentIcon(mode), color: AppColors.primaryBlue, size: 20),
                ),
                title: Text(mode, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  onSelect(mode);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String mode) {
    switch (mode) {
      case 'Cash': return Icons.payments_rounded;
      case 'UPI': return Icons.qr_code_scanner_rounded;
      case 'Card': return Icons.credit_card_rounded;
      case 'Bank Transfer': return Icons.account_balance_rounded;
      case 'Cheque': return Icons.history_edu_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  Future<void> _saveInvoiceWithPayments({required List<Map<String, dynamic>> payments, required bool shouldPrint}) async {
     // We need to pass these to _saveInvoice
     await _saveInvoice(customPayments: payments, shouldPrint: shouldPrint);
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

  Widget _buildTextField(String label, String initialValue, IconData icon, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
      child: TextFormField(
        initialValue: initialValue,
        onChanged: onChanged,
        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary),
          border: InputBorder.none,
          icon: Icon(icon, size: 18, color: context.textSecondary),
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
    final state = ref.watch(invoiceProvider);
    final qty = state.items[index]['quantity'] ?? 1;
    return Container(
      decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () { 
              if(qty > 1) { 
                final newItems = List<Map<String, dynamic>>.from(state.items);
                newItems[index] = {...newItems[index], 'quantity': qty - 1};
                ref.read(invoiceProvider.notifier).setItems(newItems);
              } 
            }, 
            icon: const Icon(Icons.remove_rounded, size: 18)
          ),
          Text("$qty", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () { 
              final newItems = List<Map<String, dynamic>>.from(state.items);
              newItems[index] = {...newItems[index], 'quantity': qty + 1};
              ref.read(invoiceProvider.notifier).setItems(newItems);
            }, 
            icon: const Icon(Icons.add_rounded, size: 18)
          ),
        ],
      ),
    );
  }

  // Action Methods
  Future<void> _selectBranch() async {
    final state = ref.read(invoiceProvider);
    final results = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if (!mounted) return;

    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Branch",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (b) => b['name'],
      onSelect: (b) {
        ref.read(invoiceProvider.notifier).updateHeader(
          branchId: b['id'].toString(),
          branchName: b['name'],
        );
        _generateInvoiceNumber(); // Regenerate number for the new branch
      },
      currentValue: state.branchName,
    );
  }

  Future<void> _selectCustomer() async {
    final state = ref.read(invoiceProvider);
    final results = await MasterDataService().getCustomers(_companyId!);
    if(!mounted) return;
    
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Customer",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (c) => c['name'],
      onSelect: (c) {
        ref.read(invoiceProvider.notifier).updateHeader(
          customerId: c['id'].toString(),
          customerName: c['name'],
        );
      },
      currentValue: state.customerName,
      badgeMapper: (c) => c['customer_type'] ?? 'B2C',
      badgeColorMapper: (c) => (c['customer_type'] == 'B2B') ? Colors.purple : Colors.blue,
      onRefresh: () async {
        await MasterDataService().getCustomers(_companyId!, forceRefresh: true);
      },
    );
  }

  Future<void> _selectDate(bool isInvoiceDate) async {
    final state = ref.read(invoiceProvider);
    final picked = await showCustomCalendarSheet(
      context: context,
      initialDate: isInvoiceDate ? state.invoiceDate : state.dueDate,
      title: isInvoiceDate ? "Select Invoice Date" : "Select Due Date",
    );
    
    if (picked != null) {
      if (isInvoiceDate) {
        DateTime newDueDate = state.dueDate;
        if (state.dueDate.isBefore(picked)) {
          newDueDate = picked.add(const Duration(days: 7));
        }
        ref.read(invoiceProvider.notifier).updateHeader(
          invoiceDate: picked,
          dueDate: newDueDate,
        );
      } else {
        ref.read(invoiceProvider.notifier).updateHeader(dueDate: picked);
      }
    }
  }

  Future<void> _editItemPrice(int index) async {
    final state = ref.read(invoiceProvider);
    final item = state.items[index];
    final controller = TextEditingController(text: item['unit_price'].toString());
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 32, left: 24, right: 24, top: 24),
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
                decoration: const InputDecoration(
                  prefixText: "₹ ",
                  labelText: "New Unit Price",
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final newPrice = double.tryParse(controller.text) ?? item['unit_price'];
                    final newItems = List<Map<String, dynamic>>.from(state.items);
                    newItems[index] = {...newItems[index], 'unit_price': newPrice};
                    ref.read(invoiceProvider.notifier).setItems(newItems);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: const Text("Save Changes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _addItem() async {
    final state = ref.read(invoiceProvider);
    final results = await MasterDataService().getItems(_companyId!);
    if (!mounted) return;

    // Construct currentValues based on ALL items currently in the list
    // If an item has quantity > 1, add it multiple times to the list so the sheet shows correct count
    List<Map<String, dynamic>> currentValues = [];
    for (var i in state.items) {
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
      onRefresh: () async {
        await MasterDataService().getItems(_companyId!, forceRefresh: true);
      },
      onSelectMultiple: (selectedList) {
        final state = ref.read(invoiceProvider);
        final qtyMap = <String, int>{};
        final itemMap = <String, Map<String, dynamic>>{};
        
        for (var item in selectedList) {
          final id = item['id'].toString();
          qtyMap[id] = (qtyMap[id] ?? 0) + 1;
          itemMap[id] = item;
        }

        final currentItems = List<Map<String, dynamic>>.from(state.items);
        currentItems.removeWhere((existing) => !qtyMap.containsKey(existing['item_id'].toString()));

        for (var itemEntry in currentItems) {
          final id = itemEntry['item_id'].toString();
          itemEntry['quantity'] = qtyMap[id]?.toDouble();
          qtyMap.remove(id);
        }

        for (var id in qtyMap.keys) {
          final item = itemMap[id]!;
          final qty = qtyMap[id]!;
          final mrp = (item['default_sales_price'] ?? 0).toDouble();
          final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
          final inclusivePrice = double.parse((mrp * (1 + rate / 100)).toStringAsFixed(2));
          
          currentItems.add({
            'item_id': item['id'],
            'name': item['name'],
            'quantity': qty.toDouble(),
            'unit_price': inclusivePrice,
            'tax_rate': rate,
            'unit': item['uom'],
            'purchase_price': (item['default_purchase_price'] ?? 0).toDouble(),
          });
        }
        ref.read(invoiceProvider.notifier).setItems(currentItems);
      },
      showScanner: true,
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

  void _removeItem(int index) {
    final state = ref.read(invoiceProvider);
    final newItems = List<Map<String, dynamic>>.from(state.items);
    newItems.removeAt(index);
    ref.read(invoiceProvider.notifier).setItems(newItems);
  }

  void _oldPrintingModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.95),
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, anim1, anim2) {
        final state = ref.read(invoiceProvider);
        return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // The "Feeding" Loop Animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: 0.0),
                duration: const Duration(milliseconds: 3000),
                builder: (context, value, child) {
                  return Stack(
                    children: [
                      // The Receipt - Larger and more detailed, moving UP and OUT
                      Positioned(
                        top: (MediaQuery.of(context).size.height * value) - 200,
                        left: (MediaQuery.of(context).size.width - 320) / 2,
                        child: Opacity(
                          opacity: value < 0.1 ? (value * 10) : 1.0,
                          child: Container(
                            width: 320,
                            height: 600,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 10))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Receipt Header
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                                        child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue, size: 32)
                                      ),
                                      const SizedBox(height: 16),
                                      Text("TAX INVOICE", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, color: Colors.grey[800])),
                                      const SizedBox(height: 8),
                                      Text(state.invoiceNumber, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
                                    ],
                                  ),
                                ),
                                
                                // Customer Info
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("BILL TO", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                                      const SizedBox(height: 4),
                                      Text(state.customerName ?? 'Walking Customer', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[900])),
                                      const SizedBox(height: 4),
                                      Text(DateTime.now().toString().substring(0, 16), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Divider(),
                                ),
                                
                                // Items List
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(flex: 3, child: Text("ITEM", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400]))),
                                            Expanded(child: Text("QTY", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400]))),
                                            Expanded(child: Text("TOTAL", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400]))),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        ...(state.items.take(4).map((item) {
                                          final qty = (item['quantity'] ?? 0).toDouble();
                                          final price = (item['unit_price'] ?? 0).toDouble();
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: Row(
                                              children: [
                                                Expanded(flex: 3, child: Text(item['name'] ?? 'Item', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                                                Expanded(child: Text("$qty", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Colors.grey[700]))),
                                                Expanded(child: Text("₹${(qty * price).toStringAsFixed(0)}", textAlign: TextAlign.right, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black))),
                                              ],
                                            ),
                                          );
                                        }).toList()),
                                        if (state.items.length > 4) 
                                          Center(child: Text("+ ${state.items.length - 4} more items", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey[400])))
                                      ],
                                    ),
                                  ),
                                ),
                                
                                // Total Footer
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("GRAND TOTAL", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
                                          Text("Payable Amount", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.white70)),
                                        ],
                                      ),
                                      Text("₹${state.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                onEnd: () {
                   // This creates a continuous loop
                   // (In a real app we'd use an AnimationController, but this is a quick way to loop)
                },
              ),

              // The "Printer Slot" at the VERY top edge - This is where the paper "leaves"
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.black.withOpacity(0)],
                    ),
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 350,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryBlue.withOpacity(0.5), blurRadius: 40, spreadRadius: 4)
                    ]
                  ),
                  child: Center(
                    child: Container(
                      width: 320,
                      height: 1,
                      color: Colors.white10,
                    ),
                  ),
                ),
              ),

              // Status indicator at bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.white.withOpacity(0.1))
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                            const SizedBox(width: 16),
                            Text("COMMUNICATING WITH PRINTER...", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white.withOpacity(0.9))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    },
    );
  }


  Future<void> _saveInvoice({List<Map<String, dynamic>>? customPayments, bool shouldPrint = false}) async {
    final state = ref.read(invoiceProvider);
    if (state.customerId == null) { StatusService.show(context, "Please select a customer"); return; }
    if (state.items.isEmpty) { StatusService.show(context, "Add at least one item"); return; }
    
    final companyId = state.companyId;
    final branchId = state.branchId;
    if (companyId == null) return;

    ref.read(invoiceProvider.notifier).setLoading(true);
    try {
      double existingPaid = 0.0;
      final isEdit = widget.invoice != null && widget.invoice!['id'] != null;
      String? savedInvoiceId = isEdit ? widget.invoice!['id'].toString() : null;
      String? sourceQuotationId = state.quotationId;
      String? sourceOrderId = state.orderId;
      String? sourceDcId = state.dcId;

      if (isEdit) {
        final invoiceId = savedInvoiceId!;
        final allocations = await Supabase.instance.client
            .from('sales_payment_allocations')
            .select('amount')
            .eq('invoice_id', invoiceId);
        existingPaid = (allocations as List).fold(0.0, (sum, a) => sum + (a['amount'] ?? 0));

        final credits = await Supabase.instance.client
            .from('sales_credit_notes')
            .select('total_amount')
            .eq('invoice_id', invoiceId)
            .eq('reason', 'Overpayment adjustment due to item reduction');
        final totalCredited = (credits as List).fold(0.0, (sum, c) => sum + (c['total_amount'] ?? 0));
        existingPaid -= totalCredited;
      }

      final double newPaid = customPayments?.fold(0.0, (sum, p) => sum! + (p['amount'] ?? 0)) ?? 0.0;
      final totalPaid = existingPaid + newPaid;
      var balanceDue = state.totalAmount - totalPaid;

      if (isEdit && balanceDue < -0.5) {
        final invoiceId = savedInvoiceId!;
        double excessToRemove = balanceDue.abs();
        final allocs = await Supabase.instance.client
            .from('sales_payment_allocations')
            .select('id, amount')
            .eq('invoice_id', invoiceId)
            .order('amount', ascending: false);
            
        for (var a in (allocs as List)) {
          if (excessToRemove <= 0) break;
          double amt = (a['amount'] ?? 0).toDouble();
          if (amt <= excessToRemove) {
            await Supabase.instance.client.from('sales_payment_allocations').delete().eq('id', a['id']);
            excessToRemove -= amt;
          } else {
            await Supabase.instance.client.from('sales_payment_allocations').update({'amount': amt - excessToRemove}).eq('id', a['id']);
            excessToRemove = 0;
          }
        }
        balanceDue = 0;
      }

      final status = balanceDue <= 0.5 ? 'paid' : (totalPaid > 0 ? 'partial' : 'unpaid');

      final invoiceData = {
        'company_id': companyId,
        'branch_id': branchId,
        'customer_id': state.customerId,
        'invoice_number': state.invoiceNumber,
        'date': state.invoiceDate.toIso8601String(),
        'due_date': state.dueDate.toIso8601String(),
        'sub_total': state.subtotal,
        'tax_total': state.totalTax,
        'total_amount': state.totalAmount,
        'balance_due': balanceDue < 0 ? 0 : balanceDue,
        'status': status,
        'created_by': state.internalUserId,
        'so_id': sourceOrderId,
        'dc_id': sourceDcId,
      };

      if (!isEdit) {
        // Consume the actual number from sequence on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: companyId,
          documentType: 'SALES_INVOICE',
          branchId: branchId,
          previewOnly: false,
        );
        invoiceData['invoice_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_invoices').insert(invoiceData).select().single();
        savedInvoiceId = inserted['id'].toString();
        
        // If conversion, update source status
        if (sourceQuotationId != null) {
          await Supabase.instance.client.from('sales_quotations').update({'status': 'converted_to_invoice'}).eq('id', sourceQuotationId);
        }
        if (sourceOrderId != null) {
          await Supabase.instance.client.from('sales_orders').update({'status': 'completed'}).eq('id', sourceOrderId);
          
          // Also update the linked quotation if this order came from one
          try {
            final orderData = await Supabase.instance.client.from('sales_orders').select('quote_id').eq('id', sourceOrderId).maybeSingle();
            if (orderData != null && orderData['quote_id'] != null) {
              await Supabase.instance.client.from('sales_quotations').update({'status': 'converted_to_invoice'}).eq('id', orderData['quote_id']);
            }
          } catch (e) {
            debugPrint("Error updating linked quotation status: $e");
          }
        }

        for (var item in state.items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;
          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

          if (item['item_id'] == null) continue;

          await Supabase.instance.client.from('sales_invoice_items').insert({
            'invoice_id': savedInvoiceId,
            'item_id': item['item_id'].toString(),
            'description': (item['name'] ?? 'Item').toString(),
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'tax_rate': item['tax_rate'],
            'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
            'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
          });

          // Update Stock for Products
          try {
            final itemSpec = await Supabase.instance.client.from('items').select('type').eq('id', item['item_id']).single();
            if (itemSpec['type'] == 'product' && branchId != null) {
              final stockData = await Supabase.instance.client.from('inventory_stock').select('quantity').eq('item_id', item['item_id']).eq('branch_id', branchId).maybeSingle();
              final currentQty = (stockData?['quantity'] ?? 0).toDouble();
              final newQty = currentQty - qty;

              await Supabase.instance.client.from('inventory_stock').upsert({
                'company_id': companyId,
                'item_id': item['item_id'],
                'branch_id': branchId,
                'quantity': newQty,
                'last_updated': DateTime.now().toIso8601String(),
              }, onConflict: 'item_id, branch_id');

              await Supabase.instance.client.from('inventory_transactions').insert({
                'company_id': companyId,
                'item_id': item['item_id'],
                'branch_id': branchId,
                'transaction_type': 'sales_out',
                'quantity_change': -qty,
                'new_balance': newQty,
                'reference_id': inserted['id'],
                'reference_type': 'INVOICE',
                'notes': "Sales Invoice: ${inserted['invoice_number']}",
                'created_by': state.internalUserId,
              });
            }
          } catch (e) {
            debugPrint("Stock update error (POST): $e");
          }
        }
        await Supabase.instance.client.from('sales_invoices').update({'stock_updated': true}).eq('id', savedInvoiceId!);
        
        // Record Multiple Payments
        if (customPayments != null && customPayments.isNotEmpty) {
          final double totalAmt = customPayments.fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));
          if (totalAmt > 0) {
            final pNum = await NumberingService.getNextDocumentNumber(
              companyId: companyId,
              documentType: 'SALES_PAYMENT',
              branchId: branchId,
              previewOnly: false,
            );

            final isMulti = customPayments.length > 1;

            final payment = await Supabase.instance.client.from('sales_payments').insert({
              'company_id': companyId,
              'branch_id': branchId,
              'customer_id': state.customerId,
              'payment_number': pNum,
              'date': DateTime.now().toIso8601String(),
              'amount': totalAmt,
              'payment_mode': isMulti ? 'Multi' : customPayments[0]['mode'],
              'created_by': state.internalUserId,
              'is_active': true,
              'payment_methods': customPayments, // Store splits
            }).select().single();

            await Supabase.instance.client.from('sales_payment_allocations').insert({
              'payment_id': payment['id'],
              'invoice_id': savedInvoiceId,
              'amount': totalAmt,
            });
          }
        }
      } else {
        savedInvoiceId = widget.invoice!['id'].toString();
        final invoiceId = savedInvoiceId;
        
        // 1. Fetch Old Items for Stock Reversal
        final oldItems = await Supabase.instance.client.from('sales_invoice_items').select('item_id, quantity').eq('invoice_id', invoiceId);
        final currentInvoice = await Supabase.instance.client.from('sales_invoices').select('branch_id, stock_updated, invoice_number').eq('id', invoiceId).single();
        final branchIdToUse = branchId ?? currentInvoice['branch_id'];

        await Supabase.instance.client.from('sales_invoices').update(invoiceData).eq('id', invoiceId);

        // 2. Reverse Stock
        if (currentInvoice['stock_updated'] == true && branchIdToUse != null) {
          for (var oldItem in oldItems) {
            final oldQty = (oldItem['quantity'] ?? 0).toDouble();
            if (oldQty > 0) {
              try {
                final stockData = await Supabase.instance.client.from('inventory_stock').select('quantity').eq('item_id', oldItem['item_id']).eq('branch_id', branchIdToUse).maybeSingle();
                final currentQty = (stockData?['quantity'] ?? 0).toDouble();
                final newQty = currentQty + oldQty;

                await Supabase.instance.client.from('inventory_stock').upsert({
                  'company_id': companyId,
                  'item_id': oldItem['item_id'],
                  'branch_id': branchIdToUse,
                  'quantity': newQty,
                  'last_updated': DateTime.now().toIso8601String(),
                }, onConflict: 'item_id, branch_id');

                await Supabase.instance.client.from('inventory_transactions').insert({
                  'company_id': companyId,
                  'item_id': oldItem['item_id'],
                  'branch_id': branchIdToUse,
                  'transaction_type': 'edit_reversal',
                  'quantity_change': oldQty,
                  'new_balance': newQty,
                  'reference_id': invoiceId,
                  'reference_type': 'INVOICE',
                  'notes': "Reversal for Invoice Edit: ${currentInvoice['invoice_number']}",
                  'created_by': state.internalUserId,
                });
              } catch (e) {
                debugPrint("Stock reversal error: $e");
              }
            }
          }
        }

        // 3. Replace Items and Apply New Stock
        await Supabase.instance.client.from('sales_invoice_items').delete().eq('invoice_id', invoiceId);
        for (var item in state.items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;

          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

          await Supabase.instance.client.from('sales_invoice_items').insert({
            'invoice_id': invoiceId,
            'item_id': item['item_id'],
            'description': item['name'],
            'quantity': item['quantity'],
            'unit_price': item['unit_price'],
            'tax_rate': item['tax_rate'],
            'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
            'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
          });

          // Apply New Stock
          if (branchIdToUse != null) {
            try {
              final itemSpec = await Supabase.instance.client.from('items').select('type').eq('id', item['item_id']).single();
              if (itemSpec['type'] == 'product' && qty > 0) {
                final stockData = await Supabase.instance.client.from('inventory_stock').select('quantity').eq('item_id', item['item_id']).eq('branch_id', branchIdToUse).maybeSingle();
                final currentQty = (stockData?['quantity'] ?? 0).toDouble();
                final newQty = currentQty - qty;

                await Supabase.instance.client.from('inventory_stock').upsert({
                  'company_id': companyId,
                  'item_id': item['item_id'],
                  'branch_id': branchIdToUse,
                  'quantity': newQty,
                  'last_updated': DateTime.now().toIso8601String(),
                }, onConflict: 'item_id, branch_id');

                await Supabase.instance.client.from('inventory_transactions').insert({
                  'company_id': companyId,
                  'item_id': item['item_id'],
                  'branch_id': branchIdToUse,
                  'transaction_type': 'sales_out',
                  'quantity_change': -qty,
                  'new_balance': newQty,
                  'reference_id': invoiceId,
                  'reference_type': 'INVOICE',
                  'notes': "Sales Invoice (Updated): ${currentInvoice['invoice_number']}",
                  'created_by': state.internalUserId,
                });
              }
            } catch (e) {
              debugPrint("Stock update error (PUT): $e");
            }
          }
        }
        // Update balance and status based on the calculated values
        await Supabase.instance.client.from('sales_invoices').update({
          ...invoiceData,
          'stock_updated': true,
        }).eq('id', invoiceId);
      }
      
      if (mounted) {
        await MasterDataService().invalidateItems();
        
        if (shouldPrint && savedInvoiceId != null) {
          // Show the wow animation
          StatusService.show(context, 'Connecting to printer...', isLoading: true, persistent: true);
          
          final fullInvoice = await Supabase.instance.client.from('sales_invoices').select('*, customer:customers(*)').eq('id', savedInvoiceId!).single();
          if (mounted) {
            await PrintService.printDocument({
              ...fullInvoice,
              'items': state.items,
            }, 'SALES_INVOICE', context);
            
            // Dismiss the animation modal
            Navigator.pop(context);
          }
        }

        SalesRefreshService.triggerRefresh();
        Navigator.pop(context, true);
        StatusService.show(context, "Invoice ${isEdit ? 'Updated' : 'Created'} successfully");
      }
    } catch (e) {
      debugPrint("Error saving invoice: $e");
      if (mounted) StatusService.show(context, "Error: $e");
    } finally {
       if (mounted) ref.read(invoiceProvider.notifier).setLoading(false);
    }
  }

  // Reuse the selection sheet pattern from earlier for consistency
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      clipBehavior: Clip.antiAlias,
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
                                          // Note: Since items list is passed as parameter, we might need a way to update the parent list
                                          // but for now, we assume the caller uses a direct reference or is fine with just triggering it.
                                          // Actually, since MasterDataService is a singleton, current refers to it might work if we re-fetch effectively.
                                          // BETTER: Selection sheet should probably fetch its own data or take a Future.
                                          // For now, let's just pop and let user reopen or tell them to reopen if we can't update 'items' local list.
                                          if (context.mounted) Navigator.pop(context);
                                          StatusService.show(context, "Data synchronized! Please reopen to see changes.");
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
                      // Premium High-Fidelity Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.cardBg,
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
                                filled: false,
                                hintText: "Search anything...",
                                 border: InputBorder.none,
                                 enabledBorder: InputBorder.none,
                                 focusedBorder: InputBorder.none,
                                hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15, fontWeight: FontWeight.normal),
                                prefixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.search_rounded, 
                                    key: ValueKey(focusNode.hasFocus),
                                    color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.5), 
                                    size: 24
                                  ),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (searchQuery.isNotEmpty) 
                                      IconButton(
                                        icon: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.1), shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, size: 14)
                                        ), 
                                        onPressed: () => setModalState(() { searchQuery = ""; searchController.clear(); })
                                      ),
                                    if (showScanner) 
                                      IconButton(
                                        icon: Icon(Icons.barcode_reader, size: 22, color: focusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary), 
                                        onPressed: () => _openScanner(
                                          allItems: items,
                                          selectedItems: selectedItems,
                                          onSelectionChanged: (l) => setModalState(() { selectedItems.clear(); selectedItems.addAll(l); }),
                                          onConfirm: () {
                                             if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); }
                                          },
                                          barcodeMapper: barcodeMapper!,
                                          labelMapper: labelMapper,
                                          isMultiple: isMultiple
                                        )
                                      ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
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
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), // Bottom padding for FAB
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final count = isMultiple ? selectedItems.where((e) => e == item).length : 0;
                            
                            void onIncrement() => setModalState(() => selectedItems.add(item));
                            void onDecrement() => setModalState(() => selectedItems.remove(item));

                            if (itemContentBuilder != null) {
                              return itemContentBuilder(context, item, count, onIncrement, onDecrement);
                            }

                            // Fallback default UI
                            final label = labelMapper(item);
                            final isSelected = isMultiple ? count > 0 : label == currentValue;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: isSelected ? AppColors.primaryBlue.withOpacity(0.05) : context.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    if (isMultiple) onIncrement();
                                    else { onSelect?.call(item); Navigator.pop(context); }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor.withOpacity(0.5), width: 1),
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
                      child: ElevatedButton(
                        onPressed: () {
                           if (onSelectMultiple != null) { onSelectMultiple(selectedItems); Navigator.pop(context); }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
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
}
