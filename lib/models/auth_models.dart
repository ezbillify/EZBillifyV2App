enum UserRole {
  owner,
  admin,
  employee,
  workforce,
  unknown;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'employee':
        return UserRole.employee;
      case 'workforce':
        return UserRole.workforce;
      default:
        return UserRole.unknown;
    }
  }

  bool get isAdminOrOwner => this == UserRole.admin || this == UserRole.owner;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.employee:
        return 'Employee';
      case UserRole.workforce:
        return 'Workforce';
      default:
        return 'User';
    }
  }
}

class AppUser {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String? companyId;
  final String? companyName;
  final String? branchId;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.companyId,
    this.companyName,
    this.branchId,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, UserRole role) {
    return AppUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: role,
      companyId: map['company_id'],
      companyName: map['company']?['name'],
      branchId: map['branch_id'], // This might come from user_roles table
    );
  }
}
