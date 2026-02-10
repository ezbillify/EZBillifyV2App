import 'package:flutter/material.dart';
import '../../core/theme_service.dart';
import 'categories_screen.dart';
import 'units_screen.dart';
import 'tax_rates_screen.dart';
import 'payment_terms_screen.dart';
import 'bank_accounts_screen.dart';
import 'currencies_screen.dart';

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access theme helpers directly or via context if you have extensions (assuming context extensions from theme_service based on other files)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Master Data",
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Manage your core business data entities.",
            style: TextStyle(fontFamily: 'Outfit', color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          
          _buildMasterDataCard(context, surfaceColor, borderColor, [
            _buildTile(
              context, 
              Icons.category_rounded, 
              Colors.orange, 
              "Categories", 
              "Product grouping & hierarchy",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CategoriesScreen())),
            ),
            _buildTile(
              context, 
              Icons.straighten_rounded, 
              Colors.blue, 
              "Units (UOM)", 
              "Measurement units for items",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const UnitsScreen())),
            ),
            _buildTile(
              context, 
              Icons.percent_rounded, 
              Colors.red, 
              "Tax Rates", 
              "Configurable tax percentages",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TaxRatesScreen())),
            ),
          ]),

          const SizedBox(height: 24),

          _buildMasterDataCard(context, surfaceColor, borderColor, [
             _buildTile(
              context, 
              Icons.account_balance_wallet_rounded, 
              Colors.green, 
              "Bank Accounts", 
              "Company bank details",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BankAccountsScreen())),
            ),
            _buildTile(
              context, 
              Icons.currency_exchange_rounded, 
              Colors.purple, 
              "Currencies", 
              "Supported currencies & exchange rates",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CurrenciesScreen())),
            ),
            _buildTile(
              context, 
              Icons.calendar_month_rounded, 
              Colors.teal, 
              "Payment Terms", 
              "Invoice due date rules",
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PaymentTermsScreen())),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildMasterDataCard(BuildContext context, Color surfaceColor, Color borderColor, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final isLast = entry.key == children.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast) Divider(height: 1, color: borderColor.withOpacity(0.5), indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, Color color, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontFamily: 'Outfit', color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
    );
  }
}
