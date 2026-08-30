import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/auth/models/auth_models.dart';
import 'package:motorix_phase2/app/features/auth/presentations/auth_screen.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:motorix_phase2/app/features/clinic/presentations/therapist_capture_screen.dart';
import 'package:motorix_phase2/app/features/home/presentations/patient_dashboard_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _openPatient(BuildContext context) async {
    if (AuthService.instance.signedIn && AuthService.instance.isPatient) {
      _open(context, const PatientDashboardScreen());
      return;
    }

    final success = await requireMotorixLogin(
      context,
      role: AuthRole.patient,
    );

    if (success && context.mounted) {
      _open(context, const PatientDashboardScreen());
    }
  }

  Future<void> _openTherapist(BuildContext context) async {
    if (AuthService.instance.signedIn &&
        AuthService.instance.isClinician &&
        AuthService.instance.assuranceLevel ==
            AuthenticatorAssuranceLevels.aal2) {
      _open(context, const TherapistCaptureScreen());
      return;
    }

    final success = await requireMotorixLogin(
      context,
      role: AuthRole.physiotherapist,
    );

    if (success && context.mounted) {
      _open(context, const TherapistCaptureScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _RoleColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _RoleColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      width: constraints.maxWidth.clamp(0, 375),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 28, 30, 64),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/motorix_wordmark.png',
                              width: 160,
                              height: 51,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'Selamat Datang',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _RoleColors.green,
                                fontFamily: 'SF Pro',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Pilih peran Anda untuk melanjutkan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _RoleColors.navy,
                                fontFamily: 'SF Pro',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _RoleCard(
                              role: _Role.patient,
                              title: 'Pasien',
                              description:
                                  'Mulai latihan mandiri dengan pelacakan AI dan feedback real-time.',
                              onTap: () => _openPatient(context),
                            ),
                            const SizedBox(height: 24),
                            _RoleCard(
                              role: _Role.physiotherapist,
                              title: 'Fisioterapis',
                              description:
                                  'Rekam demonstrasi gerakan, buat resep latihan, dan kelola pasien.',
                              onTap: () => _openTherapist(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final _Role role;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _RoleColors.green,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: _RoleColors.navy.withValues(alpha: 0.15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 280,
          height: 216,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (role == _Role.patient) ...[
                Positioned(
                  left: -12,
                  top: 7,
                  width: 181,
                  height: 199,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/role_patient_illustration.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Positioned(
                  left: 179,
                  top: 47,
                  width: 55,
                  height: 55,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/role_patient_camera.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ] else ...[
                Positioned(
                  left: 16,
                  top: 48,
                  width: 157,
                  height: 157,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/role_physio_illustration.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Positioned(
                  left: 199,
                  top: 127,
                  width: 55,
                  height: 55,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/role_physio_mobile.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ],
              Positioned(
                top: role == _Role.patient ? 115 : 16,
                right: role == _Role.patient ? 22 : 18,
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _RoleColors.background,
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              Positioned(
                top: role == _Role.patient ? 142 : 45,
                right: 22,
                width: 130,
                child: Text(
                  description,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _RoleColors.background,
                    fontFamily: 'SF Pro',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Role { patient, physiotherapist }

abstract final class _RoleColors {
  static const background = AppColors.softWhite;
  static const navy = AppColors.navy;
  static const green = AppColors.green;
}
