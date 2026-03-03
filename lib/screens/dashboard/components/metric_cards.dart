import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/theme_service.dart';

class DashboardMetricCards extends ConsumerWidget {
  const DashboardMetricCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final stats = state.stats;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          context,
          "Total Revenue",
          "₹${(stats['total_sales'] as num? ?? 0.0).toStringAsFixed(0)}",
          Icons.payments_rounded,
          const Color(0xFF2563EB),
        ),
        _buildMetricCard(
          context,
          "Receivables",
          "₹${(stats['balance_due'] as num? ?? 0.0).toStringAsFixed(0)}",
          Icons.account_balance_wallet_rounded,
          const Color(0xFF10B981),
        ),
        _buildMetricCard(
          context,
          "Customers",
          "${stats['active_customers']}",
          Icons.people_rounded,
          const Color(0xFF8B5CF6),
        ),
        _buildMetricCard(
          context,
          "Low Stock",
          "${stats['low_stock']}",
          Icons.inventory_2_rounded,
          const Color(0xFFF59E0B),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
