import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_models.dart';
import 'master_data_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendOtp(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  Future<AuthResponse> verifyOtp(String email, String token) async {
    return await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.magiclink, // Magiclink type also works for 6-digit codes in Supabase auth
    );
  }

  Future<void> signOut() async {
    MasterDataService().invalidateCache();
    await _supabase.auth.signOut();
  }

  Future<AppUser?> fetchUserProfile(String authId) async {
    try {
      // Optimized Query: Fetches user and roles in one round-trip, just like the web app
      final response = await _supabase
          .from('users')
          .select('''
            id,
            name,
            company_id,
            company:companies (name),
            user_roles (role, active, branch_id)
          ''')
          .eq('auth_id', authId)
          .maybeSingle();

      if (response == null) {
        debugPrint('AuthService: Profile not found in "users" table for auth_id: $authId');
        return null;
      }

      final rolesList = response['user_roles'] as List?;
      final activeRoles = rolesList
              ?.where((r) => r['active'] != false)
              .toList() ?? [];

      if (activeRoles.isEmpty) {
        debugPrint('AuthService: Access Denied. No active roles found for user: ${response['id']}');
        return null;
      }

      // Prioritize Roles (Owner > Admin > Others) matching web logic
      final roleStrings = activeRoles.map((r) => (r['role'] as String).toLowerCase()).toList();
      String primaryRoleStr = roleStrings[0];
      
      if (roleStrings.contains('owner')) primaryRoleStr = 'owner';
      else if (roleStrings.contains('admin')) primaryRoleStr = 'admin';

      final primaryRole = UserRole.fromString(primaryRoleStr);
      
      // Find the specific role data to get branch_id
      final primaryRoleData = activeRoles.firstWhere(
        (r) => (r['role'] as String).toLowerCase() == primaryRoleStr,
        orElse: () => activeRoles[0],
      );

      debugPrint('AuthService: User authenticated as $primaryRoleStr');
      
      return AppUser.fromMap({
        ...response,
        'branch_id': primaryRoleData['branch_id'],
        'email': _supabase.auth.currentUser?.email ?? '',
      }, primaryRole);
    } catch (e, stack) {
      debugPrint('AuthService: Critical error fetching user profile: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await fetchUserProfile(user.id);
  }
}
