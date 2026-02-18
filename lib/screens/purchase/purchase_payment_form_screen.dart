import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import '../../widgets/calendar_sheet.dart';

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
  String? _branchId;
  String? _branchName;
  String? _internalUserId;

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

  Future<void> _generatePaymentNumber() async {
    if (_companyId == null) return;
    final nextNum = await NumberingService.getNextDocumentNumber(
      companyId: _companyId!,
      documentType: 'PURCHASE_PAYMENT',
      branchId: _branchId,
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
      _internalUserId = profile['id'];
      
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
        _amountController.text = _amount.toString();
        _mode = _kebabToTitle(widget.payment!['mode'] ?? 'bank_transfer');
        _referenceId = widget.payment!['reference_id'] ?? "";
        _notes = widget.payment!['notes'] ?? "";
        _branchId = widget.payment!['branch_id']?.toString();
        // Fetch branch name if present
        if (_branchId != null) {
          final branch = await Supabase.instance.client.from('branches').select('name').eq('id', _branchId!).single();
          _branchName = branch['name'];
        }
      } else {
        // Fetch default branch
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
          _branchId = branches[0]['id'].toString();
          _branchName = branches[0]['name'];
        }
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
    final results = await Supabase.instance.client.from('vendors').select().eq('company_id', _companyId!);
    if (!mounted) return;
    
    String searchQuery = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = results.where((v) => 
            v['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            (v['phone']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
          ).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text("Select Vendor", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: "Search vendor name or phone...",
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: context.cardBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setModalState(() => searchQuery = v),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (c, i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                   decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
                   child: ListTile(
                    title: Text(filtered[i]['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
                    subtitle: Text(filtered[i]['phone'] ?? '', style: TextStyle(color: context.textSecondary)),
                    onTap: () {
                      setState(() {
                        _vendorId = filtered[i]['id'].toString();
                        _vendorName = filtered[i]['name'];
                        _billId = null; 
                        _billNumber = null;
                        _billBalance = 0;
                        _amountController.clear();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ))
            ]),
          );
        }
      )
    );
  }

  Future<void> _selectBill() async {
    if (_vendorId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vendor first")));
       return;
    }

    String searchQuery = "";

    // Show unpaid bills in a sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                  Padding(padding: const EdgeInsets.all(16), child: Text("Select Bill to Pay", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary))),
                  
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: "Search Bill Number...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: context.cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (v) => setModalState(() => searchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: Supabase.instance.client.from('purchase_bills')
                        .select()
                        .eq('vendor_id', _vendorId!)
                        .neq('status', 'paid') // Only open/partial/overdue
                        .order('created_at', ascending: false),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final allBills = snapshot.data!;
                        if (allBills.isEmpty) return const Center(child: Text("No unpaid bills found for this vendor"));
                        
                        final filtered = allBills.where((b) => 
                          b['bill_number'].toString().toLowerCase().contains(searchQuery.toLowerCase())
                        ).toList();

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final bill = filtered[index];
                            final total = (bill['total_amount'] ?? 0).toDouble();
                            final paid = (bill['paid_amount'] ?? 0).toDouble();
                            final due = total - paid;
                            final isSelected = _billId == bill['id'].toString();
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : context.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor),
                              ),
                              child: ListTile(
                                title: Text(bill['bill_number'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
                                subtitle: Text("Date: ${DateFormat('dd MMM').format(DateTime.parse(bill['date']))}\nTotal: $total", style: TextStyle(color: context.textSecondary, fontSize: 12)),
                                trailing: Text("Due: ₹$due", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                onTap: () async {
                                  Navigator.pop(context); // Close sheet
                                  setState(() {
                                    _billId = bill['id'];
                                    _billNumber = bill['bill_number'];
                                    _billBalance = due;
                                    if (_amount == 0) {
                                      _amount = due; 
                                      _amountController.text = _amount.toStringAsFixed(2);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
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
        'branch_id': _branchId,
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
         await Supabase.instance.client.from('purchase_payments').update(paymentData).eq('id', widget.payment!['id']);
      } else {
         await Supabase.instance.client.from('purchase_payments').insert(paymentData);
         
         // Update Bill Paid Amount
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.payment == null ? "Record Payment" : "Edit Payment",
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Spacer
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Company Details"),
                    const SizedBox(height: 12),
                    _buildBranchSelector(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Payee Details"),
                    const SizedBox(height: 12),
                    _buildVendorSelector(),
                    
                    if (_vendorId != null) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle("Bill to Pay"),
                      const SizedBox(height: 12),
                      _buildBillSelector(),
                    ],

                    const SizedBox(height: 32),
                    _buildPaymentDetailsSection(),
                    
                    const SizedBox(height: 32),
                    _buildNotesSection(),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                       width: double.infinity,
                       height: 54,
                       child: ElevatedButton(
                         onPressed: _loading ? null : _savePayment,
                         style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                         child: _loading 
                             ? const CircularProgressIndicator(color: Colors.white) 
                             : const Text("Save Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return InkWell(
      onTap: _selectBranch,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.business_rounded, color: AppColors.primaryBlue)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_branchName ?? "Select Branch", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
              if (_branchId == null) Text("Tap to select branch", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBranch() async {
    final results = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text("Select Branch", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary))),
          const SizedBox(height: 8),
          Expanded(child: ListView.builder(
            itemCount: results.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (c, i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
               decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.borderColor)),
               child: ListTile(
                title: Text(results[i]['name'], style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
                onTap: () {
                  setState(() {
                    _branchId = results[i]['id'].toString();
                    _branchName = results[i]['name'];
                  });
                  _generatePaymentNumber(); // Regenerate for new branch
                  Navigator.pop(context);
                },
              ),
            ),
          ))
        ]),
      )
    );
  }

  Widget _buildVendorSelector() {
    return InkWell(
      onTap: _selectVendor,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.store_rounded, color: AppColors.primaryBlue)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_vendorName ?? "Select Vendor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
              if (_vendorId == null) Text("Tap to search vendors", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSelector() {
    if (_vendorId == null) return const SizedBox.shrink();
    
    return InkWell(
      onTap: _selectBill,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.receipt_long, color: Colors.red)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_billId != null ? "${_billNumber ?? 'Unknown'} (Due: ₹$_billBalance)" : "Select Bill", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
              if (_billId == null) Text("Tap to select bill", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Payment Details"),
        const SizedBox(height: 16),
        
        // Payment Number
        TextFormField(
          key: ValueKey(_paymentNumber),
          initialValue: _paymentNumber,
          readOnly: true,
          decoration: InputDecoration(
            labelText: "Payment Number",
            prefixIcon: const Icon(Icons.numbers),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: context.cardBg,
          ),
        ),
        const SizedBox(height: 16),
        
        // Date Selector
        _buildInfoCard("Payment Date", DateFormat('dd MMM, yyyy').format(_paymentDate), Icons.calendar_today_rounded, () async {
            final picked = await showCustomCalendarSheet(
              context: context, 
              initialDate: _paymentDate, 
              title: "Select Payment Date",
              lastDate: DateTime.now()
            );
            if (picked != null) setState(() => _paymentDate = picked);
        }),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
           decoration: InputDecoration(
             labelText: "Amount",
             prefixText: "₹ ",
             fillColor: context.cardBg,
             filled: true,
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (v) => _amount = double.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _mode,
           decoration: InputDecoration(
             labelText: "Payment Mode",
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _notes,
          maxLines: 2,
           decoration: InputDecoration(
             labelText: "Remarks (Optional)",
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
             filled: true,
             fillColor: context.cardBg,
          ),
          onChanged: (v) => _notes = v,
        ),
      ],
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
}
