import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/dashboard_provider.dart';
import '../core/theme_service.dart';
import 'dashboard/components/metric_cards.dart';
import 'dashboard/components/sales_charts.dart';
import 'dashboard/components/quick_actions.dart';
import 'dashboard/components/dashboard_app_bar.dart';
import 'dashboard/components/floating_nav.dart';
import 'dashboard/components/quick_action_menu.dart';
import 'dashboard/components/profile_sheet.dart';
import 'dashboard/components/dashboard_selectors.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  bool _showFloatingBar = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadDashboardData();
    });
  }

  void _onTabSelected(int index) {
    if (index == _selectedTabIndex) return;
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: state.currentUser == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Loading Dashboard..."),
                ],
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => ref.read(dashboardProvider.notifier).loadDashboardData(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      DashboardAppBar(onProfileTap: () => showProfileSheet(context)),
                      SliverToBoxAdapter(
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 500),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Column(
                              children: [
                                _buildWelcomeSection(state),
                                const SizedBox(height: 16),
                                const DashboardMetricCards(), // Remove const if Provider complains
                                const SizedBox(height: 24),
                                const DashboardSalesCharts(), // Remove const if Provider complains
                                const SizedBox(height: 24),
                                const DashboardQuickActions(), // Changed the implementation in its file to handle "Quick Actions" text if necessary, or let's wrap it
                                const SizedBox(height: 100), // Extra space for floating bar
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showFloatingBar)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    child: DashboardFloatingNav(
                      selectedIndex: _selectedTabIndex,
                      onTabSelected: _onTabSelected,
                      onQuickAction: () => showQuickActionMenu(context, state.currentUser),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildWelcomeSection(DashboardState state) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Business Overview",
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildHeaderAction(
                  icon: Icons.calendar_today_rounded,
                  label: getDateRangeLabel(state.selectedDateRange),
                  onTap: () => showDateRangeSelector(context, ref),
                ),
                const SizedBox(width: 8),
                _buildHeaderAction(
                  icon: Icons.location_on_rounded,
                  label: state.selectedBranchId == null
                      ? "All"
                      : state.branches.firstWhere(
                          (b) => b['id'] == state.selectedBranchId,
                          orElse: () => {'name': '...'},
                        )['name'],
                  onTap: () => showBranchSelector(context, ref),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
