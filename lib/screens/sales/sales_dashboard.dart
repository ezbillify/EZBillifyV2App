import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';
import 'sales_invoices_screen.dart';
import 'quotations_screen.dart';
import 'payments_screen.dart';
import 'credit_notes_screen.dart';
import 'customers_screen.dart';
import 'sales_orders_screen.dart';
import 'delivery_challans_screen.dart';

class SalesDashboard extends StatefulWidget {
  final int initialIndex;
  const SalesDashboard({super.key, this.initialIndex = 0});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> with SingleTickerProviderStateMixin {
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
        title: Text("Sales Module", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        backgroundColor: context.surfaceBg,
        elevation: 0,
        actions: [
           IconButton(
             icon: Icon(Icons.people_alt_outlined, color: context.textPrimary),
             onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomersScreen())),
             tooltip: "Manage Customers",
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
            Tab(text: "Quotations"),
            Tab(text: "Sales Orders"),
            Tab(text: "Del. Challans"),
            Tab(text: "Payments"),
            Tab(text: "Credit Notes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SalesInvoicesScreen(showAppBar: false),
          QuotationsScreen(showAppBar: false),
          SalesOrdersScreen(showAppBar: false),
          DeliveryChallansScreen(showAppBar: false),
          PaymentsScreen(showAppBar: false),
          CreditNotesScreen(showAppBar: false),
        ],
      ),
    );
  }
}
