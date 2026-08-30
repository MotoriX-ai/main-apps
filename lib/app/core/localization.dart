import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final motorixLocale = MotorixLocaleController();

String motorixText(BuildContext context,
        {required String id, required String en}) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : id;

class MotorixLocaleController extends ChangeNotifier {
  Locale _locale = const Locale('id');
  Locale get locale => _locale;

  Future<void> load() async {
    final value = (await SharedPreferences.getInstance())
        .getString('motorix.locale.global');
    _locale = Locale(value == 'en' ? 'en' : 'id');
  }

  Future<void> set(String value) async {
    _locale = Locale(value == 'en' ? 'en' : 'id');
    await (await SharedPreferences.getInstance())
        .setString('motorix.locale.global', _locale.languageCode);
    notifyListeners();
  }
}

class MotorixStrings {
  const MotorixStrings(this.languageCode);
  final String languageCode;

  static MotorixStrings of(BuildContext context) =>
      MotorixStrings(Localizations.localeOf(context).languageCode);

  String get(String key) =>
      (_values[languageCode] ?? _values['id']!)[key] ??
      _values['id']![key] ??
      key;

  static const _values = <String, Map<String, String>>{
    'id': {
      'today': 'Hari ini',
      'agenda': 'Agenda',
      'history': 'Riwayat',
      'progress': 'Progres',
      'settings': 'Pengaturan',
      'noAgenda': 'Tidak ada latihan terjadwal.',
      'offlineAgenda':
          'Menampilkan agenda tersimpan. Sinkronkan saat terhubung.',
      'startDay': 'Mulai sesi hari ini',
      'completed': 'Selesai',
      'skipped': 'Dilewati',
      'reschedule': 'Jadwal ulang',
      'skip': 'Lewati dengan alasan',
      'reason': 'Alasan',
      'cancel': 'Batal',
      'save': 'Simpan',
      'sets': 'set',
      'reps': 'repetisi',
      'seconds': 'detik',
      'rest': 'Istirahat',
      'next': 'Lanjut',
      'sessionSaved': 'Sesi tersimpan dan akan disinkronkan.',
      'sessionSynced': 'Sesi selesai dan sudah tersinkron.',
      'language': 'Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'controlledValidation':
          'Build validasi terkendali — bukan untuk penggunaan klinis umum.',
      'nonDiagnostic':
          'Motorix tidak membuat diagnosis atau mengubah terapi secara otomatis.',
      'sessionComplete': 'Sesi hari ini selesai',
      'done': 'Selesai',
      'syncNow': 'Sinkronkan sekarang',
      'pendingSync': 'sesi menunggu sinkronisasi',
      'logout': 'Keluar',
      'notifications': 'Notifikasi',
      'noNotifications': 'Belum ada notifikasi.',
      'rehabReminder': 'Pengingat rehabilitasi',
      'enableWebPush': 'Aktifkan web push',
      'webPushEnabled': 'Web push aktif.',
      'historyEmpty': 'Belum ada riwayat sesi.',
      'last28Days': '28 hari terakhir',
      'form': 'Ketepatan gerakan',
      'rom': 'Rentang gerak',
      'stability': 'Stabilitas',
    },
    'en': {
      'today': 'Today',
      'agenda': 'Agenda',
      'history': 'History',
      'progress': 'Progress',
      'settings': 'Settings',
      'noAgenda': 'No rehabilitation sessions scheduled.',
      'offlineAgenda': 'Showing saved agenda. Sync when connected.',
      'startDay': 'Start today’s session',
      'completed': 'Completed',
      'skipped': 'Skipped',
      'reschedule': 'Reschedule',
      'skip': 'Skip with reason',
      'reason': 'Reason',
      'cancel': 'Cancel',
      'save': 'Save',
      'sets': 'sets',
      'reps': 'repetitions',
      'seconds': 'seconds',
      'rest': 'Rest',
      'next': 'Continue',
      'sessionSaved': 'Session saved and queued for synchronization.',
      'sessionSynced': 'Session completed and synchronized.',
      'language': 'Language',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'controlledValidation':
          'Controlled-validation build — not for general clinical use.',
      'nonDiagnostic':
          'Motorix does not diagnose or change treatment automatically.',
      'sessionComplete': "Today's session is complete",
      'done': 'Done',
      'syncNow': 'Sync now',
      'pendingSync': 'sessions awaiting synchronization',
      'logout': 'Sign out',
      'notifications': 'Notifications',
      'noNotifications': 'No notifications yet.',
      'rehabReminder': 'Rehabilitation reminder',
      'enableWebPush': 'Enable web push',
      'webPushEnabled': 'Web push enabled.',
      'historyEmpty': 'No session history yet.',
      'last28Days': 'Last 28 days',
      'form': 'Movement form',
      'rom': 'Range of motion',
      'stability': 'Stability',
    },
  };
}
