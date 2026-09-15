import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/pages/auth/login.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingModel> _slides = [
    OnboardingModel(
      titleEn: "Manage Tasks",
      titleId: "Manajemen Tugas",
      descEn: "Organize your daily tasks, select energy levels, and set custom reminders to stay productive.",
      descId: "Atur tugas harian Anda, pilih tingkat energi, dan atur pengingat khusus untuk tetap produktif.",
      imageAsset: AppImage.mascottask,
    ),
    OnboardingModel(
      titleEn: "Pomodoro Focus",
      titleId: "Fokus Pomodoro",
      descEn: "Boost your concentration using our integrated Pomodoro timer with ambient theme colors.",
      descId: "Tingkatkan konsentrasi Anda menggunakan timer Pomodoro terintegrasi dengan warna tema yang menenangkan.",
      imageAsset: AppImage.mascotfocus,
    ),
    OnboardingModel(
      titleEn: "Energy Tracking",
      titleId: "Lacak Energi",
      descEn: "Log your daily energy levels and get insights into your peak productivity hours.",
      descId: "Catat tingkat energi harian Anda dan dapatkan wawasan tentang jam-jam produktivitas puncak Anda.",
      imageAsset: AppImage.mascotstar,
    ),
    OnboardingModel(
      titleEn: "Cloud Sync & Backup",
      titleId: "Sinkronisasi Cloud",
      descEn: "Never lose your tasks. Securely backup and restore your local data using Firebase.",
      descId: "Jangan pernah kehilangan tugas Anda. Cadangkan dan pulihkan data lokal Anda dengan aman menggunakan Firebase.",
      imageAsset: AppImage.mascotlogin,
    ),
  ];

  void _finishOnboarding(BuildContext context) async {
    await PreferenceHandler.setHasSeenOnboarding(true);
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.button;
    final textColor = AppColors.normaltext;

    return Scaffold(
      body: BgContainer(
        child: SafeArea(
          child: Column(
            children: [
              // Top Action Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Small logo/brand text
                    Text(
                      "Kinday",
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    // Skip button
                    if (_currentPage < _slides.length - 1)
                      TextButton(
                        onPressed: () => _finishOnboarding(context),
                        child: Text(
                          L10n.tr("Skip"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: 16,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48, height: 48), // Spacer to balance layout
                  ],
                ),
              ),

              // Page Slider
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Mascot Image with floating decoration
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(20.0),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.1),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  slide.imageAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.emoji_objects_outlined,
                                      size: 150,
                                      color: primaryColor,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Title & Description Card
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                Text(
                                  L10n.tr(slide.titleEn, slide.titleId),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: Text(
                                    L10n.tr(slide.descEn, slide.descId),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: "Nunito",
                                      fontSize: 16,
                                      height: 1.5,
                                      color: textColor.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom control bar (Indicators & Navigation button)
              Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 36.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Smooth indicator dots
                    Row(
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8.0),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == index
                                ? primaryColor
                                : primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),

                    // Next/Start Button
                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          _finishOnboarding(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        shadowColor: primaryColor.withValues(alpha: 0.3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == _slides.length - 1
                                ? L10n.tr("Get Started")
                                : L10n.tr("Next"),
                            style: const TextStyle(
                              fontFamily: "Quicksand",
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == _slides.length - 1
                                ? Icons.done_all_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingModel {
  final String titleEn;
  final String titleId;
  final String descEn;
  final String descId;
  final String imageAsset;

  OnboardingModel({
    required this.titleEn,
    required this.titleId,
    required this.descEn,
    required this.descId,
    required this.imageAsset,
  });
}
