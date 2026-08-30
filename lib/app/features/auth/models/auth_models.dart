enum AuthRole { patient, physiotherapist }

class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.role,
    required this.displayName,
    required this.locale,
    required this.accountStatus,
    this.clinicId,
    this.verifiedAt,
    this.verifiedBy,
  });

  final String id;
  final String? clinicId;
  final String role;
  final String displayName;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final String locale;
  final String accountStatus;

  bool get isClinician =>
      const {'physiotherapist', 'clinic_admin'}.contains(role);
  bool get isActive => accountStatus == 'active';
  bool get isVerified => verifiedAt != null;

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
        id: json['id']?.toString() ?? '',
        clinicId: json['clinic_id']?.toString(),
        role: json['role']?.toString() ?? 'patient',
        displayName: json['display_name']?.toString() ?? '',
        verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? ''),
        verifiedBy: json['verified_by']?.toString(),
        locale: json['locale']?.toString() ?? 'id',
        accountStatus: json['account_status']?.toString() ?? 'active',
      );
}

class SignInRequest {
  const SignInRequest({required this.email, required this.password});

  final String email;
  final String password;
}

class PatientSignUpRequest {
  const PatientSignUpRequest({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
  });

  final String name;
  final String email;
  final String password;
  final String? phone;
}

class PhysiotherapistSignUpRequest {
  const PhysiotherapistSignUpRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.clinicName,
    this.licenseNumber,
  });

  final String name;
  final String email;
  final String password;
  final String clinicName;
  final String? licenseNumber;
}

class AuthEmailRequest {
  const AuthEmailRequest({required this.email});

  final String email;
}

class TotpVerificationRequest {
  const TotpVerificationRequest({required this.code, this.factorId});

  final String code;
  final String? factorId;
}
