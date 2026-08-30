import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:motorix_phase2/app/motorix_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await motorixLocale.load();
  runApp(const MotorixApp());
}
