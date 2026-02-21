import 'dart:io';

void main() {
  final file = File('/Users/devacc/ez_billify_v2_app/lib/screens/admin_dashboard.dart');
  var content = file.readAsStringSync();
  print(content.contains("child: !hasData"));
}
