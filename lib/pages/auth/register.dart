import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/models/user_model_firebase.dart';
import 'package:kinday/models/user_model_sql.dart';
import 'package:kinday/pages/auth/login.dart';
import 'package:kinday/pages/auth/terms_conditions.dart';
import 'package:kinday/pages/auth/verify_email.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isAgreeTnc = false;
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(_onFocusOrPasswordChange);
    _passwordController.addListener(_onFocusOrPasswordChange);
  }

  void _onFocusOrPasswordChange() {
    setState(() {});
  }

  bool _hasLength(String text) => text.length >= 8;
  bool _hasUppercase(String text) => RegExp(r'[A-Z]').hasMatch(text);
  bool _hasLowercase(String text) => RegExp(r'[a-z]').hasMatch(text);
  bool _hasNumber(String text) => RegExp(r'[0-9]').hasMatch(text);
  bool _hasSpecial(String text) =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(text);

  Widget _buildPasswordRequirements(String text) {
    if (!_passwordFocusNode.hasFocus) {
      return const SizedBox.shrink();
    }

    final hasLen = _hasLength(text);
    final hasUpper = _hasUppercase(text);
    final hasLower = _hasLowercase(text);
    final hasNum = _hasNumber(text);
    final hasSpec = _hasSpecial(text);

    Widget requirementRow(String label, bool isMet) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle : Icons.cancel,
              color: isMet ? Colors.green : Colors.redAccent,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: "Nunito",
                fontSize: 12,
                color: isMet ? Colors.green : Colors.redAccent,
                fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.background.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.tr("Password Requirements:"),
            style: TextStyle(
              fontFamily: "Nunito",
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.button,
            ),
          ),
          const SizedBox(height: 6),
          requirementRow(
            L10n.tr("Minimum 8 characters"),
            hasLen,
          ),
          requirementRow(
            L10n.tr("At least one uppercase letter"),
            hasUpper,
          ),
          requirementRow(
            L10n.tr("At least one lowercase letter"),
            hasLower,
          ),
          requirementRow(
            L10n.tr("At least one number"),
            hasNum,
          ),
          requirementRow(
            L10n.tr("At least one special character"),
            hasSpec,
          ),
        ],
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return L10n.tr("Please enter a password");
    }
    if (value.length < 8) {
      return L10n.tr("Password must be at least 8 characters");
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return L10n.tr("Password must contain at least one uppercase letter");
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return L10n.tr("Password must contain at least one lowercase letter");
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return L10n.tr("Password must contain at least one number");
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return L10n.tr("Password must contain at least one special character");
    }
    return null;
  }

  void _showTncDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            L10n.tr("Terms & Conditions"),
            style: TextStyle(
              fontFamily: "Quicksand",
              fontWeight: FontWeight.bold,
              color: AppColors.button,
            ),
          ),
          content: Text(
            L10n.tr("Please read and agree to the Terms & Conditions before registering a Kinday account."),
            style: const TextStyle(fontFamily: "Nunito"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                L10n.tr("Close"),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                L10n.tr("Read T&C"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _passwordFocusNode.removeListener(_onFocusOrPasswordChange);
    _passwordFocusNode.dispose();
    _passwordController.removeListener(_onFocusOrPasswordChange);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isAgreeTnc) {
      _showTncDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final dbHelper = DBHelper();
    final authService = FirebaseAuthService();

    try {
      // 1. Register in Firebase Auth & Firestore
      final firebaseUser = UserModelFirebase(
        username: username,
        email: email,
        password: password,
      );
      final firebaseSuccess = await authService.registerUser(firebaseUser);

      if (firebaseSuccess) {
        // 2. Also register in SQLite to maintain local database compatibility
        final sqlUser = UserModelSql(
          username: username,
          email: email,
          password: password,
        );
        final sqlSuccess = await dbHelper.registerUser(sqlUser);

        if (sqlSuccess) {
          final registeredUser = await dbHelper.getUserByEmail(email);
          final registeredFirebaseUser = await authService.getUserByEmail(
            email,
          );

          if (registeredUser != null && registeredUser.id != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', registeredUser.id!);
            await prefs.setString('user_name', registeredUser.username);
            await prefs.setString('user_email', registeredUser.email);

            if (registeredFirebaseUser != null &&
                registeredFirebaseUser.uid != null) {
              await prefs.setString(
                'user_id_firebase',
                registeredFirebaseUser.uid!,
              );
            }

            // Do NOT set login = true yet — the user must verify their email first.

            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmailVerificationPage(),
                ),
                (route) => false,
              );
            }
            return;
          } else {
            await _rollbackFirebaseRegistration();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Error fetching user after registration. Rolling back..."),
                ),
              );
            }
          }
        } else {
          await _rollbackFirebaseRegistration();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Local database registration failed. Rolling back..."),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Registration failed. Please try again."),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Registration failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}",
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: BgContainer(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImage.logoSplashscreen, height: 150, width: 150),
                const SizedBox(height: 24),
                CircularProgressIndicator(color: AppColors.button),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: BgContainer(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Image(image: AssetImage(AppImage.mascotlogin), height: 300),

                Text(
                  L10n.tr("Welcome"),
                  style: TextStyle(
                    color: AppColors.button,
                    fontFamily: "Super",
                    fontSize: 30,
                    letterSpacing: 8,
                  ),
                ),
                Text(
                  L10n.tr("Let's make today manageable"),
                  style: TextStyle(color: AppColors.button, letterSpacing: 2),
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                L10n.tr("Name"),
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                          InputField(
                            hint: L10n.tr("your name"),
                            icon: Icons.person,
                            controller: _usernameController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return L10n.tr("Please enter your name");
                              }
                              if (value.length > 30 || value.trim().isEmpty) {
                                return L10n.tr("Name has to be up to 30 letters");
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                L10n.tr("Email"),
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                          InputField(
                            hint: L10n.tr("your email"),
                            icon: Icons.email,
                            controller: _emailController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return L10n.tr("Please enter your email");
                              }
                              final emailRegex = RegExp(
                                r'^[^@]+@[^@]+\.[^@]+$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return L10n.tr("Please enter a valid email address");
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                L10n.tr("Password"),
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                          InputField(
                            hint: L10n.tr("your password"),
                            icon: Icons.key,
                            pwhide: true,
                            controller: _passwordController,
                            validator: _validatePassword,
                            focusNode: _passwordFocusNode,
                          ),
                          _buildPasswordRequirements(_passwordController.text),

                          SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                L10n.tr("Password Confirmation"),
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                          InputField(
                            hint: L10n.tr("retype your password"),
                            icon: Icons.key,
                            pwhide: true,
                            controller: _confirmPasswordController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return L10n.tr("Please retype your password");
                              }
                              if (value != _passwordController.text) {
                                return L10n.tr("Passwords do not match!");
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20),

                          AccButton(
                            sign: L10n.tr("Register"),
                            warnaBox: AppColors.button,
                            destination: const SizedBox(),
                            textbuttoncolor: Colors.white,
                            onPressed: _handleRegister,
                          ),

                          SizedBox(height: 20),

                          Row(
                            children: [
                              Checkbox(
                                activeColor: AppColors.button,
                                checkColor: Colors.white,
                                value: _isAgreeTnc,
                                onChanged: (value) {
                                  setState(() {
                                    _isAgreeTnc = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: "${L10n.tr("I agree to the")} ",
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Nunito",
                                      fontSize: 12,
                                    ),
                                    children: [
                                      TextSpan(
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const TermsConditionsPage(),
                                              ),
                                            );
                                          },
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                        text: L10n.tr("Terms & Conditions"),
                                      ),
                                      TextSpan(
                                        text: " ${L10n.tr("applicable.")}",
                                        style: TextStyle(
                                          color: AppColors.button,
                                          fontFamily: "Nunito",
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          Text.rich(
                            TextSpan(
                              text: L10n.tr("Already have an account?"),
                              style: TextStyle(
                                color: AppColors.button,
                                fontFamily: "Nunito",
                              ),
                              children: [
                                TextSpan(
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginPage(),
                                        ),
                                      );
                                    },
                                  style: const TextStyle(color: Colors.blue),
                                  text: " ${L10n.tr("Login")}",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rollbackFirebaseRegistration() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final uid = currentUser.uid;
        // 1. Delete Firestore document
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        // 2. Delete Firebase Auth user
        await currentUser.delete();
        debugPrint("Successfully rolled back Firebase user: $uid");
      }
    } catch (e) {
      debugPrint("Failed to rollback Firebase registration: $e");
    }
  }
}
