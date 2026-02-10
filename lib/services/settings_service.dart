import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SettingsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getCompanyProfile(String companyId) async {
    final response = await _supabase
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .single();
    return response;
  }

  Future<void> updateCompanyProfile(String companyId, Map<String, dynamic> data) async {
    await _supabase
        .from('companies')
        .update(data)
        .eq('id', companyId);
  }

  Future<List<Map<String, dynamic>>> getBranches(String companyId) async {
    final response = await _supabase
        .from('branches')
        .select('*')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getUsers(String companyId) async {
    final response = await _supabase
        .from('users')
        .select('*, user_roles(*, branches(name))')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getFinancialYears(String companyId) async {
    final response = await _supabase
        .from('financial_years')
        .select('*')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getGSTSettings(String companyId) async {
    final response = await _supabase
        .from('companies')
        .select('is_composition, enable_reverse_charge, default_hsn, enable_einvoice, enable_ewaybill')
        .eq('id', companyId)
        .single();
    return response;
  }

  Future<void> updateGSTSettings(String companyId, Map<String, dynamic> data) async {
    await _supabase
        .from('companies')
        .update(data)
        .eq('id', companyId);
  }

  Future<List<Map<String, dynamic>>> getDocumentSequences(String companyId) async {
    final response = await _supabase
        .from('document_sequences')
        .select('*, branches(id, name, code)')
        .eq('company_id', companyId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateDocumentSequence(String id, Map<String, dynamic> data) async {
    await _supabase
        .from('document_sequences')
        .update(data)
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final response = await _supabase
        .from('plans')
        .select('*')
        .eq('is_active', true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getBrandingSettings(String companyId) async {
    final response = await _supabase
        .from('companies')
        .select('branding, logo_url, thermal_logo_url')
        .eq('id', companyId)
        .single();
    return response;
  }

  Future<void> updateBrandingSettings(String companyId, Map<String, dynamic> data) async {
    await _supabase
        .from('companies')
        .update(data)
        .eq('id', companyId);
  }

  Future<Map<String, dynamic>> getBillingData(String companyId) async {
    // 1. Get Company
    final companyResponse = await _supabase
        .from('companies')
        .select('*')
        .eq('id', companyId)
        .single();
    
    // 2. Get Plan separately to avoid join errors if relationship is not defined
    Map<String, dynamic>? planData;
    if (companyResponse['plan_id'] != null) {
      try {
        planData = await _supabase
            .from('plans')
            .select('*')
            .eq('id', companyResponse['plan_id'])
            .maybeSingle();
      } catch (e) {
        debugPrint("Could not fetch plan data: $e");
      }
    }
    
    // 2. Fetch actual user count (Usage)
    int userCount = 0;
    try {
      final userCountRes = await _supabase
          .from('users')
          .select('*')
          .eq('company_id', companyId)
          .count(CountOption.exact);
      userCount = userCountRes.count ?? 0;
    } catch (e) {
      debugPrint("Could not fetch user count: $e");
    }

    // 3. Get Usage from billing_usage table if it exists
    Map<String, dynamic>? usageData;
    try {
      usageData = await _supabase
          .from('billing_usage')
          .select('*')
          .eq('company_id', companyId)
          .maybeSingle();
    } catch (e) {
      debugPrint("billing_usage table might be missing: $e");
    }

    // Map fields to match web backend response structure
    return {
      'company': {
        'id': companyResponse['id'],
        'name': companyResponse['name'],
        'email': companyResponse['email'],
        'billing_email': companyResponse['billing_email'],
        'status': companyResponse['subscription_status'] ?? 'active',
        'cycle_end': companyResponse['billing_cycle_end'],
        'created_at': companyResponse['created_at'],
      },
      'plan': planData ?? {
        'name': 'Basic Plan',
        'price': 0,
        'interval': 'month',
        'features': ['Standard Support', 'Daily Backups'],
        'limit_users': 1,
        'limit_storage_gb': 0.5,
        'limit_api_calls': 100
      },
      'usage': {
        'users': {
          'current': userCount, 
          'limit': companyResponse['plan']?['limit_users'] ?? 1
        },
        'storage': {
          'current': usageData?['storage_used'] ?? 0.0, 
          'limit': companyResponse['plan']?['limit_storage_gb'] ?? 0.5
        },
        'apiCalls': {
          'current': usageData?['api_calls_count'] ?? 0, 
          'limit': companyResponse['plan']?['limit_api_calls'] ?? 100
        }
      }
    };
  }

  Future<List<Map<String, dynamic>>> getBillingInvoices(String companyId) async {
    try {
      // Mirroring web behavior: Fetch from EZConnect
      const ezConnectUrl = 'https://support.ezbillify.com';
      final endpoint = '$ezConnectUrl/api/ezbillify/invoices?company_id=$companyId';
      
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle various response formats from EZConnect
        List list = [];
        if (data is Map) {
          if (data['success'] == true && data['data'] is List) {
            list = data['data'];
          } else if (data['invoices'] is List) {
            list = data['invoices'];
          }
        } else if (data is List) {
          list = data;
        }
        
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {
      debugPrint("Failed to fetch invoices from EZConnect: $e");
    }

    // Fallback to local table if EZConnect fails or is preferred
    try {
      // Check if billing_invoices exists by catching the error if it doesn't
      final response = await _supabase
          .from('billing_invoices')
          .select('*')
          .eq('company_id', companyId)
          .order('issue_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("billing_invoices table missing or error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getIntegrations(String companyId) async {
    final response = await _supabase
        .from('company_integrations')
        .select('provider_id, config, is_connected')
        .eq('company_id', companyId);
    
    final configMap = <String, dynamic>{};
    for (var item in response) {
      final config = Map<String, dynamic>.from(item['config'] ?? {});
      config['is_connected'] = item['is_connected'] ?? false;
      configMap[item['provider_id']] = config;
    }
    return configMap;
  }

  Future<void> updateIntegrations(String companyId, String providerId, Map<String, dynamic> config) async {
    // Determine connectivity
    final isConnected = config.values.any((v) => v != null && v.toString().isNotEmpty);
    
    await _supabase.from('company_integrations').upsert({
      'company_id': companyId,
      'provider_id': providerId,
      'config': config,
      'is_connected': isConnected,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'company_id, provider_id');
  }

  Future<void> deleteIntegration(String companyId, String providerId) async {
    await _supabase
        .from('company_integrations')
        .delete()
        .eq('company_id', companyId)
        .eq('provider_id', providerId);
  }

  Future<void> createBranch(Map<String, dynamic> data) async {
    await _supabase.from('branches').insert(data);
  }

  Future<void> updateBranch(String id, Map<String, dynamic> data) async {
    await _supabase.from('branches').update(data).eq('id', id);
  }

  Future<Map<String, String>?> fetchAddressFromPincode(String pincode) async {
    try {
      final response = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffice = data[0]['PostOffice'][0];
          return {
            'city': postOffice['District'],
            'state': postOffice['State'],
          };
        }
      }
    } catch (e) {
      debugPrint("Pincode error: $e");
    }
    return null;
  }

  Future<void> deleteBranch(String id) async {
    await _supabase.from('branches').delete().eq('id', id);
  }

  Future<void> inviteUser(Map<String, dynamic> data) async {
    // In our system, invitations are usually handled by the users table or a function
    await _supabase.from('users').insert(data);
  }

  Future<void> removeUser(String profileId) async {
    await _supabase.from('users').delete().eq('id', profileId);
  }

  Future<void> createFinancialYear(Map<String, dynamic> data) async {
    await _supabase.from('financial_years').insert(data);
  }

  Future<void> updateFinancialYear(String id, Map<String, dynamic> data) async {
    await _supabase.from('financial_years').update(data).eq('id', id);
  }

  Future<void> setActiveFinancialYear(String companyId, String yearId) async {
    await _supabase.from('financial_years').update({'is_active': false}).eq('company_id', companyId);
    await _supabase.from('financial_years').update({'is_active': true}).eq('id', yearId);
  }

  Future<String> uploadLogo(String companyId, String path, String fileName) async {
    final file = File(path);
    final fileBytes = await file.readAsBytes();
    final ext = fileName.split('.').last;
    final uploadPath = 'logos/$companyId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    await _supabase.storage.from('company-assets').uploadBinary(uploadPath, fileBytes);
    return _supabase.storage.from('company-assets').getPublicUrl(uploadPath);
  }
}

