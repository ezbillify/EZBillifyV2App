import 'package:flutter/material.dart';
import '../../../core/theme_service.dart';
import '../../hr/employee_list_screen.dart';
import '../../hr/workforce_monitor_screen.dart';
import '../../sales/sales_dashboard.dart';
import '../../inventory/inventory_dashboard_screen.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Actions",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          context,
          title: "Sales & Invoices",
          description: "Generate bills, manage returns & payments",
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const SalesDashboard()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          context,
          title: "Inventory Management",
          description: "Track products, stock levels & UOMs",
          icon: Icons.inventory_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const InventoryDashboardScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          context,
          title: "HR & Payroll",
          description: "Manage employees, salaries & bank details",
          icon: Icons.people_alt_rounded,
          color: const Color(0xFFEC4899),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const EmployeeListScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          context,
          title: "Workforce Monitor",
          description: "Assign and track warehouse staff activities",
          icon: Icons.assignment_ind_rounded,
          color: const Color(0xFF10B981),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => const WorkforceMonitorScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildBigAction(
          context,
          title: "Reports & Analytics",
          description: "Financial summaries and business growth",
          icon: Icons.analytics_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Reports - Coming Soon")),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBigAction(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
