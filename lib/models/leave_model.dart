class Leave {
  final String? id;
  final String leaveType; // sick, casual, annual
  final String startDate; // YYYY-MM-DD
  final String endDate;   // YYYY-MM-DD
  final String? reason;
  final String status;    // pending, approved, rejected
  final String? companyId;
  final String? employeeId;
  // Joined fields
  final String? employeeName;
  final String? employeeCode;

  Leave({
    this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.status = 'pending',
    this.companyId,
    this.employeeId,
    this.employeeName,
    this.employeeCode,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    final emp = json['employees'] as Map<String, dynamic>?;
    return Leave(
      id: json['id'],
      leaveType: json['leave_type'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      reason: json['reason'],
      status: json['status'] ?? 'pending',
      companyId: json['company_id'],
      employeeId: json['employee_id'],
      employeeName: emp != null ? "${emp['first_name']} ${emp['last_name'] ?? ''}".trim() : null,
      employeeCode: emp != null ? emp['employee_code'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'status': status,
      if (companyId != null) 'company_id': companyId,
      if (employeeId != null) 'employee_id': employeeId,
    };
  }
}
