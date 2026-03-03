import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sales/sales_dashboard.dart';
import '../../sales/customers_screen.dart';
import '../../inventory/inventory_dashboard_screen.dart';

class DashboardFloatingNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final VoidCallback onQuickAction;

  const DashboardFloatingNav({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 120, // Ensure height covers raised button
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipPath(
              clipper: NotchedPillClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? const Color(0xFFE2E8F0) : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItemIconButton(
                        context,
                        Icons.dashboard_rounded,
                        "Home",
                        isSelected: selectedIndex == 0,
                        onTap: () => onTabSelected(0),
                      ),
                      _buildNavItemIconButton(
                        context,
                        Icons.receipt_long_rounded,
                        "Bills",
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const SalesDashboard(initialIndex: 0)));
                        },
                        isSelected: selectedIndex == 1,
                      ),
                      const SizedBox(width: 70), // Space for the floating button
                      _buildNavItemIconButton(
                        context,
                        Icons.people_alt_rounded,
                        "Customer",
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const CustomersScreen()));
                        },
                        isSelected: selectedIndex == 2,
                      ),
                      _buildNavItemIconButton(
                        context,
                        Icons.inventory_2_rounded,
                        "Stock",
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const InventoryDashboardScreen()));
                        },
                        isSelected: selectedIndex == 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 39,
            child: _buildQuickActionBtn(onQuickAction),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItemIconButton(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = isDark ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);
    final inactiveColor = isDark ? const Color(0xFF64748B) : Colors.white.withOpacity(0.5);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn(VoidCallback onTap) {
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            onTap();
          },
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

class NotchedPillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = 24.0;
    final notchWidth = 110.0;
    final notchHeight = 34.0;
    final centerX = size.width / 2;

    path.moveTo(radius, 0);
    path.lineTo(centerX - notchWidth / 2, 0);

    path.cubicTo(
      centerX - notchWidth / 3.5,
      0,
      centerX - notchWidth / 3.5,
      notchHeight,
      centerX,
      notchHeight,
    );
    path.cubicTo(
      centerX + notchWidth / 3.5,
      notchHeight,
      centerX + notchWidth / 3.5,
      0,
      centerX + notchWidth / 2,
      0,
    );

    path.lineTo(size.width - radius, 0);
    path.arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));

    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height), radius: Radius.circular(radius));

    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius), radius: Radius.circular(radius));

    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
