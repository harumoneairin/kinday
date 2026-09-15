import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/models/user_model_sql.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePassPage extends StatefulWidget {
  const ChangePassPage({super.key});

  @override
  State<ChangePassPage> createState() => _ChangePassPageState();
}

class _ChangePassPageState extends State<ChangePassPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  final _newPasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _newPasswordFocusNode.addListener(_onFocusOrNewPasswordChange);
    _newPasswordController.addListener(_onFocusOrNewPasswordChange);
  }

  void _onFocusOrNewPasswordChange() {
    setState(() {});
  }

  bool _hasLength(String text) => text.length >= 8;
  bool _hasUppercase(String text) => RegExp(r'[A-Z]').hasMatch(text);
  bool _hasLowercase(String text) => RegExp(r'[a-z]').hasMatch(text);
  bool _hasNumber(String text) => RegExp(r'[0-9]').hasMatch(text);
  bool _hasSpecial(String text) =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(text);

  Widget _buildNewPasswordRequirements(String text) {
    if (!_newPasswordFocusNode.hasFocus) {
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
      margin: const EdgeInsets.only(top: 8, bottom: 8),
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
      return L10n.tr("Please enter a new password");
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

  @override
  void dispose() {
    _newPasswordFocusNode.removeListener(_onFocusOrNewPasswordChange);
    _newPasswordFocusNode.dispose();
    _newPasswordController.removeListener(_onFocusOrNewPasswordChange);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');

      if (email == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("User session not found."),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final dbHelper = DBHelper();
      final user = await dbHelper.getUserByEmail(email);

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("User account not found."),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // 1. Change password in Firebase (reauthenticates & updates Auth & Firestore)
      final firebaseSuccess = await FirebaseAuthService().changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (firebaseSuccess) {
        // 2. Sync password change to SQLite
        final updatedUser = UserModelSql(
          id: user.id,
          username: user.username,
          email: user.email,
          password: _newPasswordController.text,
        );

        final success = await dbHelper.updateUser(updatedUser);

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Password updated successfully!"),
                ),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("Failed to sync SQLite password."),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr("Failed to update password in Firebase."),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = e.toString().replaceAll(RegExp(r'\[.*?\]'), '');
      if (e.toString().contains("wrong-password") ||
          e.toString().contains("invalid-credential")) {
        errorMessage = L10n.tr("Incorrect current password.");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("An error occurred: $errorMessage"),
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

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required TextEditingController controller,
    required bool isObscured,
    required VoidCallback onToggleObscure,
    required String? Function(String?) validator,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.button,
            fontFamily: "Nunito",
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Color(0xFF5852A0)),
          obscureText: isObscured,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 0.0),
              child: Icon(prefixIcon, color: AppColors.background),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: AppColors.background,
              ),
              onPressed: onToggleObscure,
            ),
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.background),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.containerline1,
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.button),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          L10n.tr("Change Password"),
          style: TextStyle(
            fontFamily: "Quicksand",
            fontWeight: FontWeight.bold,
            color: AppColors.button,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: BgContainer(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Image.asset(AppImage.mascotlogin, height: 180),
                  const SizedBox(height: 10),
                  Text(
                    L10n.tr("Secure Your Account"),
                    style: TextStyle(
                      color: AppColors.button,
                      fontFamily: "Super",
                      fontSize: 24,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    L10n.tr("Update your password regularly for better security"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Nunito",
                      fontSize: 14,
                      color: AppColors.button,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container1(
                    width: double.infinity,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPasswordField(
                            label: L10n.tr("Current Password"),
                            hint: L10n.tr("Enter current password"),
                            prefixIcon: Icons.lock_open,
                            controller: _currentPasswordController,
                            isObscured: _obscureCurrent,
                            onToggleObscure: () {
                              setState(() {
                                _obscureCurrent = !_obscureCurrent;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return L10n.tr("Please enter your current password");
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            label: L10n.tr("New Password"),
                            hint: L10n.tr("Minimum 8 characters"),
                            prefixIcon: Icons.lock_outline,
                            controller: _newPasswordController,
                            isObscured: _obscureNew,
                            onToggleObscure: () {
                              setState(() {
                                _obscureNew = !_obscureNew;
                              });
                            },
                            validator: _validatePassword,
                            focusNode: _newPasswordFocusNode,
                          ),
                          _buildNewPasswordRequirements(
                            _newPasswordController.text,
                          ),
                          const SizedBox(height: 20),
                          _buildPasswordField(
                            label: L10n.tr("Confirm New Password"),
                            hint: L10n.tr("Retype new password"),
                            prefixIcon: Icons.lock,
                            controller: _confirmPasswordController,
                            isObscured: _obscureConfirm,
                            onToggleObscure: () {
                              setState(() {
                                _obscureConfirm = !_obscureConfirm;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return L10n.tr("Please confirm your new password");
                              }
                              if (value != _newPasswordController.text) {
                                return L10n.tr("Passwords do not match!");
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.button,
                                    ),
                                  ),
                                )
                              : AccButton(
                                  sign: L10n.tr("Update Password"),
                                  warnaBox: AppColors.button,
                                  destination:
                                      const SizedBox(), // Unused since we override onPressed
                                  textbuttoncolor: Colors.white,
                                  onPressed: _changePassword,
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
