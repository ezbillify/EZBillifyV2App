class Employee {
  final String? id;
  final String firstName;
  final String? lastName;
  final String? email;
  final String phone;
  final String? secondaryPhone;
  final String? designation;
  final String? departmentId;
  final DateTime? dateOfJoining;
  final DateTime? dateOfBirth;
  final String status;
  final String? gender;
  final String? bloodGroup;
  final String role;
  final Address? address;
  final BankDetails? bankDetails;
  final SalaryDetails? salaryDetails;
  final EmergencyContact? emergencyContact;
  final String? branchId;
  final bool? isUser;
  final String? userId;

  Employee({
    this.id,
    required this.firstName,
    this.lastName,
    this.email,
    required this.phone,
    this.secondaryPhone,
    this.designation,
    this.departmentId,
    this.dateOfJoining,
    this.dateOfBirth,
    this.status = 'active',
    this.gender,
    this.bloodGroup,
    this.role = 'employee',
    this.address,
    this.bankDetails,
    this.salaryDetails,
    this.emergencyContact,
    this.branchId,
    this.isUser,
    this.userId,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String?,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      secondaryPhone: json['secondary_phone'] as String?,
      designation: json['designation'] as String?,
      departmentId: json['department_id'] as String?,
      dateOfJoining: json['date_of_joining'] != null ? DateTime.parse(json['date_of_joining']) : null,
      dateOfBirth: json['date_of_birth'] != null ? DateTime.parse(json['date_of_birth']) : null,
      status: json['status'] ?? 'active',
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      role: json['role'] ?? 'employee',
      address: json['address'] != null ? Address.fromJson(json['address']) : null,
      bankDetails: json['bank_details'] != null ? BankDetails.fromJson(json['bank_details']) : null,
      salaryDetails: json['salary_details'] != null ? SalaryDetails.fromJson(json['salary_details']) : null,
      emergencyContact: json['emergency_contact'] != null ? EmergencyContact.fromJson(json['emergency_contact']) : null,
      branchId: json['branch_id'] as String?,
      isUser: json['is_user'] as bool?,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'secondary_phone': secondaryPhone,
      'designation': designation,
      'department_id': departmentId,
      'date_of_joining': dateOfJoining?.toIso8601String(),
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'status': status,
      'gender': gender,
      'blood_group': bloodGroup,
      'role': role,
      'address': address?.toJson(),
      'bank_details': bankDetails?.toJson(),
      'salary_details': salaryDetails?.toJson(),
      'emergency_contact': emergencyContact?.toJson(),
      'branch_id': branchId,
      'is_user': isUser,
      'user_id': userId,
    };
  }
}

class Address {
  final String? line1;
  final String? city;
  final String? state;
  final String? zipcode;

  Address({this.line1, this.city, this.state, this.zipcode});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      line1: json['line1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipcode: json['zipcode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'line1': line1,
    'city': city,
    'state': state,
    'zipcode': zipcode,
  };
}

class BankDetails {
  final String? accountNumber;
  final String? bankName;
  final String? ifsc;

  BankDetails({this.accountNumber, this.bankName, this.ifsc});

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      accountNumber: json['account_number'] as String?,
      bankName: json['bank_name'] as String?,
      ifsc: json['ifsc'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'account_number': accountNumber,
    'bank_name': bankName,
    'ifsc': ifsc,
  };
}

class SalaryDetails {
  final String? basic;
  final String? allowance;

  SalaryDetails({this.basic, this.allowance});

  factory SalaryDetails.fromJson(Map<String, dynamic> json) {
    return SalaryDetails(
      basic: json['basic']?.toString(), // Handle if API sends numbers
      allowance: json['allowance']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'basic': basic,
    'allowance': allowance,
  };
}

class EmergencyContact {
  final String? name;
  final String? phone;

  EmergencyContact({this.name, this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
  };
}
