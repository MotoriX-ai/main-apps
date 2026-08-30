import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/localization.dart';
import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/clinic/models/clinical_models.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

String _t(BuildContext context, String id, String en) =>
    motorixText(context, id: id, en: en);

class ClinicianPatientsScreen extends StatefulWidget {
  const ClinicianPatientsScreen({super.key});
  @override
  State<ClinicianPatientsScreen> createState() =>
      _ClinicianPatientsScreenState();
}

class _ClinicianPatientsScreenState extends State<ClinicianPatientsScreen> {
  final client = PipelineClient();
  List<ClinicianPatient>? patients;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await client.getClinicianPatients();
      if (mounted) setState(() => patients = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(_t(context, 'Pasien care team', 'Care team patients'))),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const _ClinicalBoundary(),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red))
            else if (patients == null)
              const Center(child: CircularProgressIndicator())
            else if (patients!.isEmpty)
              Text(_t(context, 'Belum ada pasien dalam care team Anda.',
                  'There are no patients in your care team yet.'))
            else
              for (final patient in patients!)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.lightGreen,
                      child: Icon(Icons.person, color: AppColors.green),
                    ),
                    title: Text(patient.displayName),
                    subtitle: Text(
                        '${patient.locale.toUpperCase()} · ${patient.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PatientProgressScreen(patient: patient),
                    )),
                  ),
                ),
          ]),
        ),
      );
}

class PatientProgressScreen extends StatefulWidget {
  const PatientProgressScreen({super.key, required this.patient});
  final ClinicianPatient patient;
  @override
  State<PatientProgressScreen> createState() => _PatientProgressScreenState();
}

class _PatientProgressScreenState extends State<PatientProgressScreen> {
  final client = PipelineClient();
  List<SessionHistoryItem>? history;
  List<CatalogExercise>? templates;
  List<Map<String, dynamic>>? plans;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        client.getPatientProgress(widget.patient.id),
        client.getMyTemplates(),
        client.getPatientPrescriptions(widget.patient.id),
      ]);
      if (mounted) {
        setState(() {
          history = values[0] as List<SessionHistoryItem>;
          templates = values[1] as List<CatalogExercise>;
          plans = values[2] as List<Map<String, dynamic>>;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _newPlan() async {
    final available = templates ?? const <CatalogExercise>[];
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t(context, 'Publikasikan gerakan terlebih dahulu.',
              'Publish an exercise first.'))));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PrescriptionEditorScreen(
        patient: widget.patient,
        templates: available,
        client: client,
      ),
    ));
    if (saved == true) await _load();
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final available = templates ?? const <CatalogExercise>[];
    if (!available.any((item) => item.id == plan['template_id']?.toString())) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
            context,
            'Hanya pembuat program atau admin klinik yang dapat mengedit program ini.',
            'Only the plan creator or a clinic administrator can edit this plan.')),
      ));
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PrescriptionEditorScreen(
        patient: widget.patient,
        templates: available,
        client: client,
        existing: plan,
      ),
    ));
    if (saved == true) await _load();
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        history?.where((item) => item.status == 'completed').toList() ??
            const [];
    final latest = completed.isEmpty ? null : completed.first;
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.displayName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newPlan,
        icon: const Icon(Icons.add_task),
        label: Text(_t(context, 'Buat program', 'Create plan')),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const _ClinicalBoundary(),
        if (latest != null) ...[
          const SizedBox(height: 16),
          Card(
            color: AppColors.lightGreen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _t(context, 'Saran progresi — wajib review klinisi',
                            'Progression suggestion — clinician review required'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(latest.totalScore >= 85
                        ? _t(
                            context,
                            'Kualitas gerak terakhir konsisten. Evaluasi langsung pasien sebelum menaikkan target.',
                            'Recent movement quality is consistent. Assess the patient directly before increasing targets.')
                        : _t(
                            context,
                            'Pertahankan target dan tinjau komponen skor terendah. Sistem tidak mengubah resep otomatis.',
                            'Keep the current targets and review the lowest score component. The system never changes a prescription automatically.')),
                  ]),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(_t(context, 'Program aktif', 'Active plans'),
            style: Theme.of(context).textTheme.titleLarge),
        if (plans == null)
          const LinearProgressIndicator()
        else if (plans!.isEmpty)
          Text(_t(context, 'Belum ada program.', 'No plans yet.'))
        else
          for (final plan in plans!)
            Card(
              child: ListTile(
                title: Text(
                    (plan['template'] as Map?)?['exercise_name']?.toString() ??
                        'Program Motorix'),
                subtitle: Text(
                    '${plan['status']} · ${plan['mode']} · ${plan['target_sets']} set'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _editPlan(plan),
              ),
            ),
        const SizedBox(height: 18),
        Text(_t(context, 'Riwayat sesi', 'Session history'),
            style: Theme.of(context).textTheme.titleLarge),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red))
        else if (history == null)
          const Center(child: CircularProgressIndicator())
        else if (history!.isEmpty)
          Text(_t(context, 'Pasien belum memiliki riwayat sesi.',
              'This patient has no session history yet.'))
        else
          for (final item in history!)
            ListTile(
              title: Text(item.exerciseName),
              subtitle: Text('${isoDate(item.scheduledFor)} · ${item.status}'),
              trailing: item.status == 'completed'
                  ? Text(item.totalScore.toStringAsFixed(0),
                      style: const TextStyle(
                          color: AppColors.green, fontWeight: FontWeight.w800))
                  : null,
            ),
      ]),
    );
  }
}

class PrescriptionEditorScreen extends StatefulWidget {
  const PrescriptionEditorScreen({
    super.key,
    required this.patient,
    required this.templates,
    required this.client,
    this.existing,
  });
  final ClinicianPatient patient;
  final List<CatalogExercise> templates;
  final PipelineClient client;
  final Map<String, dynamic>? existing;
  @override
  State<PrescriptionEditorScreen> createState() =>
      _PrescriptionEditorScreenState();
}

class _PrescriptionEditorScreenState extends State<PrescriptionEditorScreen> {
  late CatalogExercise selected;
  final weekdays = <int>{};
  late final TextEditingController sets;
  late final TextEditingController reps;
  late final TextEditingController duration;
  late final TextEditingController rest;
  late final TextEditingController reminder;
  late DateTime starts;
  DateTime? ends;
  late TimeOfDay time;
  bool saving = false;
  late String mode;
  late String status;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    selected = widget.templates.firstWhere(
      (item) => item.id == existing?['template_id']?.toString(),
      orElse: () => widget.templates.first,
    );
    weekdays.addAll((existing?['weekdays'] as List? ?? const [1, 3, 5])
        .map((value) => (value as num).toInt()));
    sets = TextEditingController(text: '${existing?['target_sets'] ?? 2}');
    reps = TextEditingController(text: '${existing?['target_reps'] ?? 10}');
    duration = TextEditingController(
        text: '${existing?['target_duration_sec'] ?? 30}');
    rest = TextEditingController(text: '${existing?['rest_sec'] ?? 60}');
    reminder = TextEditingController(
        text: '${existing?['reminder_minutes_before'] ?? 30}');
    starts = DateTime.tryParse(existing?['active_from']?.toString() ?? '') ??
        DateTime.now();
    ends = DateTime.tryParse(existing?['active_until']?.toString() ?? '');
    final preferred = existing?['preferred_time']?.toString().split(':') ??
        const ['08', '00'];
    time = TimeOfDay(
      hour: int.tryParse(preferred.first) ?? 8,
      minute: int.tryParse(preferred.elementAtOrNull(1) ?? '') ?? 0,
    );
    mode = existing?['mode']?.toString() ?? 'reps';
    status = existing?['status']?.toString() ?? 'active';
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final targetSets = int.tryParse(sets.text);
      final targetReps = int.tryParse(reps.text);
      final targetDuration = int.tryParse(duration.text);
      final restSeconds = int.tryParse(rest.text);
      final reminderMinutes = int.tryParse(reminder.text);
      if (targetSets == null ||
          targetSets < 1 ||
          restSeconds == null ||
          restSeconds < 0 ||
          reminderMinutes == null ||
          reminderMinutes < 0 ||
          (mode == 'reps' && (targetReps == null || targetReps < 1)) ||
          (mode == 'duration' &&
              (targetDuration == null || targetDuration < 1))) {
        throw FormatException(_t(
            context,
            'Periksa kembali target angka program.',
            'Check the numeric plan targets.'));
      }
      final payload = {
        'patient_id': widget.patient.id,
        'template_id': selected.id,
        'template_version': selected.currentVersion,
        'active_from': isoDate(starts),
        'active_until': ends == null ? null : isoDate(ends!),
        'weekdays': weekdays.toList()..sort(),
        'preferred_time':
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        'timezone': 'Asia/Jakarta',
        'reschedule_window_days': 1,
        'sort_order': 0,
        'mode': mode,
        'target_sets': targetSets,
        'target_reps': mode == 'reps' ? targetReps : null,
        'target_duration_sec': mode == 'duration' ? targetDuration : null,
        'rest_sec': restSeconds,
        'reminder_enabled': true,
        'reminder_minutes_before': reminderMinutes,
        'status': status,
      };
      if (widget.existing == null) {
        payload.remove('status');
        await widget.client.createPrescription(payload);
      } else {
        await widget.client
            .updatePrescription(widget.existing!['id'].toString(), payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    sets.dispose();
    reps.dispose();
    duration.dispose();
    rest.dispose();
    reminder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                _t(context, 'Program rehabilitasi', 'Rehabilitation plan'))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          DropdownButtonFormField<CatalogExercise>(
            initialValue: selected,
            decoration: InputDecoration(
                labelText:
                    _t(context, 'Gerakan terpublikasi', 'Published exercise')),
            items: [
              for (final item in widget.templates)
                DropdownMenuItem(value: item, child: Text(item.name))
            ],
            onChanged: (value) => setState(() => selected = value ?? selected),
          ),
          const SizedBox(height: 16),
          if (widget.existing != null)
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: InputDecoration(
                  labelText: _t(context, 'Status program', 'Plan status')),
              items: [
                DropdownMenuItem(
                    value: 'active',
                    child: Text(_t(context, 'Aktif', 'Active'))),
                DropdownMenuItem(
                    value: 'paused',
                    child: Text(_t(context, 'Dijeda', 'Paused'))),
                DropdownMenuItem(
                    value: 'completed',
                    child: Text(_t(context, 'Selesai', 'Completed'))),
                DropdownMenuItem(
                    value: 'revoked',
                    child: Text(_t(context, 'Dicabut', 'Revoked'))),
              ],
              onChanged: (value) => setState(() => status = value ?? status),
            ),
          if (widget.existing != null) const SizedBox(height: 16),
          Text(_t(context, 'Hari latihan', 'Exercise days'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Wrap(spacing: 6, children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: Text((Localizations.localeOf(context).languageCode ==
                        'en'
                    ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    : const [
                        'Sen',
                        'Sel',
                        'Rab',
                        'Kam',
                        'Jum',
                        'Sab',
                        'Min'
                      ])[day - 1]),
                selected: weekdays.contains(day),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    weekdays.add(day);
                  } else if (weekdays.length > 1) {
                    weekdays.remove(day);
                  }
                }),
              ),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'reps',
                  label: Text(_t(context, 'Repetisi', 'Repetitions'))),
              ButtonSegment(
                  value: 'duration',
                  label: Text(_t(context, 'Tahan waktu', 'Timed hold'))),
            ],
            selected: {mode},
            onSelectionChanged: (value) => setState(() => mode = value.first),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: sets,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: _t(context, 'Set', 'Sets')))),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
                    controller: mode == 'reps' ? reps : duration,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: mode == 'reps'
                            ? _t(context, 'Repetisi', 'Repetitions')
                            : _t(context, 'Durasi tahan (detik)',
                                'Hold duration (seconds)')))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: TextFormField(
                    controller: rest,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: _t(
                            context, 'Istirahat (detik)', 'Rest (seconds)')))),
            const SizedBox(width: 8),
            Expanded(
                child: TextFormField(
                    controller: reminder,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: _t(context, 'Pengingat (menit)',
                            'Reminder (minutes)')))),
          ]),
          const SizedBox(height: 16),
          ListTile(
            title: Text(_t(context, 'Tanggal mulai', 'Start date')),
            trailing: Text(isoDate(starts)),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: starts,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (value != null) setState(() => starts = value);
            },
          ),
          ListTile(
            title: Text(_t(context, 'Tanggal akhir', 'End date')),
            subtitle: Text(_t(context, 'Opsional', 'Optional')),
            trailing: Text(ends == null
                ? _t(context, 'Tanpa batas', 'No end date')
                : isoDate(ends!)),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate: ends ?? starts.add(const Duration(days: 28)),
                firstDate: starts,
                lastDate: starts.add(const Duration(days: 730)),
              );
              if (value != null) setState(() => ends = value);
            },
          ),
          ListTile(
            title: Text(_t(context, 'Waktu latihan', 'Exercise time')),
            trailing: Text(time.format(context)),
            onTap: () async {
              final value =
                  await showTimePicker(context: context, initialTime: time);
              if (value != null) setState(() => time = value);
            },
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: saving ? null : _save,
              child: Text(_t(context, 'Simpan program', 'Save plan'))),
        ]),
      );
}

class _ClinicalBoundary extends StatelessWidget {
  const _ClinicalBoundary();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(12)),
        child: Text(_t(
            context,
            'Build validasi terkendali. Semua perubahan terapi memerlukan keputusan klinisi.',
            'Controlled-validation build. Every treatment change requires a clinician decision.')),
      );
}
