import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:motorix_phase2/motorix_phase2.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/auth/presentations/role_selection_screen.dart';
import 'package:motorix_phase2/app/features/auth/services/auth_service.dart';
import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/clinical_cache.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';
import 'package:motorix_phase2/app/features/home/services/notification_service.dart';
import 'package:motorix_phase2/app/features/home/services/web_push_bridge.dart';

import 'guided_day_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  late final PipelineClient client;
  late final ClinicalCache cache;
  List<AgendaEntry> agenda = const [];
  List<SessionHistoryItem> history = const [];
  int pendingCount = 0;
  int tab = 0;
  bool loading = true;
  bool showingOffline = false;
  String? error;

  @override
  void initState() {
    super.initState();
    client = PipelineClient();
    cache = ClinicalCache(AuthService.instance.user?.id ?? 'signed-out');
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => error = null);
    final now = DateTime.now();
    try {
      final results = await Future.wait([
        client.getAgenda(now.subtract(const Duration(days: 35)),
            now.add(const Duration(days: 14))),
        client.getHistory(limit: 180),
      ]);
      agenda = results[0] as List<AgendaEntry>;
      history = results[1] as List<SessionHistoryItem>;
      await cache.saveAgenda(agenda);
      await MotorixNotifications.instance.scheduleAgenda(
        agenda,
        languageCode: motorixLocale.locale.languageCode,
      );
      showingOffline = false;
      await _flushPending();
    } catch (exception) {
      agenda = await cache.loadAgenda();
      showingOffline = agenda.isNotEmpty;
      error = agenda.isEmpty ? exception.toString() : null;
    }
    pendingCount = (await cache.pendingSessions()).length;
    if (mounted) setState(() => loading = false);
  }

  Future<void> _flushPending() async {
    final pending = await cache.pendingSessions();
    for (final session in pending) {
      try {
        await client.syncSession(session);
        await cache.acknowledge(session.clientSessionId);
      } catch (_) {
        break;
      }
    }
    pendingCount = (await cache.pendingSessions()).length;
    if (mounted) setState(() {});
  }

  List<AgendaEntry> get _today {
    final today = isoDate(DateTime.now());
    return agenda.where((item) => isoDate(item.scheduledFor) == today).toList()
      ..sort((a, b) => a.preferredTime.compareTo(b.preferredTime));
  }

  Future<void> _startToday() async {
    final items =
        _today.where((item) => !item.completed && !item.skipped).toList();
    if (items.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          GuidedDayScreen(entries: items, cache: cache, client: client),
    ));
    if (changed == true) await _load();
  }

  Future<String?> _reasonDialog(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: InputDecoration(
              labelText: MotorixStrings.of(context).get('reason')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MotorixStrings.of(context).get('cancel'))),
          FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.length >= 2) Navigator.pop(context, reason);
              },
              child: Text(MotorixStrings.of(context).get('save'))),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _reschedule(AgendaEntry entry) async {
    final strings = MotorixStrings.of(context);
    final selected = await showDatePicker(
      context: context,
      initialDate: entry.scheduledFor,
      firstDate: entry.scheduledFor
          .subtract(Duration(days: entry.rescheduleWindowDays)),
      lastDate:
          entry.scheduledFor.add(Duration(days: entry.rescheduleWindowDays)),
    );
    if (selected == null || isoDate(selected) == isoDate(entry.scheduledFor)) {
      return;
    }
    final reason = await _reasonDialog(strings.get('reschedule'));
    if (reason == null) return;
    try {
      await client.reschedule(
        prescriptionId: entry.prescriptionId,
        originalDate: entry.scheduledFor,
        scheduledDate: selected,
        reason: reason,
      );
      await _load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  Future<void> _skip(AgendaEntry entry) async {
    final reason = await _reasonDialog(MotorixStrings.of(context).get('skip'));
    if (reason == null) return;
    final now = DateTime.now().toUtc();
    final pending = PendingSession({
      'client_session_id': newClientSessionId(),
      'prescription_id': entry.prescriptionId,
      'template_version': entry.templateVersion,
      'scheduled_for': isoDate(entry.scheduledFor),
      'completed_at': now.toIso8601String(),
      'status': 'skipped',
      'skip_reason': reason,
      'app_version': await motorixAppVersion(),
      'device_platform': 'flutter',
      'uploaded_offline': false,
      'summary': <String, dynamic>{},
      'sets': <Map<String, dynamic>>[],
    });
    await cache.enqueue(pending);
    await _flushPending();
    await _load();
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  Future<void> _enableWebPush() async {
    const publicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');
    if (publicKey.isEmpty) {
      setState(() => error = motorixText(context,
          id: 'VAPID_PUBLIC_KEY belum dikonfigurasi.',
          en: 'VAPID_PUBLIC_KEY is not configured.'));
      return;
    }
    try {
      await client.registerPushSubscription(await subscribeWebPush(publicKey));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(MotorixStrings.of(context).get('webPushEnabled'))),
        );
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _showNotifications() async {
    try {
      final items = await client.getNotifications();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(MotorixStrings.of(context).get('notifications'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(MotorixStrings.of(context).get('noNotifications'))
              else
                for (final item in items)
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title:
                        Text(MotorixStrings.of(context).get('rehabReminder')),
                    subtitle: Text(item['scheduled_for']?.toString() ?? ''),
                    trailing: Text(item['status']?.toString() ?? ''),
                  ),
            ],
          ),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.toString())));
      }
    }
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = MotorixStrings.of(context);
    final titles = [
      strings.get('agenda'),
      strings.get('history'),
      strings.get('progress'),
      strings.get('settings'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          IconButton(
            onPressed: _showNotifications,
            tooltip: strings.get('notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          Stack(children: [
            IconButton(onPressed: _flushPending, icon: const Icon(Icons.sync)),
            if (pendingCount > 0)
              Positioned(
                right: 7,
                top: 7,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.red,
                  child: Text('$pendingCount',
                      style: const TextStyle(fontSize: 9, color: Colors.white)),
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child:
                Image.asset('assets/images/motorix_logo_large.png', width: 30),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: IndexedStack(index: tab, children: [
                _AgendaView(
                  items: _today,
                  showingOffline: showingOffline,
                  error: error,
                  onStart: _startToday,
                  onReschedule: _reschedule,
                  onSkip: _skip,
                ),
                _HistoryView(items: history),
                _ProgressView(items: history),
                _SettingsView(
                  pendingCount: pendingCount,
                  onSync: _flushPending,
                  onSignOut: _signOut,
                  onEnableWebPush: kIsWeb ? _enableWebPush : null,
                ),
              ]),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              label: strings.get('agenda')),
          NavigationDestination(
              icon: const Icon(Icons.history), label: strings.get('history')),
          NavigationDestination(
              icon: const Icon(Icons.insights_outlined),
              label: strings.get('progress')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              label: strings.get('settings')),
        ],
      ),
    );
  }
}

class _AgendaView extends StatelessWidget {
  const _AgendaView({
    required this.items,
    required this.showingOffline,
    required this.error,
    required this.onStart,
    required this.onReschedule,
    required this.onSkip,
  });
  final List<AgendaEntry> items;
  final bool showingOffline;
  final String? error;
  final VoidCallback onStart;
  final ValueChanged<AgendaEntry> onReschedule;
  final ValueChanged<AgendaEntry> onSkip;

  @override
  Widget build(BuildContext context) {
    final strings = MotorixStrings.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      const _ValidationBanner(),
      if (showingOffline) ...[
        const SizedBox(height: 12),
        Text(strings.get('offlineAgenda'),
            style: const TextStyle(color: Colors.orange)),
      ],
      const SizedBox(height: 20),
      Text(strings.get('today'),
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red))
      else if (items.isEmpty)
        _EmptyState(text: strings.get('noAgenda'))
      else
        for (final entry in items)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(entry.exerciseName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (entry.completed)
                        Chip(label: Text(strings.get('completed')))
                      else if (entry.skipped)
                        Chip(label: Text(strings.get('skipped'))),
                    ]),
                    Text(
                        '${entry.preferredTime.substring(0, 5)} · ${entry.targetSets} ${strings.get('sets')} · '
                        '${entry.recipe.mode == ExerciseMode.duration ? '${entry.recipe.targetDurationSeconds} ${strings.get('seconds')}' : '${entry.recipe.targetReps} ${strings.get('reps')}'}'),
                    if (!entry.completed && !entry.skipped)
                      Wrap(spacing: 8, children: [
                        TextButton(
                            onPressed: () => onReschedule(entry),
                            child: Text(strings.get('reschedule'))),
                        TextButton(
                            onPressed: () => onSkip(entry),
                            child: Text(strings.get('skip'))),
                      ]),
                  ]),
            ),
          ),
      if (items.any((item) => !item.completed && !item.skipped)) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onStart,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(strings.get('startDay')),
        ),
      ],
    ]);
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.items});
  final List<SessionHistoryItem> items;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (items.isEmpty)
            _EmptyState(text: MotorixStrings.of(context).get('historyEmpty'))
          else
            for (final item in items)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.status == 'completed'
                      ? AppColors.lightGreen
                      : Colors.orange.shade100,
                  child: Icon(item.status == 'completed'
                      ? Icons.check
                      : Icons.event_busy),
                ),
                title: Text(item.exerciseName),
                subtitle:
                    Text('${isoDate(item.scheduledFor)} · ${item.status}'),
                trailing: item.status == 'completed'
                    ? Text(item.totalScore.toStringAsFixed(0),
                        style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 20))
                    : null,
              ),
        ],
      );
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.items});
  final List<SessionHistoryItem> items;

  @override
  Widget build(BuildContext context) {
    final completed =
        items.where((item) => item.status == 'completed').toList();
    double average(double Function(SessionHistoryItem) select) =>
        completed.isEmpty
            ? 0
            : completed.map(select).reduce((a, b) => a + b) / completed.length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(MotorixStrings.of(context).get('last28Days'),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 14),
      _AdherenceHeatmap(items: items),
      const SizedBox(height: 28),
      _ScoreBar(
          label: MotorixStrings.of(context).get('form'),
          value: average((item) => item.formScore)),
      _ScoreBar(
          label: MotorixStrings.of(context).get('rom'),
          value: average((item) => item.romScore)),
      _ScoreBar(label: 'Tempo', value: average((item) => item.tempoScore)),
      _ScoreBar(
          label: MotorixStrings.of(context).get('stability'),
          value: average((item) => item.stabilityScore)),
    ]);
  }
}

class _AdherenceHeatmap extends StatelessWidget {
  const _AdherenceHeatmap({required this.items});
  final List<SessionHistoryItem> items;
  @override
  Widget build(BuildContext context) {
    final completed = items
        .where((item) => item.status == 'completed')
        .map((item) => isoDate(item.scheduledFor))
        .toSet();
    final today = DateTime.now();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(28, (index) {
        final date = today.subtract(Duration(days: 27 - index));
        final done = completed.contains(isoDate(date));
        return Tooltip(
          message: isoDate(date),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done ? AppColors.green : AppColors.lightGreen,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text(value.toStringAsFixed(0))
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (value / 100).clamp(0, 1),
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
        ]),
      );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView(
      {required this.pendingCount,
      required this.onSync,
      required this.onSignOut,
      this.onEnableWebPush});
  final int pendingCount;
  final VoidCallback onSync;
  final VoidCallback onSignOut;
  final VoidCallback? onEnableWebPush;
  @override
  Widget build(BuildContext context) {
    final strings = MotorixStrings.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      const _ValidationBanner(),
      const SizedBox(height: 20),
      Text(strings.get('language'),
          style: Theme.of(context).textTheme.titleLarge),
      RadioGroup<String>(
        groupValue: Localizations.localeOf(context).languageCode,
        onChanged: (value) => motorixLocale.set(value ?? 'id'),
        child: Column(children: [
          RadioListTile(value: 'id', title: Text(strings.get('indonesian'))),
          RadioListTile(value: 'en', title: Text(strings.get('english'))),
        ]),
      ),
      ListTile(
        leading: const Icon(Icons.sync),
        title: Text(strings.get('syncNow')),
        subtitle: Text('$pendingCount ${strings.get('pendingSync')}'),
        onTap: onSync,
      ),
      if (onEnableWebPush != null)
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(strings.get('enableWebPush')),
          onTap: onEnableWebPush,
        ),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(strings.get('logout')),
        onTap: onSignOut,
      ),
    ]);
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.science_outlined, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(MotorixStrings.of(context).get('controlledValidation'))),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const Icon(Icons.event_available_outlined,
              size: 52, color: AppColors.green),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ]),
      );
}
