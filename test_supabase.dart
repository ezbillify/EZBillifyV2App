import 'package:supabase_flutter/supabase_flutter.dart';
void main() {
  final supabase = SupabaseClient('https://xyz.supabase.co', '123');
  var query = supabase.from('test').select();
  query = query.isFilter('branch_id', null);
  print('success isFilter');
  // query = query.is_('branch_id', null);
  print('success is_');
}
