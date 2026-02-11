import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterDataService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static final MasterDataService _instance = MasterDataService._internal();
  factory MasterDataService() => _instance;
  MasterDataService._internal();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _customers = [];
  
  DateTime? _lastItemsSync;
  DateTime? _lastCustomersSync;

  List<Map<String, dynamic>> get cachedItems => _items;
  List<Map<String, dynamic>> get cachedCustomers => _customers;

  Future<List<Map<String, dynamic>>> getItems(String companyId, {bool forceRefresh = false}) async {
    // 1. Check if we have valid memory cache (valid for 30 mins)
    if (!forceRefresh && _items.isNotEmpty && _lastItemsSync != null && 
        DateTime.now().difference(_lastItemsSync!).inMinutes < 30) {
      return _items;
    }
    
    // 2. Try to load from local persistent cache if memory is empty
    if (_items.isEmpty) {
      await _loadFromLocal('items');
      if (_items.isNotEmpty && !forceRefresh) {
        // If we loaded from local, check if it's too old (e.g., > 2 hours)
        if (_lastItemsSync != null && DateTime.now().difference(_lastItemsSync!).inHours < 2) {
          return _items;
        }
      }
    }

    // 3. Fetch from API
    try {
      debugPrint("Fetching items from Supabase for company: $companyId");
      final results = await _supabase
          .from('items')
          .select('*, tax_rate:tax_rates(rate)')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(5000);
      
      _items = List<Map<String, dynamic>>.from(results);
      _lastItemsSync = DateTime.now();
      
      // Background save to local persistent storage
      _saveToLocal('items', _items);
      
      return _items;
    } catch (e) {
      debugPrint("Error fetching items: $e");
      return _items; // Return whatever we have (even if empty)
    }
  }

  Future<List<Map<String, dynamic>>> getCustomers(String companyId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _customers.isNotEmpty && _lastCustomersSync != null && 
        DateTime.now().difference(_lastCustomersSync!).inMinutes < 30) {
      return _customers;
    }

    if (_customers.isEmpty) {
      await _loadFromLocal('customers');
      if (_customers.isNotEmpty && !forceRefresh) {
        if (_lastCustomersSync != null && DateTime.now().difference(_lastCustomersSync!).inHours < 2) {
          return _customers;
        }
      }
    }

    try {
      debugPrint("Fetching customers from Supabase for company: $companyId");
      final results = await _supabase
          .from('customers')
          .select()
          .eq('company_id', companyId)
          .eq('is_active', true)
          .order('name', ascending: true)
          .limit(3000);
      
      _customers = List<Map<String, dynamic>>.from(results);
      _lastCustomersSync = DateTime.now();
      
      _saveToLocal('customers', _customers);
      
      return _customers;
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      return _customers;
    }
  }

  Future<void> _saveToLocal(String key, List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_$key', jsonEncode(data));
      await prefs.setString('cache_${key}_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint("Cache save error: $e");
    }
  }

  Future<void> _loadFromLocal(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cache_$key');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        if (key == 'items') {
          _items = List<Map<String, dynamic>>.from(decoded);
          final time = prefs.getString('cache_items_time');
          if (time != null) _lastItemsSync = DateTime.tryParse(time);
        } else {
          _customers = List<Map<String, dynamic>>.from(decoded);
          final time = prefs.getString('cache_customers_time');
          if (time != null) _lastCustomersSync = DateTime.tryParse(time);
        }
      }
    } catch (e) {
      debugPrint("Cache load error for $key: $e");
    }
  }

  void invalidateCache() {
    _items = [];
    _customers = [];
    _lastItemsSync = null;
    _lastCustomersSync = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('cache_items');
      prefs.remove('cache_items_time');
      prefs.remove('cache_customers');
      prefs.remove('cache_customers_time');
    });
  }
}
