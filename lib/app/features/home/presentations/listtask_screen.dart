import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/features/home/presentations/patient_dashboard_screen.dart';

/// Backward-compatible entry point for older navigation links.
class ListTaskScreen extends StatelessWidget {
  const ListTaskScreen({super.key});

  @override
  Widget build(BuildContext context) => const PatientDashboardScreen();
}
