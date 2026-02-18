import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'purchase_payment_form_screen.dart';
import 'purchase_payment_details_sheet.dart';

class PurchasePaymentsScreen extends StatefulWidget {
  final bool showAppBar;
  const PurchasePaymentsScreen({super.key, this.showAppBar = true});

  @override
  State<PurchasePaymentsScreen> createState() => _PurchasePaymentsScreenState();
}

class _PurchasePaymentsScreenState extends State<PurchasePaymentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _payments = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _fetchPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('purchase_payments')
          .select('*, vendor:vendors(name), bill:purchase_bills(bill_number)')
          .eq('company_id', profile['company_id']);

      if (_searchQuery.isNotEmpty) {
        query = query.or('payment_number.ilike.%$_searchQuery%,vendors.name.ilike.%$_searchQuery%');
      }
      
      final response = await query.order('date', ascending: false);
      
      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching payments: $e");
      if (mounted) setState(() => _loading = false);
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
            useSafeArea: true,
            builder: (c) => const PurchasePaymentFormScreen()
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
            _buildSearchAndFilters(),
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
      title: Text("Purchase Payments", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _searchFocusNode.hasFocus ? AppColors.primaryBlue.withOpacity(0.04) : context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.2),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textPrimary),
                  cursorColor: AppColors.primaryBlue,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Search Payment # or vendor...",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.4), fontSize: 15),
                    prefixIcon: Icon(
                      Icons.search_rounded, 
                      color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.4), 
                      size: 22
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.primaryBlue), 
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            _fetchPayments();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchPayments();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPaymentList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_payments.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payments_outlined, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No payments found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final payment = _payments[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildPaymentCard(payment),
            );
          },
          childCount: _payments.length,
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final date = DateTime.tryParse(payment['date']?.toString() ?? '') ?? 
                 DateTime.tryParse(payment['created_at']?.toString() ?? '') ?? 
                 DateTime.now();
    final vendorName = (payment['vendor'] != null && payment['vendor']['name'] != null) 
        ? payment['vendor']['name'].toString() 
        : 'Unknown Vendor';
    final billNumber = (payment['bill'] != null && payment['bill']['bill_number'] != null)
        ? payment['bill']['bill_number']
        : 'N/A';
        
    final amount = (payment['amount'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            builder: (context) => PurchasePaymentDetailsSheet(
              payment: payment,
              onRefresh: _fetchPayments,
            ),
          );
          _fetchPayments();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Expanded(
                     child: Row(
                       children: [
                         Flexible(
                           child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(payment['payment_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue), overflow: TextOverflow.ellipsis),
                          ),
                         ),
                         const SizedBox(width: 8),
                         Flexible(child: Text("For Bill: $billNumber", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary), overflow: TextOverflow.ellipsis)),
                       ],
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text("₹${NumberFormat('#,##,###.00').format(amount)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.account_balance_wallet_outlined, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendorName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                        Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.borderColor)),
                    child: Text(payment['mode']?.toString().toUpperCase() ?? 'CASH', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: context.textSecondary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
