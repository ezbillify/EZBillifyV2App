import 'dart:io';

void main() {
  final file = File('/Users/devacc/ez_billify_v2_app/lib/screens/admin_dashboard.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll(
'''          SizedBox(
            height: 280,
            child: !hasData 
            child: !hasData 
              ? Center(child: Text("No data for this period", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)))
              : Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: LineChart(''','''          SizedBox(
            height: 280,
            child: !hasData 
              ? Center(child: Text("No data for this period", style: TextStyle(fontFamily: 'Outfit', color: context.textSecondary)))
              : Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: LineChart(''');
  file.writeAsStringSync(content);
}
