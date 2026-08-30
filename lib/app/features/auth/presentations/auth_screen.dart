import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/auth/models/auth_models.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';

Future<bool> requireMotorixLogin(
  BuildContext context, {
  AuthRole role = AuthRole.patient,
  bool initialSignup = false,
}) async {
  if (AuthService.instance.signedIn) {
    final profile = await AuthService.instance.profile();
    final userRole = profile?.role ?? AuthService.instance.currentRole;
    if (role == AuthRole.physiotherapist) {
      if (const {'physiotherapist', 'clinic_admin'}.contains(userRole)) {
        if (AuthService.instance.assuranceLevel ==
            AuthenticatorAssuranceLevels.aal2) {
          return true;
        }
      }
    } else {
      return true;
    }
  }

  if (!context.mounted) return false;
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AuthScreen(role: role, initialSignup: initialSignup),
        ),
      ) ??
      false;
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.role = AuthRole.patient,
    this.initialSignup = false,
  });

  final AuthRole role;
  final bool initialSignup;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _clinicController = TextEditingController();
  final _licenseController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();

  late bool _isSignup;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _busy = false;
  String? _error;
  String? _infoMessage;

  // MFA State for clinicians
  String? _mfaFactorId;
  String? _mfaSecret;
  bool _mfaChallenge = false;

  @override
  void initState() {
    super.initState();
    _isSignup = _isClinician ? false : widget.initialSignup;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _clinicController.dispose();
    _licenseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isClinician => widget.role == AuthRole.physiotherapist;

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form != null && !form.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    try {
      if (!AuthService.instance.configured) {
        await SupabaseConfig.initialize();
      }

      if (!AuthService.instance.configured) {
        throw StateError(
            'Server Supabase belum dikonfigurasi atau tidak dapat dijangkau.');
      }

      if (_isSignup) {
        await AuthService.instance.signUpPatient(PatientSignUpRequest(
          name: name,
          email: email,
          password: password,
        ));

        if (!AuthService.instance.signedIn) {
          setState(() {
            _infoMessage =
                'Akun berhasil dibuat. Silakan periksa email Anda untuk verifikasi, lalu masuk.';
            _isSignup = false;
          });
          return;
        }
      } else {
        await AuthService.instance.signIn(
          SignInRequest(email: email, password: password),
        );
      }

      var profile = await AuthService.instance.profile(forceRefresh: true);
      var role = profile?.role ?? AuthService.instance.currentRole;

      if (_isClinician) {
        if (!const {'physiotherapist', 'clinic_admin'}.contains(role)) {
          await AuthService.instance.signOut();
          throw StateError(
              'Akun klinisi harus dibuat melalui invitation administrator klinik.');
        }
        if (profile?.isVerified != true || profile?.isActive != true) {
          await AuthService.instance.signOut();
          throw StateError(
              'Akun klinisi belum diverifikasi atau sedang ditangguhkan. Hubungi administrator klinik.');
        }

        // Handle MFA for clinician
        if (AuthService.instance.assuranceLevel !=
            AuthenticatorAssuranceLevels.aal2) {
          final aal = Supabase.instance.client.auth.mfa
              .getAuthenticatorAssuranceLevel();
          if (aal.nextLevel == AuthenticatorAssuranceLevels.aal2) {
            setState(() => _mfaChallenge = true);
          } else {
            final enrolled = await AuthService.instance.enrollTotp();
            setState(() {
              _mfaFactorId = enrolled.id;
              _mfaSecret = enrolled.totp?.secret;
            });
          }
          return;
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      setState(() {
        _error = _formatErrorMessage(exception);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatErrorMessage(Object exception) {
    if (exception is AuthException) {
      final code = exception.code?.toLowerCase() ?? '';
      final msg = exception.message.toLowerCase();
      if (code == 'email_not_confirmed' ||
          code == 'email_not_verified' ||
          msg.contains('email not confirmed') ||
          msg.contains('email not verified')) {
        return 'Email Anda belum dikonfirmasi. Silakan periksa kotak masuk atau folder spam email Anda untuk mengonfirmasi akun.';
      }
      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          msg.contains('invalid login credentials')) {
        return 'Email atau kata sandi tidak cocok. Silakan periksa kembali.';
      }
      if (code == 'user_already_exists' ||
          code == 'user_already_registered' ||
          msg.contains('already registered')) {
        return 'Email ini sudah terdaftar. Silakan langsung masuk ke akun Anda.';
      }
      if (code == 'weak_password' || msg.contains('weak password')) {
        return 'Kata sandi terlalu pendek. Gunakan minimal 6 karakter.';
      }
      if (code == 'over_email_send_rate_limit' || msg.contains('rate limit')) {
        return 'Terlalu banyak permintaan email. Harap tunggu beberapa saat sebelum mencoba lagi.';
      }
      return exception.message;
    }
    return exception
        .toString()
        .replaceAll('StateError: ', '')
        .replaceAll('Exception: ', '');
  }

  Future<void> _resendConfirmationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
          () => _error = 'Masukkan alamat email yang valid di kolom input.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.resendEmailConfirmation(
        AuthEmailRequest(email: email),
      );
      setState(() {
        _infoMessage =
            'Tautan konfirmasi baru telah dikirim ke $email. Silakan periksa kotak masuk atau spam email Anda.';
      });
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyMfa() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Masukkan 6 digit kode dari authenticator.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_mfaChallenge) {
        await AuthService.instance.challengeExistingTotp(
          TotpVerificationRequest(code: code),
        );
      } else if (_mfaFactorId != null) {
        await AuthService.instance.verifyTotp(
          TotpVerificationRequest(code: code, factorId: _mfaFactorId),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      setState(() => _error = 'Kode verifikasi salah atau kedaluwarsa.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Kata Sandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Masukkan email akun Motorix Anda untuk menerima instruksi reset kata sandi:'),
            const SizedBox(height: 14),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Akun'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, resetEmailController.text.trim()),
            child: const Text('Kirim Link Reset'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await AuthService.instance.resetPassword(
          AuthEmailRequest(email: result),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Link reset kata sandi telah dikirim ke email Anda.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal mengirim reset email: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enteringMfa = _mfaChallenge || _mfaFactorId != null;

    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: AppColors.softWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.navy),
          onPressed: () => Navigator.maybePop(context, false),
        ),
        title: Text(
          _isClinician ? 'Portal Fisioterapis' : 'Portal Pasien',
          style: const TextStyle(
            color: AppColors.navy,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: enteringMfa ? _buildMfaView() : _buildAuthForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBadge() {
    final isClinician = _isClinician;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.green.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  isClinician
                      ? 'assets/images/physiotherapist_avatar.png'
                      : 'assets/images/patient_avatar.png',
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    isClinician
                        ? Icons.medical_services_rounded
                        : Icons.accessibility_new_rounded,
                    size: 38,
                    color: AppColors.green,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  isClinician
                      ? Icons.medical_services_rounded
                      : Icons.fitness_center_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isClinician ? 'MOTORIX CLINICAL' : 'MOTORIX PATIENT',
            style: const TextStyle(
              color: AppColors.green,
              fontFamily: 'SF Pro',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignup
              ? (isClinician ? 'Registrasi Fisioterapis' : 'Daftar Akun Pasien')
              : (isClinician ? 'Masuk Portal Klinisi' : 'Selamat Datang'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navy,
            fontFamily: 'SF Pro',
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isClinician
              ? (_isSignup
                  ? 'Daftarkan profil profesional Anda untuk mengelola resep latihan pasien.'
                  : 'Masuk dengan kredensial fisioterapis Anda.')
              : (_isSignup
                  ? 'Mulai program latihan mandiri terpandu berbasis AI.'
                  : 'Masuk untuk mengakses riwayat dan resep latihan Anda.'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navy,
            fontFamily: 'SF Pro',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _isSignup = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isSignup ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !_isSignup
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Masuk',
                  style: TextStyle(
                    color: !_isSignup ? Colors.white : AppColors.navy,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => setState(() => _isSignup = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isSignup ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isSignup
                      ? [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Daftar Baru',
                  style: TextStyle(
                    color: _isSignup ? Colors.white : AppColors.navy,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderBadge(),
          const SizedBox(height: 24),
          if (!_isClinician) _buildTabSelector(),
          if (_isClinician)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Akun klinisi hanya tersedia melalui invitation administrator klinik.',
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          if (_infoMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _infoMessage!,
                      style:
                          const TextStyle(color: AppColors.green, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_isSignup) ...[
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText:
                    _isClinician ? 'Nama Lengkap & Gelar' : 'Nama Lengkap',
                hintText: _isClinician
                    ? 'Contoh: dr. Nadia Sp.K.F.R'
                    : 'Contoh: Budi Santoso',
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Nama lengkap minimal 2 karakter.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            if (_isClinician) ...[
              TextFormField(
                controller: _clinicController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama Klinik / Rumah Sakit',
                  hintText: 'Contoh: Klinik Fisioterapi Sehat',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 2) {
                    return 'Nama klinik wajib diisi (minimal 2 karakter).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _licenseController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nomor SIP / STR (Opsional)',
                  hintText: 'Nomor izin praktik fisioterapi',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: _isClinician ? 'Email Klinis' : 'Alamat Email',
              hintText: 'nama@domain.com',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email tidak boleh kosong.';
              }
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Format email tidak valid.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction:
                _isSignup ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => _isSignup ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Kata Sandi',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.gray,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Kata sandi tidak boleh kosong.';
              }
              if (value.length < 6) {
                return 'Kata sandi minimal 6 karakter.';
              }
              return null;
            },
          ),
          if (_isSignup) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Konfirmasi Kata Sandi',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.gray,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Konfirmasi kata sandi tidak cocok.';
                }
                return null;
              },
            ),
          ],
          if (!_isSignup) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  foregroundColor: AppColors.green,
                ),
                child: const Text(
                  'Lupa Kata Sandi?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
          ],
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF87171)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),
                  if (_error!.contains('belum dikonfirmasi')) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _resendConfirmationEmail,
                        icon: const Icon(Icons.mark_email_read_outlined,
                            size: 16),
                        label: const Text('Kirim Ulang Email Konfirmasi'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      _isSignup
                          ? (_isClinician
                              ? 'Daftar sebagai Fisioterapis'
                              : 'Daftar sebagai Pasien')
                          : (_isClinician
                              ? 'Masuk Portal Klinisi'
                              : 'Masuk ke Aplikasi'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMfaView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.green.withValues(alpha: 0.3), width: 2),
          ),
          child: const Icon(
            Icons.security_rounded,
            size: 36,
            color: AppColors.green,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verifikasi Keamanan 2FA',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.navy,
            fontFamily: 'SF Pro',
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Untuk melindungi data klinis pasien, akun fisioterapis wajib menggunakan autentikasi 2 faktor (TOTP).',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.navy,
            fontFamily: 'SF Pro',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        if (_mfaSecret != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightGreen, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Salin Kunci Rahasia (Secret Key)',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Buka Google Authenticator / Authy, pilih "Input Setup Key", lalu tempelkan kunci di bawah ini:',
                  style: TextStyle(fontSize: 12, color: AppColors.gray),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _mfaSecret!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded,
                            size: 20, color: AppColors.green),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _mfaSecret!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Secret key berhasil disalin!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '2. Masukkan 6 Digit Kode dari Aplikasi Authenticator',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.navy),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '000000',
            prefixIcon: Icon(Icons.pin_rounded),
          ),
          onSubmitted: (_) => _verifyMfa(),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _busy ? null : _verifyMfa,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Verifikasi & Masuk',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _mfaChallenge = false;
                    _mfaFactorId = null;
                    _mfaSecret = null;
                  }),
          child: const Text('Kembali ke Login'),
        ),
      ],
    );
  }
}
