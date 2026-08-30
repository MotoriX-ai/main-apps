import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motorix_phase2/motorix_phase2.dart';
import 'package:video_player/video_player.dart';

import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';
import 'package:motorix_phase2/app/features/clinic/models/pipeline_models.dart';
import 'package:motorix_phase2/app/features/clinic/services/pipeline_client.dart';

String _focusLabel(Object? focus, Object? side) {
  const focuses = {
    'auto': 'Otomatis',
    'full_body': 'Seluruh tubuh',
    'head_neck': 'Kepala & leher',
    'shoulder': 'Bahu',
    'arm_elbow': 'Lengan & siku',
    'wrist_hand': 'Tangan',
    'fingers': 'Jari-jari',
    'trunk': 'Badan',
    'hip_thigh': 'Panggul & paha',
    'knee': 'Lutut',
    'ankle_foot': 'Kaki',
    'leg': 'Seluruh tungkai',
  };
  const sides = {
    'auto': 'sisi otomatis',
    'left': 'kiri',
    'right': 'kanan',
    'bilateral': 'keduanya',
  };
  return '${focuses[focus] ?? 'Otomatis'} · ${sides[side] ?? 'sisi otomatis'}';
}

bool _isFingerOnlyRecipe(
    Map<String, dynamic> capture, Map<String, dynamic> joints) {
  final primary = List<String>.from(joints['primary'] as List? ?? const []);
  return capture['movement_focus'] == 'fingers' &&
      primary.isNotEmpty &&
      primary.every((name) =>
          name.startsWith('curl_') || name.startsWith('hand_spread_'));
}

bool _isIrrelevantPoseError(String message, Map<String, dynamic> capture,
        Map<String, dynamic> joints) =>
    _isFingerOnlyRecipe(capture, joints) &&
    (message.startsWith('Confidence deteksi rendah') ||
        message.startsWith('Subjek tidak terdeteksi pada'));

const _fingerPoseWarning =
    'Confidence Pose tubuh rendah; ini tidak menghalangi validasi jari '
    'karena recipe memakai Hand Landmarker 21 titik.';

class RecipeReviewScreen extends StatefulWidget {
  const RecipeReviewScreen(
      {super.key, required this.jobId, required this.client});
  final String jobId;
  final PipelineClient client;

  @override
  State<RecipeReviewScreen> createState() => _RecipeReviewScreenState();
}

class _RecipeReviewScreenState extends State<RecipeReviewScreen> {
  Map<String, dynamic>? recipe;
  PipelineJob? job;
  String? error;
  bool publishing = false;
  bool loading = false;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    refreshTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (loading || publishing) return;
    loading = true;
    try {
      final values = await Future.wait<Object>([
        widget.client.getJob(widget.jobId),
        widget.client.getRecipe(widget.jobId),
      ]);
      if (mounted) {
        setState(() {
          job = values[0] as PipelineJob;
          recipe = values[1] as Map<String, dynamic>;
          error = null;
        });
        if (job?.status == 'published') refreshTimer?.cancel();
      }
    } catch (exception) {
      if (mounted && !silent) {
        setState(
            () => error = exception.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      publishing = true;
      error = null;
    });
    try {
      final value = await widget.client.publish(widget.jobId);
      final publishedJob = await widget.client.getJob(widget.jobId);
      if (!mounted) return;
      setState(() {
        recipe = value;
        job = publishedJob;
        publishing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recipe dipublikasikan dan siap dipakai pasien.')));
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = exception.toString().replaceFirst('Bad state: ', '');
          publishing = false;
        });
        // Ambil ulang recipe agar pesan dari percobaan lama tidak tertinggal
        // setelah backend menurunkan quality issue menjadi warning.
        await _load(silent: true);
      }
    }
  }

  Future<void> _editParameters() async {
    final currentRecipe = recipe;
    if (currentRecipe == null) return;
    final prescription =
        currentRecipe['prescription'] as Map<String, dynamic>? ?? {};
    final guidance = currentRecipe['guidance'] as Map<String, dynamic>? ?? {};

    final nameCtrl = TextEditingController(
        text: currentRecipe['exercise_name'] as String? ?? '');
    final repsCtrl =
        TextEditingController(text: '${prescription['target_reps'] ?? 12}');
    final setsCtrl =
        TextEditingController(text: '${prescription['sets'] ?? 3}');
    final restCtrl = TextEditingController(
        text: '${prescription['rest_between_sets_seconds'] ?? 60}');
    final cueCtrl =
        TextEditingController(text: guidance['cue'] as String? ?? '');
    final cautionCtrl =
        TextEditingController(text: guidance['caution'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Parameter Recipe',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nama Latihan', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Target Reps',
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Sets', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: restCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Istirahat (dtk)',
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cueCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Instruksi Suara (Cue)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cautionCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Catatan Keamanan (Caution)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff176b4b)),
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => error = null);
      try {
        final patch = <String, dynamic>{
          'exercise_name': nameCtrl.text.trim(),
          'prescription': {
            'target_reps': int.tryParse(repsCtrl.text.trim()) ?? 12,
            'sets': int.tryParse(setsCtrl.text.trim()) ?? 3,
            'rest_between_sets_seconds':
                int.tryParse(restCtrl.text.trim()) ?? 60,
          },
          'guidance': {
            'cue': cueCtrl.text.trim(),
            'caution': cautionCtrl.text.trim(),
          },
        };
        final updated = await widget.client.patchRecipe(widget.jobId, patch);
        if (!mounted) return;
        setState(() => recipe = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Parameter recipe berhasil diperbarui!')),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => error = e.toString().replaceFirst('Bad state: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = recipe;
    final currentJob = job;
    final currentError = error;
    if (data == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Tinjauan dokter')),
          body: Center(
              child: currentError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(currentError))));
    }
    final quality = data['quality'] as Map<String, dynamic>? ?? {};
    final timing = data['timing'] as Map<String, dynamic>? ?? {};
    final prescription = data['prescription'] as Map<String, dynamic>? ?? {};
    final capture = data['capture'] as Map<String, dynamic>? ?? {};
    final joints = data['joints'] as Map<String, dynamic>? ?? {};
    final phaseAnchors =
        timing['phase_anchors'] as Map<String, dynamic>? ?? const {};
    final directions = timing['direction'] as Map<String, dynamic>? ?? const {};
    final validationErrors =
        List<String>.from(quality['errors'] as List? ?? const []);
    final blockingErrors = validationErrors
        .where((message) => !_isIrrelevantPoseError(message, capture, joints))
        .toList();
    final poseWarnings = validationErrors
        .where((message) => _isIrrelevantPoseError(message, capture, joints))
        .map((_) => _fingerPoseWarning);
    final issues = <String>{
      ...blockingErrors,
      ...poseWarnings,
      ...List<String>.from(quality['warnings'] as List? ?? const []),
    }.toList();
    final rawStatus = quality['validation_status'] as String? ?? 'review';
    final effectiveStatus = rawStatus == 'rejected' && blockingErrors.isEmpty
        ? 'pending_review'
        : rawStatus;
    final approved = effectiveStatus == 'approved';
    final reviewed = quality['therapist_reviewed'] == true;
    final canPublish = effectiveStatus != 'rejected' && blockingErrors.isEmpty;

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Tinjauan dokter',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('TINJAUAN DOKTER',
                        style: TextStyle(
                            color: Color(0xff176b4b),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8)),
                    const SizedBox(height: 10),
                    Text(data['exercise_name'] as String? ?? 'Recipe latihan',
                        style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 40,
                            height: 1.05,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Chip(
                          backgroundColor: approved
                              ? const Color(0xffd9f2df)
                              : const Color(0xfffff5d9),
                          label: Text(effectiveStatus,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const Spacer(),
                        if (!reviewed)
                          OutlinedButton.icon(
                            onPressed: _editParameters,
                            icon: const Icon(Icons.tune_rounded, size: 16),
                            label: const Text('Edit Parameter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff176b4b),
                              side: const BorderSide(color: Color(0xff176b4b)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      _Metric(
                          label: 'Tempo',
                          value: '${timing['cycle_sec'] ?? '-'} dtk'),
                      _Metric(
                          label: 'Target',
                          value: '${prescription['target_reps'] ?? '-'} reps'),
                      _Metric(
                          label: 'Progresi',
                          value:
                              '${prescription['progression_factor'] ?? '-'}'),
                      _Metric(
                          label: 'Kamera',
                          value: '${capture['camera_view'] ?? '-'}'),
                      _Metric(
                          label: 'Fokus dokter',
                          value: _focusLabel(capture['movement_focus'],
                              capture['movement_side'])),
                    ]),
                    if (issues.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff5d9),
                          borderRadius: BorderRadius.circular(16),
                          border: const Border(
                              left: BorderSide(
                                  color: Color(0xffd0a22e), width: 4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pemeriksaan kualitas',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            for (final issue in issues)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text('• $issue',
                                    style: const TextStyle(height: 1.35)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ReviewQualityBars(quality: quality),
                    const SizedBox(height: 18),
                    _AnalysisPreviewCard(
                      jobId: widget.jobId,
                      client: widget.client,
                      hasGuide: job?.guideUrl != null,
                      hasOverlay: job?.previewUrl != null,
                    ),
                    if (phaseAnchors.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _PhaseTimelineCard(
                        anchors: phaseAnchors,
                        directions: directions,
                        confidence:
                            (quality['phase_confidence'] as num?)?.toDouble(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    _JointCard(
                        title: 'Sendi utama',
                        joints: List<String>.from(
                            joints['primary'] as List? ?? const []),
                        color: const Color(0xffd9f2df)),
                    const SizedBox(height: 12),
                    _JointCard(
                        title: 'Sendi penjaga',
                        joints: List<String>.from(
                            joints['guard'] as List? ?? const []),
                        color: const Color(0xfff4e4b9)),
                    if (reviewed && currentJob?.shareCode != null) ...[
                      const SizedBox(height: 18),
                      _ShareCodeCard(
                          code: currentJob?.shareCode ?? '', recipe: data),
                    ],
                    if (currentError != null) ...[
                      const SizedBox(height: 14),
                      Text(currentError,
                          style: const TextStyle(color: Color(0xff9f3229)))
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: canPublish && !reviewed && !publishing
                          ? _publish
                          : null,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffd9f26a),
                          foregroundColor: const Color(0xff1d321b)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Text(
                            reviewed
                                ? 'Sudah dipublikasikan'
                                : publishing
                                    ? 'Memublikasikan…'
                                    : 'Tinjau & publikasikan',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                        'Pastikan gerakan dan hasil analisis sudah sesuai sebelum recipe digunakan pasien.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xff66736d),
                            fontSize: 12,
                            height: 1.4)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

enum _QualityLevel { good, warning, poor, unavailable }

class _QualityMetricData {
  const _QualityMetricData(this.label, this.value, this.progress, this.level);

  final String label;
  final String value;
  final double? progress;
  final _QualityLevel level;
}

class ReviewQualityBars extends StatelessWidget {
  const ReviewQualityBars({super.key, required this.quality});

  final Map<String, dynamic> quality;

  num? _number(String key) => quality[key] is num ? quality[key] as num : null;

  _QualityMetricData _ratioMetric(
    String label,
    String key, {
    required double good,
    required double warning,
    bool inverse = false,
  }) {
    final raw = _number(key)?.toDouble();
    if (raw == null || !raw.isFinite) {
      return _QualityMetricData(label, '—', null, _QualityLevel.unavailable);
    }
    final shown = inverse ? 1 - raw : raw;
    final level = shown >= good
        ? _QualityLevel.good
        : shown >= warning
            ? _QualityLevel.warning
            : _QualityLevel.poor;
    return _QualityMetricData(
        label, '${(shown * 100).round()}%', shown.clamp(0, 1), level);
  }

  List<_QualityMetricData> get _metrics {
    final detected = _number('n_cycles_detected')?.toInt();
    final used = _number('n_cycles_used')?.toInt();
    final snr = _number('snr_primary')?.toDouble();
    return [
      _QualityMetricData(
        'Siklus terpakai',
        detected == null || used == null ? '—' : '$used / $detected',
        detected == null || detected <= 0 || used == null
            ? null
            : (used / detected).clamp(0, 1),
        used == null
            ? _QualityLevel.unavailable
            : used >= 4
                ? _QualityLevel.good
                : used >= 2
                    ? _QualityLevel.warning
                    : _QualityLevel.poor,
      ),
      _ratioMetric('Confidence pose', 'mean_confidence',
          good: .55, warning: .4),
      _ratioMetric('Frame terdeteksi', 'missing_frame_ratio',
          good: .85, warning: .7, inverse: true),
      _ratioMetric('Kejelasan gerakan', 'pc1_variance_ratio',
          good: .4, warning: .25),
      _QualityMetricData(
        'Signal sendi utama',
        snr == null || !snr.isFinite ? '—' : snr.toStringAsFixed(2),
        snr == null || !snr.isFinite ? null : (snr / 9).clamp(0, 1),
        snr == null || !snr.isFinite
            ? _QualityLevel.unavailable
            : snr >= 9
                ? _QualityLevel.good
                : snr >= 6
                    ? _QualityLevel.warning
                    : _QualityLevel.poor,
      ),
      _ratioMetric('Kejelasan fase', 'phase_confidence',
          good: .65, warning: .55),
      _ratioMetric('Batas repetisi', 'boundary_confidence',
          good: .65, warning: .45),
      _ratioMetric('Konsistensi pose awal', 'phase_anchor_confidence',
          good: .65, warning: .5),
    ];
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xffeef3ef),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffcdd9d2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('INDIKATOR KUALITAS PIPELINE',
              style: TextStyle(
                  color: Color(0xff176b4b),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3)),
          const SizedBox(height: 5),
          const Text(
              'Nilai ini membantu audit capture; error pipeline tetap menentukan apakah recipe dapat dipublikasikan.',
              style: TextStyle(color: Color(0xff52665d), height: 1.35)),
          const SizedBox(height: 16),
          for (final metric in _metrics) _QualityBar(metric: metric),
          const SizedBox(height: 8),
          const Wrap(spacing: 12, runSpacing: 6, children: [
            _QualityLegend(Color(0xff38a169), 'Baik / sesuai toleransi'),
            _QualityLegend(Color(0xffd8a529), 'Perlu perhatian'),
            _QualityLegend(Color(0xffd3544d), 'Di bawah batas'),
            _QualityLegend(Color(0xff9aa3a8), 'Belum terbaca'),
          ]),
        ]),
      );
}

class _QualityBar extends StatelessWidget {
  const _QualityBar({required this.metric});

  final _QualityMetricData metric;

  Color get _color => switch (metric.level) {
        _QualityLevel.good => const Color(0xff38a169),
        _QualityLevel.warning => const Color(0xffd8a529),
        _QualityLevel.poor => const Color(0xffd3544d),
        _QualityLevel.unavailable => const Color(0xff9aa3a8),
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(metric.label,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(metric.value,
                style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: metric.progress ?? 0,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
            color: _color,
            backgroundColor: const Color(0xffd9e0dc),
          ),
        ]),
      );
}

class _QualityLegend extends StatelessWidget {
  const _QualityLegend(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Color(0xff52665d), fontSize: 11)),
        ],
      );
}

class _ShareCodeCard extends StatelessWidget {
  const _ShareCodeCard({required this.code, this.recipe});

  final String code;
  final Map<String, dynamic>? recipe;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kode latihan disalin.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRecipe = recipe;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffd9f2df),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xff9bc9ad)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.verified_rounded, color: Color(0xff176b4b)),
          SizedBox(width: 8),
          Expanded(
            child: Text('Recipe siap dibagikan',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Berikan kode ini kepada pasien. Pasien memasukkannya sekali untuk mengambil recipe latihan.',
          style: TextStyle(color: Color(0xff52665d), height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: SelectableText(
              code,
              style: const TextStyle(
                  color: Color(0xff176b4b),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Salin kode',
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded),
          ),
        ]),
        if (currentRecipe != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              try {
                final parsed = ExerciseRecipe.fromJson(currentRecipe);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionScreen(recipe: parsed),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal memulai sesi: $e')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff176b4b),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Coba Latihan Sebagai Pasien',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

enum _PreviewKind { guide, overlay }

class _AnalysisPreviewCard extends StatefulWidget {
  const _AnalysisPreviewCard({
    required this.jobId,
    required this.client,
    required this.hasGuide,
    required this.hasOverlay,
  });

  final String jobId;
  final PipelineClient client;
  final bool hasGuide;
  final bool hasOverlay;

  @override
  State<_AnalysisPreviewCard> createState() => _AnalysisPreviewCardState();
}

class _AnalysisPreviewCardState extends State<_AnalysisPreviewCard> {
  VideoPlayerController? _controller;
  _PreviewKind _kind = _PreviewKind.guide;
  bool _loading = false;
  String? _error;
  int _loadVersion = 0;

  bool get _hasSelected =>
      _kind == _PreviewKind.guide ? widget.hasGuide : widget.hasOverlay;

  @override
  void initState() {
    super.initState();
    if (!widget.hasGuide && widget.hasOverlay) {
      _kind = _PreviewKind.overlay;
    }
    _openSelected();
  }

  @override
  void didUpdateWidget(covariant _AnalysisPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId ||
        oldWidget.hasGuide != widget.hasGuide ||
        oldWidget.hasOverlay != widget.hasOverlay) {
      if (_kind == _PreviewKind.guide &&
          !widget.hasGuide &&
          widget.hasOverlay) {
        _kind = _PreviewKind.overlay;
      }
      _openSelected();
    }
  }

  Future<void> _openSelected() async {
    final version = ++_loadVersion;
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    if (!_hasSelected) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final uri = _kind == _PreviewKind.guide
        ? widget.client.guideUri(widget.jobId)
        : widget.client.previewUri(widget.jobId);
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: widget.client.mediaHeaders,
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted || version != _loadVersion) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (exception) {
      await controller.dispose();
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _error =
            'Video pratinjau gagal dimuat. Pastikan engine Python tetap menyala.';
      });
    }
  }

  Future<void> _select(_PreviewKind kind) async {
    if (_kind == kind) return;
    setState(() => _kind = kind);
    await _openSelected();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    controller.value.isPlaying
        ? await controller.pause()
        : await controller.play();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _loadVersion++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final title = _kind == _PreviewKind.guide
        ? 'Panduan skeleton'
        : 'Video dengan skeleton';
    final description = _kind == _PreviewKind.guide
        ? 'Skeleton bergerak tanpa video asli untuk memeriksa fase latihan.'
        : 'Periksa apakah titik sendi dan garis rangka mengikuti tubuh dengan tepat.';

    return Card(
      clipBehavior: Clip.antiAlias,
      color: const Color(0xff18372d),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PRATINJAU HASIL ANALISIS',
                style: TextStyle(
                    color: Color(0xffd9f26a),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(
                    color: Color(0xffb8c9c1), fontSize: 14, height: 1.4)),
            const SizedBox(height: 14),
            SegmentedButton<_PreviewKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: _PreviewKind.guide,
                    enabled: widget.hasGuide,
                    icon: const Icon(Icons.accessibility_new_rounded),
                    label: const Text('Skeleton saja')),
                ButtonSegment(
                    value: _PreviewKind.overlay,
                    enabled: widget.hasOverlay,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Video asli')),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => _select(selection.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? const Color(0xff18372d)
                        : Colors.white),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? const Color(0xffd9f26a)
                        : Colors.transparent),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(minHeight: 220),
              decoration: BoxDecoration(
                  color: const Color(0xff0c1d18),
                  borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xffd9f26a)))
                  : _error != null
                      ? _PreviewMessage(
                          icon: Icons.error_outline_rounded, text: _error!)
                      : !_hasSelected
                          ? const _PreviewMessage(
                              icon: Icons.movie_filter_outlined,
                              text:
                                  'Preview belum tersedia. Jalankan ulang analisis video dengan engine terbaru.')
                          : controller != null && controller.value.isInitialized
                              ? GestureDetector(
                                  onTap: _togglePlayback,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      AspectRatio(
                                        aspectRatio:
                                            controller.value.aspectRatio,
                                        child: VideoPlayer(controller),
                                      ),
                                      if (!controller.value.isPlaying)
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: const BoxDecoration(
                                              color: Color(0xccd9f26a),
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Color(0xff18372d),
                                              size: 38),
                                        ),
                                    ],
                                  ),
                                )
                              : const _PreviewMessage(
                                  icon: Icons.hourglass_empty_rounded,
                                  text: 'Menyiapkan pratinjau…'),
            ),
            if (controller != null && controller.value.isInitialized) ...[
              const SizedBox(height: 8),
              VideoProgressIndicator(controller,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                      playedColor: Color(0xffd9f26a),
                      bufferedColor: Color(0xff71857c),
                      backgroundColor: Color(0xff29493e))),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _togglePlayback,
                  icon: Icon(controller.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  label: Text(controller.value.isPlaying
                      ? 'Jeda pratinjau'
                      : 'Putar pratinjau'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xffd9f26a)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xffb8c9c1), size: 34),
              const SizedBox(height: 10),
              Text(text,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xffb8c9c1), height: 1.4)),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xff18372d),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xffadc1b7), fontSize: 12)),
          const SizedBox(height: 7),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ]),
      );
}

class _JointCard extends StatelessWidget {
  const _JointCard(
      {required this.title, required this.joints, required this.color});
  final String title;
  final List<String> joints;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xffdcd8ce))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final joint in joints)
                Chip(backgroundColor: color, label: Text(_jointLabel(joint))),
              if (joints.isEmpty)
                const Text('Belum ada sendi terdeteksi',
                    style: TextStyle(color: Color(0xff66736d))),
            ]),
          ]),
        ),
      );

  String _jointLabel(String name) {
    const exact = {
      'head_yaw': 'Kepala menoleh',
      'head_pitch': 'Kepala menunduk/menengadah',
      'head_roll': 'Kepala miring',
      'hand_spread_L': 'Bukaan tangan kiri',
      'hand_spread_R': 'Bukaan tangan kanan',
      'wrist_flex_L': 'Pergelangan kiri',
      'wrist_flex_R': 'Pergelangan kanan',
    };
    if (exact.containsKey(name)) return exact[name] ?? name;
    final side = name.endsWith('_L')
        ? 'kiri'
        : name.endsWith('_R')
            ? 'kanan'
            : '';
    final finger = switch (true) {
      _ when name.contains('thumb') => 'jempol',
      _ when name.contains('index') => 'telunjuk',
      _ when name.contains('middle') => 'jari tengah',
      _ when name.contains('ring') => 'jari manis',
      _ when name.contains('pinky') => 'kelingking',
      _ => null,
    };
    if (finger != null) return 'Tekukan $finger $side';
    return name.replaceAll('_', ' ');
  }
}

class _PhaseTimelineCard extends StatelessWidget {
  const _PhaseTimelineCard({
    required this.anchors,
    required this.directions,
    this.confidence,
  });

  final Map<String, dynamic> anchors;
  final Map<String, dynamic> directions;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    const phases = [
      ('movement_start', 'Mulai'),
      ('turning_point', 'Titik balik'),
      ('hold_end', 'Selesai tahan'),
      ('return_start', 'Kembali'),
      ('return_complete', 'Posisi awal'),
      ('cycle_end', 'Siklus selesai'),
    ];
    return Card(
      color: const Color(0xff18372d),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Text('Peta fase gerakan',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ),
            if (confidence != null)
              Text('${(confidence! * 100).round()}% yakin',
                  style: const TextStyle(
                      color: Color(0xffd9f26a), fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Urutan yang dipakai untuk mengenali keluar, berhenti, dan kembali.',
            style: TextStyle(color: Color(0xffbfcfc7), height: 1.4),
          ),
          const SizedBox(height: 15),
          for (final phase in phases)
            if (anchors[phase.$1] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xffd9f26a), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(phase.$2,
                          style: const TextStyle(color: Colors.white))),
                  Text('${(anchors[phase.$1] as num).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          color: Color(0xffbfcfc7),
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          if (directions.isNotEmpty) ...[
            const Divider(color: Color(0xff496158), height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in directions.entries)
                  Chip(
                    backgroundColor: const Color(0xffd9f2df),
                    label: Text(
                        '${entry.key.replaceAll('_', ' ')} · ${entry.value == 'decreasing' ? 'nilai menurun' : 'nilai meningkat'}'),
                  ),
              ],
            ),
          ],
        ]),
      ),
    );
  }
}
