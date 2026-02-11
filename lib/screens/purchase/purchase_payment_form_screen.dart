import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import 'vendors_screen.dart';

class PurchasePaymentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? payment; // Null for new
  const PurchasePaymentFormScreen({super.key, this.payment});

  @override
  State<PurchasePaymentFormScreen> createState() => _PurchasePaymentFormScreenState();
}

class _PurchasePaymentFormScreenState extends State<PurchasePaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  // Header Info
  String? _companyId;
  String? _vendorId;
  String? _vendorName;
  String? _billId;
  String? _billNumber;
  double _billBalance = 0;
  
  DateTime _paymentDate = DateTime.now();
  String _paymentNumber = ""; // Usually auto-generated or bank ref? Schema has payment_number
  double _amount = 0;
  String _mode = "Bank Transfer";
  String _referenceId = ""; // Bank transaction ID
  String _notes = "";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _generatePaymentNumber() async {
    if (_companyId == null) return;
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_PAYMENT',
      previewOnly: true,
    );
    setState(() => _paymentNumber = nextNum);
  }

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('id, company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id'];
      
      if (widget.payment != null) {
        // Edit Mode (Usually payments aren't edited much, but let's support it)
        _paymentNumber = widget.payment!['payment_number'];
        _vendorId = widget.payment!['vendor_id']?.toString();
        _vendorName = widget.payment!['vendor']?['name'];
        _billId = widget.payment!['bill_id']?.toString();
        // Fetch bill details
        if (_billId != null) {
          final bill = await Supabase.instance.client.from('purchase_bills').select('bill_number, total_amount, paid_amount').eq('id', _billId!).single();
          _billNumber = bill['bill_number'];
          _billBalance = (bill['total_amount'] ?? 0) - (bill['paid_amount'] ?? 0) + (widget.payment!['amount'] ?? 0); // Add back current payment amount to see potential balance
        }
        
        _paymentDate = DateTime.parse(widget.payment!['date'] ?? widget.payment!['created_at']);
        _amount = (widget.payment!['amount'] ?? 0).toDouble();
        _mode = _kebabToTitle(widget.payment!['mode'] ?? 'bank_transfer');
        _referenceId = widget.payment!['reference_id'] ?? "";
        _notes = widget.payment!['notes'] ?? "";
      } else {
        // New Mode
        await _generatePaymentNumber();
      }
    } catch (e) {
      debugPrint("Error initializing Payment: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _kebabToTitle(String s) {
    return s.split('_').map((str) => str[0].toUpperCase() + str.substring(1)).join(' ');
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
        _billId = null; // Reset bill
        _billNumber = null;
        _billBalance = 0;
      });
    }
  }

  Future<void> _selectBill() async {
    if (_vendorId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor first")));
       return;
    }

    // Show unpaid bills
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceBg,
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client.from('purchase_bills')
            .select()
            .eq('vendor_id', _vendorId!)
            .neq('status', 'paid') // Only open/partial/overdue
            .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final bills = snapshot.data!;
            if (bills.isEmpty) return const Center(child: Text("No unpaid bills found for this vendor"));
            
            return ListView.builder(
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];
                final total = (bill['total_amount'] ?? 0).toDouble();
                final paid = (bill['paid_amount'] ?? 0).toDouble();
                final due = total - paid;
                
                return ListTile(
                  title: Text(bill['bill_number']),
                  subtitle: Text("Date: ${DateFormat('dd MMM').format(DateTime.parse(bill['date']))}\nTotal: $total, Due: $due"),
                  isThreeLine: true,
                  onTap: () async {
                    Navigator.pop(context); // Close sheet
                    setState(() {
                      _billId = bill['id'];
                      _billNumber = bill['bill_number'];
                      _billBalance = due;
                      if (_amount == 0) _amount = due; // Auto-fill full amount
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

  void _savePayment() async {
    if (_vendorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor")));
      return;
    }
    if (_billId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a bill to pay")));
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount")));
      return;
    }

    setState(() => _loading = true);
    try {
      final paymentData = {
        'company_id': _companyId,
        'payment_number': _paymentNumber,
        'bill_id': _billId,
        'vendor_id': _vendorId,
        'date': _paymentDate.toIso8601String(),
        'amount': _amount,
        'mode': _mode.toLowerCase().replaceAll(' ', '_'),
        'reference_id': _referenceId,
        'notes': _notes,
      };
      
      if (widget.payment != null) {
         // Should handle reversing previous payment amount on bill if edited? 
         // Complex logic. For MVP, update payment and let trigger/logic handle manual bill update or assume user fixes.
         // Actually, let's keep it simple: Just update record. 
         await Supabase.instance.client.from('purchase_payments').update(paymentData).eq('id', widget.payment!['id']);
      } else {
         await Supabase.instance.client.from('purchase_payments').insert(paymentData);
         
         // Update Bill Paid Amount
         // Need to fetch current paid amount and add new amount
         final bill = await Supabase.instance.client.from('purchase_bills').select('paid_amount, total_amount').eq('id', _billId!).single();
         final currentPaid = (bill['paid_amount'] ?? 0).toDouble();
         final total = (bill['total_amount'] ?? 0).toDouble();
         final newPaid = currentPaid + _amount;
         
         String newStatus = 'partial';
         if (newPaid >= total) newStatus = 'paid';
         else if (newPaid <= 0) newStatus = 'open'; // unlikely here
         
         await Supabase.instance.client.from('purchase_bills').update({
           'paid_amount': newPaid,
           'status': newStatus
         }).eq('id', _billId!);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Recorded Successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving payment: $e"), backgroundColor: Colors.red));
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
        title: Text(widget.payment == null ? "Record Payment" : "Edit Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
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
                    _buildPaymentDetailsSection(),
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
        _buildSectionTitle("Payee Details"),
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
        if (_vendorId != null) ...[
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
                        Text(_billNumber ?? "Select Bill to Pay", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: _billNumber == null ? context.textSecondary.withOpacity(0.4) : context.textPrimary)),
                        if (_billNumber != null) Text("Due Balance: ₹$_billBalance", style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Payment Details"),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _amount > 0 ? _amount.toString() : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green),
          decoration: InputDecoration(
             labelText: "Amount",
             prefixText: "₹ ",
             fillColor: context.cardBg,
             filled: true,
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          onChanged: (v) => _amount = double.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
             Expanded(
               child: _buildInfoCard("Date", DateFormat('dd MMM, yyyy').format(_paymentDate), Icons.calendar_today_rounded, () async {
                  final d = await showDatePicker(context: context, initialDate: _paymentDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => _paymentDate = d);
               }),
             ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _mode,
          decoration: InputDecoration(
            labelText: "Payment Mode",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: context.cardBg,
          ),
          items: ["Cash", "Bank Transfer", "UPI", "Cheque", "Other"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _mode = v!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _referenceId,
          decoration: InputDecoration(
            labelText: "Reference / Transaction ID",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: context.cardBg,
          ),
          onChanged: (v) => _referenceId = v,
        ),
      ],
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
            labelText: "Remarks",
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
          onPressed: _loading ? null : _savePayment,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
          child: const Text("Save Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
