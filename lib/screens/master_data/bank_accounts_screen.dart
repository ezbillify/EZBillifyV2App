import 'package:flutter/material.dart';

class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bank Accounts", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold))),
      body: const Center(child: Text("Bank Accounts Management - Coming Soon")),
    );
  }
}
