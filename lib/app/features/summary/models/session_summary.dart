import 'package:motorix_phase2/motorix_phase2.dart';

class SessionSummary {
  const SessionSummary({
    required this.recipe,
    required this.scores,
    required this.repetitions,
    required this.duration,
    this.tempoMatchRatio = const {},
  });

  final ExerciseRecipe recipe;
  final List<RepScore> scores;
  final int repetitions;
  final Duration duration;
  final Map<String, double> tempoMatchRatio;

  double average(double Function(RepScore score) select) => scores.isEmpty
      ? 0
      : scores.map(select).reduce((a, b) => a + b) / scores.length;

  double get total => average((score) => score.total);
  double get form => average((score) => score.form);
  double get rom => average((score) => score.rom);
  double get tempo => average((score) => score.tempo);
  double get compensation => average((score) => score.compensation);
  bool get completed => recipe.mode == ExerciseMode.duration
      ? duration.inSeconds >= (recipe.targetDurationSeconds ?? 1)
      : repetitions >= recipe.targetReps;

  String get recommendation {
    final components = {
      'Ketepatan gerakan': form,
      'Rentang gerak': rom,
      'Tempo': tempo,
      'Stabilitas tubuh': compensation,
    };
    final weakest =
        components.entries.reduce((a, b) => a.value <= b.value ? a : b);
    if (scores.isEmpty) {
      return 'Belum ada repetisi lengkap yang dapat dinilai. Pastikan seluruh tubuh terlihat dan ikuti satu siklus gerakan penuh.';
    }
    if (weakest.value >= 85) {
      return 'Gerakan sudah sangat konsisten. Pertahankan kualitas yang sama pada sesi berikutnya.';
    }
    return switch (weakest.key) {
      'Rentang gerak' =>
        'Fokus berikutnya: capai rentang gerak secara bertahap tanpa memaksa sendi.',
      'Tempo' =>
        'Fokus berikutnya: ikuti tempo panduan dan hindari gerakan terlalu cepat.',
      'Stabilitas tubuh' =>
        'Fokus berikutnya: jaga sendi penjaga dan badan tetap stabil untuk mengurangi kompensasi.',
      _ =>
        'Fokus berikutnya: ikuti pola skeleton lebih dekat pada setiap fase gerakan.',
    };
  }
}
