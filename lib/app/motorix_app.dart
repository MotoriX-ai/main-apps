import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/auth/presentations/onboarding_screen.dart';
import 'package:motorix_phase2/app/features/auth/presentations/role_selection_screen.dart';
import 'package:motorix_phase2/app/features/auth/presentations/splash_screen.dart';

class MotorixApp extends StatelessWidget {
  const MotorixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: motorixLocale,
        builder: (context, _) => MaterialApp(
              title: 'Motorix PhysioAI',
              debugShowCheckedModeBanner: false,
              locale: motorixLocale.locale,
              supportedLocales: const [Locale('id'), Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.green,
                  brightness: Brightness.light,
                  primary: AppColors.green,
                  surface: AppColors.white,
                ),
                scaffoldBackgroundColor: AppColors.softWhite,
                canvasColor: AppColors.softWhite,
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: const [
                  'SF Pro Text',
                  '.SF Pro Text',
                  'SF Pro Display',
                ],
                textTheme: AppTypography.textTheme,
                primaryTextTheme: AppTypography.textTheme,
                useMaterial3: true,
                cardTheme: const CardThemeData(
                  color: AppColors.white,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.lightGreen),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: AppColors.lightGreen),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.softWhite,
                    textStyle: AppTypography.textTheme.labelLarge,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              home: const SplashScreen(
                nextScreen: OnboardingScreen(nextScreen: RoleSelectionScreen()),
              ),
            ));
  }
}
