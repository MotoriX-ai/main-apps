import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorix_phase2/app/features/auth/models/auth_models.dart';
import 'package:motorix_phase2/app/features/auth/presentations/auth_screen.dart';

void main() {
  group('AuthScreen Widget Tests', () {
    testWidgets('renders patient login and signup form correctly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(role: AuthRole.patient),
        ),
      );

      expect(find.text('Portal Pasien'), findsOneWidget);
      expect(find.text('Selamat Datang'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Daftar Baru'), findsOneWidget);
      expect(find.text('Alamat Email'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Lupa Kata Sandi?'), findsOneWidget);
      expect(find.text('Lanjutkan sebagai Tamu (Mode Offline)'), findsNothing);

      // Switch to sign up tab
      await tester.tap(find.text('Daftar Baru'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Akun Pasien'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
      expect(find.text('Daftar sebagai Pasien'), findsOneWidget);
    });

    testWidgets('renders invitation-only physiotherapist login',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(role: AuthRole.physiotherapist),
        ),
      );

      expect(find.text('Portal Fisioterapis'), findsOneWidget);
      expect(find.text('Masuk Portal Klinisi'), findsNWidgets(2));
      expect(find.text('Email Klinis'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Lanjutkan sebagai Tamu (Mode Offline)'), findsNothing);

      expect(find.text('Daftar Baru'), findsNothing);
      expect(find.textContaining('invitation'), findsOneWidget);
      expect(find.text('Registrasi Fisioterapis'), findsNothing);
    });

    testWidgets('validates required fields on submit', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(role: AuthRole.patient, initialSignup: true),
        ),
      );

      final submitFinder = find.text('Daftar sebagai Pasien');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Nama lengkap minimal 2 karakter.'), findsOneWidget);
      expect(find.text('Email tidak boleh kosong.'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong.'), findsOneWidget);
    });

    testWidgets('validates matching password on signup', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(role: AuthRole.patient, initialSignup: true),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'john@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.enterText(find.byType(TextFormField).at(3), 'mismatched123');

      final submitFinder = find.text('Daftar sebagai Pasien');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi kata sandi tidak cocok.'), findsOneWidget);
    });
  });
}
