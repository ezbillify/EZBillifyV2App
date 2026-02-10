import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/settings_service.dart';
import '../../core/theme_service.dart';

class IntegrationsScreen extends ConsumerStatefulWidget {
  final String companyId;
  const IntegrationsScreen({super.key, required this.companyId});

  @override
  ConsumerState<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends ConsumerState<IntegrationsScreen> {
  final _settingsService = SettingsService();
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _configs = {};

  final List<Map<String, dynamic>> _providers = [
    {
      'id': 'gsp_einvoice',
      'name': 'GSP: E-Invoicing',
      'icon': Icons.cloud_done_rounded,
      'description': 'Connect IRP/GSP for generating Invoice Reference Numbers (IRN).',
      'fields': [
        {'id': 'provider', 'label': 'Provider Name', 'type': 'select', 'options': ['cleartax', 'mastergst', 'irp']},
        {'id': 'client_id', 'label': 'Client ID / Username', 'type': 'text'},
        {'id': 'client_secret', 'label': 'Client Secret / Password', 'type': 'password'},
        {'id': 'gstin', 'label': 'Linked GSTIN', 'type': 'text', 'placeholder': 'Optional'},
      ]
    },
    {
      'id': 'gsp_eway',
      'name': 'GSP: E-Way Bill',
      'icon': Icons.local_shipping_rounded,
      'description': 'Connect NIC/GSP for generating E-Way Bills (Part A & B).',
      'fields': [
        {'id': 'provider', 'label': 'Provider Name', 'type': 'select', 'options': ['cleartax', 'mastergst', 'nic']},
        {'id': 'client_id', 'label': 'Client ID / Username', 'type': 'text'},
        {'id': 'client_secret', 'label': 'Client Secret / Password', 'type': 'password'},
      ]
    },
    {
      'id': 'payment',
      'name': 'Payment Gateway',
      'icon': Icons.account_balance_wallet_rounded,
      'description': 'Accept online payments on invoices via payment links.',
      'fields': [
        {'id': 'provider', 'label': 'Gateway Provider', 'type': 'select', 'options': ['razorpay', 'stripe']},
        {'id': 'key_id', 'label': 'Key ID / Public Key', 'type': 'text'},
        {'id': 'key_secret', 'label': 'Key Secret / Secret Key', 'type': 'password'},
        {'id': 'webhook_secret', 'label': 'Webhook Secret', 'type': 'password'},
      ]
    },
    {
      'id': 'email',
      'name': 'Email Service (SMTP)',
      'icon': Icons.alternate_email_rounded,
      'description': 'Use your own SMTP server for sending system emails.',
      'fields': [
        {'id': 'host', 'label': 'SMTP Host', 'type': 'text', 'placeholder': 'smtp.gmail.com'},
        {'id': 'port', 'label': 'Port', 'type': 'number', 'placeholder': '587'},
        {'id': 'user', 'label': 'Username', 'type': 'text'},
        {'id': 'password', 'label': 'Password', 'type': 'password'},
        {'id': 'from_name', 'label': 'Sender Display Name', 'type': 'text', 'placeholder': 'e.g. Sales Team'},
      ]
    },
    {
      'id': 'whatsapp_direct',
      'name': 'Direct WhatsApp',
      'icon': Icons.message_rounded,
      'isPremium': true,
      'description': 'Connect your personal or business WhatsApp for direct messaging.',
      'fields': [] // Specialized handling
    },
    {
      'id': 'sms',
      'name': 'SMS / WhatsApp Business',
      'icon': Icons.sms_rounded,
      'description': 'Send automated alerts via SMS or WhatsApp Business API.',
      'fields': [
        {'id': 'provider', 'label': 'Provider', 'type': 'select', 'options': ['twilio', 'interakt', 'msg91']},
        {'id': 'api_key', 'label': 'API Key', 'type': 'password'},
        {'id': 'sender_id', 'label': 'Sender ID / Phone Number', 'type': 'text'},
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadIntegrations();
  }

  Future<void> _loadIntegrations() async {
    try {
      final data = await _settingsService.getIntegrations(widget.companyId);
      if (mounted) {
        setState(() {
          _configs = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveIntegration(String providerId, Map<String, dynamic> data) async {
    setState(() => _isSaving = true);
    try {
      await _settingsService.updateIntegrations(widget.companyId, providerId, data);
      await _loadIntegrations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Integration saved successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _disconnectIntegration(String providerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surfaceBg,
        title: Text("Disconnect Service?", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text("Are you sure you want to remove these credentials? All credentials will be deleted.", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await _settingsService.deleteIntegration(widget.companyId, providerId);
      await _loadIntegrations();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch theme to rebuild on changes
    ref.watch(themeServiceProvider);
    
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.surfaceBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("API & Integrations", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textPrimary, fontSize: 18)),
            Text("Power up your business workflow", style: TextStyle(fontFamily: 'Outfit', fontSize: 11, color: textSecondary)),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              final provider = _providers[index];
              final isConnected = _configs[provider['id']]?['is_connected'] == true;
              return FadeInUp(
                duration: Duration(milliseconds: 300 + (index * 100)),
                child: _buildProviderCard(provider, isConnected),
              );
            },
          ),
      bottomNavigationBar: _isSaving ? const LinearProgressIndicator() : null,
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider, bool isConnected) {
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final cardBg = context.cardBg;
    final borderColor = context.borderColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isConnected ? const Color(0xFF10B981).withOpacity(0.3) : borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          if (isConnected)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(20), 
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
                    const SizedBox(width: 4),
                    Text("CONNECTED", style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFF10B981).withOpacity(0.1) : context.isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC), 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: isConnected ? const Color(0xFF10B981).withOpacity(0.1) : borderColor)
                      ),
                      child: Icon(provider['icon'], color: isConnected ? const Color(0xFF10B981) : textSecondary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(provider['name'], style: TextStyle(fontFamily: 'Outfit', fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
                          const SizedBox(height: 4),
                          Text(provider['description'], style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: textSecondary, height: 1.4)),
                          if (provider['isPremium'] == true) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFF97316).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text("PREMIUM", style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isConnected) const SizedBox(width: 80), // Space for badge
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: context.isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC), 
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12, color: textSecondary.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text("End-to-End Encrypted", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: textSecondary.withOpacity(0.5), fontWeight: FontWeight.w500)),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: () => _showConfigSheet(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.transparent : textPrimary,
                          foregroundColor: isConnected ? textPrimary : context.surfaceBg,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), 
                            side: isConnected ? BorderSide(color: borderColor) : BorderSide.none
                          ),
                        ),
                        child: Text(isConnected ? "Manage" : "Connect", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConfigSheet(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _IntegrationForm(
        provider: provider,
        initialData: _configs[provider['id']] ?? {},
        isConnected: _configs[provider['id']]?['is_connected'] == true,
        onDisconnect: () {
          Navigator.pop(context);
          _disconnectIntegration(provider['id']);
        },
        onSave: (data) {
          Navigator.pop(context);
          _saveIntegration(provider['id'], data);
        },
      ),
    );
  }
}

class _IntegrationForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> provider;
  final Map<String, dynamic> initialData;
  final bool isConnected;
  final VoidCallback onDisconnect;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _IntegrationForm({required this.provider, required this.initialData, required this.isConnected, required this.onDisconnect, required this.onSave});

  @override
  ConsumerState<_IntegrationForm> createState() => _IntegrationFormState();
}

class _IntegrationFormState extends ConsumerState<_IntegrationForm> {
  late Map<String, dynamic> _formData;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _formData = Map<String, dynamic>.from(widget.initialData);
    
    // Initialize controllers
    for (var field in widget.provider['fields']) {
      if (field['type'] != 'select') {
        final fieldId = field['id'];
        _controllers[fieldId] = TextEditingController(text: _formData[fieldId]?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeServiceProvider);
    final textPrimary = context.textPrimary;
    final textSecondary = context.textSecondary;
    final surfaceBg = context.surfaceBg;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: surfaceBg, 
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Icon(widget.provider['icon'], color: AppColors.primaryBlue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.provider['name'], 
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (widget.isConnected) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1), 
                                      borderRadius: BorderRadius.circular(6), 
                                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2))
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 10),
                                        SizedBox(width: 4),
                                        Text("CONNECTED", style: TextStyle(fontFamily: 'Outfit', fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text("Secure Configuration", style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (widget.provider['id'] == 'whatsapp_direct')
                     _buildWhatsAppDirectInfo()
                  else
                    ...widget.provider['fields'].map<Widget>((field) {
                      if (field['type'] == 'select') {
                        return _buildDropdownField(field['label'], field['id'], List<String>.from(field['options']));
                      }
                      return _buildTextField(field['label'], field['id'], field['type'] == 'password', field['placeholder']);
                    }).toList(),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      if (widget.isConnected)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onDisconnect,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: const Text("Disconnect", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (widget.isConnected) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            widget.onSave(_formData);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: Text(widget.isConnected ? "Update Settings" : "Connect Service", style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 8),
                        Text("AES-256 Bit Encryption Active", style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: textSecondary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppDirectInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_scanner_rounded, size: 48, color: Color(0xFF10B981)),
          const SizedBox(height: 16),
          const Text(
            "Direct WhatsApp Connection",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Direct Messaging is currently available primarily through the Desktop application. On mobile, this requires an active background bridge. If not connected, please use the desktop dashboard to link your device.",
            style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String fieldId, bool isPassword, String? hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            obscureText: isPassword,
            controller: _controllers[fieldId],
            onChanged: (v) => _formData[fieldId] = v,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.normal, color: context.textSecondary.withOpacity(0.5)),
              filled: true,
              fillColor: context.cardBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: context.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              suffixIcon: isPassword ? Icon(Icons.lock_outline_rounded, size: 20, color: context.textSecondary.withOpacity(0.5)) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String fieldId, List<String> options) {
    final value = _formData[fieldId] ?? options.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: context.textSecondary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showSelectionSheet(label, fieldId, options),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(value.toString().toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary)),
                  Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSelectionSheet(String label, String fieldId, List<String> options) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(color: context.surfaceBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text("Select Option", style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
                    const SizedBox(height: 8),
                    Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: context.textSecondary)),
                    const SizedBox(height: 24),
                    ...options.map((opt) {
                      final isSelected = _formData[fieldId] == opt;
                      return ListTile(
                        onTap: () {
                          setState(() => _formData[fieldId] = opt);
                          Navigator.pop(context);
                        },
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(opt.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppColors.primaryBlue : context.textPrimary)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 24) : null,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
