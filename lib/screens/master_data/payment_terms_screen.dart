import 'package:flutter/material.dart';

class PaymentTermsScreen extends StatelessWidget {
  const PaymentTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Terms", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))),
      body: const Center(child: Text("Payment Terms Management - Coming Soon")),
    );
  }
}
