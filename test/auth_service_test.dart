import 'package:motorix_phase2/app/features/auth/models/auth_models.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:test/test.dart';

void main() {
  group('AuthService Tests', () {
    test('instance returns singleton and default values when unconfigured', () {
      final auth = AuthService.instance;
      expect(auth.configured, isFalse);
      expect(auth.signedIn, isFalse);
      expect(auth.accessToken, isNull);
      expect(auth.user, isNull);
      expect(auth.currentRole, 'patient');
      expect(auth.isPatient, isTrue);
      expect(auth.isClinician, isFalse);
      expect(auth.currentDisplayName, isNull);
    });

    test('throws StateError when unconfigured auth methods are called',
        () async {
      final auth = AuthService.instance;

      expect(
        () => auth.signIn(const SignInRequest(
          email: 'test@test.com',
          password: 'password',
        )),
        throwsA(isA<StateError>()),
      );

      expect(
        () => auth.signUpPatient(const PatientSignUpRequest(
          name: 'John Doe',
          email: 'john@test.com',
          password: 'password123',
        )),
        throwsA(isA<StateError>()),
      );

      expect(
        () => auth.signUpPhysiotherapist(
          const PhysiotherapistSignUpRequest(
            name: 'Dr Nadia',
            email: 'nadia@test.com',
            password: 'password123',
            clinicName: 'Motorix Clinic',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
