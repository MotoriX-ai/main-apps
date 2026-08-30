import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:flutter/services.dart';
import 'package:motorix_phase2/motorix_phase2.dart';

import 'package:motorix_phase2/app/core/widgets/server_selector_sheet.dart';
import 'package:motorix_phase2/app/features/camera/presentations/session_screen.dart';
import 'package:motorix_phase2/app/features/home/services/recipe_repository.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final repository = RecipeRepository();
  final codeController = TextEditingController();
  ExerciseRecipe? recipe;
  String? error;
  bool loadingCode = false;

  @override
  void initState() {
    super.initState();
    repository.loadDemo().then((value) {
      if (mounted) setState(() => recipe = value);
    }).catchError((Object value) {
      if (mounted) setState(() => error = value.toString());
    });
  }

  Future<void> _import() async {
    try {
      final selected = await repository.importFromDevice();
      if (selected != null && mounted) {
        setState(() {
          recipe = selected;
          error = null;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    }
  }

  Future<void> _loadCode() async {
    final code = codeController.text.trim();
    if (code.isEmpty) {
      setState(() => error = 'Masukkan kode latihan dari dokter.');
      return;
    }
    setState(() {
      loadingCode = true;
      error = null;
    });
    try {
      final selected = await repository.loadByCode(code);
      if (!mounted) return;
      setState(() {
        recipe = selected;
        loadingCode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.exerciseName} siap digunakan.')),
      );
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        loadingCode = false;
        error = exception.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _startExercise() {
    final selectedRecipe = recipe;
    if (selectedRecipe == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionScreen(recipe: selectedRecipe),
      ),
    );
  }

  @override
  void dispose() {
    codeController.dispose();
    repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _HomeColors.background,
        bottomNavigationBar: const _BottomNavigation(),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 375),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 7, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PageHeader(),
                    const SizedBox(height: 21),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      child: _CodeCard(
                        controller: codeController,
                        loading: loadingCode,
                        onSubmit: _loadCode,
                      ),
                    ),
                    const SizedBox(height: 31),
                    Text(
                      recipe?.exerciseName ?? 'Task Hand 1',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _HomeColors.green,
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 17),
                    _ExercisePreview(
                      loading: recipe == null && error == null,
                      enabled: recipe != null,
                      onTap: _startExercise,
                    ),
                    const SizedBox(height: 10),
                    _ExerciseStats(recipe: recipe),
                    const SizedBox(height: 10),
                    _RecipeDetails(recipe: recipe),
                    if (currentError != null) ...[
                      const SizedBox(height: 10),
                      _ErrorMessage(message: currentError),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 43,
                      child: FilledButton(
                        onPressed: recipe == null ? null : _startExercise,
                        style: FilledButton.styleFrom(
                          backgroundColor: _HomeColors.green,
                          disabledBackgroundColor:
                              _HomeColors.green.withValues(alpha: .35),
                          foregroundColor: _HomeColors.background,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Start',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 43,
                      child: FilledButton(
                        onPressed: _import,
                        style: FilledButton.styleFrom(
                          backgroundColor: _HomeColors.lightGreen,
                          foregroundColor: _HomeColors.green,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Import Recipe from doctor',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kode membutuhkan koneksi sekali untuk mengambil recipe. '
                      'Pose estimation, repetisi, feedback, dan scoring tetap '
                      'berjalan di perangkat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _HomeColors.muted,
                        fontFamily: 'SF Pro',
                        fontSize: 10,
                        height: 1.5,
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
                color: _HomeColors.green,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: _HomeColors.background,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Today Task',
                  style: TextStyle(
                    color: _HomeColors.navy,
                    fontFamily: 'SF Pro',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              InkWell(
                onTap: () => ServerSelectorSheet.show(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    'assets/images/motorix_logo_large.png',
                    width: 29,
                    height: 28,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: _HomeColors.green,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.fromLTRB(13, 14, 12, 9),
      decoration: BoxDecoration(
        color: _HomeColors.green,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Have a code from your doctor?',
            style: TextStyle(
              color: _HomeColors.background,
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const Text(
            'Enter the code to access your exercise guide.',
            style: TextStyle(
              color: _HomeColors.background,
              fontFamily: 'SF Pro',
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 47,
            child: TextField(
              controller: controller,
              enabled: !loading,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(
                color: _HomeColors.navy,
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
              decoration: InputDecoration(
                hintText: 'MX-2AB26799',
                hintStyle: TextStyle(
                  color: _HomeColors.muted.withValues(alpha: .65),
                ),
                filled: true,
                fillColor: _HomeColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _HomeColors.lightGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 33,
            child: FilledButton(
              onPressed: loading ? null : onSubmit,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: _HomeColors.lightGreen,
                disabledBackgroundColor:
                    _HomeColors.lightGreen.withValues(alpha: .7),
                foregroundColor: _HomeColors.green,
                shape: const StadiumBorder(),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _HomeColors.green,
                      ),
                    )
                  : const Text(
                      'Use Code',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePreview extends StatelessWidget {
  const _ExercisePreview({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeColors.green,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 158,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                left: 24,
                top: 20,
                child: _Bubble(size: 35, opacity: .10),
              ),
              const Positioned(
                right: 25,
                bottom: 18,
                child: _Bubble(size: 52, opacity: .08),
              ),
              const Positioned(
                right: 62,
                top: 20,
                child: Icon(
                  Icons.star_rounded,
                  size: 24,
                  color: Color(0x30F5F7FA),
                ),
              ),
              if (loading)
                const CircularProgressIndicator(
                  color: _HomeColors.background,
                )
              else
                Icon(
                  Icons.play_arrow_rounded,
                  color: enabled
                      ? _HomeColors.background
                      : _HomeColors.background.withValues(alpha: .45),
                  size: 42,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _HomeColors.background.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ExerciseStats extends StatelessWidget {
  const _ExerciseStats({required this.recipe});

  final ExerciseRecipe? recipe;

  @override
  Widget build(BuildContext context) {
    final data = recipe;
    return Row(
      children: [
        Expanded(
          child: _InfoChip(
            label: data == null
                ? 'Every Morning\n09.00 AM'
                : '${data.targetReps} Target\nRepetitions',
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _InfoChip(
            icon: Icons.access_time_filled_rounded,
            label: data == null
                ? '10 Minutes'
                : '${data.cycleSeconds.toStringAsFixed(1)} sec tempo',
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _InfoChip(
            icon: Icons.repeat_rounded,
            label: data == null ? '2 times' : data.cameraView,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: _HomeColors.lightGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _HomeColors.green, size: 20),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _HomeColors.navy,
                fontFamily: 'SF Pro',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({required this.recipe});

  final ExerciseRecipe? recipe;

  @override
  Widget build(BuildContext context) {
    final data = recipe;
    if (data == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary: ${data.primary.join(', ')}',
            style: const TextStyle(
              color: _HomeColors.navy,
              fontFamily: 'SF Pro',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Guard: ${data.guard.join(', ')}',
            style: const TextStyle(
              color: _HomeColors.muted,
              fontFamily: 'SF Pro',
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _HomeColors.error.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: _HomeColors.error, size: 18),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _HomeColors.error,
                fontFamily: 'SF Pro',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: .16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _NavigationItem(icon: Icons.home_rounded, selected: true),
                _NavigationItem(icon: Icons.photo_rounded),
                _NavigationItem(icon: Icons.calendar_month_outlined),
                _NavigationItem(icon: Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      height: 56,
      decoration: BoxDecoration(
        color: selected ? _HomeColors.navigationSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 26, color: _HomeColors.navy),
          if (selected)
            const Positioned(
              bottom: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _HomeColors.green,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(width: 5, height: 5),
              ),
            ),
        ],
      ),
    );
  }
}

abstract final class _HomeColors {
  static const background = AppColors.softWhite;
  static const navy = AppColors.navy;
  static const green = AppColors.green;
  static const lightGreen = AppColors.lightGreen;
  static const muted = Color(0xFF5D6A85);
  static const navigationSelected = Color(0xFFF4F2F7);
  static const error = Color(0xFFB42318);
}
