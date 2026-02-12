class AttendanceRecord {
  final String? id;
  final String employeeId;
  final String date;  // YYYY-MM-DD
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status; // present, late, absent
  final String? deviationReason;
  final Map<String, dynamic>? locationMetadata;
  // Join for display
  final String? employeeName;
  final String? employeeCode;
  final String? employeeAvatarUrl;

  AttendanceRecord({
    this.id,
    required this.employeeId,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'absent',
    this.deviationReason,
    this.locationMetadata,
    this.employeeName,
    this.employeeCode,
    this.employeeAvatarUrl,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final emp = json['employees'] as Map<String, dynamic>?;
    return AttendanceRecord(
      id: json['id'],
      employeeId: json['employee_id'],
      date: json['date'],
      checkIn: json['check_in'] != null ? DateTime.parse(json['check_in']) : null,
      checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      status: json['status'] ?? 'absent',
      deviationReason: json['deviation_reason'],
      locationMetadata: json['location_metadata'],
      employeeName: emp != null ? "${emp['first_name']} ${emp['last_name'] ?? ''}".trim() : null,
      employeeCode: emp != null ? emp['employee_code'] : null,
      employeeAvatarUrl: emp != null ? emp['avatar_url'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'date': date,
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'status': status,
      'deviation_reason': deviationReason,
      'location_metadata': locationMetadata,
    };
  }
}
