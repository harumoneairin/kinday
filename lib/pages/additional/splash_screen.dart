import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/pages/auth/login.dart';
import 'package:kinday/pages/auth/onboarding.dart';
import 'package:kinday/pages/mainpage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // High-fidelity animations for a premium feel
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    // 1. Safely initialize configurations in the background while splash is showing
    try {
      await PreferenceHandler.init();
      final notificationHelper = NotificationHelper();
      await notificationHelper.init();
    } catch (e) {
      debugPrint("Error initializing configuration/plugins: $e");
    }

    // 2. Allow splash screen to show for a brief moment (animations can finish)
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;

    // 3. Navigate to appropriate page
    bool isLoggedIn = false;
    try {
      isLoggedIn = PreferenceHandler.isLogin;
    } catch (e) {
      debugPrint("Failed to read login preference: $e");
    }

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const Mainpage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      final hasSeenOnboarding = PreferenceHandler.hasSeenOnboarding;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              hasSeenOnboarding ? const LoginPage() : const OnboardingPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppColors.button;
    final textColor = AppColors.normaltext;

    return Scaffold(
      body: BgContainer(
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background decorative circles for a premium look
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                left: -100,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      // Logo Container (GIF)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.18),
                                blurRadius: 40,
                                offset: const Offset(0, 15),
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              AppImage.logoSplashscreen,
                              height: 200,
                              width: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 180,
                                  height: 180,
                                  color: Colors.grey[100],
                                  child: Icon(
                                    Icons.task_alt_rounded,
                                    size: 100,
                                    color: primaryColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Title & Subtitle with slide-fade animation
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _slideAnimation.value),
                            child: Opacity(
                              opacity: _opacityAnimation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Text(
                              "Kinday",
                              style: AppTextStyles.username.copyWith(
                                fontFamily: "Super",
                                fontSize: 46,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    offset: const Offset(1, 2),
                                    blurRadius: 3,
                                  ),
                                  Shadow(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    offset: const Offset(-1, -1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Text(
                                L10n.tr("Manage your tasks and focus with ease"),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.affirmation.copyWith(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Elegant Spinner
                      SpinKitThreeBounce(
                        color: primaryColor.withValues(alpha: 0.8),
                        size: 28.0,
                      ),

                      const SizedBox(height: 32),

                      // Version Footer
                      Opacity(
                        opacity: 0.5,
                        child: Text(
                          "Version 1.0.3",
                          style: AppTextStyles.bodytext.copyWith(
                            fontSize: 12,
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
