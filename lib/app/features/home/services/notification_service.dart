import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';

class MotorixNotifications {
  MotorixNotifications._();

  static final instance = MotorixNotifications._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> initialize() async {
    if (_ready || kIsWeb) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> scheduleAgenda(
    Iterable<AgendaEntry> agenda, {
    required String languageCode,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancelAll();
    for (final entry in agenda.where((item) =>
        item.reminderEnabled &&
        item.sessionStatus == null &&
        item.scheduledFor
            .isAfter(DateTime.now().subtract(const Duration(days: 1))))) {
      final location = tz.getLocation(entry.timezone);
      final local = tz.TZDateTime(
        location,
        entry.scheduledFor.year,
        entry.scheduledFor.month,
        entry.scheduledFor.day,
        entry.preferredHour,
        entry.preferredMinute,
      ).subtract(Duration(minutes: entry.reminderMinutesBefore));
      if (!local.isAfter(tz.TZDateTime.now(location))) continue;
      await _plugin.zonedSchedule(
        entry.prescriptionId.hashCode ^ entry.scheduledFor.hashCode,
        languageCode == 'en'
            ? 'Motorix rehabilitation'
            : 'Rehabilitasi Motorix',
        languageCode == 'en'
            ? '${entry.exerciseName} is scheduled soon.'
            : '${entry.exerciseName} akan segera dimulai.',
        local,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'motorix_rehabilitation',
            'Motorix rehabilitation',
            channelDescription: 'Clinician-prescribed rehabilitation reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> restComplete() async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.show(
      2147483646,
      'Motorix',
      'Waktu istirahat selesai.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'motorix_rest',
          'Motorix rest timer',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
