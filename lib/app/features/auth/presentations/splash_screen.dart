import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:flutter/services.dart';

import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:motorix_phase2/app/features/clinic/presentations/therapist_capture_screen.dart';
import 'package:motorix_phase2/app/features/home/presentations/patient_dashboard_screen.dart';

/// Animated splash screen based on the two MotoriX Figma states.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  final Widget nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _designSize = Size(375, 812);
  static const _animationDuration = Duration(milliseconds: 1100);
  static const _initialPause = Duration(milliseconds: 350);
  static const _finalPause = Duration(milliseconds: 850);

  late final AnimationController _controller;
  late final Animation<double> _logoProgress;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    _logoProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _playSplash());
  }

  Future<void> _playSplash() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      await Future<void>.delayed(_initialPause);
      if (!mounted) return;
      await _controller.forward();
    } else {
      _controller.value = 1;
    }

    if (!mounted) return;
    _navigationTimer = Timer(_finalPause, _openNextScreen);
  }

  Future<void> _openNextScreen() async {
    if (!mounted) return;

    Widget destination = widget.nextScreen;
    if (AuthService.instance.signedIn) {
      try {
        final profile = await AuthService.instance.profile();
        final role = profile?.role ?? AuthService.instance.currentRole;
        if (const {'physiotherapist', 'clinic_admin'}.contains(role)) {
          destination = const TherapistCaptureScreen();
        } else {
          destination = const PatientDashboardScreen();
        }
      } catch (_) {
        destination = widget.nextScreen;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => destination,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _SplashColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _SplashColors.background,
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox.fromSize(
              size: _designSize,
              child: AnimatedBuilder(
                animation: _logoProgress,
                builder: (context, child) {
                  final progress = _logoProgress.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: _lerp(169.502, 102.503, progress),
                        top: _lerp(427, 288.81, progress),
                        width: _lerp(38.936, 169.314, progress),
                        height: _lerp(37.189, 161.717, progress),
                        child: child!,
                      ),
                      const Positioned(
                        top: 464,
                        left: 0,
                        right: 0,
                        child: _Wordmark(),
                      ),
                    ],
                  );
                },
                child: Image.asset(
                  'assets/images/motorix_logo_large.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _lerp(double begin, double end, double progress) {
    return begin + ((end - begin) * progress);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'MotoriX',
          style: TextStyle(
            color: _SplashColors.title,
            fontFamily: 'SF Pro',
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: const Text(
            'Every Movement Counts',
            style: TextStyle(
              color: _SplashColors.subtitle,
              fontFamily: 'SF Pro',
              fontSize: 18,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

abstract final class _SplashColors {
  static const background = AppColors.softWhite;
  static const title = Color(0xFF124067);
  static const subtitle = Color(0xFF5D6A85);
}
