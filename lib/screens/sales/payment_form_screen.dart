import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
// import 'scanner_modal_content.dart'; // Not needed unless scanning invoice QR

class PaymentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? payment; // Null for new
  final Map<String, dynamic>? initialInvoice;
  const PaymentFormScreen({super.key, this.payment, this.initialInvoice});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Data
  String? _companyId;
  String? _branchId; // Optional link to branch
  String? _customerId;
  String? _customerName;
  String? _invoiceId;
  String? _invoiceNumber;
  double _invoiceBalance = 0;
  
  DateTime _paymentDate = DateTime.now();
  String _paymentNumber = "";
  double _amount = 0;
  String _paymentMode = "Cash";
  String _referenceNumber = "";
  String _notes = "";

  List<Map<String, dynamic>> _unpaidInvoices = [];

  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id'];
      
      if (widget.payment == null) {
        // Fetch branch for proper linking
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
           _branchId = branches[0]['id'].toString();
        }

        await _generatePaymentNumber();
        
        if (widget.initialInvoice != null) {
           _customerId = widget.initialInvoice!['customer_id']?.toString();
           _customerName = widget.initialInvoice!['customer']?['name'] ?? widget.initialInvoice!['customer_name'];
           _invoiceId = widget.initialInvoice!['id']?.toString();
           _invoiceNumber = widget.initialInvoice!['invoice_number'];
           _invoiceBalance = (widget.initialInvoice!['balance_due'] ?? widget.initialInvoice!['balance_amount'] ?? 0).toDouble();
           _amount = _invoiceBalance;
           _amountController.text = _amount.toStringAsFixed(2);
           await _fetchUnpaidInvoices(); // To populate list and validate
        }
      } else {
        // Edit mode (Rare for payments - usually void/delete, but let's support view/edit if needed)
        // Omitted for brevity, assume new payment for now as per robust accounting practices (edit is restricted)
      }
    } catch (e) {
      debugPrint("Error initializing: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generatePaymentNumber() async {
    if (_companyId == null) return;
    
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'SALES_PAYMENT',
      branchId: _branchId,
      previewOnly: true,
    );
    
    setState(() => _paymentNumber = nextNum);
  }
  
  Future<void> _fetchUnpaidInvoices() async {
    if (_customerId == null) return;
    
    final res = await Supabase.instance.client
        .from('sales_invoices')
        .select('id, invoice_number, balance_due, total_amount, date')
        .eq('customer_id', _customerId!)
        .neq('status', 'paid') 
        .gt('balance_due', 0) 
        .order('date', ascending: true); 
    
    setState(() {
      _unpaidInvoices = List<Map<String, dynamic>>.from(res.map((i) => {
        ...i,
        'balance_amount': (i['balance_due'] ?? 0).toDouble(), // Map back for local UI consistency if needed
        'invoice_date': i['date']
      }));
      // Reset invoice selection if not valid
      if (_invoiceId != null && !_unpaidInvoices.any((i) => i['id'].toString() == _invoiceId)) {
        _invoiceId = null;
        _invoiceNumber = null;
        _invoiceBalance = 0;
        _amount = 0;
        _amountController.clear();
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
        title: Text("Record Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSectionTitle("Customer"),
               const SizedBox(height: 12),
               _buildCustomerSelector(),
               
               if (_customerId != null) ...[
                 const SizedBox(height: 24),
                 _buildSectionTitle("Invoice to Pay"),
                 const SizedBox(height: 12),
                 _buildInvoiceSelector(),
               ],

               const SizedBox(height: 24),
               _buildSectionTitle("Payment Details"),
               const SizedBox(height: 12),
               
               // Date Selector
               _buildInfoCard("Payment Date", DateFormat('dd MMM, yyyy').format(_paymentDate), Icons.calendar_today_rounded, () async {
                  final picked = await showDatePicker(context: context, initialDate: _paymentDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (picked != null) setState(() => _paymentDate = picked);
               }),
               const SizedBox(height: 16),
               
               // Amount Field
               TextFormField(
                 controller: _amountController,
                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
                 style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                 decoration: InputDecoration(
                   labelText: "Amount Received",
                   prefixText: "₹ ",
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                   filled: true,
                   fillColor: context.cardBg,
                 ),
                 onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                 validator: (v) {
                   if (v == null || v.isEmpty) return "Enter amount";
                   final val = double.tryParse(v);
                   if (val == null || val <= 0) return "Invalid amount";
                   if (_invoiceId != null && val > _invoiceBalance) return "Exceeds balance (₹$_invoiceBalance)"; // Optional check
                   return null;
                 },
               ),
               const SizedBox(height: 16),
               
               // Mode Selector
               DropdownButtonFormField<String>(
                 value: _paymentMode,
                 decoration: InputDecoration(labelText: "Payment Mode", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
                 items: ["Cash", "Bank Transfer", "Cheque", "UPI", "Other"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                 onChanged: (v) => setState(() => _paymentMode = v!),
               ),
               const SizedBox(height: 16),
               
               TextFormField(
                 decoration: InputDecoration(labelText: "Reference # (Optional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
                 onChanged: (v) => _referenceNumber = v,
               ),
               const SizedBox(height: 16),
               
               TextFormField(
                 maxLines: 3,
                 decoration: InputDecoration(labelText: "Notes (Optional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
                 onChanged: (v) => _notes = v,
               ),
               
               const SizedBox(height: 40),
               SizedBox(
                 width: double.infinity,
                 height: 54,
                 child: ElevatedButton(
                   onPressed: _loading ? null : _savePayment,
                   style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                   child: const Text("Save Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerSelector() {
    return InkWell(
      onTap: _selectCustomer,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person_outline, color: AppColors.primaryBlue)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_customerName ?? "Select Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
              if (_customerId == null) Text(" Tap to search customers", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSelector() {
    if (_unpaidInvoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.3))),
        child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange), const SizedBox(width: 12), const Expanded(child: Text("No unpaid invoices found for this customer.", style: TextStyle(fontFamily: 'Outfit', color: Colors.orange)))],),
      );
    }

    return DropdownButtonFormField<String>(
      value: _invoiceId,
      decoration: InputDecoration(labelText: "Select Invoice", border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: context.cardBg),
      items: _unpaidInvoices.map((inv) {
        return DropdownMenuItem<String>(
          value: inv['id'].toString(),
          child: Text("${inv['invoice_number']} (Bal: ₹${inv['balance_amount']})", style: const TextStyle(fontFamily: 'Outfit')),
        );
      }).toList(),
      onChanged: (val) {
        if (val == null) return;
        final selected = _unpaidInvoices.firstWhere((i) => i['id'].toString() == val);
        setState(() {
          _invoiceId = val;
          _invoiceNumber = selected['invoice_number'];
          _invoiceBalance = (selected['balance_amount'] ?? 0).toDouble();
          _amount = _invoiceBalance; // Auto-fill
          _amountController.text = _amount.toStringAsFixed(2);
        });
      },
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary));
  }
  
  Widget _buildInfoCard(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
        child: Row(children: [Icon(icon, size: 16, color: context.textSecondary), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary))])]),
      ),
    );
  }

  Future<void> _selectCustomer() async {
    // Basic reuse of sheet logic or direct list fetch
    // For brevity, using a simple modal list here or reusing from invoice form via copy-paste of a helper class
    // I'll implement a simple one-off sheet here for speed/simplicity
    
    final results = await Supabase.instance.client.from('customers').select().eq('company_id', _companyId!);
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text("Select Customer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (c, i) => ListTile(
              title: Text(results[i]['name']),
              subtitle: Text(results[i]['phone'] ?? ''),
              onTap: () {
                setState(() {
                  _customerId = results[i]['id'].toString();
                  _customerName = results[i]['name'];
                  _invoiceId = null; 
                  _unpaidInvoices = [];
                });
                _fetchUnpaidInvoices();
                Navigator.pop(context);
              },
            ),
          ))
        ]),
      )
    );
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select customer"))); return; }
    if (_invoiceId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select invoice"))); return; }
    
    setState(() => _loading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // 1. Consume actual number and Insert Payment
      final actualNumber = await NumberingService.getNextDocumentNumber(
        companyId: _companyId!,
        documentType: 'SALES_PAYMENT',
        branchId: _branchId,
        previewOnly: false,
      );

      final paymentPayload = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'payment_number': actualNumber,
        'date': _paymentDate.toIso8601String(),
        'amount': _amount,
        'payment_mode': _paymentMode,
        'reference_number': _referenceNumber,
        'notes': _notes,
        'created_by': user?.id,
        'is_active': true,
      };

      final payment = await Supabase.instance.client.from('sales_payments').insert(paymentPayload).select().single();

      // 2. Create Allocation
      await Supabase.instance.client.from('sales_payment_allocations').insert({
        'payment_id': payment['id'],
        'invoice_id': _invoiceId,
        'amount': _amount,
      });

      // 3. Update Invoice Balance
      final newBalance = _invoiceBalance - _amount;
      // Web logic: balance_due <= 0.5 ? 'paid' : partially_paid / unpaid
      final newStatus = newBalance <= 0.5 ? 'paid' : 'partially_paid';
      
      await Supabase.instance.client.from('sales_invoices').update({
        'balance_due': newBalance < 0 ? 0 : newBalance,
        'status': newStatus,
      }).eq('id', _invoiceId!);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving payment: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }
}
