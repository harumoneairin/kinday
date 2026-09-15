import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/pages/auth/forgotpass.dart';
import 'package:kinday/pages/auth/register.dart';
import 'package:kinday/pages/auth/verify_email.dart';
import 'package:kinday/pages/mainpage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHelper().requestPermissions();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final dbHelper = DBHelper();
    final authService = FirebaseAuthService();

    try {
      // 1. Sign in via Firebase Auth
      final firebaseUser = await authService.loginUser(email, password);

      if (firebaseUser != null) {
        // 2. Check if email is verified
        final emailVerified = await authService.isEmailVerified();
        if (!emailVerified) {
          // Send a fresh verification email and redirect to the waiting screen
          await authService.sendEmailVerification();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Please verify your email. A new link has been sent to your inbox."),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const EmailVerificationPage(),
              ),
              (route) => false,
            );
          }
          return;
        }

        // 3. Check if user exists in local SQLite database by email
        var localUser = await dbHelper.getUserByEmail(email);
        if (localUser == null) {
          // If not, register locally to generate an integer ID
          final successRegisterLocal = await dbHelper.registerUser(
            firebaseUser.toSql(),
          );
          if (successRegisterLocal) {
            localUser = await dbHelper.getUserByEmail(email);
          }
        }

        // 4. Sync the SQLite password in case the user reset it via email link
        if (localUser != null && localUser.password != password) {
          final updatedUser = localUser.copyWith(password: password);
          await dbHelper.updateUser(updatedUser);
          localUser = await dbHelper.getUserByEmail(email);
        }

        if (localUser != null && localUser.id != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', localUser.id!);
          await prefs.setString('user_name', localUser.username);
          await prefs.setString('user_email', localUser.email);

          if (firebaseUser.uid != null) {
            await prefs.setString('user_id_firebase', firebaseUser.uid!);
          }

          await PreferenceHandler.setLogin(true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Login successful!"),
                ),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const Mainpage()),
              (route) => false,
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Error setting up local profile session."),
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("Invalid email or password."),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Login failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}",
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    final dbHelper = DBHelper();
    final authService = FirebaseAuthService();

    try {
      final firebaseUser = await authService.signInWithGoogle();

      if (firebaseUser != null) {
        // Check if user exists in local SQLite database by email
        var localUser = await dbHelper.getUserByEmail(firebaseUser.email);
        if (localUser == null) {
          // If not, register locally to generate an integer ID
          final successRegisterLocal = await dbHelper.registerUser(
            firebaseUser.toSql(),
          );
          if (successRegisterLocal) {
            localUser = await dbHelper.getUserByEmail(firebaseUser.email);
          }
        }

        if (localUser != null && localUser.id != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', localUser.id!);
          await prefs.setString('user_name', localUser.username);
          await prefs.setString('user_email', localUser.email);

          if (firebaseUser.uid != null) {
            await prefs.setString('user_id_firebase', firebaseUser.uid!);
          }

          await PreferenceHandler.setLogin(true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Login successful!"),
                ),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const Mainpage()),
              (route) => false,
            );
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Error setting up local profile session."),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Google Sign-In failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '')}",
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
                CircularProgressIndicator(
                  color: AppColors.button,
                ),
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
                  L10n.tr("Welcome Back"),
                  style: TextStyle(
                    color: AppColors.button,
                    fontFamily: "Super",
                    fontSize: 30,
                    letterSpacing: 5,
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return L10n.tr("Please enter your password");
                              }
                              return null;
                            },
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  L10n.tr("Forgot Password ?"),
                                  style: TextStyle(
                                    color: AppColors.button,
                                    fontFamily: "Nunito",
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          AccButton(
                            sign: L10n.tr("Sign In"),
                            warnaBox: AppColors.button,
                            destination: const SizedBox(),
                            textbuttoncolor: Colors.white,
                            onPressed: _handleLogin,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    thickness: 2,
                                    color: AppColors.background,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    L10n.tr("or continue with"),
                                    style: TextStyle(
                                      color: AppColors.background,
                                      fontFamily: "Nunito",
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    thickness: 2,
                                    color: AppColors.background,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              AccButton(
                                warnaBox: AppColors.background,
                                destination: const SizedBox(),
                                textbuttoncolor: AppColors.button,
                                leadImage: AppImage.icongoogle,
                                sign: L10n.tr("sign in with google"),
                                onPressed: _handleGoogleSignIn,
                              ),
                            ],
                          ),

                          SizedBox(height: 20),

                          Text.rich(
                            TextSpan(
                              text: L10n.tr("New here ?"),
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
                                              const RegisterPage(),
                                        ),
                                      );
                                    },
                                  style: const TextStyle(color: Colors.blue),
                                  text: " ${L10n.tr("Create an account")}",
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
}
