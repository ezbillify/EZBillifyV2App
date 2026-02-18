import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'purchase_debit_note_form_screen.dart';
import 'purchase_debit_note_details_sheet.dart';

class PurchaseDebitNotesScreen extends StatefulWidget {
  final bool showAppBar;
  const PurchaseDebitNotesScreen({super.key, this.showAppBar = true});

  @override
  State<PurchaseDebitNotesScreen> createState() => _PurchaseDebitNotesScreenState();
}

class _PurchaseDebitNotesScreenState extends State<PurchaseDebitNotesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notes = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() { if (mounted) setState(() {}); });
    _fetchDebitNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDebitNotes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('purchase_debit_notes')
          .select('*, vendor:vendors(name)')
          .eq('company_id', profile['company_id']);

      if (_searchQuery.isNotEmpty) {
        query = query.or('debit_note_number.ilike.%$_searchQuery%,vendors.name.ilike.%$_searchQuery%');
      }
      
      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _notes = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching debit notes: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDebitNoteFormScreen()));
          if (result == true) _fetchDebitNotes();
        },
        backgroundColor: Colors.red[400],
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Debit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDebitNotes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (widget.showAppBar) _buildAppBar(),
            _buildSearchAndFilters(),
            _buildNoteList(),
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
      title: Text("Debit Notes", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
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
                    hintText: "Search Debit Note # or vendor...",
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
                            _fetchDebitNotes();
                          }
                        ) 
                      : null,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    _fetchDebitNotes();
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

  Widget _buildNoteList() {
    if (_loading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    if (_notes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.remove_circle_outline_rounded, size: 64, color: context.textSecondary.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text("No debit notes found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
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
            final note = _notes[index];
            return FadeInUp(
              duration: Duration(milliseconds: 400 + (index % 5 * 100)),
              child: _buildNoteCard(note),
            );
          },
          childCount: _notes.length,
        ),
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final date = DateTime.tryParse(note['date']?.toString() ?? '') ?? 
                 DateTime.tryParse(note['created_at']?.toString() ?? '') ?? 
                 DateTime.now();
    final vendorName = (note['vendor'] != null && note['vendor']['name'] != null) 
        ? note['vendor']['name'].toString() 
        : 'Unknown Vendor';
    final amount = (note['total_amount'] ?? 0).toDouble();

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
            builder: (context) => PurchaseDebitNoteDetailsSheet(
              debitNote: note,
              onRefresh: _fetchDebitNotes,
            ),
          );
          _fetchDebitNotes();
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
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(note['debit_note_number'] ?? '#---', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                  ),
                  Text("₹${NumberFormat('#,##,###.00').format(amount)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.replay_rounded, color: context.textSecondary.withOpacity(0.5), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendorName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary)),
                         Text("${DateFormat('dd MMM, yyyy').format(date)} • ${note['reason'] ?? 'Return'}", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
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
}
