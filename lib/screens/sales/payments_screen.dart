import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'payment_form_screen.dart';
import '../../services/sales_refresh_service.dart';
import 'payment_details_sheet.dart'; // To be created
import 'customers_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final bool showAppBar;
  const PaymentsScreen({super.key, this.showAppBar = true});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _cachedCompanyId;

  @override
  void initState() {
    super.initState();
    _initPayments();
    SalesRefreshService.refreshNotifier.addListener(_fetchPayments);
  }

  Future<void> _initPayments() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _fetchPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    SalesRefreshService.refreshNotifier.removeListener(_fetchPayments);
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      final String companyId;
      if (_cachedCompanyId != null) {
        companyId = _cachedCompanyId!;
      } else {
        final profile = await Supabase.instance.client
            .from('users')
            .select('company_id')
            .eq('auth_id', user.id)
            .maybeSingle();

        if (profile == null || profile['company_id'] == null) {
          debugPrint("Sales Payments: Profile or Company ID not found for user ${user.id}");
          if (mounted) {
            setState(() {
              _payments = [];
              _loading = false;
            });
          }
          return;
        }
        companyId = profile['company_id'];
        _cachedCompanyId = companyId;
      }
      
      var query = Supabase.instance.client
          .from('sales_payments')
          .select('*, customer:customers(name), allocations:sales_payment_allocations(amount, invoice:sales_invoices(invoice_number))')
          .eq('company_id', companyId);
final response = await query.order('date', ascending: false);
      
      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");
      if (mounted) {
        setState(() {
          _payments = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            clipBehavior: Clip.antiAlias,
            useSafeArea: true,
            builder: (c) => const PaymentFormScreen()
          );
          if (result == true) _fetchPayments();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Record Payment", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPayments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearch(),
            _buildPaymentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: context.scaffoldBg,
      elevation: 0,
      title: Text("Payments Received", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
    );
  }

  Widget _buildSearch() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search payment #...",
              hintStyle: TextStyle(color: context.textSecondary.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: context.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
              // Throttle usually, but direct call for now
              _fetchPayments();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentList() {
    final filteredList = _payments.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return item.values.any((v) => v != null && v.toString().toLowerCase().contains(q)) || 
             (item['customer'] != null && item['customer']['name'] != null && item['customer']['name'].toString().toLowerCase().contains(q)) ||
             (item['vendor'] != null && item['vendor']['name'] != null && item['vendor']['name'].toString().toLowerCase().contains(q));
    }).toList();

    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (filteredList.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No payments recorded", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final payment = filteredList[index];
          return _buildPaymentCard(payment);
        },
        childCount: filteredList.length,
      ),
    );
  }
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final date = DateTime.tryParse(payment['date'] ?? payment['payment_date'] ?? '') ?? DateTime.now();
    final amount = (payment['amount'] ?? 0).toDouble();
    final customerName = payment['customer']?['name'] ?? 'Unknown';
    
    // Get invoice number from allocations
    String invoiceNum = 'N/A';
    if (payment['allocations'] != null && (payment['allocations'] as List).isNotEmpty) {
      final firstAlloc = (payment['allocations'] as List).first;
      invoiceNum = firstAlloc['invoice']?['invoice_number'] ?? 'N/A';
    } else if (payment['invoice_number'] != null) {
      invoiceNum = payment['invoice_number'];
    }
    
    final mode = payment['payment_mode'] ?? 'Cash';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            clipBehavior: Clip.antiAlias,
            useSafeArea: true,
            builder: (context) => PaymentDetailsSheet(
              payment: payment,
              onRefresh: _fetchPayments,
            ),
          );
          _fetchPayments();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customerName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    const SizedBox(height: 4),
                    Text("#${payment['payment_number']} • Via $mode", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                    Text("For Inv: $invoiceNum", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.primaryBlue)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${NumberFormat('#,##,##0.00').format(amount)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                  Text(DateFormat('dd MMM').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
