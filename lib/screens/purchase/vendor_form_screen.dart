import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_service.dart';

class VendorFormScreen extends StatefulWidget {
  final Map<String, dynamic>? vendor;
  const VendorFormScreen({super.key, this.vendor});

  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  
  String _name = '';
  String _contactPerson = '';
  String _phone = '';
  String _email = '';
  String _gstin = '';
  String _pan = '';
  String _paymentTerms = 'Net 30';

  // Address
  String _line1 = '';
  String _city = '';
  String _state = '';
  String _pincode = '';
  String _country = 'India';

  @override
  void initState() {
    super.initState();
    if (widget.vendor != null) {
      _name = widget.vendor!['name'] ?? '';
      _contactPerson = widget.vendor!['contact_person'] ?? '';
      _phone = widget.vendor!['phone'] ?? '';
      _email = widget.vendor!['email'] ?? '';
      _gstin = widget.vendor!['gstin'] ?? '';
      _pan = widget.vendor!['pan'] ?? '';
      _paymentTerms = widget.vendor!['payment_terms'] ?? 'Net 30';
      
      final addr = widget.vendor!['address'] ?? {};
      _line1 = addr['line1'] ?? '';
      _city = addr['city'] ?? '';
      _state = addr['state'] ?? '';
      _pincode = addr['pincode'] ?? '';
      _country = addr['country'] ?? 'India';
    }
  }

  void _saveVendor() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = await Supabase.instance.client.from('users').select('company_id').eq('auth_id', user!.id).single();
      final companyId = profile['company_id'];

      final vendorData = {
        'company_id': companyId,
        'name': _name,
        'contact_person': _contactPerson,
        'phone': _phone,
        'email': _email,
        'gstin': _gstin,
        'pan': _pan,
        'payment_terms': _paymentTerms,
        'address': {
          'line1': _line1,
          'city': _city,
          'state': _state,
          'pincode': _pincode,
          'country': _country
        }
      };

      if (widget.vendor != null) {
        await Supabase.instance.client.from('vendors').update(vendorData).eq('id', widget.vendor!['id']);
      } else {
        await Supabase.instance.client.from('vendors').insert(vendorData);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vendor saved successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.vendor == null ? "New Vendor" : "Edit Vendor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        backgroundColor: context.surfaceBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Basic Details"),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  labelText: "Vendor Name",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: context.cardBg,
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                     child: TextFormField(
                      initialValue: _contactPerson,
                      decoration: InputDecoration(
                        labelText: "Contact Person",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _contactPerson = v!,
                    ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextFormField(
                      initialValue: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone Number",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                      onSaved: (v) => _phone = v!,
                    ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: context.cardBg,
                ),
                onSaved: (v) => _email = v!,
              ),
              
              const SizedBox(height: 32),
              _buildSectionTitle("Tax & Terms"),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _gstin,
                      decoration: InputDecoration(
                        labelText: "GSTIN",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _gstin = v!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _pan,
                      decoration: InputDecoration(
                        labelText: "PAN",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _pan = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ["Net 15", "Net 30", "Net 45", "Net 60", "Due on Receipt"].contains(_paymentTerms) ? _paymentTerms : "Net 30",
                decoration: InputDecoration(
                  labelText: "Payment Terms",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: context.cardBg,
                ),
                items: ["Net 15", "Net 30", "Net 45", "Net 60", "Due on Receipt"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _paymentTerms = v!),
                onSaved: (v) => _paymentTerms = v!,
              ),

              const SizedBox(height: 32),
              _buildSectionTitle("Address"),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _line1,
                decoration: InputDecoration(
                  labelText: "Address Line 1",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: context.cardBg,
                ),
                onSaved: (v) => _line1 = v!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _city,
                      decoration: InputDecoration(
                        labelText: "City",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _city = v!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _pincode,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Pincode",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _pincode = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _state,
                      decoration: InputDecoration(
                        labelText: "State",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _state = v!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _country,
                      decoration: InputDecoration(
                        labelText: "Country",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: context.cardBg,
                      ),
                      onSaved: (v) => _country = v!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(color: context.surfaceBg, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveVendor,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
            child: const Text("Save Vendor", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary));
  }
}
