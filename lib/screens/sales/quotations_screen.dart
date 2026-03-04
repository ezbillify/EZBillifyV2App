import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'quotation_form_screen.dart'; // To be created
import 'customers_screen.dart';
import 'quotation_details_sheet.dart';
import '../../services/sales_refresh_service.dart';

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
  bool _showArchived = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  RealtimeChannel? _realtimeChannel;
  String? _cachedCompanyId;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _initQuotations();
    SalesRefreshService.refreshNotifier.addListener(_fetchQuotations);
  }

  Future<void> _initQuotations() async {
    // Staggered delay to prevent DNS query burst across multiple tabs
    await Future.delayed(const Duration(milliseconds: 200));
    await _fetchQuotations();
    if (mounted) _setupRealtime();
  }

  void _setupRealtime() async {
    final companyId = _cachedCompanyId;
    if (companyId == null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('public:sales_quotations:company_id=eq.$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sales_quotations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (payload) {
            debugPrint("Realtime event received: ${payload.eventType}");
            _fetchQuotations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    SalesRefreshService.refreshNotifier.removeListener(_fetchQuotations);
    super.dispose();
  }

  Future<void> _fetchQuotations() async {
    if (_quotations.isEmpty && mounted) setState(() => _loading = true);
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
          debugPrint("Sales Quotations: Profile or Company ID not found for user ${user.id}");
          if (mounted) {
            setState(() {
              _quotations = [];
              _loading = false;
            });
          }
          return;
        }
        companyId = profile['company_id'];
        _cachedCompanyId = companyId;
      }
      
      var query = Supabase.instance.client
          .from('sales_quotations')
          .select('*, customer:customers(name)')
          .eq('company_id', companyId);
          
      if (_showArchived) {
        query = query.eq('is_active', false);
      } else {
        query = query.or('is_active.is.null,is_active.eq.true');
      }

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
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
      if (mounted) {
        setState(() {
          _quotations = [];
          _loading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': 
      case 'converted': 
      case 'converted_to_order':
      case 'converted_to_invoice': return Colors.green;
      case 'sent': return Colors.blue;
      case 'rejected': return Colors.red;
      case 'draft': return Colors.grey;
      case 'expired': return Colors.orange;
      default: return Colors.blueGrey;
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
                    filled: false,
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
                            }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
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
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: context.borderColor),
                const SizedBox(width: 12),
                _buildArchivedToggle(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildQuotationList() {
    final filteredList = _quotations.where((item) {
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
            final quote = filteredList[index];
            return _buildQuotationCard(quote);
          },
          childCount: filteredList.length,
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
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
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

  Widget _buildArchivedToggle() {
    return FilterChip(
      label: const Text("Show Archived"),
      selected: _showArchived,
      onSelected: (v) {
        setState(() => _showArchived = v);
        _fetchQuotations();
      },
      backgroundColor: context.cardBg,
      selectedColor: Colors.red.withOpacity(0.1),
      labelStyle: TextStyle(
        color: _showArchived ? Colors.red : context.textSecondary,
        fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal,
        fontFamily: 'Outfit',
        fontSize: 13,
      ),
      showCheckmark: false,
      avatar: Icon(Icons.archive_outlined, size: 16, color: _showArchived ? Colors.red : context.textSecondary),
      shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: BorderSide(color: _showArchived ? Colors.red : context.borderColor),
      ),
    );
  }
}
