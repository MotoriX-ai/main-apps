import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';

class ClinicalCache {
  ClinicalCache(this.userId);

  final String userId;
  String get _agendaKey => 'motorix.agenda.$userId';
  String get _pendingKey => 'motorix.pending-sessions.$userId';
  String get _localeKey => 'motorix.locale.$userId';

  Future<void> saveAgenda(List<AgendaEntry> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _agendaKey, jsonEncode(items.map((item) => item.toJson()).toList()));
  }

  Future<List<AgendaEntry>> loadAgenda() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_agendaKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) =>
              AgendaEntry.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<PendingSession>> pendingSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingKey);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) =>
              PendingSession.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> enqueue(PendingSession session) async {
    final pending = await pendingSessions();
    final byId = {for (final item in pending) item.clientSessionId: item};
    byId[session.clientSessionId] = session;
    await _savePending(byId.values.toList());
  }

  Future<void> acknowledge(String clientSessionId) async {
    final pending = await pendingSessions();
    await _savePending(pending
        .where((item) => item.clientSessionId != clientSessionId)
        .toList());
  }

  Future<void> _savePending(List<PendingSession> pending) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _pendingKey, jsonEncode(pending.map((item) => item.toJson()).toList()));
  }

  Future<String> locale() async =>
      (await SharedPreferences.getInstance()).getString(_localeKey) ?? 'id';

  Future<void> setLocale(String value) async =>
      (await SharedPreferences.getInstance())
          .setString(_localeKey, value == 'en' ? 'en' : 'id');
}
