import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../core/theme_service.dart';

void showDateRangeSelector(BuildContext context, WidgetRef ref) {
  final state = ref.read(dashboardProvider);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Select Date Range",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildRangeTile(context, ref, "Today", "today", Icons.today, state.selectedDateRange),
          _buildRangeTile(context, ref, "Yesterday", "yesterday", Icons.history, state.selectedDateRange),
          _buildRangeTile(context, ref, "Last 7 Days", "7days", Icons.date_range, state.selectedDateRange),
          _buildRangeTile(context, ref, "Last 30 Days", "30days", Icons.calendar_month, state.selectedDateRange),
          _buildRangeTile(context, ref, "This Month", "thisMonth", Icons.calendar_today, state.selectedDateRange),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Widget _buildRangeTile(BuildContext context, WidgetRef ref, String label, String value, IconData icon, String selectedValue) {
  final isSelected = selectedValue == value;
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isSelected ? const Color(0xFF2563EB) : Colors.grey).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 18),
    ),
    title: Text(
      label,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF2563EB) : context.textPrimary,
      ),
    ),
    onTap: () {
      ref.read(dashboardProvider.notifier).setDateRange(value);
      Navigator.pop(context);
    },
    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
  );
}

void showBranchSelector(BuildContext context, WidgetRef ref) {
  final state = ref.read(dashboardProvider);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Select Branch",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildBranchOption(context, ref, null, "All Branches", state.selectedBranchId == null),
          ...state.branches.map((b) => _buildBranchOption(
                context,
                ref,
                b['id'],
                b['name'],
                state.selectedBranchId == b['id'],
              )),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Widget _buildBranchOption(BuildContext context, WidgetRef ref, String? id, String name, bool isSelected) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (isSelected ? const Color(0xFF2563EB) : Colors.grey).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(id == null ? Icons.all_inclusive : Icons.store_rounded, color: isSelected ? const Color(0xFF2563EB) : Colors.grey, size: 18),
    ),
    title: Text(
      name,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? const Color(0xFF2563EB) : context.textPrimary,
      ),
    ),
    onTap: () {
      ref.read(dashboardProvider.notifier).setBranch(id);
      Navigator.pop(context);
    },
    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
  );
}

String getDateRangeLabel(String range) {
  switch (range) {
    case 'today':
      return 'Today';
    case 'yesterday':
      return 'Yesterday';
    case '7days':
      return '7 Days';
    case '30days':
      return '30 Days';
    default:
      return 'Month';
  }
}
