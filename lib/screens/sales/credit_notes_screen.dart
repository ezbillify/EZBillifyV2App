import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme_service.dart';
import 'credit_note_form_screen.dart';
import 'credit_note_details_sheet.dart'; // To be created
import 'customers_screen.dart';

class CreditNotesScreen extends StatefulWidget {
  final bool showAppBar;
  const CreditNotesScreen({super.key, this.showAppBar = true});

  @override
  State<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends State<CreditNotesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _creditNotes = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCreditNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCreditNotes() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('sales_credit_notes')
          .select('*, customer:customers(name), invoice:sales_invoices(invoice_number)')
          .eq('company_id', profile['company_id']);
          
      if (_searchQuery.isNotEmpty) {
        query = query.or('cn_number.ilike.%$_searchQuery%');
      }
      
      final response = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _creditNotes = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching credit notes: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (c) => const CreditNoteFormScreen()));
          if (result == true) _fetchCreditNotes();
        },
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Credit Note", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: CustomScrollView(
        slivers: [
          if (widget.showAppBar) SliverAppBar(
            pinned: true,
            backgroundColor: context.scaffoldBg,
            elevation: 0,
            title: Text("Credit Notes (Returns)", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search credit note #...",
                    hintStyle: TextStyle(color: context.textSecondary.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: context.textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onChanged: (v) { setState(() => _searchQuery = v); _fetchCreditNotes(); },
                ),
              ),
            ),
          ),
          if (_loading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_creditNotes.isEmpty)
             SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_return_outlined, size: 64, color: context.textSecondary.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text("No credit notes found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cn = _creditNotes[index];
                  final date = DateTime.tryParse(cn['credit_note_date'] ?? '') ?? DateTime.now();
                  final amount = (cn['total_amount'] ?? 0).toDouble();
                  final customerName = cn['customer']?['name'] ?? 'Unknown';
                  
                  return FadeInUp(
                    duration: Duration(milliseconds: 300 + (index % 5 * 100)),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            useSafeArea: true,
                            builder: (context) => CreditNoteDetailsSheet(
                              creditNote: cn,
                              onRefresh: _fetchCreditNotes,
                            ),
                          );
                          _fetchCreditNotes();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.undo_rounded, color: Colors.red, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customerName, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary)),
                                    Text("#${cn['cn_number'] ?? cn['credit_note_number']}", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.primaryBlue)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("-₹${NumberFormat('#,##,##0.00').format(amount)}", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                                  Text(DateFormat('dd MMM').format(date), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _creditNotes.length,
              ),
            ),
        ],
      ),
    );
  }
}
