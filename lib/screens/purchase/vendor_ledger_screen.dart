import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme_service.dart';

class VendorLedgerScreen extends StatefulWidget {
  final String vendorId;
  final String vendorName;

  const VendorLedgerScreen({super.key, required this.vendorId, required this.vendorName});

  @override
  State<VendorLedgerScreen> createState() => _VendorLedgerScreenState();
}

class _VendorLedgerScreenState extends State<VendorLedgerScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _ledgerEntries = [];
  double _openingBalance = 0;
  double _currentBalance = 0; // Negative means we owe them (Credit), Positive means they owe us (Debit)

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() => _loading = true);
    try {
      final vendorId = widget.vendorId;
      
      // Fetch Bills
      final billsRes = await Supabase.instance.client.from('purchase_bills').select('id, bill_number, date, total_amount, paid_amount').eq('vendor_id', vendorId).neq('status', 'cancelled');
      // Fetch Payments
      final paymentsRes = await Supabase.instance.client.from('purchase_payments').select('id, payment_number, date, amount, mode').eq('vendor_id', vendorId);
      // Fetch Debit Notes
      final debitNotesRes = await Supabase.instance.client.from('purchase_debit_notes').select('id, dn_number, date, total_amount, status').eq('vendor_id', vendorId).neq('status', 'cancelled');
      
      List<Map<String, dynamic>> entries = [];
      
      for (var b in billsRes) {
        entries.add(<String, dynamic>{
          'type': 'BILL',
          'id': b['id'],
          'number': b['bill_number'],
          'date': DateTime.parse(b['date']),
          'debit': 0.0,
          'credit': (b['total_amount'] ?? 0).toDouble(), // Increase payable
          'desc': 'Purchase Bill'
        });
      }
      
      for (var p in paymentsRes) {
        entries.add(<String, dynamic>{
          'type': 'PAYMENT',
          'id': p['id'],
          'number': p['payment_number'],
          'date': DateTime.parse(p['date']),
          'debit': (p['amount'] ?? 0).toDouble(), // Decrease payable
          'credit': 0.0,
          'desc': 'Payment: ${p['mode']}'
        });
      }

      for (var d in debitNotesRes) {
        entries.add(<String, dynamic>{
          'type': 'DEBIT_NOTE',
          'id': d['id'],
          'number': d['dn_number'],
          'date': DateTime.parse(d['date']),
          'debit': (d['total_amount'] ?? 0).toDouble(), // Decrease payable
          'credit': 0.0,
          'desc': 'Debit Note'
        });
      }

      // Sort chronological
      entries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      
      double runningBal = 0;
      for (var e in entries) {
        runningBal += (e['credit'] as double) - (e['debit'] as double); // Positive means we owe them (Payable)
        e['balance'] = runningBal;
      }

      setState(() {
        _ledgerEntries = entries.reversed.toList(); // Newest first
        _currentBalance = runningBal;
      });
    } catch (e) {
      debugPrint("Error loading ledger: \$e");
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
          children: [
            Text('Vendor Ledger', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary)),
            Text(widget.vendorName, style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: context.surfaceBg, border: Border(bottom: BorderSide(color: context.borderColor))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Closing Balance", style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.bold)),
                          Text("₹\${_currentBalance.toStringAsFixed(2)}", style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold, color: _currentBalance > 0 ? Colors.red : Colors.green)),
                          Text(_currentBalance > 0 ? "You Owe" : (_currentBalance < 0 ? "Vendor Owes You" : "Settled"), style: TextStyle(fontSize: 12, color: context.textSecondary)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryBlue),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _ledgerEntries.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final entry = _ledgerEntries[index];
                      final date = DateFormat('dd MMM, yyyy').format(entry['date']);
                      final isCredit = entry['credit'] > 0;
                      final amount = isCredit ? entry['credit'] : entry['debit'];
                      final bal = entry['balance'];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor)
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isCredit ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCredit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                color: isCredit ? Colors.red : Colors.green,
                                size: 16,
                              )
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry['desc'], style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary, fontFamily: 'Outfit')),
                                  Text("\${entry['number']} • \$date", style: TextStyle(fontSize: 12, color: context.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹\${amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary, fontFamily: 'Outfit')),
                                Text("Bal: ₹\${bal.toStringAsFixed(2)}", style: TextStyle(fontSize: 11, color: context.textSecondary)),
                              ],
                            )
                          ],
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
    );
  }
}
