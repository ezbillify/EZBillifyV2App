import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_model.dart';
import '../models/shift_model.dart';
import '../models/attendance_model.dart';
import '../models/leave_model.dart';

class HrService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  static final HrService _instance = HrService._internal();
  factory HrService() => _instance;
  HrService._internal();

  // Fetch all employees for the company
  Future<List<Employee>> getEmployees(String companyId) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId)
          .order('first_name', ascending: true);
          
      return (response as List).map((e) => Employee.fromJson(e)).toList();
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching employees: $e");
      rethrow;
    }
  }

  // Fetch single employee
  Future<Employee?> getEmployeeById(String id) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('id', id)
          .single();
      
      return Employee.fromJson(response);
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching employee $id: $e");
      return null;
    }
  }

  // Create new employee
  Future<void> createEmployee(Employee employee, String companyId) async {
    try {
      final data = employee.toJson();
      data['company_id'] = companyId;
      // Remove ID if null to let DB generate it
      if (data['id'] == null) data.remove('id');
      
      await _supabase.from('employees').insert(data);
    } catch (e) {
      debugPrint("HR SERVICE: Error creating employee: $e");
      rethrow;
    }
  }

  // Update existing employee
  Future<void> updateEmployee(Employee employee) async {
    try {
      if (employee.id == null) throw Exception("Employee ID is required for update");
      
      final data = employee.toJson();
      // Don't update company_id typically, but can be safe to remove
      data.remove('company_id'); 
      
      await _supabase
          .from('employees')
          .update(data)
          .eq('id', employee.id!);
    } catch (e) {
      debugPrint("HR SERVICE: Error updating employee: $e");
      rethrow;
    }
  }

  // Delete employee (soft delete usually better, but sticking to simple delete for now based on request)
  Future<void> deleteEmployee(String id) async {
    try {
      await _supabase.from('employees').delete().eq('id', id);
    } catch (e) {
      debugPrint("HR SERVICE: Error deleting employee: $e");
      rethrow;
    }
  }

  // Fetch branches for dropdown
  Future<List<Map<String, dynamic>>> getBranches(String companyId) async {
    try {
      final response = await _supabase
          .from('branches')
          .select('id, name, is_primary')
          .eq('company_id', companyId)
          .order('name');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching branches: $e");
      return [];
    }
  }

  // --- SHIFTS ---
  Future<List<Shift>> getShifts(String companyId) async {
    try {
      final response = await _supabase
          .from('shifts')
          .select()
          .eq('company_id', companyId)
          .order('name');
      return (response as List).map((e) => Shift.fromJson(e)).toList();
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching shifts: $e");
      return [];
    }
  }

  Future<void> createShift(Shift shift, String companyId) async {
    try {
      final data = shift.toJson();
      data['company_id'] = companyId;
      if (data['id'] == null) data.remove('id');
      await _supabase.from('shifts').insert(data);
    } catch (e) {
      debugPrint("HR SERVICE: Error creating shift: $e");
      rethrow;
    }
  }

  Future<void> updateShift(Shift shift) async {
    try {
      if (shift.id == null) throw Exception("Shift ID required");
      final data = shift.toJson();
      data.remove('company_id');
      await _supabase.from('shifts').update(data).eq('id', shift.id!);
    } catch (e) {
      debugPrint("HR SERVICE: Error updating shift: $e");
      rethrow;
    }
  }

  Future<void> deleteShift(String id) async {
    try {
      await _supabase.from('shifts').delete().eq('id', id);
    } catch (e) {
      debugPrint("HR SERVICE: Error deleting shift: $e");
      rethrow;
    }
  }

  // --- ATTENDANCE ---
  Future<List<AttendanceRecord>> getAttendance(String companyId, {DateTime? date, String? employeeId}) async {
    try {
      var query = _supabase
        .from('attendance')
        .select('*, employees:employee_id(first_name, last_name, employee_code, avatar_url)')
        .eq('company_id', companyId);
      
      if (date != null) {
        // Filter by date string YYYY-MM-DD
        final dateStr = date.toIso8601String().split('T')[0];
        query = query.eq('date', dateStr);
      }
      
      if (employeeId != null && employeeId != 'all') {
        query = query.eq('employee_id', employeeId);
      }

      final response = await query.order('check_in', ascending: false);
      return (response as List).map((e) => AttendanceRecord.fromJson(e)).toList();
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching attendance: $e");
      return [];
    }
  }

  Future<void> updateAttendanceRecord(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('attendance').update(updates).eq('id', id);
    } catch (e) {
      debugPrint("HR SERVICE: Error updating attendance: $e");
      rethrow;
    }
  }

  // --- WORKFORCE MONITOR ---
  Future<List<Map<String, dynamic>>> getWorkforceUsers(String companyId) async {
    try {
      // Join to get latest status if possible, or just user details
      final response = await _supabase
          .from('users') // Assuming 'users' table has role
          .select('id, name, email, is_online, last_seen, role') 
          .eq('company_id', companyId)
          .eq('role', 'workforce') 
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching workforce users: $e");
      return [];
    }
  }
  
  // Realtime subscription setup to be done in UI screens

  // --- LEAVES ---
  Future<List<Leave>> getLeaves(String companyId) async {
    try {
      final response = await _supabase
          .from('leaves')
          .select('*, employees:employee_id(first_name, last_name, employee_code)')
          .eq('company_id', companyId)
          .order('created_at', ascending: false);
      return (response as List).map((e) => Leave.fromJson(e)).toList();
    } catch (e) {
      debugPrint("HR SERVICE: Error fetching leaves: $e");
      return [];
    }
  }

  Future<void> updateLeaveStatus(String id, String status) async {
    try {
      await _supabase.from('leaves').update({'status': status}).eq('id', id);
    } catch (e) {
      debugPrint("HR SERVICE: Error updating leave: $e");
      rethrow;
    }
  }

  Future<void> createLeave(Leave leave) async {
     try {
      final data = leave.toJson();
      if (data['id'] == null) data.remove('id');
      await _supabase.from('leaves').insert(data);
    } catch (e) {
      debugPrint("HR SERVICE: Error creating leave: $e");
      rethrow;
    }
  }
}
