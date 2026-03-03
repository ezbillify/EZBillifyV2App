import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sales/sales_dashboard.dart';
import '../../sales/customers_screen.dart';
import '../../inventory/inventory_dashboard_screen.dart';
import '../../inventory/items_screen.dart';
import '../../inventory/stock_management_screen.dart';
import '../../purchase/vendors_screen.dart';
import '../../purchase/purchase_dashboard.dart';
import '../../master_data/master_data_screen.dart';
import '../../hr/workforce_monitor_screen.dart';
import '../../hr/employee_list_screen.dart';
import '../../hr/shift_list_screen.dart';
import '../../hr/attendance_list_screen.dart';
import '../../hr/leave_list_screen.dart';
import '../../settings_screen.dart';
import '../../settings/company_profile_screen.dart';
import '../../../models/auth_models.dart';

void showQuickActionMenu(BuildContext context, AppUser? user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    useSafeArea: true,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Global Actions",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              "Quickly access all business modules",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildOverlaySection(context, "Sales", [
                      _buildActionIcon(context, Icons.people_alt_rounded, "Customers", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomersScreen()));
                      }),
                      _buildActionIcon(context, Icons.request_quote_rounded, "Quotations", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 1)));
                      }),
                      _buildActionIcon(context, Icons.shopping_bag_rounded, "Sales Orders", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 2)));
                      }),
                      _buildActionIcon(context, Icons.local_shipping_rounded, "Delivery Challans", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 3)));
                      }),
                      _buildActionIcon(context, Icons.receipt_long_rounded, "Sales Invoices", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 0)));
                      }),
                      _buildActionIcon(context, Icons.qr_code_2_rounded, "E-Invoicing", const Color(0xFF3B82F6), () {}),
                      _buildActionIcon(context, Icons.route_rounded, "E-Way Bills", const Color(0xFF3B82F6), () {}),
                      _buildActionIcon(context, Icons.payments_rounded, "Payments", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 4)));
                      }),
                      _buildActionIcon(context, Icons.assignment_return_rounded, "Credit Notes", const Color(0xFF3B82F6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 5)));
                      }),
                    ]),
                    const SizedBox(height: 24),
                    _buildOverlaySection(context, "Purchase", [
                      _buildActionIcon(context, Icons.storefront_rounded, "Vendors", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const VendorsScreen()));
                      }),
                      _buildActionIcon(context, Icons.quiz_rounded, "RFQs", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 2)));
                      }),
                      _buildActionIcon(context, Icons.description_rounded, "Purchase Orders", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 1)));
                      }),
                      _buildActionIcon(context, Icons.inventory_rounded, "Goods Received (GRN)", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 3)));
                      }),
                      _buildActionIcon(context, Icons.receipt_rounded, "Purchase Bills", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 0)));
                      }),
                      _buildActionIcon(context, Icons.assignment_returned_rounded, "Debit Notes", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 5)));
                      }),
                      _buildActionIcon(context, Icons.account_balance_wallet_rounded, "Payments", const Color(0xFFF59E0B), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseDashboard(initialIndex: 4)));
                      }),
                    ]),
                    const SizedBox(height: 24),
                    _buildOverlaySection(context, "Inventory", [
                      _buildActionIcon(context, Icons.dashboard_rounded, "Dashboard", const Color(0xFF10B981), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const InventoryDashboardScreen()));
                      }),
                      _buildActionIcon(context, Icons.inventory_2_rounded, "Items", const Color(0xFF10B981), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const ItemsScreen()));
                      }),
                      _buildActionIcon(context, Icons.warehouse_rounded, "Stock", const Color(0xFF10B981), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const StockManagementScreen()));
                      }),
                    ]),
                    const SizedBox(height: 24),
                    _buildOverlaySection(context, "HR & Payroll", [
                      _buildActionIcon(context, Icons.engineering_rounded, "Workforce Monitor", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const WorkforceMonitorScreen()));
                      }),
                      _buildActionIcon(context, Icons.badge_rounded, "Employees", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const EmployeeListScreen()));
                      }),
                      _buildActionIcon(context, Icons.schedule_rounded, "Shifts", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const ShiftListScreen()));
                      }),
                      _buildActionIcon(context, Icons.event_available_rounded, "Attendance", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AttendanceListScreen()));
                      }),
                      _buildActionIcon(context, Icons.beach_access_rounded, "Leaves", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const LeaveListScreen()));
                      }),
                      _buildActionIcon(context, Icons.settings_rounded, "Settings", const Color(0xFF8B5CF6), () {}),
                    ]),
                    const SizedBox(height: 24),
                    _buildOverlaySection(context, "Master Data & Management", [
                      _buildActionIcon(context, Icons.category_rounded, "Categories", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                      _buildActionIcon(context, Icons.straighten_rounded, "Units (UOM)", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                      _buildActionIcon(context, Icons.account_balance_rounded, "Bank Accounts", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                      _buildActionIcon(context, Icons.percent_rounded, "Tax Rates", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                      _buildActionIcon(context, Icons.account_tree_rounded, "Chart of Accounts", const Color(0xFF8B5CF6), () {}),
                      _buildActionIcon(context, Icons.access_time_filled_rounded, "Payment Terms", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                      _buildActionIcon(context, Icons.currency_exchange_rounded, "Currencies", const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterDataScreen()));
                      }),
                    ]),
                    const SizedBox(height: 24),
                    _buildOverlaySection(context, "Others", [
                      _buildActionIcon(context, Icons.analytics_rounded, "Reports", const Color(0xFFEF4444), () {}),
                      _buildActionIcon(context, Icons.business_rounded, "Company Settings", const Color(0xFFEF4444), () {
                        if (user?.companyId != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => CompanyProfileScreen(companyId: user!.companyId!)));
                        }
                      }),
                      _buildActionIcon(context, Icons.settings_rounded, "App Settings", const Color(0xFFEF4444), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => SettingsScreen(user: user)));
                      }),
                    ]),
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

Widget _buildOverlaySection(BuildContext context, String title, List<Widget> items) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
      ),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.0,
        children: items,
      ),
      const SizedBox(height: 24),
    ],
  );
}

Widget _buildActionIcon(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(context); // Close the modal first
      onTap();
    },
    borderRadius: BorderRadius.circular(16),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
