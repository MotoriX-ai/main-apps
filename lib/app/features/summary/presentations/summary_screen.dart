import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:motorix_phase2/app/features/summary/models/session_summary.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _SummaryColors.lowerBackground,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _SummaryColors.background,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 375),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 7, 22, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _PageHeader(),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 60,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                summary.recipe.exerciseName,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: AppTypography.largeTitle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            summary.completed
                                ? 'Congratulation!\nYou Done it!'
                                : 'Session Complete!\nYou Did it!',
                            textAlign: TextAlign.center,
                            style: AppTypography.headline.copyWith(
                              color: _SummaryColors.green,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 47),
                          _ScoreHero(score: summary.total),
                        ],
                      ),
                    ),
                    Container(
                      color: _SummaryColors.lowerBackground,
                      padding: const EdgeInsets.fromLTRB(32, 18, 32, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ScoreBreakdown(summary: summary),
                          const SizedBox(height: 22),
                          _TempoHeatmap(summary: summary),
                          const SizedBox(height: 22),
                          _RecommendationCard(text: summary.recommendation),
                          const SizedBox(height: 22),
                          Center(
                            child: SizedBox(
                              width: 293,
                              height: 43,
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _SummaryColors.green,
                                  foregroundColor: _SummaryColors.background,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  'Back to Home',
                                  style: AppTypography.caption1.copyWith(
                                    color: _SummaryColors.background,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Material(
                color: _SummaryColors.green,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _SummaryColors.background,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Today Task',
                  style: AppTypography.headline,
                ),
              ),
              Image.asset(
                'assets/images/motorix_logo_large.png',
                width: 29,
                height: 28,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: _SummaryColors.green,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 402,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const designWidth = 331.0;
          final scale = constraints.maxWidth / designWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -2 * scale,
                top: 22 * scale,
                width: 321 * scale,
                height: 321 * scale,
                child: Image.asset(
                  'assets/images/summary_score_halo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                right: -5 * scale,
                top: 0,
                width: 152 * scale,
                height: 152 * scale,
                child: Image.asset(
                  'assets/images/summary_sun.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: 7 * scale,
                top: 31 * scale,
                width: 304 * scale,
                height: 304 * scale,
                child: Image.asset(
                  'assets/images/summary_score_circle.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: -60 * scale,
                top: 219 * scale,
                width: 178 * scale,
                height: 178 * scale,
                child: Image.asset(
                  'assets/images/summary_cloud_left.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                right: -60 * scale,
                top: 175 * scale,
                width: 178 * scale,
                height: 178 * scale,
                child: Image.asset(
                  'assets/images/summary_cloud_right.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 76 * scale,
                child: Text(
                  score.toStringAsFixed(0),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _SummaryColors.background,
                    fontFamily: AppTypography.fontSFPro,
                    fontSize: 132 * scale,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 239 * scale,
                child: Text(
                  'from 100',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption1.copyWith(
                    color: _SummaryColors.background,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 162),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: _SummaryColors.lightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _ScoreRow(label: 'Ketepatan gerakan', value: summary.form),
          _ScoreRow(label: 'Rentang gerak', value: summary.rom),
          _ScoreRow(label: 'Tempo', value: summary.tempo),
          _ScoreRow(label: 'Stabilitas tubuh', value: summary.compensation),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption4.copyWith(
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value.clamp(0, 100) / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              color: _scoreColor(value),
              backgroundColor: const Color(0xFFE1E5DE),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 25,
            child: Text(
              value.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: AppTypography.caption4.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF38A169);
    if (score >= 60) return const Color(0xFFD8A529);
    return const Color(0xFFD3544D);
  }
}

class _TempoHeatmap extends StatelessWidget {
  const _TempoHeatmap({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final names = summary.recipe.primary
        .where((name) => summary.tempoMatchRatio.containsKey(name))
        .toList(growable: false);

    return Container(
      constraints: const BoxConstraints(minHeight: 162),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _SummaryColors.green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heatmap tempo sendi',
            style: AppTypography.footnote.copyWith(
              color: _SummaryColors.background,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rata-rata kecocokan tempo selama gerakan.',
            style: AppTypography.caption4.copyWith(
              color: _SummaryColors.background,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              _SummaryLegend(color: Color(0xFFFF4D4D), label: 'Pas'),
              _SummaryLegend(color: Color(0xFFFFC857), label: 'Belum sesuai'),
              _SummaryLegend(color: Colors.white54, label: 'Belum terbaca'),
            ],
          ),
          const SizedBox(height: 12),
          if (names.isEmpty)
            Text(
              'Belum ada siklus gerakan yang cukup untuk dinilai.',
              style: AppTypography.caption4.copyWith(
                color: _SummaryColors.background,
                height: 1.4,
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final name in names)
                  _TempoJointTile(
                    name: _jointLabel(name),
                    ratio: summary.tempoMatchRatio[name] ?? 0.0,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SummaryLegend extends StatelessWidget {
  const _SummaryLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption4.copyWith(
            color: _SummaryColors.background,
          ),
        ),
      ],
    );
  }
}

class _TempoJointTile extends StatelessWidget {
  const _TempoJointTile({required this.name, required this.ratio});

  final String name;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final matched = ratio >= .7;
    final color = matched ? const Color(0xFFFF4D4D) : const Color(0xFFFFC857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$name · ${(ratio * 100).round()}% pas',
        style: AppTypography.caption4.copyWith(
          color: _SummaryColors.background,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.fromLTRB(23, 16, 23, 16),
      decoration: BoxDecoration(
        color: _SummaryColors.lightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommendation Task',
            style: AppTypography.footnote.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: AppTypography.caption4.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _jointLabel(String name) {
  final side = name.endsWith('_L')
      ? ' kiri'
      : name.endsWith('_R')
          ? ' kanan'
          : '';
  final key = name.replaceFirst(RegExp(r'_[LR]$'), '');
  final label = switch (key) {
    'curl_thumb' => 'Ibu jari',
    'curl_index' => 'Telunjuk',
    'curl_middle' => 'Jari tengah',
    'curl_ring' => 'Jari manis',
    'curl_pinky' => 'Kelingking',
    'hand_spread' => 'Bukaan tangan',
    'wrist_flex' => 'Pergelangan tangan',
    'elbow_flex' => 'Siku',
    'shoulder_elev' => 'Bahu',
    'hip_flex' => 'Pinggul',
    'knee_flex' => 'Lutut',
    'ankle_dorsi' => 'Pergelangan kaki',
    'head_yaw' => 'Kepala',
    'neck_flex' => 'Leher',
    _ => key.replaceAll('_', ' '),
  };
  return '$label$side';
}

abstract final class _SummaryColors {
  static const background = AppColors.softWhite;
  static const lowerBackground = AppColors.softWhite;
  static const green = AppColors.green;
  static const lightGreen = AppColors.lightGreen;
}
