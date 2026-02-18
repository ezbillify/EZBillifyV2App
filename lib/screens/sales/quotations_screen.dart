import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'quotation_form_screen.dart'; // To be created
import 'customers_screen.dart';
import 'quotation_details_sheet.dart';

class QuotationsScreen extends StatefulWidget {
  final bool showAppBar;
  const QuotationsScreen({super.key, this.showAppBar = true});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _quotations = [];
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _fetchQuotations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchQuotations() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('sales_quotations')
          .select('*, customer:customers(name)')
          .eq('company_id', profile['company_id']);
          
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.or('quote_number.ilike.%$_searchQuery%,customers.name.ilike.%$_searchQuery%');
      }
      
      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _quotations = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching quotations: $e");
      // Fallback for demo if table doesn't exist yet
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.green;
      case 'sent': return Colors.blue;
      case 'rejected': return Colors.red;
      case 'draft': return Colors.grey;
      case 'expired': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const QuotationFormScreen()));
          if (result == true) _fetchQuotations();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Create Quote", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchQuotations,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearchAndFilters(),
            _buildQuotationList(),
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
      title: Text("Quotations / Estimates", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
      actions: [
        IconButton(
          icon: Icon(Icons.people_alt_outlined, color: context.textPrimary),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomersScreen())),
        ),
        const SizedBox(width: 8),
      ],
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
                    hintText: "Search quote # or customer...",
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
                            _fetchQuotations();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchQuotations();
                  },
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All Quotes', 'all'),
                _buildFilterChip('Draft', 'draft'),
                _buildFilterChip('Sent', 'sent'),
                _buildFilterChip('Accepted', 'accepted'),
                _buildFilterChip('Rejected', 'rejected'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuotationList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_quotations.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.request_quote_outlined, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No quotations found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
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
            final quote = _quotations[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildQuotationCard(quote),
            );
          },
          childCount: _quotations.length,
        ),
      ),
    );
  }

  Widget _buildQuotationCard(Map<String, dynamic> quote) {
    final status = quote['status'] ?? 'Draft';
    final statusColor = _getStatusColor(status);
    final date = DateTime.tryParse(quote['quotation_date']?.toString() ?? '') ?? DateTime.now();
    final customerName = (quote['customer'] != null && quote['customer']['name'] != null) 
        ? quote['customer']['name'].toString() 
        : 'Unknown Customer';

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
            builder: (context) => QuotationDetailsSheet(
              quotation: quote,
              onRefresh: _fetchQuotations,
            ),
          );
          _fetchQuotations();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(quote['quote_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 10, color: statusColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.business_rounded, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customerName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                        Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${NumberFormat('#,##,###.00').format(quote['total_amount'] ?? 0)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (v) {
          setState(() => _filterStatus = value);
          _fetchQuotations();
        },
        backgroundColor: context.cardBg,
        selectedColor: AppColors.primaryBlue.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primaryBlue : context.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'Outfit',
          fontSize: 13,
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
           side: BorderSide(color: isSelected ? AppColors.primaryBlue : context.borderColor),
        ),
      ),
    );
  }
}
