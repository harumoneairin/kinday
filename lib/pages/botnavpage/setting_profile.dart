import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/firebase_auth_service.dart';
import 'package:kinday/database/firebase_backup_service.dart';

import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/models/user_model_sql.dart';
import 'package:kinday/pages/additional/about.dart';
import 'package:kinday/pages/additional/changepass.dart';
import 'package:kinday/pages/additional/faq.dart';
import 'package:kinday/pages/additional/theme_preview_sheet.dart';
import 'package:kinday/pages/auth/login.dart';
import 'package:kinday/pages/auth/terms_conditions.dart';
import 'package:kinday/pages/service/google_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingProfile extends StatefulWidget {
  const SettingProfile({super.key});

  @override
  State<SettingProfile> createState() => _SettingProfileState();
}

class _SettingProfileState extends State<SettingProfile> {
  // User info state
  String _name = "User";
  String _email = "user@kinday.com";
  String _avatarKey = "letter";
  String? _avatarPath;

  // Linked accounts state
  bool _isFirebaseLoggedIn = false;
  bool _isGmailLinked = false;
  bool _isEmailLinked = false;
  String _gmailEmail = "";
  String _passwordEmail = "";

  // Google Calendar state
  bool _isGcalConnected = false;
  String? _gcalEmail;

  // Setting states
  bool _notificationsEnabled = true;
  String _currentTheme = "Lavender Dreams";
  String _aiBreakdownLevel = "Balanced";
  String _lastBackupTime = "Never";
  bool _gcalIncludeSubCalendars = false;

  // Statistics states
  int _completedTasksCount = 0;
  int _streakDays = 0;
  int _totalFocusMinutes = 0;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _clickBackupText();
    _loadSettings();
    TaskNotifier.taskUpdated.addListener(_loadSettings);
  }

  @override
  void dispose() {
    TaskNotifier.taskUpdated.removeListener(_loadSettings);
    super.dispose();
  }

  void _clickBackupText() {
    // DIUBAH
  }

  Future<void> _handleBackup() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final success = await FirebaseBackupService().backupData(userId);
    if (success) {
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Successfully backed up!", "Berhasil di backup!"),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Backup failed! Make sure you are logged in to Firebase.",
                "Gagal mencadangkan! Pastikan Anda masuk ke Firebase.",
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final success = await FirebaseBackupService().restoreData(userId);
    if (success) {
      await _loadSettings();
      TaskNotifier.taskUpdated.value = !TaskNotifier.taskUpdated.value;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Successfully restored!", "Berhasil di restore!"),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Restore failed! No backup found or not logged in.",
                "Gagal memulihkan! Pencadangan tidak ditemukan atau belum masuk.",
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  String _getAvatarAssetPath(String key) {
    switch (key) {
      case 'login':
        return AppImage.mascotlogin;
      case 'task':
        return AppImage.mascottask;
      case 'focus':
        return AppImage.mascotfocus;
      case 'star':
        return AppImage.mascotstar;
      default:
        return "";
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;

      final dbTasks = await DBHelper().getTasksForUser(userId);
      final completedCount = dbTasks.where((t) => t.isCompleted).length;

      // Calculate streak
      final creationDays = dbTasks.map((t) => t.createdAt).toList();
      final streak = _calculateStreak(creationDays);

      // Get focus time
      final totalFocus = await DBHelper().getTotalFocusMinutesForUser(userId);

      final lastBackupStr = prefs.getString('last_backup_time');
      String lastBackupTimeStr = "Never";
      if (lastBackupStr != null) {
        try {
          final dt = DateTime.parse(lastBackupStr);
          lastBackupTimeStr =
              "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        } catch (_) {}
      }

      // Firebase Auth linking status
      final currentUser = FirebaseAuthService().currentUser;
      final isFirebaseLoggedIn = currentUser != null;
      final isGmailLinked = currentUser != null &&
          currentUser.providerData.any((p) => p.providerId == 'google.com');
      final isEmailLinked = currentUser != null &&
          currentUser.providerData.any((p) => p.providerId == 'password');

      String gmailEmail = "";
      String passwordEmail = "";
      if (currentUser != null) {
        for (final p in currentUser.providerData) {
          if (p.providerId == 'google.com') {
            gmailEmail = p.email ?? "";
          } else if (p.providerId == 'password') {
            passwordEmail = p.email ?? "";
          }
        }
      }

      // Check Google Calendar connection
      final gcalConnected = await GoogleCalendarService().isConnected();
      final gcalEmail = GoogleCalendarService().userEmail;
      final gcalIncludeSub =
          await GoogleCalendarService().isIncludeSubCalendarsEnabled();

      if (!mounted) return;
      setState(() {
        _name = prefs.getString('user_name') ?? "User";
        _email = prefs.getString('user_email') ?? "user@kinday.com";
        _avatarKey = prefs.getString('user_avatar') ?? "letter";
        _avatarPath = prefs.getString('user_avatar_path');

        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _currentTheme = prefs.getString('app_theme') ?? "Lavender Dreams";
        _aiBreakdownLevel = prefs.getString('ai_breakdown_level') ?? "Balanced";

        _completedTasksCount = completedCount;
        _streakDays = streak;
        _totalFocusMinutes = totalFocus;
        _lastBackupTime = lastBackupTimeStr;

        _isFirebaseLoggedIn = isFirebaseLoggedIn;
        _isGmailLinked = isGmailLinked;
        _isEmailLinked = isEmailLinked;
        _gmailEmail = gmailEmail;
        _passwordEmail = passwordEmail;

        _isGcalConnected = gcalConnected;
        _gcalEmail = gcalEmail;
        _gcalIncludeSubCalendars = gcalIncludeSub;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleGcal() async {
    setState(() {
      _isLoading = true;
    });
    if (_isGcalConnected) {
      await GoogleCalendarService().disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Google Calendar disconnected", "Google Calendar terputus"),
            ),
          ),
        );
      }
    } else {
      final error = await GoogleCalendarService().connect();
      if (mounted) {
        if (error == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr(
                  "Google Calendar connected successfully!",
                  "Google Calendar berhasil terhubung!",
                ),
              ),
              backgroundColor: AppColors.button,
            ),
          );
        } else if (error != "cancelled") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${L10n.tr("Failed to connect Google Calendar", "Gagal menghubungkan Google Calendar")}: $error",
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
    await _loadSettings();
    TaskNotifier.notify();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateStreak(List<DateTime> creationDays) {
    if (creationDays.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final uniqueDays = creationDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    if (!uniqueDays.contains(today) && !uniqueDays.contains(yesterday)) {
      return 0;
    }

    DateTime checkDay = uniqueDays.contains(today) ? today : yesterday;
    int streak = 0;

    while (uniqueDays.contains(checkDay)) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    }

    return streak;
  }

  String _formatFocusTime(int totalMinutes) {
    if (totalMinutes < 60) {
      return "$totalMinutes min";
    } else {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      if (mins == 0) {
        return "${hours}h";
      }
      return "${hours}h ${mins}m";
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (e) {
      debugPrint("Error saving setting: $e");
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _name);
    final emailController = TextEditingController(text: _email);
    String dialogAvatarKey = _avatarKey;
    String? dialogAvatarPath = _avatarPath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildAvatarOption(String key, Widget child) {
              final isSelected = dialogAvatarKey == key;
              return GestureDetector(
                onTap: () {
                  setDialogState(() {
                    dialogAvatarKey = key;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.button : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.background.withValues(
                      alpha: 0.2,
                    ),
                    child: child,
                  ),
                ),
              );
            }

            Widget buildCustomAvatarOption() {
              final isSelected = dialogAvatarKey == 'custom';
              final hasImage =
                  dialogAvatarPath != null && dialogAvatarPath!.isNotEmpty;

              return GestureDetector(
                onTap: () async {
                  try {
                    final ImageSource? source = await showModalBottomSheet<ImageSource>(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (BuildContext context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                child: Text(
                                  L10n.tr("Select Image Source", "Pilih Sumber Gambar"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.button,
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(Icons.camera_alt_rounded, color: AppColors.button),
                                title: Text(
                                  L10n.tr("Take Photo", "Ambil Foto"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.button,
                                  ),
                                ),
                                onTap: () => Navigator.pop(context, ImageSource.camera),
                              ),
                              ListTile(
                                leading: Icon(Icons.photo_library_rounded, color: AppColors.button),
                                title: Text(
                                  L10n.tr("Choose from Gallery", "Pilih dari Galeri"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.button,
                                  ),
                                ),
                                onTap: () => Navigator.pop(context, ImageSource.gallery),
                              ),
                            ],
                          ),
                        );
                      },
                    );

                    if (source == null) return;

                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: source,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() {
                        dialogAvatarPath = image.path;
                        dialogAvatarKey = 'custom';
                      });
                    } else if (hasImage) {
                      setDialogState(() {
                        dialogAvatarKey = 'custom';
                      });
                    }
                  } catch (e) {
                    debugPrint("Error picking image: $e");
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.button : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.background.withValues(
                      alpha: 0.2,
                    ),
                    backgroundImage: hasImage
                        ? FileImage(File(dialogAvatarPath!))
                        : null,
                    child: !hasImage
                        ? Icon(
                            Icons.add_photo_alternate_outlined,
                            color: AppColors.button,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                L10n.tr("Edit Profile", "Ubah Profil"),
                style: TextStyle(
                  fontFamily: "Quicksand",
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: L10n.tr("Name", "Nama"),
                        labelStyle: TextStyle(color: AppColors.button),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.background),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: TextStyle(color: AppColors.button),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.background),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      L10n.tr("Choose Avatar", "Pilih Avatar"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.button,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        buildAvatarOption(
                          'letter',
                          Text(
                            nameController.text.isNotEmpty
                                ? nameController.text[0].toUpperCase()
                                : "U",
                            style: TextStyle(
                              color: AppColors.button,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        buildAvatarOption(
                          'login',
                          ClipOval(
                            child: Image.asset(
                              AppImage.mascotlogin,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                        buildAvatarOption(
                          'task',
                          ClipOval(
                            child: Image.asset(
                              AppImage.mascottask,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                        buildAvatarOption(
                          'focus',
                          ClipOval(
                            child: Image.asset(
                              AppImage.mascotfocus,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                        buildAvatarOption(
                          'star',
                          ClipOval(
                            child: Image.asset(
                              AppImage.mascotstar,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            ),
                          ),
                        ),
                        buildCustomAvatarOption(),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    L10n.tr("Cancel", "Batal"),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final email = emailController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            L10n.tr(
                              "Name cannot be empty.",
                              "Nama tidak boleh kosong.",
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    if (email.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            L10n.tr(
                              "Email cannot be empty.",
                              "Email tidak boleh kosong.",
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                    if (!emailRegex.hasMatch(email)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            L10n.tr(
                              "Please enter a valid email.",
                              "Silakan masukkan email yang valid.",
                            ),
                          ),
                        ),
                      );
                      return;
                    }

                    final dbHelper = DBHelper();
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getInt('user_id') ?? 1;

                    // Unique email check
                    final isTaken = await dbHelper.isEmailRegistered(
                      email,
                      excludeUserId: userId,
                    );
                    if (isTaken) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L10n.tr(
                                "Email is already taken by another account.",
                                "Email sudah digunakan oleh akun lain.",
                              ),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }

                    // Retrieve current password to update profile
                    final user = await dbHelper.getUserById(userId);
                    final password = user?.password ?? "";

                    final updatedUser = UserModelSql(
                      id: userId,
                      username: name,
                      email: email,
                      password: password,
                    );

                    final success = await dbHelper.updateUser(updatedUser);

                    if (success) {
                      await prefs.setString('user_name', name);
                      await prefs.setString('user_email', email);
                      await prefs.setString('user_avatar', dialogAvatarKey);
                      if (dialogAvatarPath != null) {
                        await prefs.setString(
                          'user_avatar_path',
                          dialogAvatarPath!,
                        );
                      } else {
                        await prefs.remove('user_avatar_path');
                      }

                      setState(() {
                        _name = name;
                        _email = email;
                        _avatarKey = dialogAvatarKey;
                        _avatarPath = dialogAvatarPath;
                      });

                      // Trigger updates across tabs
                      TaskNotifier.notify();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L10n.tr(
                                "Profile updated successfully!",
                                "Profil berhasil diperbarui!",
                              ),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L10n.tr(
                                "Failed to update profile.",
                                "Gagal memperbarui profil.",
                              ),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    L10n.tr("Save", "Simpan"),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Log Out",
            style: TextStyle(
              fontFamily: "Quicksand",
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          content: const Text("Are you sure you want to log out from Kinday?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                await PreferenceHandler.logOut();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Logged out successfully!")),
                  );
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Log Out",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    final controller = TextEditingController();
    bool isDeleteEnabled = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                L10n.tr("Delete Account?", "Hapus Akun?"),
                style: const TextStyle(
                  fontFamily: "Quicksand",
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.tr(
                      "This action is permanent and cannot be undone. To confirm, please type \"DELETE\" below:",
                      "Tindakan ini permanen dan tidak dapat dibatalkan. Untuk mengonfirmasi, silakan ketik \"DELETE\" di bawah:",
                    ),
                    style: const TextStyle(fontFamily: "Nunito"),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: "DELETE",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        isDeleteEnabled = val == "DELETE";
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    L10n.tr("Cancel", "Batal"),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleteEnabled
                      ? () async {
                          Navigator.pop(context);
                          await _handleDeleteAccount();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    L10n.tr("Delete Permanently", "Hapus Permanen"),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteAccount() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;
      final firebaseUid = prefs.getString('user_id_firebase');

      // 1. Delete from Firebase
      if (firebaseUid != null) {
        final authService = FirebaseAuthService();
        await authService.deleteUser(firebaseUid);
      }

      // 2. Delete from SQLite
      final dbHelper = DBHelper();
      await dbHelper.deleteUser(userId);

      // 3. Clear preferences & log out
      await PreferenceHandler.logOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Account deleted successfully.",
                "Akun berhasil dihapus.",
              ),
            ),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]'), '');
        if (e.toString().contains("requires-recent-login")) {
          errorMsg = L10n.tr(
            "This action is sensitive and requires recent authentication. Please log out, log back in, and try again.",
            "Tindakan ini sensitif dan memerlukan autentikasi baru. Silakan keluar, masuk kembali, dan coba lagi.",
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Delete failed: $errorMsg", "Gagal menghapus: $errorMsg"),
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

  Future<void> _handleBindGmail() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = FirebaseAuthService();
      final credential = await authService.linkGoogle();
      if (credential != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr(
                  "Google account successfully linked!",
                  "Akun Google berhasil dihubungkan!",
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]'), '');
        if (e.toString().contains("credential-already-in-use") || 
            e.toString().contains("email-already-in-use")) {
          errorMsg = L10n.tr(
            "This Google account is already linked to another Kinday account.",
            "Akun Google ini sudah terhubung dengan akun Kinday lain.",
          );
        } else if (e.toString().contains("provider-already-linked")) {
          errorMsg = L10n.tr(
            "This account is already linked.",
            "Akun ini sudah terhubung.",
          );
        } else if (e.toString().contains("requires-recent-login")) {
          errorMsg = L10n.tr(
            "This action is sensitive and requires recent authentication. Please log out, log back in, and try again.",
            "Tindakan ini sensitif dan memerlukan autentikasi baru. Silakan keluar, masuk kembali, dan coba lagi.",
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Failed to link Google: $errorMsg",
                "Gagal menghubungkan Google: $errorMsg",
              ),
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

  Future<void> _handleBindEmail(String email, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = FirebaseAuthService();
      final credential = await authService.linkEmail(email, password);
      
      if (credential != null) {
        // Also update local SQLite database user to sync this email and password
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id') ?? 1;
        
        final dbHelper = DBHelper();
        final localUser = await dbHelper.getUserById(userId);
        
        if (localUser != null) {
          final updatedUser = UserModelSql(
            id: userId,
            username: localUser.username,
            email: email,
            password: password,
          );
          await dbHelper.updateUser(updatedUser);
        }
        
        await prefs.setString('user_email', email);
        
        setState(() {
          _email = email;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                L10n.tr(
                  "Email successfully linked!",
                  "Email berhasil dihubungkan!",
                ),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]'), '');
        if (e.toString().contains("credential-already-in-use") || 
            e.toString().contains("email-already-in-use")) {
          errorMsg = L10n.tr(
            "This email is already in use by another Kinday account.",
            "Email ini sudah digunakan oleh akun Kinday lain.",
          );
        } else if (e.toString().contains("provider-already-linked")) {
          errorMsg = L10n.tr(
            "This account is already linked.",
            "Akun ini sudah terhubung.",
          );
        } else if (e.toString().contains("requires-recent-login")) {
          errorMsg = L10n.tr(
            "This action is sensitive and requires recent authentication. Please log out, log back in, and try again.",
            "Tindakan ini sensitif dan memerlukan autentikasi baru. Silakan keluar, masuk kembali, dan coba lagi.",
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Failed to link Email: $errorMsg",
                "Gagal menghubungkan Email: $errorMsg",
              ),
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

  Future<void> _handleUnbindProvider(String providerId) async {
    final currentUser = FirebaseAuthService().currentUser;
    if (currentUser == null) return;

    if (currentUser.providerData.length <= 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            L10n.tr("Cannot Disconnect", "Tidak Dapat Memutuskan"),
            style: TextStyle(
              fontFamily: "Quicksand",
              fontWeight: FontWeight.bold,
              color: AppColors.button,
            ),
          ),
          content: Text(
            L10n.tr(
              "You cannot disconnect this account because it is your only way to log in. Please connect another method first.",
              "Anda tidak dapat memutuskan akun ini karena ini adalah satu-satunya metode login Anda. Harap hubungkan metode lain terlebih dahulu.",
            ),
            style: const TextStyle(fontFamily: "Nunito"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                L10n.tr("OK", "OK"),
                style: TextStyle(color: AppColors.button),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          L10n.tr("Disconnect Account", "Putuskan Hubungan Akun"),
          style: TextStyle(
            fontFamily: "Quicksand",
            fontWeight: FontWeight.bold,
            color: AppColors.button,
          ),
        ),
        content: Text(
          providerId == 'google.com'
              ? L10n.tr(
                  "Are you sure you want to disconnect your Google account?",
                  "Apakah Anda yakin ingin memutuskan hubungan akun Google Anda?",
                )
              : L10n.tr(
                  "Are you sure you want to disconnect your Email/Password?",
                  "Apakah Anda yakin ingin memutuskan hubungan Email/Password Anda?",
                ),
          style: const TextStyle(fontFamily: "Nunito"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              L10n.tr("Cancel", "Batal"),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              L10n.tr("Disconnect", "Putuskan"),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = FirebaseAuthService();
      await authService.unlinkProvider(providerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Account disconnected successfully!",
                "Hubungan akun berhasil diputuskan!",
              ),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll(RegExp(r'\[.*?\]'), '');
        if (e.toString().contains("requires-recent-login")) {
          errorMsg = L10n.tr(
            "This action is sensitive and requires recent authentication. Please log out, log back in, and try again.",
            "Tindakan ini sensitif dan memerlukan autentikasi baru. Silakan keluar, masuk kembali, dan coba lagi.",
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr(
                "Failed to disconnect: $errorMsg",
                "Gagal memutuskan hubungan: $errorMsg",
              ),
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

  Future<void> _showBindEmailDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureText = true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                L10n.tr("Bind Email Account", "Hubungkan Akun Email"),
                style: TextStyle(
                  fontFamily: "Quicksand",
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        L10n.tr(
                          "Link an email and password to log in using this method in the future.",
                          "Hubungkan email dan kata sandi untuk masuk menggunakan metode ini di masa mendatang.",
                        ),
                        style: const TextStyle(
                          fontFamily: "Nunito",
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.button),
                          labelText: L10n.tr("Email Address", "Alamat Email"),
                          labelStyle: TextStyle(color: AppColors.button),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.button),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.button.withValues(alpha: 0.3)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return L10n.tr("Please enter email", "Harap masukkan email");
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                            return L10n.tr("Invalid email format", "Format email tidak valid");
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscureText,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, color: AppColors.button),
                          labelText: L10n.tr("Password", "Kata Sandi"),
                          labelStyle: TextStyle(color: AppColors.button),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureText ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.button,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                obscureText = !obscureText;
                              });
                            },
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.button),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.button.withValues(alpha: 0.3)),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return L10n.tr("Please enter password", "Harap masukkan kata sandi");
                          }
                          if (val.length < 6) {
                            return L10n.tr("Password must be at least 6 characters", "Kata sandi minimal 6 karakter");
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    L10n.tr("Cancel", "Batal"),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      await _handleBindEmail(emailController.text.trim(), passwordController.text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    L10n.tr("Connect", "Hubungkan"),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: "Quicksand",
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: AppColors.button,
          ),
        ),
      ),
    );
  }

  void _showThemePreview(String newTheme) {
    final previousTheme = _currentTheme;
    AppColors.themeNotifier.value = newTheme;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ThemePreviewSheet(
          themeName: newTheme,
          previousTheme: previousTheme,
          userName: _name,
          onCancel: () {
            AppColors.themeNotifier.value = previousTheme;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.button)),
      );
    }

    return Scaffold(
      body: BgContainer(
        child: Column(
          children: [
            // Fixed Header Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        L10n.tr("Settings & Profile", "Pengaturan & Profil"),
                        style: AppTextStyles.greeting,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -5),
                        child: Text(
                          L10n.tr(
                            "Customize your Kinday experience",
                            "Sesuaikan pengalaman Kinday-mu",
                          ),
                          style: AppTextStyles.affirmation,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showLogoutDialog,
                    icon: Icon(
                      Icons.logout_rounded,
                      color: AppColors.button,
                      size: 24,
                    ),
                    tooltip: L10n.tr("Log Out", "Keluar"),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Profile Info Header Card
                    Container1(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: AppColors.button,
                                    backgroundImage:
                                        _avatarKey == 'custom' &&
                                            _avatarPath != null &&
                                            _avatarPath!.isNotEmpty
                                        ? FileImage(File(_avatarPath!))
                                        : (_avatarKey != 'letter' &&
                                                  _avatarKey.isNotEmpty
                                              ? AssetImage(
                                                  _getAvatarAssetPath(
                                                    _avatarKey,
                                                  ),
                                                )
                                              : null),
                                    child:
                                        (_avatarKey == 'letter' ||
                                            _avatarKey.isEmpty)
                                        ? Text(
                                            _name.isNotEmpty
                                                ? _name[0].toUpperCase()
                                                : "U",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: "Quicksand",
                                            ),
                                          )
                                        : null,
                                  ),
                                  GestureDetector(
                                    onTap: _showEditProfileDialog,
                                    child: CircleAvatar(
                                      radius: 13,
                                      backgroundColor: Colors.white,
                                      child: Icon(
                                        Icons.edit_rounded,
                                        size: 14,
                                        color: AppColors.button,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _name,
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.button,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _email,
                                      style: TextStyle(
                                        fontFamily: "Nunito",
                                        fontSize: 14,
                                        color: AppColors.button.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _showEditProfileDialog,
                                icon: Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.button,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Divider(height: 1),
                          ),
                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                "$_completedTasksCount",
                                L10n.tr("Completed", "Selesai"),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.background.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              _buildStatItem(
                                L10n.tr(
                                  "$_streakDays Days",
                                  "$_streakDays Hari",
                                ),
                                L10n.tr("Streak", "Beruntun"),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: AppColors.background.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                              _buildStatItem(
                                _formatFocusTime(_totalFocusMinutes),
                                L10n.tr("Focus Time", "Waktu Fokus"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(
                      L10n.tr("App Preferences", "Preferensi Aplikasi"),
                    ),

                    // Preferences Container (Container 3: Leaning pink/purple)
                    Container3(
                      width: double.infinity,
                      child: Column(
                        children: [
                          // Notifications Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_active_rounded,
                                      color: AppColors.button,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        L10n.tr(
                                          "Enable Notifications",
                                          "Aktifkan Notifikasi",
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.button,
                                          fontFamily: "Quicksand",
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _notificationsEnabled,
                                activeThumbColor: AppColors.button,
                                activeTrackColor: AppColors.button.withValues(
                                  alpha: 0.5,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _notificationsEnabled = val;
                                  });
                                  _saveSetting('notifications_enabled', val);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: AppColors.containerline1.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Theme Selector Dropdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.palette_rounded,
                                      color: AppColors.button,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        L10n.tr("App Theme", "Tema Aplikasi"),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.button,
                                          fontFamily: "Quicksand",
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.containerline1
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _currentTheme,
                                      dropdownColor: Colors.white,
                                      iconEnabledColor: AppColors.button,
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "Quicksand",
                                        fontSize: 13,
                                      ),
                                      items: const [
                                        "Lavender Dreams",
                                        "Sakura Bloom",
                                        "Matcha Garden",
                                        "Sky Blue",
                                        "Peach Cream",
                                        "Moonlight Lavender",
                                        "Twilight Blue",
                                        "Midnight Forest",
                                      ].map((String name) {
                                        String emoji = "";
                                        switch (name) {
                                          case "Lavender Dreams":
                                            emoji = "💜";
                                            break;
                                          case "Sakura Bloom":
                                            emoji = "🌸";
                                            break;
                                          case "Matcha Garden":
                                            emoji = "🌿";
                                            break;
                                          case "Sky Blue":
                                            emoji = "☁️";
                                            break;
                                          case "Peach Cream":
                                            emoji = "🍑";
                                            break;
                                          case "Moonlight Lavender":
                                            emoji = "🌙";
                                            break;
                                          case "Twilight Blue":
                                            emoji = "🌌";
                                            break;
                                          case "Midnight Forest":
                                            emoji = "🌲";
                                            break;
                                        }

                                        final isUnlocked = PreferenceHandler.unlockedThemes.contains(name);

                                        return DropdownMenuItem<String>(
                                          value: name,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "$emoji $name",
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (!isUnlocked)
                                                const Icon(Icons.lock_rounded, size: 14, color: Colors.grey),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          if (!PreferenceHandler.unlockedThemes.contains(value)) {
                                            _showThemePreview(value);
                                          } else {
                                            setState(() {
                                              _currentTheme = value;
                                            });
                                            AppColors.setTheme(value);
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: AppColors.containerline1.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // AI Breakdown Detail
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.psychology_rounded,
                                      color: AppColors.button,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        L10n.tr(
                                          "AI Breakdown Level",
                                          "Tingkat Detail AI",
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.button,
                                          fontFamily: "Quicksand",
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.containerline1
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _aiBreakdownLevel,
                                      dropdownColor: Colors.white,
                                      iconEnabledColor: AppColors.button,
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "Quicksand",
                                        fontSize: 13,
                                      ),
                                      items:
                                          const [
                                                "Simple",
                                                "Balanced",
                                                "Detailed",
                                              ]
                                              .map(
                                                (val) => DropdownMenuItem(
                                                  value: val,
                                                  child: Text(
                                                    val,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _aiBreakdownLevel = value;
                                          });
                                          _saveSetting(
                                            'ai_breakdown_level',
                                            value,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: AppColors.containerline1.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // App Language selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.language_rounded,
                                      color: AppColors.button,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        L10n.tr(
                                          "App Language",
                                          "Bahasa Aplikasi",
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.button,
                                          fontFamily: "Quicksand",
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.containerline1
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: L10n.lang == "en"
                                          ? "English"
                                          : L10n.lang == "id"
                                          ? "Bahasa Indonesia"
                                          : "Japanese",
                                      dropdownColor: Colors.white,
                                      iconEnabledColor: AppColors.button,
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: "Quicksand",
                                        fontSize: 13,
                                      ),
                                      items:
                                          const [
                                                "English",
                                                "Bahasa Indonesia",
                                                "Japanese",
                                              ]
                                              .map(
                                                (val) => DropdownMenuItem(
                                                  value: val,
                                                  child: Text(
                                                    val,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            L10n.setLanguage(
                                              value == "English"
                                                  ? "en"
                                                  : value == "Bahasa Indonesia"
                                                  ? "id"
                                                  : "ja",
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(
                      L10n.tr("Google Calendar Awareness", "Integrasi Google Calendar"),
                    ),

                    Container1(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_note_rounded,
                                  color: Color(0xFF4285F4),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Google Calendar & Tasks",
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _isGcalConnected
                                          ? (_gcalEmail != null && _gcalEmail!.isNotEmpty
                                              ? "${L10n.tr("Connected as", "Terhubung sebagai")} $_gcalEmail"
                                              : L10n.tr("Connected (Read-Only)", "Terhubung (Hanya Baca)"))
                                          : L10n.tr(
                                              "Sync your schedule & to-do tasks gently",
                                              "Sinkronkan agenda & tugas Google dengan tenang",
                                            ),
                                      style: TextStyle(
                                        fontFamily: "Nunito",
                                        fontSize: 12,
                                        color: AppColors.normaltext.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _handleToggleGcal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isGcalConnected
                                      ? Colors.red.shade400
                                      : const Color(0xFF4285F4),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  _isGcalConnected
                                      ? L10n.tr("Disconnect", "Putuskan")
                                      : L10n.tr("Connect", "Hubungkan"),
                                  style: const TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isGcalConnected) ...[
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              thickness: 0.8,
                              color: AppColors.normaltext.withValues(alpha: 0.12),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.library_books_rounded,
                                  size: 18,
                                  color: AppColors.button.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        L10n.tr(
                                          "Sync Sub & Shared Calendars",
                                          "Sinkronkan Kalender Bersama",
                                        ),
                                        style: TextStyle(
                                          fontFamily: "Quicksand",
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.button,
                                        ),
                                      ),
                                      Text(
                                        L10n.tr(
                                          "Include events from sub-calendars & shared calendars",
                                          "Sertakan agenda dari sub-kalender & kalender bersama",
                                        ),
                                        style: TextStyle(
                                          fontFamily: "Nunito",
                                          fontSize: 11,
                                          color: AppColors.normaltext.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _gcalIncludeSubCalendars,
                                  activeTrackColor: AppColors.button,
                                  onChanged: (val) async {
                                    setState(() {
                                      _gcalIncludeSubCalendars = val;
                                    });
                                    await GoogleCalendarService()
                                        .setIncludeSubCalendars(val);
                                    TaskNotifier.notify();
                                  },
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    _buildSectionHeader(
                      L10n.tr("Account & Info", "Akun & Info"),
                    ),

                    // Info Container (Container 1: White/Grey card style)
                    Container1(
                      width: double.infinity,
                      child: Column(
                        children: [
                          _buildListTile(
                            icon: Icons.lock_outline_rounded,
                            title: L10n.tr(
                              "Change Password",
                              "Ubah Kata Sandi",
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChangePassPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            icon: Icons.help_outline_rounded,
                            title: L10n.tr("Help & FAQ", "Bantuan & FAQ"),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FaqPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            icon: Icons.info_outline_rounded,
                            title: L10n.tr("About Kinday", "Tentang Kinday"),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AboutPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            icon: Icons.description_outlined,
                            title: L10n.tr("Terms & Conditions", "Syarat & Ketentuan"),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TermsConditionsPage(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            icon: Icons.bug_report_outlined,
                            title: L10n.tr("Report a Bug", "Laporkan Bug"),
                            onTap: () async {
                              final Uri url = Uri.parse('https://forms.gle/PWU1nEtCS4vM53aCA');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        L10n.tr("Could not launch link", "Tidak dapat membuka tautan"),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(
                      L10n.tr("Linked Accounts", "Akun Terhubung"),
                    ),

                    Container1(
                      width: double.infinity,
                      child: Column(
                        children: [
                          _buildLinkedAccountTile(
                            providerName: "Gmail (Google)",
                            isLinked: _isGmailLinked,
                            linkedEmail: _gmailEmail,
                            onBind: _handleBindGmail,
                            onUnbind: () => _handleUnbindProvider('google.com'),
                            icon: Icons.mail_outline_rounded,
                          ),
                          const Divider(height: 1),
                          _buildLinkedAccountTile(
                            providerName: "Email",
                            isLinked: _isEmailLinked,
                            linkedEmail: _passwordEmail,
                            onBind: _showBindEmailDialog,
                            onUnbind: () => _handleUnbindProvider('password'),
                            icon: Icons.alternate_email_rounded,
                          ),
                        ],
                      ),
                    ),

                    _buildSectionHeader(
                      L10n.tr(
                        "Data Backup & Restore",
                        "Cadangkan & Pulihkan Data",
                      ),
                    ),

                    // Data Backup & Restore Container
                    Container2(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.backup_rounded,
                                color: AppColors.button,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                L10n.tr("Last Backup", "Pencadangan Terakhir"),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _lastBackupTime,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: AppColors.containerline2.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleBackup,
                                  icon: const Icon(
                                    Icons.cloud_upload_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: Text(
                                    L10n.tr("Backup", "Cadangkan"),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.button,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _handleRestore,
                                  icon: Icon(
                                    Icons.cloud_download_rounded,
                                    color: AppColors.button,
                                    size: 16,
                                  ),
                                  label: Text(
                                    L10n.tr("Restore", "Pulihkan"),
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppColors.button),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Delete Account Button Section
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showDeleteAccountDialog,
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            color: Colors.redAccent,
                          ),
                          label: Text(
                            L10n.tr("Delete Account", "Hapus Akun"),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: "Quicksand",
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: "Quicksand",
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.button,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: "Nunito",
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.button),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: "Quicksand",
          fontWeight: FontWeight.bold,
          color: AppColors.button,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.button),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }

  Widget _buildLinkedAccountTile({
    required String providerName,
    required bool isLinked,
    required String linkedEmail,
    required VoidCallback onBind,
    required VoidCallback onUnbind,
    required IconData icon,
  }) {
    final bool canInteract = _isFirebaseLoggedIn;
    
    return ListTile(
      leading: Icon(
        icon,
        color: canInteract 
            ? AppColors.button 
            : AppColors.button.withValues(alpha: 0.4),
      ),
      title: Text(
        providerName,
        style: TextStyle(
          fontFamily: "Quicksand",
          fontWeight: FontWeight.bold,
          color: canInteract 
              ? AppColors.button 
              : AppColors.button.withValues(alpha: 0.4),
        ),
      ),
      subtitle: Text(
        !_isFirebaseLoggedIn
            ? L10n.tr("Cloud account not active", "Akun Cloud tidak aktif")
            : isLinked
                ? (linkedEmail.isNotEmpty ? linkedEmail : L10n.tr("Connected", "Terhubung"))
                : L10n.tr("Not Connected", "Belum Terhubung"),
        style: TextStyle(
          fontFamily: "Nunito",
          color: !_isFirebaseLoggedIn
              ? Colors.grey
              : isLinked
                  ? Colors.green
                  : Colors.grey,
          fontSize: 12,
        ),
      ),
      trailing: ElevatedButton(
        onPressed: canInteract 
            ? (isLinked ? onUnbind : onBind) 
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      L10n.tr(
                        "Please log in with a cloud account first.",
                        "Silakan masuk dengan akun cloud terlebih dahulu.",
                      ),
                    ),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: canInteract 
              ? (isLinked 
                  ? Colors.red.shade50 
                  : AppColors.button.withValues(alpha: 0.1))
              : Colors.grey.shade100,
          foregroundColor: canInteract 
              ? (isLinked ? Colors.red : AppColors.button)
              : Colors.grey,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          isLinked
              ? L10n.tr("Disconnect", "Putuskan")
              : L10n.tr("Connect", "Hubungkan"),
          style: const TextStyle(
            fontFamily: "Quicksand",
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

