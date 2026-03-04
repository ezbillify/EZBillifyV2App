
import 'package:ez_billify_v2_app/services/status_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/sales_refresh_service.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';
import '../../services/numbering_service.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/cupertino.dart';
import '../../widgets/calendar_sheet.dart';

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
  String? _internalUserId;
  String? _branchId; // Optional link to branch
  String? _customerId;
  String? _customerName;
  String? _invoiceId;
  String? _invoiceNumber;
  double _invoiceBalance = 0;
  
  DateTime _paymentDate = DateTime.now();
  String _paymentNumber = "";
  double _amount = 0;
  String _referenceNumber = "";
  String _notes = "";
  String? _branchName;
  List<Map<String, dynamic>> _unpaidInvoices = [];
  final List<Map<String, dynamic>> _payments = [];
  bool _showSplits = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  @override
  void dispose() {
    for (var p in _payments) {
       p['controller'].dispose();
    }
    super.dispose();
  }

  String _formatAmount(double val) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(2);
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

  Future<void> _initializeData() async {
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('id, company_id').eq('auth_id', user!.id).single();
      _companyId = profile['company_id'];
      _internalUserId = profile['id'];
      
      if (widget.payment == null) {
        // Fetch branch for proper linking
        final branches = await Supabase.instance.client.from('branches').select().eq('company_id', _companyId!);
        if (branches.isNotEmpty) {
           _branchId = branches[0]['id'].toString();
           _branchName = branches[0]['name'];
        }

        await _generatePaymentNumber();
        
        if (widget.initialInvoice != null) {
           _customerId = widget.initialInvoice!['customer_id']?.toString();
           _customerName = widget.initialInvoice!['customer']?['name'] ?? widget.initialInvoice!['customer_name'];
           _invoiceId = widget.initialInvoice!['id']?.toString();
           _invoiceNumber = widget.initialInvoice!['invoice_number'];
           _invoiceBalance = (widget.initialInvoice!['balance_due'] ?? widget.initialInvoice!['balance_amount'] ?? 0).toDouble();
           _amount = _invoiceBalance;
           _payments.add({
             'mode': 'Cash', 
             'amount': _amount, 
             'controller': TextEditingController(text: _formatAmount(_amount))
           });
           await _fetchUnpaidInvoices(); // To populate list and validate
        } else {
           _payments.add({
             'mode': 'Cash', 
             'amount': 0.0, 
             'controller': TextEditingController(text: "0")
           });
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

  void _updateTotalAmount() {
    setState(() {
      _amount = _payments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
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
        if (_payments.isNotEmpty) {
           _payments[0]['amount'] = 0.0;
           _payments[0]['controller'].text = "0";
           // If we had more than one payment mode, reset it
           if (_payments.length > 1) {
             for (int i = 1; i < _payments.length; i++) {
               _payments[i]['controller'].dispose();
             }
             _payments.removeRange(1, _payments.length);
           }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "Record Payment",
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary),
            ),
            Text(_paymentNumber.isEmpty ? "Generating ID..." : _paymentNumber, style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildSectionTitle("Company Details"),
                   const SizedBox(height: 12),
                   _buildBranchSelector(),
                   const SizedBox(height: 24),
                   
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

                   // Payment Number
                   TextFormField(
                     key: ValueKey(_paymentNumber),
                     initialValue: _paymentNumber, 
                     readOnly: true, 
                     style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                     decoration: InputDecoration(
                       labelText: "Payment Number",
                       prefixIcon: const Icon(Icons.numbers),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                   const SizedBox(height: 24),
                   
                   // Payment Breakdown
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       _buildSectionTitle("Payment Breakdown"),
                       if (!_showSplits && _payments.length <= 1)
                         TextButton.icon(
                           onPressed: () => setState(() => _showSplits = true),
                           icon: const Icon(Icons.call_split_rounded, size: 16),
                           label: const Text("Split Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                         ),
                     ],
                   ),
                   const SizedBox(height: 8),
                   
                   ..._payments.asMap().entries.map((entry) {
                     int idx = entry.key;
                     var p = entry.value;
                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: context.cardBg,
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(color: context.borderColor),
                       ),
                       child: Column(
                         children: [
                           Row(
                             children: [
                               InkWell(
                                 onTap: () => _showModeSelectionSheet(context, (mode) {
                                   setState(() => p['mode'] = mode);
                                 }),
                                 borderRadius: BorderRadius.circular(12),
                                 child: Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                   decoration: BoxDecoration(
                                     color: AppColors.primaryBlue.withOpacity(0.1),
                                     borderRadius: BorderRadius.circular(12),
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Icon(_getPaymentIcon(p['mode']), size: 16, color: AppColors.primaryBlue),
                                       const SizedBox(width: 8),
                                       Text(p['mode'], style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                                       const SizedBox(width: 4),
                                       const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.primaryBlue),
                                     ],
                                   ),
                                 ),
                               ),
                               const Spacer(),
                               if (_payments.length > 1)
                                 IconButton(
                                   onPressed: () => setState(() {
                                     p['controller'].dispose();
                                     _payments.removeAt(idx);
                                     _updateTotalAmount();
                                   }),
                                   icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 20),
                                 ),
                             ],
                           ),
                           const SizedBox(height: 12),
                           TextFormField(
                             controller: p['controller'],
                             keyboardType: const TextInputType.numberWithOptions(decimal: true),
                             style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                               decoration: const InputDecoration(
                                 prefixText: "₹ ",
                                 labelText: "Amount",
                               ),
                             onChanged: (v) {
                               p['amount'] = double.tryParse(v) ?? 0.0;
                               _updateTotalAmount();
                             },
                           ),
                         ],
                       ),
                     );
                   }).toList(),

                   if (_showSplits || _payments.length > 1)
                     Center(
                       child: TextButton.icon(
                         onPressed: () {
                           setState(() {
                             double currentTotal = _payments.fold(0.0, (sum, p) => sum + (double.tryParse(p['controller'].text) ?? 0.0));
                             double remaining = _invoiceId != null ? (_invoiceBalance - currentTotal) : 0.0;
                             if (remaining < 0) remaining = 0;
                             
                             _payments.add({
                               'mode': 'UPI', 
                               'amount': remaining, 
                               'controller': TextEditingController(text: _formatAmount(remaining))
                             });
                             _updateTotalAmount();
                           });
                         },
                         icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                         label: const Text("Add Another Mode", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                       ),
                     ),
                   
                   const SizedBox(height: 16),
                   
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                       color: AppColors.primaryBlue.withOpacity(0.05),
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                     ),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text("Total Amount", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
                         Text("₹ ${_formatAmount(_amount)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                   
                   TextFormField(
                     decoration: const InputDecoration(labelText: "Reference # (Optional)"),
                     onChanged: (v) => _referenceNumber = v,
                   ),
                   const SizedBox(height: 16),
                   
                   TextFormField(
                     maxLines: 3,
                      decoration: const InputDecoration(labelText: "Notes (Optional)"),
                     onChanged: (v) => _notes = v,
                   ),
                   
                   const SizedBox(height: 48),
                   SizedBox(
                     width: double.infinity,
                     height: 56,
                     child: ElevatedButton(
                       onPressed: _loading ? null : _savePayment,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.primaryBlue, 
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         elevation: 0,
                       ),
                       child: _loading 
                           ? const CircularProgressIndicator(color: Colors.white) 
                           : const Text("Save Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                     ),
                   ),
                   const SizedBox(height: 40),
                ],
              ),
            ),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(color: context.surfaceBg),
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
              if (_customerId == null) Text("Tap to search customers", style: TextStyle(fontSize: 12, color: context.textSecondary)),
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
    
    // Sheet-like selector using InkWell + ShowModal
    return InkWell(
      onTap: _showInvoicePickerSheet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.receipt_long, color: Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_invoiceId != null ? "${_invoiceNumber ?? 'Unknown'} (Bal: ₹$_invoiceBalance)" : "Select Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
              if (_invoiceId == null) Text("Tap to select invoice", style: TextStyle(fontSize: 12, color: context.textSecondary)),
            ])),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
  
  void _showInvoicePickerSheet() {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _unpaidInvoices.where((inv) => 
            inv['invoice_number'].toString().toLowerCase().contains(searchQuery.toLowerCase())
          ).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: context.surfaceBg),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
                Padding(padding: const EdgeInsets.all(16), child: Text("Select Invoice", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary))),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: "Search Invoice Number...",
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
                  itemBuilder: (context, index) {
                    final inv = filtered[index];
                    final isSelected = _invoiceId == inv['id'].toString();
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primaryBlue : context.borderColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text("${inv['invoice_number']}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
                        subtitle: Text("Date: ${DateFormat('dd MMM').format(DateTime.parse(inv['date'] ?? inv['invoice_date']))}", style: TextStyle(color: context.textSecondary, fontSize: 12)),
                        trailing: Text("₹${inv['balance_amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), // Show Balance
                        onTap: () {
                          setState(() {
                            _invoiceId = inv['id'].toString();
                            _invoiceNumber = inv['invoice_number'];
                            _invoiceBalance = (inv['balance_amount'] ?? 0).toDouble();
                            _amount = _invoiceBalance;
                            if (_payments.isNotEmpty) {
                              _payments[0]['amount'] = _amount;
                              _payments[0]['controller'].text = _formatAmount(_amount);
                            }
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                )),
              ],
            ),
          );
        }
      ),
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
    final results = await Supabase.instance.client.from('customers').select().eq('company_id', _companyId!);
    if (!mounted) return;
    
    String searchQuery = "";
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = results.where((c) => 
            c['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            (c['phone']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false)
          ).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: context.surfaceBg),
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.all(16), child: Text("Select Customer", style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  decoration: InputDecoration(
                    hintText: "Search customer name or phone...",
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
                        _customerId = filtered[i]['id'].toString();
                        _customerName = filtered[i]['name'];
                        _invoiceId = null; 
                        _unpaidInvoices = [];
                      });
                      _fetchUnpaidInvoices();
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
  Future<void> _savePayment() async {
    if (_customerId == null) { StatusService.show(context, "Select customer"); return; }
    if (_invoiceId == null) { StatusService.show(context, "Select invoice"); return; }
    
    final finalPayments = _payments.map((p) => {
      'mode': p['mode'],
      'amount': double.tryParse(p['controller'].text) ?? 0.0,
      'reference': _referenceNumber ?? '',
    }).where((p) => (p['amount'] as double) > 0).toList();

    if (finalPayments.isEmpty) {
      StatusService.show(context, "Enter payment amount");
      return;
    }

    double totalAmt = finalPayments.fold(0.0, (sum, p) => sum + (p['amount'] as double));
    if (_invoiceId != null && totalAmt > _invoiceBalance + 0.99) {
      StatusService.show(context, "Total amount exceeds balance (₹$_invoiceBalance)");
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      final actualNumber = await NumberingService.getNextDocumentNumber(
        companyId: _companyId!,
        documentType: 'SALES_PAYMENT',
        branchId: _branchId,
        previewOnly: false,
      );

      final isMulti = finalPayments.length > 1;

      final paymentPayload = {
        'company_id': _companyId,
        'branch_id': _branchId,
        'customer_id': _customerId,
        'payment_number': actualNumber,
        'date': _paymentDate.toIso8601String(),
        'amount': totalAmt,
        'payment_mode': isMulti ? 'Multi' : finalPayments[0]['mode'],
        'reference_number': _referenceNumber,
        'notes': _notes,
        'created_by': _internalUserId,
        'is_active': true,
        'payment_methods': finalPayments, // Store splits for multi-mode
      };

      final payment = await Supabase.instance.client.from('sales_payments').insert(paymentPayload).select().single();

      // 2. Create Allocation
      await Supabase.instance.client.from('sales_payment_allocations').insert({
        'payment_id': payment['id'],
        'invoice_id': _invoiceId,
        'amount': totalAmt,
      });

      // 3. Update Invoice Balance
      final newBalance = _invoiceBalance - totalAmt;
      final newStatus = newBalance <= 0.5 ? 'paid' : 'partially_paid';
      
      await Supabase.instance.client.from('sales_invoices').update({
        'balance_due': newBalance < 0 ? 0 : newBalance,
        'status': newStatus,
      }).eq('id', _invoiceId!);

      SalesRefreshService.triggerRefresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving payment: $e");
      if (mounted) StatusService.show(context, "Error: $e");
    } finally {
       if (mounted) setState(() => _loading = false);
    }
  }
}
