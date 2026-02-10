import 'package:flutter/material.dart';

import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import 'login_screen.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const Color employeeColor = Colors.teal;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, employeeColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInLeft(
                    child: Text(
                      "Daily Workspace",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Logged in as Sales Executive.", style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF64748B), fontSize: 16)),
                  const SizedBox(height: 32),
                  
                  _buildDailyStats(employeeColor),
                  const SizedBox(height: 32),
                  
                  Text("Sales Operations", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildToolCard(
                    title: "New Sale",
                    subtitle: "Generate a quick GST invoice",
                    icon: Icons.add_shopping_cart_rounded,
                    color: employeeColor,
                  ),
                  const SizedBox(height: 12),
                  _buildToolCard(
                    title: "Recent Transactions",
                    subtitle: "View your sales history",
                    icon: Icons.history_rounded,
                    color: Colors.blueGrey,
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, employeeColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar(BuildContext context, Color color) {
    return SliverAppBar(
      expandedHeight: 140.0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.badge_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                Text("Employee Portal", style: TextStyle(fontFamily: 'Outfit', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            Text("Sales & Billing Operations", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[600])),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(onPressed: () => _signOut(context), icon: Icon(Icons.logout_rounded, color: color)),
      ],
    );
  }

  Widget _buildDailyStats(Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Performance", style: TextStyle(fontFamily: 'Outfit', color: Colors.white.withOpacity(0.8), fontSize: 14)),
          const SizedBox(height: 4),
          Text("₹4,250", style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat("Bills", "12"),
              _buildMiniStat("Target", "₹10k"),
              _buildMiniStat("XP", "450"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 12)),
        Text(val, style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildToolCard({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: InkWell(
              onTap: () {},
              child: Center(
                child: Text("Quick Scan Billing", style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LoginScreen()));
  }
}
