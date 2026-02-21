import 'package:shared_preferences/shared_preferences.dart';

enum TemplateType {
  a4Standard,
  a5Modern,
  thermal80mm,
  thermal58mm
}

class PrintSettingsService {
  static const String _prefix = 'print_template_';
  static const String _printerIpKey = 'thermal_printer_ip';
  static const String _printerTypeKey = 'thermal_printer_type'; // e.g., 'network', 'bluetooth'
  static const String _paperSizeKey = 'thermal_paper_size'; // '58mm' or '80mm'
  static const String _printerBtAddressKey = 'thermal_printer_bt_address';
  
  static Future<void> setTemplate(String docType, TemplateType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$docType', type.name);
  }

  static Future<TemplateType> getTemplate(String docType) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_prefix$docType');
    
    if (value == null) {
      // Default logic
      if (docType == 'payment') return TemplateType.thermal80mm;
      return TemplateType.a4Standard;
    }
    
    return TemplateType.values.byName(value);
  }

  // Printer Configuration
  static Future<void> setPrinterConfig({
    String? ip,
    String? type,
    String? paperSize,
    String? btAddress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (ip != null) await prefs.setString(_printerIpKey, ip);
    if (type != null) await prefs.setString(_printerTypeKey, type);
    if (paperSize != null) await prefs.setString(_paperSizeKey, paperSize);
    if (btAddress != null) await prefs.setString(_printerBtAddressKey, btAddress);
  }

  static Future<Map<String, String?>> getPrinterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ip': prefs.getString(_printerIpKey),
      'type': prefs.getString(_printerTypeKey) ?? 'network',
      'paperSize': prefs.getString(_paperSizeKey) ?? '80mm',
      'btAddress': prefs.getString(_printerBtAddressKey),
    };
  }

  // Helper to get all settings at once
  static Future<Map<String, TemplateType>> getAllSettings() async {
    const docTypes = ['invoice', 'order', 'quotation', 'dc', 'payment', 'credit_note'];
    final settings = <String, TemplateType>{};
    
    for (var type in docTypes) {
      settings[type] = await getTemplate(type);
    }
    return settings;
  }
}
