import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/pages/auth/login.dart';
import 'package:kinday/pages/mainpage.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();

  Timer? _checkTimer;
  Timer? _cooldownTimer;

  bool _isResendCooldown = false;
  int _cooldownSeconds = 0;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Polls Firebase every 3 seconds to see if the user has verified their email.
  void _startVerificationCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final verified = await _authService.isEmailVerified();
        if (verified && mounted) {
          timer.cancel();
          _cooldownTimer?.cancel();
          await _onEmailVerified();
        }
      } catch (e) {
        debugPrint("Error checking email verification: $e");
      }
    });
  }

  /// Called once email verification is confirmed. Saves login state and navigates to the main app.
  Future<void> _onEmailVerified() async {
    await PreferenceHandler.setLogin(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          L10n.tr("Email verified! Welcome to Kinday 🎉"),
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Mainpage()),
      (route) => false,
    );
  }

  /// Resends the verification email and starts a 60-second cooldown timer.
  Future<void> _resendVerificationEmail() async {
    if (_isResendCooldown) return;

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.tr("Verification email sent! Please check your inbox."),
          ),
          backgroundColor: Colors.green,
        ),
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to resend email: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  /// Starts a 60-second cooldown preventing the user from spamming resend.
  void _startCooldown() {
    setState(() {
      _isResendCooldown = true;
      _cooldownSeconds = 60;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _isResendCooldown = false;
          timer.cancel();
        }
      });
    });
  }

  /// Signs out the unverified user and returns to the login page.
  Future<void> _cancelVerification() async {
    _checkTimer?.cancel();
    _cooldownTimer?.cancel();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      body: BgContainer(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Image.asset(AppImage.mascotlogin, height: 240),
                  const SizedBox(height: 20),

                  Text(
                    L10n.tr("Check Your Email"),
                    style: TextStyle(
                      color: AppColors.button,
                      fontFamily: "Super",
                      fontSize: 26,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L10n.tr("We've sent a verification link to"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.button.withAlpha(180),
                      fontFamily: "Nunito",
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.button,
                      fontFamily: "Nunito",
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        // Animated checking indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.button,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              L10n.tr("Waiting for verification..."),
                              style: TextStyle(
                                color: AppColors.button,
                                fontFamily: "Nunito",
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Text(
                          L10n.tr("Open the link in your email to continue. This page will update automatically."),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.button.withAlpha(160),
                            fontFamily: "Nunito",
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Resend button
                        _isResending
                            ? CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.button,
                                ),
                              )
                            : AccButton(
                                sign: _isResendCooldown
                                    ? L10n.tr("Resend in ${_cooldownSeconds}s")
                                    : L10n.tr("Resend Verification Email"),
                                warnaBox: _isResendCooldown
                                    ? AppColors.button.withAlpha(100)
                                    : AppColors.button,
                                destination: const SizedBox(),
                                textbuttoncolor: Colors.white,
                                onPressed: _isResendCooldown
                                    ? null
                                    : _resendVerificationEmail,
                              ),

                        const SizedBox(height: 16),

                        // Back to login
                        TextButton(
                          onPressed: _cancelVerification,
                          child: Text(
                            L10n.tr("Back to Login"),
                            style: TextStyle(
                              color: AppColors.button,
                              fontFamily: "Nunito",
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.button,
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
    );
  }
}
