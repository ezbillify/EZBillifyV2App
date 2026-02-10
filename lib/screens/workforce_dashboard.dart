import 'package:flutter/material.dart';

import 'package:animate_do/animate_do.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import 'login_screen.dart';

class WorkforceDashboard extends StatelessWidget {
  const WorkforceDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const Color workforceColor = Colors.orange;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, workforceColor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInUp(
                    child: Text(
                      "Operations Center",
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Inventory & Logistics Tracking.", style: TextStyle(fontFamily: 'Outfit', color: const Color(0xFF64748B), fontSize: 16)),
                  const SizedBox(height: 32),
                  
                  _buildInventoryStatus(workforceColor),
                  const SizedBox(height: 32),
                  
                  Text("Field Tasks", style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildTaskCard(
                    title: "Stock Audit",
                    subtitle: "Scan items to verify inventory",
                    icon: Icons.inventory_rounded,
                    color: workforceColor,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    title: "Inward Goods",
                    subtitle: "Register new stock arrival",
                    icon: Icons.local_shipping_rounded,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    title: "Quality Check",
                    subtitle: "Inspect for damages or leaks",
                    icon: Icons.fact_check_rounded,
                    color: Colors.redAccent,
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context, workforceColor),
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
                Icon(Icons.engineering_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                Text("Workforce Portal", style: TextStyle(fontFamily: 'Outfit', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            Text("Inventory & Warehouse Management", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: Colors.grey[600])),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(onPressed: () => _signOut(context), icon: Icon(Icons.logout_rounded, color: color)),
      ],
    );
  }

  Widget _buildInventoryStatus(Color color) {
    return Row(
      children: [
        Expanded(child: _buildInfoBox("Scanned", "128", Icons.qr_code_2_rounded, color)),
        const SizedBox(width: 16),
        Expanded(child: _buildInfoBox("Pending", "12", Icons.hourglass_empty_rounded, Colors.grey)),
      ],
    );
  }

  Widget _buildInfoBox(String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 16),
          Text(val, style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTaskCard({required String title, required String subtitle, required IconData icon, required Color color}) {
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text("Inventory Scan", style: TextStyle(fontFamily: 'Outfit', color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
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
