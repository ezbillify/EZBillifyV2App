import 'package:flutter/material.dart';
import '../../core/theme_service.dart';
import 'purchase_bills_screen.dart';
import 'purchase_orders_screen.dart';
import 'purchase_rfqs_screen.dart';
import 'purchase_grns_screen.dart';
import 'purchase_payments_screen.dart';
import 'purchase_debit_notes_screen.dart';
import 'vendors_screen.dart';

class PurchaseDashboard extends StatefulWidget {
  final int initialIndex;
  const PurchaseDashboard({super.key, this.initialIndex = 0});

  @override
  State<PurchaseDashboard> createState() => _PurchaseDashboardState();
}

class _PurchaseDashboardState extends State<PurchaseDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text("Purchase Module", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
           IconButton(
             icon: Icon(Icons.store_outlined, color: context.textPrimary),
             onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VendorsScreen())),
             tooltip: "Manage Vendors",
           ),
           const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Invoices"),
            Tab(text: "Orders (PO)"),
            Tab(text: "RFQs"),
            Tab(text: "GRNs"),
            Tab(text: "Payments"),
            Tab(text: "Debit Notes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          PurchaseBillsScreen(showAppBar: false),
          PurchaseOrdersScreen(showAppBar: false),
          PurchaseRfqsScreen(showAppBar: false),
          PurchaseGrnsScreen(showAppBar: false),
          PurchasePaymentsScreen(showAppBar: false),
          PurchaseDebitNotesScreen(showAppBar: false),
        ],
      ),
    );
  }
}
