import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/pages/auth/login.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _resetEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final authService = FirebaseAuthService();

    try {
      // Check if email actually exists before sending reset link
      final firebaseUser = await authService.getUserByEmail(email);

      if (firebaseUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("No account found with this email address."),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Send the secure Firebase password reset email
      final sent = await authService.sendPasswordResetEmail(email);

      if (sent) {
        if (mounted) {
          setState(() {
            _resetEmailSent = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("Failed to send reset email. Please try again."),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BgContainer(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Image(image: AssetImage(AppImage.mascotlogin), height: 280),
                Text(
                  L10n.tr("Reset Password"),
                  style: TextStyle(
                    color: AppColors.button,
                    fontFamily: "Super",
                    fontSize: 28,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  _resetEmailSent
                      ? L10n.tr("Check your inbox!")
                      : L10n.tr("Find your Kinday account"),
                  style: TextStyle(
                    color: AppColors.button.withAlpha(204),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 25),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(35.0),
                    child: _resetEmailSent
                        ? _buildSuccessContent()
                        : _buildEmailInputContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shown after a reset email has been successfully sent.
  Widget _buildSuccessContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_rounded,
          size: 60,
          color: AppColors.button,
        ),
        const SizedBox(height: 16),
        Text(
          L10n.tr("Reset link sent!"),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.button,
            fontFamily: "Nunito",
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "${L10n.tr("We sent a password reset link to:")}\n${_emailController.text.trim()}\n\n${L10n.tr("Open the link in your email to create a new password, then come back and log in.")}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.button.withAlpha(180),
            fontFamily: "Nunito",
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 30),
        AccButton(
          sign: L10n.tr("Back to Login"),
          warnaBox: AppColors.button,
          destination: const SizedBox(),
          textbuttoncolor: Colors.white,
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  /// Shown initially for user to enter their email.
  Widget _buildEmailInputContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.tr("Email Address"),
            style: TextStyle(
              color: AppColors.button,
              fontFamily: "Nunito",
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          InputField(
            hint: L10n.tr("Enter your email"),
            icon: Icons.email,
            controller: _emailController,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return L10n.tr("Please enter your email");
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return L10n.tr("Please enter a valid email address");
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            L10n.tr("We will send a secure reset link to this email."),
            style: TextStyle(
              color: AppColors.button.withAlpha(160),
              fontFamily: "Nunito",
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 30),
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.button),
                  ),
                )
              : AccButton(
                  sign: L10n.tr("Send Reset Link"),
                  warnaBox: AppColors.button,
                  destination: const SizedBox(),
                  textbuttoncolor: Colors.white,
                  onPressed: _sendResetEmail,
                ),
          const SizedBox(height: 25),
          Center(
            child: Text.rich(
              TextSpan(
                text: "${L10n.tr("Remembered your password?")} ",
                style: TextStyle(
                  color: AppColors.button,
                  fontFamily: "Nunito",
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      },
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    text: L10n.tr("Login"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
