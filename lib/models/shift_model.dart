class Shift {
  final String? id;
  final String name;
  final String startTime; // "09:00"
  final String endTime;   // "18:00"
  final int breakDurationMinutes;
  final bool isActive;
  final String? companyId;

  Shift({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.breakDurationMinutes = 60,
    this.isActive = true,
    this.companyId,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      name: json['name'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      breakDurationMinutes: json['break_duration_minutes'] ?? 0,
      isActive: json['is_active'] ?? true,
      companyId: json['company_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      'break_duration_minutes': breakDurationMinutes,
      'is_active': isActive,
      if (companyId != null) 'company_id': companyId,
    };
  }
}
