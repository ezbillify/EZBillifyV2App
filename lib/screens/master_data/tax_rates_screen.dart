import 'package:flutter/material.dart';

class TaxRatesScreen extends StatelessWidget {
  const TaxRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tax Rates", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))),
      body: const Center(child: Text("Tax Rates Management - Coming Soon")),
    );
  }
}
