import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'purchase_grn_form_screen.dart';
import 'purchase_grn_details_sheet.dart';
import '../../services/purchase_refresh_service.dart';

class PurchaseGrnsScreen extends StatefulWidget {
  final bool showAppBar;
  const PurchaseGrnsScreen({super.key, this.showAppBar = true});

  @override
  State<PurchaseGrnsScreen> createState() => _PurchaseGrnsScreenState();
}

class _PurchaseGrnsScreenState extends State<PurchaseGrnsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _grns = [];
  String _filterStatus = 'all';
  String _searchQuery = '';
  String _sortBy = 'created_at';
  bool _sortAscending = false;
  bool _showArchived = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _cachedCompanyId;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _initGrns();
    PurchaseRefreshService.refreshNotifier.addListener(_fetchGrns);
  }

  Future<void> _initGrns() async {
    // 500ms stagger for purchase GRN tab
    await Future.delayed(const Duration(milliseconds: 500));
    await _fetchGrns();
    if (mounted) _setupRealtime();
  }

  void _setupRealtime() {
    final companyId = _cachedCompanyId;
    if (companyId == null) return;
    
    _realtimeChannel = Supabase.instance.client
        .channel('public:purchase_grns:company_id=eq.$companyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'purchase_grns',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: companyId,
          ),
          callback: (payload) => _fetchGrns(),
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
    PurchaseRefreshService.refreshNotifier.removeListener(_fetchGrns);
    super.dispose();
  }

  Future<void> _fetchGrns() async {
    if (_grns.isEmpty && mounted) setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
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
          if (mounted) setState(() => _loading = false);
          return;
        }
        companyId = profile['company_id'];
        _cachedCompanyId = companyId;
      }
      
      var query = Supabase.instance.client
          .from('purchase_grns')
          .select('*, vendor:vendors(name)')
          .eq('company_id', companyId);

      if (_showArchived) {
        query = query.eq('is_active', false);
      } else {
        query = query.or('is_active.is.null,is_active.eq.true');
      }
          
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.or('grn_number.ilike.%$_searchQuery%');
      }
      
      final response = await query.order(_sortBy, ascending: _sortAscending);
      
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(response);
      
      if (_searchQuery.isNotEmpty) {
        results = results.where((o) {
          final grnMatch = (o['grn_number'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
          final vendorMatch = (o['vendor']?['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
          final refMatch = (o['reference_number'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
          return grnMatch || vendorMatch || refMatch;
        }).toList();
      }
      
      if (mounted) {
        setState(() {
          _grns = results;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching GRNs: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseGrnFormScreen()));
          if (result == true) _fetchGrns();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Receive Goods", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGrns,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearchAndFilters(),
            _buildGrnList(),
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
      title: Text("Goods Received Notes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.sort_rounded, color: context.textPrimary),
          onSelected: (val) {
            setState(() {
              if (val == 'newest') { _sortBy = 'created_at'; _sortAscending = false; }
              else if (val == 'oldest') { _sortBy = 'created_at'; _sortAscending = true; }
            });
            _fetchGrns();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'newest', child: Text('Newest First')),
            const PopupMenuItem(value: 'oldest', child: Text('Oldest First')),
          ],
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
                    hintText: "Search GRN # or vendor...",
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
                            _fetchGrns();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchGrns();
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
                _buildFilterChip('All GRNs', 'all'),
                _buildFilterChip('Received', 'received'),
                _buildFilterChip('Draft', 'draft'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildArchivedToggle(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
          _fetchGrns();
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

  Widget _buildGrnList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_grns.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_rounded, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No GRNs found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
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
            final grn = _grns[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildGrnCard(grn),
            );
          },
          childCount: _grns.length,
        ),
      ),
    );
  }

  Widget _buildGrnCard(Map<String, dynamic> grn) {
    final date = DateTime.tryParse(grn['date']?.toString() ?? '') ?? 
                 DateTime.tryParse(grn['created_at']?.toString() ?? '') ?? 
                 DateTime.now();
    final vendorName = (grn['vendor'] != null && grn['vendor']['name'] != null) 
        ? grn['vendor']['name'].toString() 
        : 'Unknown Vendor';

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
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            clipBehavior: Clip.antiAlias,
            useSafeArea: true,
            builder: (context) => PurchaseGrnDetailsSheet(
              grn: grn,
              onRefresh: _fetchGrns,
            ),
          );
          _fetchGrns();
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
                    child: Text(grn['grn_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue)),
                  ),
                  Text(DateFormat('dd MMM, yyyy').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.assignment_returned_outlined, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendorName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                        if (grn['reference_number'] != null && grn['reference_number'].toString().isNotEmpty)
                          Text("Inv #: ${grn['reference_number']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                        if (grn['po_id'] != null) Text("Linked PO Available", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        _fetchGrns();
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
