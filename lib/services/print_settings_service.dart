import 'package:shared_preferences/shared_preferences.dart';

enum TemplateType {
  a4Standard,
  a5Modern,
  thermal80mm,
  thermal58mm
}

class PrintSettingsService {
  static const String _prefix = 'print_template_';
  
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
