import 'package:flutter/foundation.dart';
import 'package:motorix_phase2/app/features/auth/models/auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static const defaultUrl = 'https://oiefwzquzwnvctezxvmk.supabase.co';
  static const defaultPublishableKey =
      'sb_publishable_KvnO6jp9gJhexp5psTAhMA_IdIYbrLI';

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultUrl,
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: defaultPublishableKey,
  );

  static bool get available => url.isNotEmpty && publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!available) return;
    try {
      await Supabase.initialize(url: url, publishableKey: publishableKey);
      AuthService.instance._bindAuthListener();
    } catch (_) {
      // Supabase already initialized or in test environment
    }
  }
}

class AuthService extends ChangeNotifier {
  AuthService._() {
    _bindAuthListener();
  }

  static final instance = AuthService._();

  bool _listenerBound = false;

  void _bindAuthListener() {
    if (_listenerBound) return;
    try {
      if (SupabaseConfig.available) {
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (data.session == null) {
            _cachedProfile = null;
          }
          notifyListeners();
        });
        _listenerBound = true;
      }
    } catch (_) {
      // Ignored if Supabase.initialize has not run yet
    }
  }

  SupabaseClient? get _client {
    if (!SupabaseConfig.available) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  AuthProfile? _cachedProfile;

  bool get configured => _client != null;
  bool get signedIn => _client?.auth.currentSession != null;
  String? get accessToken => _client?.auth.currentSession?.accessToken;
  User? get user => _client?.auth.currentUser;

  AuthProfile? get cachedProfile => _cachedProfile;

  String? get currentDisplayName {
    final profileName = _cachedProfile?.displayName;
    if (profileName != null && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    final metaName = user?.userMetadata?['display_name']?.toString();
    if (metaName != null && metaName.trim().isNotEmpty) {
      return metaName.trim();
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }

  String get currentRole {
    final profileRole = _cachedProfile?.role;
    if (profileRole != null && profileRole.isNotEmpty) {
      return profileRole;
    }
    return 'patient';
  }

  bool get isClinician =>
      const {'physiotherapist', 'clinic_admin'}.contains(currentRole);

  bool get isPatient => currentRole == 'patient';

  Future<void> signIn(SignInRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    _cachedProfile = null;
    await client.auth.signInWithPassword(
      email: request.email.trim(),
      password: request.password,
    );
    await profile(forceRefresh: true);
    notifyListeners();
  }

  Future<void> signUpPatient(PatientSignUpRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    _cachedProfile = null;
    await client.auth.signUp(
      email: request.email.trim(),
      password: request.password,
      data: {
        'display_name': request.name.trim(),
        'role': 'patient',
        if (request.phone != null && request.phone!.trim().isNotEmpty)
          'phone': request.phone!.trim(),
      },
    );
    if (signedIn) {
      await profile(forceRefresh: true);
    }
    notifyListeners();
  }

  Future<void> signUpPhysiotherapist(
    PhysiotherapistSignUpRequest request,
  ) async {
    throw StateError(
        'Akun fisioterapis hanya dapat dibuat melalui invitation administrator klinik.');
  }

  Future<void> resetPassword(AuthEmailRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    await client.auth.resetPasswordForEmail(request.email.trim());
  }

  Future<void> resendEmailConfirmation(AuthEmailRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    await client.auth.resend(
      type: OtpType.signup,
      email: request.email.trim(),
    );
  }

  Future<void> signOut() async {
    _cachedProfile = null;
    await _client?.auth.signOut();
    notifyListeners();
  }

  Future<AuthProfile?> profile({bool forceRefresh = false}) async {
    if (_cachedProfile != null && !forceRefresh) {
      return _cachedProfile;
    }
    final client = _client;
    final id = user?.id;
    if (client == null || id == null) {
      _cachedProfile = null;
      return null;
    }
    final data = await client
        .from('profiles')
        .select(
            'id,clinic_id,role,display_name,verified_at,verified_by,locale,account_status')
        .eq('id', id)
        .maybeSingle();
    _cachedProfile = data == null
        ? null
        : AuthProfile.fromJson(Map<String, dynamic>.from(data));
    notifyListeners();
    return _cachedProfile;
  }

  Future<void> syncProfileWithMetadata() async {
    final client = _client;
    if (client == null || user == null) return;
    try {
      await client.rpc('sync_profile_from_metadata');
      await profile(forceRefresh: true);
    } catch (_) {
      // Ignored if RPC is not available in database
    }
  }

  AuthenticatorAssuranceLevels? get assuranceLevel =>
      _client?.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel;

  Future<AuthMFAEnrollResponse> enrollTotp() async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    return client.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Motorix',
      friendlyName: 'Motorix Authenticator',
    );
  }

  Future<void> verifyTotp(TotpVerificationRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    final factorId = request.factorId;
    if (factorId == null || factorId.isEmpty) {
      throw ArgumentError.value(factorId, 'factorId', 'Factor ID wajib diisi.');
    }
    await client.auth.mfa.challengeAndVerify(
      factorId: factorId,
      code: request.code.trim(),
    );
    notifyListeners();
  }

  Future<void> challengeExistingTotp(TotpVerificationRequest request) async {
    final client = _client;
    if (client == null) throw StateError('Supabase belum dikonfigurasi.');
    final factors = await client.auth.mfa.listFactors();
    if (factors.totp.isEmpty) {
      throw StateError('Authenticator belum didaftarkan.');
    }
    await client.auth.mfa.challengeAndVerify(
      factorId: factors.totp.first.id,
      code: request.code.trim(),
    );
    notifyListeners();
  }
}
