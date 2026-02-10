import 'package:flutter/material.dart';

class CurrenciesScreen extends StatelessWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Currencies", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))),
      body: const Center(child: Text("Currencies Management - Coming Soon")),
    );
  }
}
