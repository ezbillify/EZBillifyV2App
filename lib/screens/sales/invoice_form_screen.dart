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
import '../../services/numbering_service.dart';
import '../../services/master_data_service.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? invoice; // Null for new
  const InvoiceFormScreen({super.key, this.invoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _internalUserId;
  String? _branchId;
  String? _branchName;
  String? _customerId;
  String? _customerName;
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  String _invoiceNumber = "";
  
  // Line Items
  List<Map<String, dynamic>> _items = [];
  
  // Totals
  double _subtotal = 0;
  double _totalTax = 0;
  double _totalAmount = 0;

  // Record Payment State
  bool _recordPayment = false;
  double _paidAmount = 0;
  String _paymentMode = "Cash";
  String _referenceNumber = "";
  String _paymentNotes = "";
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
      
      final isEdit = widget.invoice != null && widget.invoice!['id'] != null;
      
      if (!isEdit) {
        // Fetch branches to select default if only one
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
        await _generateInvoiceNumber();

        // Check if we have pre-fill data (like from Quotation conversion)
        if (widget.invoice != null) {
           if (widget.invoice!['items'] != null) {
             _items = List<Map<String, dynamic>>.from(widget.invoice!['items']);
           }
           _customerId = widget.invoice!['customer_id']?.toString();
           _customerName = widget.invoice!['customer_name'] ?? widget.invoice!['customer']?['name'];
           _calculateTotals();
        }
      } else {
        // Load existing invoice data for EDIT
        _invoiceNumber = widget.invoice!['invoice_number'];
        _branchId = widget.invoice!['branch_id']?.toString();
        _branchName = widget.invoice!['branch']?['name'];
        _customerId = widget.invoice!['customer_id']?.toString();
        _customerName = widget.invoice!['customer']?['name'];
        _invoiceDate = DateTime.parse(widget.invoice!['date'] ?? widget.invoice!['invoice_date'] ?? DateTime.now().toIso8601String());
        _dueDate = DateTime.parse(widget.invoice!['due_date'] ?? DateTime.now().toIso8601String());
        _items = List<Map<String, dynamic>>.from(widget.invoice!['items'] ?? []);
        _calculateTotals();
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateInvoiceNumber() async {
    if (_branchId == null || _companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'SALES_INVOICE',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _invoiceNumber = nextNum);
  }

  void _calculateTotals() {
    double sub = 0;
    double tax = 0;
    for (var item in _items) {
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['unit_price'] ?? 0).toDouble();
      final taxRate = (item['tax_rate'] ?? 0).toDouble();
      
      final totalInclusive = qty * price;
      // Back calculate base price from inclusive price: Base = Total / (1 + Rate/100)
      final lineSub = totalInclusive / (1 + (taxRate / 100));
      final lineTax = totalInclusive - lineSub;
      
      sub += lineSub;
      tax += lineTax;
    }
    setState(() {
      _subtotal = double.parse(sub.toStringAsFixed(2));
      _totalTax = double.parse(tax.toStringAsFixed(2));
      _totalAmount = double.parse((sub + tax).toStringAsFixed(2));
      
      // Keep paid amount in sync if record payment is toggled and it was previously matching total or just enabled
      if (_recordPayment) {
        _paidAmount = _totalAmount;
        _paidAmountController.text = _paidAmount.toStringAsFixed(2);
      }
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
            Text(widget.invoice == null ? "New Invoice" : "Edit Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 18)),
            Text(_invoiceNumber.isEmpty ? "Generating ID..." : _invoiceNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
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

  Widget _buildDocumentHeader() {
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
                Text(_invoiceNumber.isEmpty ? "#---" : _invoiceNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
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
        _buildSectionTitle("Dates & Settings"),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard("Invoice Date", DateFormat('dd MMM, yyyy').format(_invoiceDate), Icons.calendar_today_rounded, () => _selectDate(true)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard("Due Date", DateFormat('dd MMM, yyyy').format(_dueDate), Icons.event_available_rounded, () => _selectDate(false)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField("Reference Number (Optional)", "", Icons.edit_note_rounded, (v) {}),
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
    return Column(
      children: [
        Container(
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
        ),
        const SizedBox(height: 24),
        if (widget.invoice == null) _buildPaymentToggleSection(),
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
                    Text("Add immediate payment to this invoice", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
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
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
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
                labelText: "Reference # (Optional)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: context.scaffoldBg,
              ),
              onChanged: (v) => _referenceNumber = v,
            ),
          ]
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
              onPressed: _loading ? null : _saveInvoice,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              child: const Text("Save Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
        _generateInvoiceNumber(); // Regenerate number for the new branch
      }),
      currentValue: _branchName,
    );
  }

  Future<void> _selectCustomer() async {
    // Use MasterDataService for caching
    final results = await MasterDataService().getCustomers(_companyId!);
    if(!mounted) return;
    
    _showSelectionSheet<Map<String, dynamic>>(
      title: "Select Customer",
      items: List<Map<String, dynamic>>.from(results),
      labelMapper: (c) => c['name'],
      onSelect: (c) => setState(() { _customerId = c['id'].toString(); _customerName = c['name']; }),
      currentValue: _customerName,
      badgeMapper: (c) => c['customer_type'] ?? 'B2C',
      badgeColorMapper: (c) => (c['customer_type'] == 'B2B') ? Colors.purple : Colors.blue,
      onRefresh: () async {
        await MasterDataService().getCustomers(_companyId!, forceRefresh: true);
      },
    );
  }

  Future<void> _selectDate(bool isInvoiceDate) async {
    final picked = await showCustomCalendarSheet(
      context: context,
      initialDate: isInvoiceDate ? _invoiceDate : _dueDate,
      title: isInvoiceDate ? "Select Invoice Date" : "Select Due Date",
    );
    
    if (picked != null) {
      setState(() {
        if (isInvoiceDate) {
          _invoiceDate = picked;
          // Auto update due date if it becomes before invoice date
          if (_dueDate.isBefore(_invoiceDate)) {
            _dueDate = _invoiceDate.add(const Duration(days: 7));
          }
        } else {
          _dueDate = picked;
        }
      });
    }
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


  Future<void> _addItem() async {
    final results = await MasterDataService().getItems(_companyId!);
    if (!mounted) return;

    // Construct currentValues based on ALL items currently in the list
    // If an item has quantity > 1, add it multiple times to the list so the sheet shows correct count
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
        setState(() {
          // Since the sheet now returns the 'Absolute Truth' of the selection (including previous items)
          // We map the selectedList into a consolidated map of ID -> Qty
          final qtyMap = <String, int>{};
          final itemMap = <String, Map<String, dynamic>>{};
          
          for (var item in selectedList) {
            final id = item['id'].toString();
            qtyMap[id] = (qtyMap[id] ?? 0) + 1;
            itemMap[id] = item;
          }

          // We want to keep existing edited items (to preserve manual price changes etc.)
          // 1. Remove items that are no longer in the selection
          _items.removeWhere((existing) => !qtyMap.containsKey(existing['item_id'].toString()));

          // 2. Update quantities for items that still exist
          for (var itemEntry in _items) {
            final id = itemEntry['item_id'].toString();
            itemEntry['quantity'] = qtyMap[id];
            qtyMap.remove(id); // Mark as processed
          }

          // 3. Add entirely new items
          for (var id in qtyMap.keys) {
            final item = itemMap[id]!;
            final qty = qtyMap[id]!;
            final mrp = (item['default_sales_price'] ?? 0).toDouble();
            final rate = (item['tax_rate']?['rate'] ?? 0).toDouble();
            final inclusivePrice = double.parse((mrp * (1 + rate / 100)).toStringAsFixed(2));
            
            _items.add({
              'item_id': item['id'],
              'name': item['name'],
              'quantity': qty,
              'unit_price': inclusivePrice,
              'tax_rate': rate,
              'unit': item['unit'],
              'purchase_price': (item['purchase_price'] ?? 0).toDouble(),
            });
          }
        });
        _calculateTotals();
      },
      showScanner: true,
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



  Future<void> _saveInvoice() async {
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a customer"))); return; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least one item"))); return; }
    
    setState(() => _loading = true);
    try {
      final balanceDue = _recordPayment ? (_totalAmount - _paidAmount) : _totalAmount;
      final status = balanceDue <= 0.5 ? 'paid' : (_recordPayment && _paidAmount > 0 ? 'partial' : 'unpaid');

      final invoiceData = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'invoice_number': _invoiceNumber,
        'date': _invoiceDate.toIso8601String(),
        'due_date': _dueDate.toIso8601String(),
        'sub_total': _subtotal,
        'tax_total': _totalTax,
        'total_amount': _totalAmount,
        'balance_due': balanceDue < 0 ? 0 : balanceDue,
        'status': status,
        'created_by': _internalUserId,
      };

      final isEdit = widget.invoice != null && widget.invoice!['id'] != null;

      if (!isEdit) {
        // Consume the actual number from sequence on save
        final actualNumber = await NumberingService.getNextDocumentNumber(
          companyId: _companyId!,
          documentType: 'SALES_INVOICE',
          branchId: _branchId,
          previewOnly: false,
        );
        invoiceData['invoice_number'] = actualNumber;

        final inserted = await Supabase.instance.client.from('sales_invoices').insert(invoiceData).select().single();
        for (var item in _items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;
          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

            await Supabase.instance.client.from('sales_invoice_items').insert({
              'invoice_id': inserted['id'],
              'item_id': item['item_id'],
              'description': item['name'],
              'quantity': item['quantity'],
              'unit_price': item['unit_price'],
              'tax_rate': item['tax_rate'],
              'tax_amount': double.parse(lineTax.toStringAsFixed(2)),
              'total_amount': double.parse(totalInclusive.toStringAsFixed(2)),
            });
        }
        
        // If this was a conversion from a quotation, update the quotation status
        if (widget.invoice != null && widget.invoice!['quotation_id'] != null) {
          await Supabase.instance.client.from('sales_quotations')
              .update({'status': 'converted'})
              .eq('id', widget.invoice!['quotation_id']);
        }

        // 4. Record Payment if enabled
        if (_recordPayment && _paidAmount > 0) {
          final paymentNumber = await NumberingService.getNextDocumentNumber(
            companyId: _companyId!,
            documentType: 'SALES_PAYMENT',
            branchId: _branchId,
            previewOnly: false,
          );

          final payment = await Supabase.instance.client.from('sales_payments').insert({
            'company_id': _companyId,
            'branch_id': _branchId,
            'customer_id': _customerId,
            'payment_number': paymentNumber,
            'date': DateTime.now().toIso8601String(),
            'amount': _paidAmount,
            'payment_mode': _paymentMode,
            'reference_number': _referenceNumber,
            'created_by': _internalUserId,
            'is_active': true,
          }).select().single();

          await Supabase.instance.client.from('sales_payment_allocations').insert({
            'payment_id': payment['id'],
            'invoice_id': inserted['id'],
            'amount': _paidAmount,
          });
        }
      } else {
        await Supabase.instance.client.from('sales_invoices').update(invoiceData).eq('id', widget.invoice!['id']);
        // Delete and re-insert items
        await Supabase.instance.client.from('sales_invoice_items').delete().eq('invoice_id', widget.invoice!['id']);
        for (var item in _items) {
          final qty = (item['quantity'] ?? 0).toDouble();
          final price = (item['unit_price'] ?? 0).toDouble();
          final taxRate = (item['tax_rate'] ?? 0).toDouble();
          final totalInclusive = qty * price;
          final lineSub = totalInclusive / (1 + (taxRate / 100));
          final lineTax = totalInclusive - lineSub;

            await Supabase.instance.client.from('sales_invoice_items').insert({
              'invoice_id': widget.invoice!['id'],
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
      debugPrint("Error saving invoice: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _loading = false);
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
                      // Premium High-Fidelity Search Bar
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
