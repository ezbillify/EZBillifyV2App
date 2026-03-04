import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_service.dart';
import 'vendor_form_screen.dart';
import 'vendor_ledger_screen.dart';
import 'package:ez_billify_v2_app/services/status_service.dart';

class VendorsScreen extends StatefulWidget {
  final bool isSelecting; // If true, return selected vendor
  const VendorsScreen({super.key, this.isSelecting = false});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _vendors = [];
  String _searchQuery = '';
  String _sortBy = 'created_at';
  bool _sortAscending = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchVendors();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      final profile = await Supabase.instance.client
          .from('users')
          .select('company_id')
          .eq('auth_id', user.id)
          .single();
      
      var query = Supabase.instance.client
          .from('vendors')
          .select()
          .eq('company_id', profile['company_id']);
          
      if (_searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$_searchQuery%,email.ilike.%$_searchQuery%,phone.ilike.%$_searchQuery%');
      }
      
      final response = await query.order(_sortBy, ascending: _sortAscending);
      
      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching vendors: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVendorDetailSheet(Map<String, dynamic> vendor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DraggableScrollableSheet(
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
                    color: context.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    children: [
                      _buildDetailHeader(vendor),
                      const SizedBox(height: 32),
                      _buildQuickContactActions(vendor),
                      const SizedBox(height: 32),
                      _buildStatsCards(vendor),
                      const SizedBox(height: 32),
                      _buildInfoSection(vendor),
                      const SizedBox(height: 32),
                      _buildAddressSection(vendor),
                      const SizedBox(height: 40),
                      _buildBottomActions(vendor),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> vendor) {
    final name = vendor['name'] ?? 'Unknown';
    final contactPerson = vendor['contact_person'] ?? '';

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
                name.isNotEmpty ? name[0].toUpperCase() : '?',
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
        if (contactPerson.isNotEmpty) ...[
          const SizedBox(height: 8),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                contactPerson.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickContactActions(Map<String, dynamic> vendor) {
    final phone = vendor['phone']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
    final hasPhone = phone.length == 10;
    final formattedPhone = hasPhone ? "+91$phone" : vendor['phone'];
    final whatsappPhone = hasPhone ? "91$phone" : phone;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildContactBtn(Icons.phone_rounded, "Call", const Color(0xFF10B981), () => _launchURL("tel:$formattedPhone")),
        _buildContactBtn(Icons.message_rounded, "Message", const Color(0xFF3B82F6), () => _launchURL("sms:$formattedPhone")),
        _buildContactBtn(Icons.mail_rounded, "Email", const Color(0xFFF59E0B), () => _launchURL("mailto:${vendor['email']}")),
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

  Widget _buildStatsCards(Map<String, dynamic> vendor) {
    final balance = (vendor['balance_amount'] ?? 0.0).toDouble(); // Assuming vendors table might have this or it's calculated
    // In a real app, join purchase data. For now, use opening_balance if balance not available?
    // The schema has opening_balance. Real balance might require calculation from bills.
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Payables",
            "₹${NumberFormat('#,##,###').format(balance)}",
            Icons.account_balance_wallet_rounded,
            Colors.red,
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

  Widget _buildInfoSection(Map<String, dynamic> vendor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Vendor Information"),
        const SizedBox(height: 16),
        _buildDetailRow("Email Address", vendor['email'] ?? "N/A", Icons.alternate_email_rounded),
        _buildDetailRow("Phone Number", vendor['phone'] ?? "N/A", Icons.phone_iphone_rounded),
        _buildDetailRow("GSTIN Number", vendor['gstin'] ?? "Unregistered", Icons.verified_user_rounded),
        _buildDetailRow("PAN Number", vendor['pan'] ?? "N/A", Icons.badge_rounded),
        _buildDetailRow("Payment Terms", vendor['payment_terms'] ?? "N/A", Icons.handshake_rounded),
      ],
    );
  }

  Widget _buildAddressSection(Map<String, dynamic> vendor) {
    final address = vendor['address'] ?? {};
    final addressStr = [
      address['line1'],
      address['city'],
      address['state'],
      address['pincode'],
      address['country']
    ].where((e) => e != null && e.toString().isNotEmpty).join(", ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Address"),
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

  Widget _buildBottomActions(Map<String, dynamic> vendor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close detail sheet
                  _showVendorFormSheet(vendor: vendor);
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
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close detail sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => VendorLedgerScreen(
                        vendorId: vendor['id'].toString(),
                        vendorName: vendor['name'],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.primaryBlue),
                label: const Text("View Ledger", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  side: BorderSide(color: AppColors.primaryBlue.withOpacity(0.5)),
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.05)
                ),
              ),
            ),
          ],
        ),
      ],
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
        StatusService.show(context, "Error: $e", backgroundColor: Colors.red);
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
        title: Text(widget.isSelecting ? "Select Vendor" : "Vendors", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        titleTextStyle: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 20),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
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
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(fontFamily: 'Outfit', color: context.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    hintText: "Search vendor by name, email or phone...",
                    hintStyle: TextStyle(fontFamily: 'Outfit', color: context.textSecondary.withOpacity(0.5), fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: _searchFocusNode.hasFocus ? AppColors.primaryBlue : context.textSecondary.withOpacity(0.5)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.primaryBlue), 
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                          _fetchVendors();
                        }
                      ) 
                    : null,
                ),
                onChanged: (v) {
                  setState(() => _searchQuery = v);
                  _fetchVendors();
                },
              ),
            ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vendors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_rounded, size: 64, color: context.textSecondary.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text("No vendors found", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _vendors.length,
                        itemBuilder: (context, index) {
                          final vendor = _vendors[index];
                          return _buildVendorCard(vendor);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: widget.isSelecting ? null : FloatingActionButton.extended(
        onPressed: () => _showVendorFormSheet(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Add Vendor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
    final name = vendor['name'] ?? 'Unknown';
    final contactPerson = vendor['contact_person'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: InkWell(
        onTap: () {
          if (widget.isSelecting) {
            Navigator.pop(context, vendor);
          } else {
            _showVendorDetailSheet(vendor);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: context.textPrimary,
                      ),
                    ),
                    if (contactPerson.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: context.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            contactPerson,
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.isSelecting)
                const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ),
    );
  }

  void _showVendorFormSheet({Map<String, dynamic>? vendor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => VendorFormScreen(
            vendor: vendor,
            isSheet: true,
          ),
        ),
      ),
    ).then((_) => _fetchVendors());
  }
}
