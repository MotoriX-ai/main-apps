import 'package:flutter/material.dart';

import 'package:motorix_phase2/app/core/theme.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.nextScreen,
  });

  final Widget nextScreen;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPageData(
      artwork: _OnboardingArtworkType.learn,
      title: 'Learn from Movement',
      subtitle: 'Upload or record videos to guide your\npersonalized practice.',
    ),
    _OnboardingPageData(
      artwork: _OnboardingArtworkType.monitor,
      title: 'Monitor Every Movement',
      subtitle: 'Complete daily exercises with precise\nmotion tracking.',
    ),
    _OnboardingPageData(
      artwork: _OnboardingArtworkType.recovery,
      title: 'Empower Your Recovery',
      subtitle: 'Turn daily practice into long-term\nhealing.',
    ),
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _OnboardingColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _OnboardingColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 375),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 34),
                child: Column(
                  children: [
                    _ProgressHeader(
                      currentPage: _currentPage,
                      pageCount: _pages.length,
                      onSkip: _finish,
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (page) {
                          setState(() => _currentPage = page);
                        },
                        itemBuilder: (context, index) {
                          return _OnboardingPage(data: _pages[index]);
                        },
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _currentPage == _pages.length - 1 ? 220 : 181,
                      height: 48,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: _OnboardingColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 8,
                          shadowColor: const Color(0x38111A14),
                          shape: const StadiumBorder(),
                        ),
                        child: _currentPage == _pages.length - 1
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Mulai Sekarang',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              )
                            : Image.asset(
                                'assets/images/onboarding_arrow.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
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

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.currentPage,
    required this.pageCount,
    required this.onSkip,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _OnboardingColors.navy),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentPage + 1} of $pageCount',
              style: const TextStyle(
                color: _OnboardingColors.navySecondary,
                fontFamily: 'SF Pro',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: -.14,
              ),
            ),
          ),
          const SizedBox(width: 21),
          Expanded(
            child: Container(
              height: 10,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: _OnboardingColors.navy),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                widthFactor: (currentPage + 1) / pageCount,
                heightFactor: 1,
                child: const ColoredBox(color: _OnboardingColors.navy),
              ),
            ),
          ),
          const SizedBox(width: 21),
          TextButton(
            onPressed: onSkip,
            style: TextButton.styleFrom(
              foregroundColor: _OnboardingColors.green,
              minimumSize: const Size(32, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Skip',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -.14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 343,
            height: 593,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _OnboardingArtwork(type: data.artwork),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 466,
                  child: Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _OnboardingColors.subtitle,
                      fontFamily: 'SF Pro',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 503,
                  child: Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _OnboardingColors.subtitle,
                      fontFamily: 'SF Pro',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.artwork,
    required this.title,
    required this.subtitle,
  });

  final _OnboardingArtworkType artwork;
  final String title;
  final String subtitle;
}

class _OnboardingArtwork extends StatelessWidget {
  const _OnboardingArtwork({required this.type});

  final _OnboardingArtworkType type;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: switch (type) {
        _OnboardingArtworkType.learn => const [
            _ArtworkAsset(
              asset: 'assets/images/onboarding_learn_folder.png',
              left: 243,
              top: 164,
              width: 71,
              height: 71,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_learn_video.png',
              left: 204,
              top: 71,
              width: 110,
              height: 110,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_learn_phone.png',
              left: 12,
              top: 132,
              width: 278,
              height: 278,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_learn_hand.png',
              left: 117,
              top: 288,
              width: 147,
              height: 147,
            ),
          ],
        _OnboardingArtworkType.monitor => const [
            _ArtworkAsset(
              asset: 'assets/images/onboarding_monitor_person.png',
              left: 8,
              top: 117,
              width: 266,
              height: 292,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_monitor_phone.png',
              left: 207,
              top: 171,
              width: 123,
              height: 123,
            ),
          ],
        _OnboardingArtworkType.recovery => const [
            _ArtworkAsset(
              asset: 'assets/images/onboarding_recovery_cloud_left.png',
              left: -69,
              top: 246,
              width: 125,
              height: 178,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_recovery_cloud_right.png',
              left: 254,
              top: 190,
              width: 105,
              height: 178,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_recovery_person.png',
              left: 67,
              top: 190,
              width: 234,
              height: 234,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_recovery_phone.png',
              left: 74,
              top: 135,
              width: 95,
              height: 95,
            ),
            _ArtworkAsset(
              asset: 'assets/images/onboarding_recovery_sun.png',
              left: 184,
              top: 93,
              width: 86,
              height: 86,
            ),
          ],
      },
    );
  }
}

class _ArtworkAsset extends StatelessWidget {
  const _ArtworkAsset({
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Image.asset(
          asset,
          width: width,
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

enum _OnboardingArtworkType { learn, monitor, recovery }

abstract final class _OnboardingColors {
  static const background = AppColors.softWhite;
  static const navy = AppColors.navy;
  static const navySecondary = Color(0xFF124067);
  static const green = AppColors.green;
  static const subtitle = Color(0xFF5D6A85);
}
