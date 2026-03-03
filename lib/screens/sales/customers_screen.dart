import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_service.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  final bool isSelecting; // If true, return selected customer
  const CustomersScreen({super.key, this.isSelecting = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _customers = [];
  String _searchQuery = '';
  String _sortBy = 'created_at';
  bool _sortAscending = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomers() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('customers')
          .select()
          .eq('company_id', profile['company_id']);
final response = await query.order(_sortBy, ascending: _sortAscending);
      
      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCustomerDetailSheet(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
       shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Material(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          elevation: 16,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    _buildDetailHeader(customer),
                    const SizedBox(height: 32),
                    _buildQuickContactActions(customer),
                    const SizedBox(height: 32),
                    _buildStatsCards(customer),
                    const SizedBox(height: 32),
                    _buildRecentTransactionsSection(customer),
                    const SizedBox(height: 32),
                    _buildInfoSection(customer),
                    const SizedBox(height: 32),
                    _buildAddressSection(customer),
                    const SizedBox(height: 40),
                    _buildBottomActions(customer),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection(Map<String, dynamic> customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("Recent Transactions"),
            TextButton(
              onPressed: () {
                // Navigate to Ledger/Transactions Screen
              },
              child: const Text("View All", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchCustomerTransactions(customer['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor),
                ),
                child: Center(
                  child: Text(
                    "No recent transactions",
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary),
                  ),
                ),
              );
            }

            final txs = snapshot.data!;
            return Column(
              children: txs.map((tx) => _buildTransactionItem(tx)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final date = tx['invoice_date'] ?? tx['created_at'];
    final formattedDate = date != null ? DateFormat('dd MMM, yyyy').format(DateTime.parse(date)) : 'N/A';
    final amount = (tx['total_amount'] ?? 0.0).toDouble();
    final status = tx['status'] ?? 'Draft';
    final isOverdue = (tx['balance_amount'] ?? 0.0) > 0 && DateTime.parse(date).isBefore(DateTime.now().subtract(const Duration(days: 30))); // Mock logic

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (status == 'Paid' ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == 'Paid' ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: status == 'Paid' ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx['invoice_number'] ?? '#---',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹${NumberFormat('#,##,###').format(amount)}",
                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: status == 'Paid' ? Colors.green : Colors.orange,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCustomerTransactions(String customerId) async {
    try {
      final response = await Supabase.instance.client
          .from('sales_invoices')
          .select()
          .eq('customer_id', customerId)
          .order('invoice_date', ascending: false)
          .limit(3);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching txs: $e");
      return [];
    }
  }

  Widget _buildDetailHeader(Map<String, dynamic> customer) {
    final name = customer['name'] ?? 'Unknown';
    final type = customer['customer_type'] ?? 'B2C';

    return Column(
      children: [
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FadeInUp(
          delay: const Duration(milliseconds: 100),
          duration: const Duration(milliseconds: 600),
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 600),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: (type == 'B2B' ? Colors.purple : Colors.blue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              type == 'B2B' ? "BUSINESS (B2B)" : "CONSUMER (B2C)",
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: type == 'B2B' ? Colors.purple : Colors.blue,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickContactActions(Map<String, dynamic> customer) {
    final phone = customer['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    final hasPhone = phone.length == 10;
    final formattedPhone = hasPhone ? "+91$phone" : customer['phone'];
    final whatsappPhone = hasPhone ? "91$phone" : phone;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildContactBtn(Icons.phone_rounded, "Call", const Color(0xFF10B981), () => _launchURL("tel:$formattedPhone")),
        _buildContactBtn(Icons.message_rounded, "Message", const Color(0xFF3B82F6), () => _launchURL("sms:$formattedPhone")),
        _buildContactBtn(Icons.mail_rounded, "Email", const Color(0xFFF59E0B), () => _launchURL("mailto:${customer['email']}")),
        _buildContactBtn(Icons.chat_bubble_rounded, "WhatsApp", const Color(0xFF22C55E), () => _launchURL("https://api.whatsapp.com/send?phone=$whatsappPhone")),
      ],
    );
  }

  Widget _buildContactBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 11,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(Map<String, dynamic> customer) {
    final balance = (customer['balance_amount'] ?? 0.0).toDouble();
    // In a real app, these would come from joined sales data
    final totalSales = (customer['total_sales'] ?? 0.0).toDouble();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Receivables",
            "₹${NumberFormat('#,##,###').format(balance)}",
            Icons.account_balance_wallet_rounded,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            "Total Sales",
            "₹${NumberFormat('#,##,###').format(totalSales)}",
            Icons.payments_rounded,
            const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> customer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Business Information"),
        const SizedBox(height: 16),
        _buildDetailRow("Email Address", customer['email'] ?? "N/A", Icons.alternate_email_rounded),
        _buildDetailRow("Phone Number", customer['phone'] ?? "N/A", Icons.phone_iphone_rounded),
        _buildDetailRow("GSTIN Number", customer['gstin'] ?? "Unregistered", Icons.verified_user_rounded),
        _buildDetailRow("Credit Limit", customer['credit_limit'] != null ? "₹${customer['credit_limit']}" : "No Limit", Icons.speed_rounded),
      ],
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> customer) {
    final billing = customer['billing_address'] ?? {};
    final addressStr = [
      billing['street'],
      billing['city'],
      billing['state'],
      billing['postal_code'],
      billing['country']
    ].where((e) => e != null && e.toString().isNotEmpty).join(", ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Billing Address"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  addressStr.isEmpty ? "No address specified" : addressStr,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: context.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Outfit',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.textSecondary.withOpacity(0.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: context.textSecondary),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(Map<String, dynamic> customer) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showLedgerSheet(customer),
            icon: const Icon(Icons.analytics_rounded, size: 20),
            label: const Text("View Account Ledger", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 4,
              shadowColor: AppColors.primaryBlue.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close detail sheet
                  _showCustomerFormSheet(customer: customer); // Open form sheet
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text("Edit Details", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: context.borderColor),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLedgerSheet(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Material(
          color: context.surfaceBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          elevation: 8,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_rounded, color: AppColors.primaryBlue, size: 28),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Detailed Ledger", style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary)),
                        Text(customer['name'] ?? '', style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                     Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: AppColors.primaryBlue.withOpacity(0.05),
                         borderRadius: BorderRadius.circular(24),
                       ),
                       child: Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text("Net Balance", style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
                               const SizedBox(height: 4),
                               Text("₹${NumberFormat('#,##,###').format(customer['balance_amount'] ?? 0)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                             ],
                           ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: (customer['balance_amount'] ?? 0) > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(12),
                             ),
                             child: Text(
                               (customer['balance_amount'] ?? 0) > 0 ? "PAYABLE" : "SETTLED",
                               style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: (customer['balance_amount'] ?? 0) > 0 ? Colors.red : Colors.green),
                             ),
                           ),
                         ],
                       ),
                     ),
                     const SizedBox(height: 24),
                     _buildSectionHeader("Transaction History"),
                     const SizedBox(height: 16),
                     // Mocked or Real Ledger Items
                     FutureBuilder<List<Map<String, dynamic>>>(
                       future: _fetchCustomerTransactions(customer['id']),
                       builder: (context, snapshot) {
                         if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                         return Column(
                           children: snapshot.data!.map((tx) => _buildLedgerItem(tx)).toList(),
                         );
                       }
                     ),
                     const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerItem(Map<String, dynamic> tx) {
    final amount = (tx['total_amount'] ?? 0.0).toDouble();
    final balance = (tx['balance_amount'] ?? 0.0).toDouble();
    final isInvoice = true; // For now

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isInvoice ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isInvoice ? Icons.receipt_long_rounded : Icons.payments_rounded, color: isInvoice ? Colors.blue : Colors.green, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['invoice_number'] ?? 'TXN', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                Text(DateFormat('dd MMM, yyyy').format(DateTime.parse(tx['invoice_date'])), style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("₹${NumberFormat('#,##,###').format(amount)}", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15)),
              if (balance > 0)
                Text("Due: ₹${NumberFormat('#,##,###').format(balance)}", style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for Android 11+ if canLaunchUrl returns false despite queries
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Customers", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerFormSheet(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text("New Customer", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
        elevation: 4,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _searchFocusNode.hasFocus 
                  ? AppColors.primaryBlue.withOpacity(0.04) 
                  : context.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _searchFocusNode.hasFocus 
                    ? AppColors.primaryBlue 
                    : context.textSecondary.withOpacity(0.2),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: TextField(
                  focusNode: _searchFocusNode,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: context.textPrimary),
                  cursorColor: AppColors.primaryBlue,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: "Search by name, email or phone...",
                    hintStyle: TextStyle(
                      fontFamily: 'Outfit', 
                      color: context.textSecondary.withOpacity(0.4), 
                      fontSize: 15
                    ),
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
                            setState(() => _searchQuery = '');
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
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator()) 
              : RefreshIndicator(
                  onRefresh: _fetchCustomers,
                  child: Builder(
                    builder: (context) {
                      final filteredCustomers = _customers.where((c) {
                        if (_searchQuery.isEmpty) return true;
                        final q = _searchQuery.toLowerCase();
                        final name = (c['name'] ?? '').toString().toLowerCase();
                        final email = (c['email'] ?? '').toString().toLowerCase();
                        final phone = (c['phone'] ?? '').toString().toLowerCase();
                        final gstin = (c['gstin'] ?? '').toString().toLowerCase();
                        return name.contains(q) || email.contains(q) || phone.contains(q) || gstin.contains(q);
                      }).toList();
                      if (filteredCustomers.isEmpty) return _buildEmptyState();
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return _buildCustomerCard(customer);
                        },
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }
  void _showSortSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Material(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        elevation: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.sort_rounded, color: AppColors.primaryBlue),
                  const SizedBox(width: 16),
                  Text("Sort Customers", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary)),
                ],
              ),
            ),
            _buildSortOption("Name (A-Z)", 'name', true),
            _buildSortOption("Name (Z-A)", 'name', false),
            _buildSortOption("Newest First", 'created_at', false),
            _buildSortOption("Oldest First", 'created_at', true),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String field, bool ascending) {
    bool isSelected = _sortBy == field && _sortAscending == ascending;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _sortBy = field;
          _sortAscending = ascending;
          _loading = true;
        });
        Navigator.pop(context);
        _fetchCustomers();
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          field == 'name' ? Icons.sort_by_alpha_rounded : Icons.calendar_today_rounded,
          size: 20,
          color: isSelected ? AppColors.primaryBlue : context.textSecondary,
        ),
      ),
      title: Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue) : null,
    );
  }


  void _showCustomerFormSheet({Map<String, dynamic>? customer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => CustomerFormScreen(
          customer: customer,
          isSheet: true,
        ),
      ),
    ).then((_) => _fetchCustomers());
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final name = customer['name'] ?? 'Unknown';
    final billing = customer['billing_address'] ?? {};
    final balance = (customer['balance_amount'] ?? 0.0).toDouble();

    return FadeInUp(
      duration: Duration(milliseconds: 400 + (100 * (_customers.indexOf(customer) % 5))),
      child: InkWell(
        onTap: widget.isSelecting 
            ? () => Navigator.pop(context, customer)
            : () => _showCustomerDetailSheet(customer),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer['phone'] ?? (customer['email'] ?? 'No contact info'),
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: context.textSecondary),
                    ),
                  ],
                ),
              ),
              if (balance > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "OUTSTANDING",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: 0.5),
                    ),
                    Text(
                      "₹${NumberFormat('#,##,###').format(balance)}",
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14),
                    ),
                  ],
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: context.textSecondary.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline_rounded, size: 64, color: AppColors.primaryBlue.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Customers Yet",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Start by adding your first customer.",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }
}

