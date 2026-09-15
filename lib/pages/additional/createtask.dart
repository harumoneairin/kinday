import 'dart:convert';

import 'package:cool_dropdown/cool_dropdown.dart';
import 'package:cool_dropdown/models/cool_dropdown_item.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:kinday/widgets/speech_mic_button.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CreateTaskPage extends StatefulWidget {
  final String? initialTitle;
  final List<Map<String, dynamic>>? initialSubtasks;

  const CreateTaskPage({
    super.key,
    this.initialTitle,
    this.initialSubtasks,
  });

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final energylvlController = DropdownController();
  final titleController = NonSelectingTextEditingController();
  final descController = NonSelectingTextEditingController();
  List<Map<String, dynamic>> subtasks = [];

  String? selectedDropdown = "Mid priority";
  int _taskScheduleMode = 0; // 0 = Single Task, 1 = Repeated Task
  DateTime? selectedStartDate = DateTime.now();
  DateTime? selectedDate = DateTime.now();
  TimeOfDay? selectedTime;
  int? selectedReminderMinutes;
  int selectedIndex = 0;
  String selectedEnergy = "low";
  RepeatType _repeatType = RepeatType.none;
  List<int> _selectedWeekDays = [];
  DateTime? _finishDate;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListeningTitle = false;
  bool _isListeningDesc = false;
  bool _isRestoring = false;
  bool _isLoadingAI = false;

  @override
  void initState() {
    super.initState();
    titleController.addListener(_autosaveDraft);
    descController.addListener(_autosaveDraft);
    if (widget.initialTitle != null || widget.initialSubtasks != null) {
      _isRestoring = true;
      if (widget.initialTitle != null) {
        titleController.text = widget.initialTitle!;
      }
      if (widget.initialSubtasks != null) {
        subtasks = List.from(widget.initialSubtasks!);
      }
      _isRestoring = false;
      _autosaveDraft();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndRestoreDraft();
      });
    }
  }

  Future<void> _autosaveDraft() async {
    if (_isRestoring) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_task_title', titleController.text);
      await prefs.setString('draft_task_desc', descController.text);
      await prefs.setString(
        'draft_task_priority',
        selectedDropdown ?? "Mid priority",
      );
      await prefs.setString('draft_task_energy', selectedEnergy);
      await prefs.setString('draft_task_subtasks', jsonEncode(subtasks));
      await prefs.setInt('draft_task_schedule_mode', _taskScheduleMode);
      await prefs.setString('draft_task_repeat_type', _repeatType.name);
      await prefs.setString(
        'draft_task_selected_weekdays',
        jsonEncode(_selectedWeekDays),
      );

      if (selectedStartDate != null) {
        await prefs.setString(
          'draft_task_start_date',
          selectedStartDate!.toIso8601String(),
        );
      } else {
        await prefs.remove('draft_task_start_date');
      }

      if (selectedDate != null) {
        await prefs.setString(
          'draft_task_due_date',
          selectedDate!.toIso8601String(),
        );
      } else {
        await prefs.remove('draft_task_due_date');
      }

      if (_finishDate != null) {
        await prefs.setString(
          'draft_task_finish_date',
          _finishDate!.toIso8601String(),
        );
      } else {
        await prefs.remove('draft_task_finish_date');
      }

      if (selectedTime != null) {
        await prefs.setString(
          'draft_task_due_time',
          '${selectedTime!.hour}:${selectedTime!.minute}',
        );
      } else {
        await prefs.remove('draft_task_due_time');
      }

      if (selectedReminderMinutes != null) {
        await prefs.setInt('draft_task_reminder', selectedReminderMinutes!);
      } else {
        await prefs.remove('draft_task_reminder');
      }
    } catch (e) {
      debugPrint("Error autosaving draft: $e");
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_task_title');
      await prefs.remove('draft_task_desc');
      await prefs.remove('draft_task_priority');
      await prefs.remove('draft_task_schedule_mode');
      await prefs.remove('draft_task_start_date');
      await prefs.remove('draft_task_due_date');
      await prefs.remove('draft_task_finish_date');
      await prefs.remove('draft_task_due_time');
      await prefs.remove('draft_task_reminder');
      await prefs.remove('draft_task_energy');
      await prefs.remove('draft_task_subtasks');
      await prefs.remove('draft_task_repeat_type');
      await prefs.remove('draft_task_selected_weekdays');
    } catch (e) {
      debugPrint("Error clearing draft: $e");
    }
  }

  Future<void> _checkAndRestoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftTitle = prefs.getString('draft_task_title');
      final draftDesc = prefs.getString('draft_task_desc');

      if ((draftTitle != null && draftTitle.isNotEmpty) ||
          (draftDesc != null && draftDesc.isNotEmpty)) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                L10n.tr("Restore Draft?"),
                style: TextStyle(
                  fontFamily: "Quicksand",
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                ),
              ),
              content: Text(
                L10n.tr("You have an unsaved task draft. Would you like to restore it?"),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _clearDraft();
                    Navigator.pop(context);
                  },
                  child: Text(
                    L10n.tr("Discard"),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _restoreDraftValues(prefs);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    L10n.tr("Restore"),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Error checking draft: $e");
    }
  }

  void _restoreDraftValues(SharedPreferences prefs) {
    setState(() {
      _isRestoring = true;
      titleController.text = prefs.getString('draft_task_title') ?? "";
      descController.text = prefs.getString('draft_task_desc') ?? "";
      selectedDropdown =
          prefs.getString('draft_task_priority') ?? "Mid priority";
      selectedEnergy = prefs.getString('draft_task_energy') ?? "low";

      final String? subtasksJson = prefs.getString('draft_task_subtasks');
      if (subtasksJson != null && subtasksJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(subtasksJson);
          subtasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (e) {
          debugPrint("Error restoring subtasks: $e");
        }
      }

      final String? repeatTypeName = prefs.getString('draft_task_repeat_type');
      if (repeatTypeName != null) {
        _repeatType = RepeatType.values.firstWhere(
          (e) => e.name == repeatTypeName,
          orElse: () => RepeatType.none,
        );
      } else {
        _repeatType = RepeatType.none;
      }

      _taskScheduleMode = prefs.getInt('draft_task_schedule_mode') ?? (_repeatType != RepeatType.none ? 1 : 0);

      final String? startDateStr = prefs.getString('draft_task_start_date');
      if (startDateStr != null) {
        selectedStartDate = DateTime.parse(startDateStr);
      } else {
        selectedStartDate = DateTime.now();
      }

      final String? weekDaysJson = prefs.getString(
        'draft_task_selected_weekdays',
      );
      if (weekDaysJson != null && weekDaysJson.isNotEmpty) {
        try {
          final List decoded = jsonDecode(weekDaysJson);
          _selectedWeekDays = decoded.cast<int>();
        } catch (e) {
          debugPrint("Error restoring weekdays: $e");
        }
      } else {
        _selectedWeekDays = [];
      }

      final String? finishDateStr = prefs.getString('draft_task_finish_date');
      if (finishDateStr != null) {
        _finishDate = DateTime.parse(finishDateStr);
      } else {
        _finishDate = null;
      }

      final String? dueDateStr = prefs.getString('draft_task_due_date');
      if (dueDateStr != null) {
        selectedDate = DateTime.parse(dueDateStr);
      } else {
        selectedDate = DateTime.now();
      }

      final String? dueTimeStr = prefs.getString('draft_task_due_time');
      if (dueTimeStr != null) {
        final parts = dueTimeStr.split(':');
        if (parts.length == 2) {
          selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } else {
        selectedTime = null;
      }

      selectedReminderMinutes = prefs.getInt('draft_task_reminder');
      _isRestoring = false;
    });
  }

  void _listenForField(TextEditingController controller, bool isTitle) async {
    final messenger = ScaffoldMessenger.of(context);

    if (isTitle ? _isListeningTitle : _isListeningDesc) {
      await _speech.stop();
      setState(() {
        if (isTitle) {
          _isListeningTitle = false;
        } else {
          _isListeningDesc = false;
        }
      });
      return;
    }

    if (isTitle && _isListeningDesc) {
      await _speech.stop();
      setState(() {
        _isListeningDesc = false;
      });
    } else if (!isTitle && _isListeningTitle) {
      await _speech.stop();
      setState(() {
        _isListeningTitle = false;
      });
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT status: $status');
        if (status == 'done' || status == 'notListening') {
          if (!mounted) return;
          setState(() {
            if (isTitle) {
              _isListeningTitle = false;
            } else {
              _isListeningDesc = false;
            }
          });
        }
      },
      onError: (error) {
        debugPrint('STT error: $error');
        if (!mounted) return;
        setState(() {
          if (isTitle) {
            _isListeningTitle = false;
          } else {
            _isListeningDesc = false;
          }
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Speech recognition error: ${error.errorMsg}"),
            ),
          ),
        );
      },
    );

    if (available) {
      setState(() {
        if (isTitle) {
          _isListeningTitle = true;
        } else {
          _isListeningDesc = true;
        }
      });

      String baseText = controller.text;
      if (baseText.isNotEmpty && !baseText.endsWith(' ')) {
        baseText += ' ';
      }

      String localeId;
      switch (L10n.lang) {
        case 'id':
          localeId = 'id_ID';
          break;
        case 'ja':
          localeId = 'ja_JP';
          break;
        default:
          localeId = 'en_US';
      }

      _speech.listen(
        listenOptions: stt.SpeechListenOptions(localeId: localeId),
        onResult: (val) {
          setState(() {
            if (val.recognizedWords.isNotEmpty) {
              controller.text = baseText + val.recognizedWords;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
          });
        },
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Speech recognition is not available or permission denied",
          ),
        ),
      );
    }
  }

  void _sortSubtasks(String criteria) {
    setState(() {
      if (criteria == 'A-Z') {
        subtasks.sort(
          (a, b) => (a['title'] as String).toLowerCase().compareTo(
            (b['title'] as String).toLowerCase(),
          ),
        );
      } else if (criteria == 'Z-A') {
        subtasks.sort(
          (a, b) => (b['title'] as String).toLowerCase().compareTo(
            (a['title'] as String).toLowerCase(),
          ),
        );
      } else if (criteria == 'Incomplete first') {
        subtasks.sort((a, b) {
          final aDone = a['isDone'] ?? false;
          final bDone = b['isDone'] ?? false;
          if (aDone == bDone) return 0;
          return aDone ? 1 : -1;
        });
      } else if (criteria == 'Completed first') {
        subtasks.sort((a, b) {
          final aDone = a['isDone'] ?? false;
          final bDone = b['isDone'] ?? false;
          if (aDone == bDone) return 0;
          return aDone ? -1 : 1;
        });
      }
    });
    _autosaveDraft();
  }

  Future<void> _breakDownTaskWithAI() async {
    final taskTitle = titleController.text.trim();
    if (taskTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.tr("Please write what you want to do today first!"),
          ),
        ),
      );
      return;
    }

    if (!PreferenceHandler.isPremium && !PreferenceHandler.checkAndIncrementAiUsage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.tr("Your daily AI limit of ${PreferenceHandler.maxAiUsagePerDay} breakdowns has been reached! Try again tomorrow."),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoadingAI = true;
    });

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.1-flash-lite',
      );

      final prompt =
          'Break down the task: "$taskTitle" into 3 to 5 brief, actionable subtasks. '
          'Output a JSON list of strings only. Example: ["Subtask 1", "Subtask 2"]. Do not include markdown code block formatting.';

      final response = await model.generateContent([Content.text(prompt)]);

      if (response.text != null) {
        String cleanJson = response.text!.trim();
        // Remove markdown formatting if present
        if (cleanJson.startsWith("```")) {
          final match = RegExp(
            r'^```(?:json)?\s*(.*?)\s*```$',
            dotAll: true,
          ).firstMatch(cleanJson);
          if (match != null && match.groupCount >= 1) {
            cleanJson = match.group(1)!.trim();
          } else {
            if (cleanJson.startsWith("```json")) {
              cleanJson = cleanJson.substring(7);
            } else if (cleanJson.startsWith("```")) {
              cleanJson = cleanJson.substring(3);
            }
            if (cleanJson.endsWith("```")) {
              cleanJson = cleanJson.substring(0, cleanJson.length - 3);
            }
            cleanJson = cleanJson.trim();
          }
        }

        final List decodedList = jsonDecode(cleanJson);
        final List<String> aiSubtasks = decodedList
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();

        if (aiSubtasks.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  L10n.tr("AI could not generate subtasks. Try a more descriptive task."),
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          await _showAISubtasksDialog(aiSubtasks);
        }
      }
    } catch (e) {
      debugPrint("AI error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("Failed to break down task: $e"),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAI = false;
        });
      }
    }
  }

  Future<void> _showAISubtasksDialog(List<String> aiSubtasks) async {
    final isDark = AppColors.background2 == Colors.black87;
    // Track which subtasks are selected (all selected by default)
    final List<bool> selected = List.filled(aiSubtasks.length, true);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedCount = selected.where((s) => s).length;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF1E1E2E)
                  : Colors.white,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.button.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: AppColors.button,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr("AI Subtasks"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : AppColors.button,
                          ),
                        ),
                        Text(
                          L10n.tr("$selectedCount of ${aiSubtasks.length} selected"),
                          style: TextStyle(
                            fontFamily: "Nunito",
                            fontSize: 12,
                            color: (isDark ? Colors.white : AppColors.button)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      color: AppColors.button.withValues(alpha: 0.1),
                      thickness: 1,
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(aiSubtasks.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setDialogState(() {
                                selected[index] = !selected[index];
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: selected[index]
                                    ? AppColors.button.withValues(alpha: 0.08)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.grey.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected[index]
                                      ? AppColors.button.withValues(alpha: 0.3)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      selected[index]
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      key: ValueKey(selected[index]),
                                      color: selected[index]
                                          ? AppColors.button
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.grey),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      aiSubtasks[index],
                                      style: TextStyle(
                                        fontFamily: "Nunito",
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.button,
                                        decoration: selected[index]
                                            ? null
                                            : TextDecoration.lineThrough,
                                        decorationColor: isDark
                                            ? Colors.white38
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.button.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          L10n.tr("Cancel"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : AppColors.button,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCount == 0
                            ? null
                            : () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.button,
                          disabledBackgroundColor:
                              AppColors.button.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          L10n.tr("Add ($selectedCount)"),
                          style: const TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        for (int i = 0; i < aiSubtasks.length; i++) {
          if (selected[i]) {
            subtasks.add({"title": aiSubtasks[i], "isDone": false});
          }
        }
      });
      _autosaveDraft();

      if (mounted) {
        final addedCount = selected.where((s) => s).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              L10n.tr("$addedCount subtask(s) added successfully!"),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    titleController.removeListener(_autosaveDraft);
    descController.removeListener(_autosaveDraft);
    titleController.dispose();
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.background2 == Colors.black87;
    final cardDecoration = BoxDecoration(
      color: isDark
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.button.withValues(alpha: 0.12), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    );

    return Scaffold(
      body: BgContainer(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 50, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.button,
                        size: 22,
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Text(
                            L10n.tr("Create New Task"),
                            style: AppTextStyles.greeting,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            L10n.tr("Tiny progress is still progress"),
                            style: AppTextStyles.affirmation,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(AppImage.mascotlogin, height: 90),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20.0,
                  left: 20,
                  right: 20,
                ),
                child: Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_border,
                            size: 22,
                            color: AppColors.button,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              L10n.tr("What do you want to do today?"),
                              style: TextStyle(
                                fontFamily: "Quicksand",
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.button,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        maxLines: 2,
                        onTap: () {
                          if (!titleController.selection.isCollapsed &&
                              titleController.selection.isValid) {
                            titleController.selection = TextSelection.collapsed(
                              offset: titleController.selection.extentOffset.clamp(
                                0,
                                titleController.text.length,
                              ),
                            );
                          }
                        },
                        style: TextStyle(
                          color: AppColors.button,
                          fontFamily: "Nunito",
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: L10n.tr("eg. Study for Exam"),
                          hintStyle: TextStyle(
                            color: AppColors.button.withValues(alpha: 0.5),
                            fontFamily: "Nunito",
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.button.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.button,
                              width: 2.0,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.7),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: SpeechMicButton(
                              isListening: _isListeningTitle,
                              onTap: () =>
                                  _listenForField(titleController, true),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 22,
                            color: AppColors.button,
                          ),
                          const SizedBox(width: 10),
                           Text(
                            L10n.tr("Description (Optional)"),
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.button,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descController,
                        maxLines: 3,
                        onTap: () {
                          if (!descController.selection.isCollapsed &&
                              descController.selection.isValid) {
                            descController.selection = TextSelection.collapsed(
                              offset: descController.selection.extentOffset.clamp(
                                0,
                                descController.text.length,
                              ),
                            );
                          }
                        },
                        style: TextStyle(
                          color: AppColors.button,
                          fontFamily: "Nunito",
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: L10n.tr("Add details about this task..."),
                          hintStyle: TextStyle(
                            color: AppColors.button.withValues(alpha: 0.5),
                            fontFamily: "Nunito",
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.button.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.button,
                              width: 2.0,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.7),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: SpeechMicButton(
                              isListening: _isListeningDesc,
                              onTap: () =>
                                  _listenForField(descController, false),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(
                        child: _isLoadingAI
                            ? SizedBox(
                                height: 36,
                                width: 36,
                                child: CircularProgressIndicator(
                                  color: AppColors.button,
                                  strokeWidth: 3,
                                ),
                              )
                            : SmallButton(
                                sign: L10n.tr("Break down task"),
                                warnaBox: AppColors.button,
                                textbuttoncolor: Colors.white,
                                leadImage: AppImage.iconsubtask,
                                onPressed: _breakDownTaskWithAI,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20.0,
                  left: 20,
                  right: 20,
                ),
                child: Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Mode Selector: Single Task vs Repeated Task
                      CustomSlidingSegmentedControl<int>(
                        isStretch: true,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : AppColors.container2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: 1,
                            color: isDark
                                ? AppColors.button.withValues(alpha: 0.15)
                                : AppColors.containerline2,
                          ),
                        ),
                        thumbDecoration: BoxDecoration(
                          color: AppColors.button,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        initialValue: _taskScheduleMode,
                        children: {
                          0: Text(
                            L10n.tr("Single Task"),
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _taskScheduleMode == 0
                                  ? Colors.white
                                  : AppColors.button,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          1: Text(
                            L10n.tr("Repeated Task"),
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _taskScheduleMode == 1
                                  ? Colors.white
                                  : AppColors.button,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        },
                        onValueChanged: (val) {
                          setState(() {
                            _taskScheduleMode = val;
                            if (val == 0) {
                              _repeatType = RepeatType.none;
                              _finishDate = null;
                              _selectedWeekDays = [];
                            } else {
                              if (_repeatType == RepeatType.none) {
                                _repeatType = RepeatType.daily;
                              }
                            }
                          });
                          _autosaveDraft();
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_taskScheduleMode == 0) ...[
                        // --- SINGLE TASK FIELDS ---
                        // 1. Start Date (Default: Today)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 22,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Start Date"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppColors.button,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.button.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartDate ?? DateTime.now(),
                                  firstDate: DateTime(1990),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedStartDate = picked;
                                  });
                                  _autosaveDraft();
                                }
                              },
                              label: Text(
                                selectedStartDate == null
                                    ? L10n.tr("Today")
                                    : "${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year}",
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.button.withValues(alpha: 0.1),
                          ),
                        ),
                        // 2. Due Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Image.asset(
                                    AppImage.iconduedate,
                                    height: 22,
                                    width: 22,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Due Date"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (selectedDate != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedDate = null;
                                        selectedTime = null;
                                        selectedReminderMinutes = null;
                                      });
                                      _autosaveDraft();
                                    },
                                  ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppColors.button,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.button.withValues(alpha: 0.3),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate ?? DateTime.now(),
                                      firstDate: DateTime(1990),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        selectedDate = picked;
                                      });
                                      _autosaveDraft();
                                    }
                                  },
                                  label: Text(
                                    selectedDate == null
                                        ? L10n.tr("Choose Date")
                                        : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (selectedDate != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(
                              thickness: 1,
                              color: AppColors.button.withValues(alpha: 0.1),
                            ),
                          ),
                          // 3. Due Time
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Image.asset(
                                      AppImage.iconduetime,
                                      height: 22,
                                      width: 22,
                                      color: AppColors.button,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        L10n.tr("Due Time (Opt)"),
                                        style: TextStyle(
                                          fontFamily: "Quicksand",
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.button,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  if (selectedTime != null)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          selectedTime = null;
                                        });
                                        _autosaveDraft();
                                      },
                                    ),
                                  OutlinedButton.icon(
                                    icon: Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: AppColors.button,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: AppColors.button.withValues(alpha: 0.3),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final TimeOfDay? picked =
                                          await showTimePicker(
                                            context: context,
                                            initialTime:
                                                selectedTime ?? TimeOfDay.now(),
                                          );
                                      if (picked != null) {
                                        setState(() {
                                          selectedTime = picked;
                                        });
                                        _autosaveDraft();
                                      }
                                    },
                                    label: Text(
                                      selectedTime == null
                                          ? L10n.tr("Choose Time")
                                          : selectedTime!.format(context),
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(
                              thickness: 1,
                              color: AppColors.button.withValues(alpha: 0.1),
                            ),
                          ),
                          // 4. Reminder
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.notifications_active_outlined,
                                      size: 22,
                                      color: AppColors.button,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        L10n.tr("Reminder"),
                                        style: TextStyle(
                                          fontFamily: "Quicksand",
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.button,
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
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.button.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      isExpanded: true,
                                      value: selectedReminderMinutes,
                                      dropdownColor: isDark
                                          ? Colors.grey.shade900
                                          : Colors.white,
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontFamily: "Nunito",
                                        fontWeight: FontWeight.bold,
                                      ),
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: AppColors.button,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                            L10n.tr("No reminder"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 0,
                                          child: Text(
                                            L10n.tr("At due time"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 5,
                                          child: Text(
                                            L10n.tr("5 minutes before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 10,
                                          child: Text(
                                            L10n.tr("10 minutes before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 15,
                                          child: Text(
                                            L10n.tr("15 minutes before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 30,
                                          child: Text(
                                            L10n.tr("30 minutes before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 60,
                                          child: Text(
                                            L10n.tr("1 hour before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 1440,
                                          child: Text(
                                            L10n.tr("1 day before"),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged: (int? value) {
                                        setState(() {
                                          selectedReminderMinutes = value;
                                        });
                                        _autosaveDraft();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        // --- REPEATED TASK FIELDS ---
                        // 1. Repeat Frequency Dropdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    color: AppColors.button,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Repeat"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
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
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.button.withValues(alpha: 0.15),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<RepeatType>(
                                    isExpanded: true,
                                    value: _repeatType == RepeatType.none
                                        ? RepeatType.daily
                                        : _repeatType,
                                    dropdownColor: isDark
                                        ? Colors.grey.shade900
                                        : Colors.white,
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.bold,
                                    ),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.button,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: RepeatType.daily,
                                        child: Text(
                                          L10n.tr("Every Day"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.selectedDays,
                                        child: Text(
                                          L10n.tr("Every Few Days"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.weekly,
                                        child: Text(
                                          L10n.tr("Every Week"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.monthly,
                                        child: Text(
                                          L10n.tr("Every Month"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.yearly,
                                        child: Text(
                                          L10n.tr("Every Year"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    onChanged: (RepeatType? value) {
                                      setState(() {
                                        _repeatType = value ?? RepeatType.daily;
                                      });
                                      _autosaveDraft();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_repeatType == RepeatType.selectedDays) ...[
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children:
                                [
                                  {"label": "Mon", "value": DateTime.monday},
                                  {"label": "Tue", "value": DateTime.tuesday},
                                  {"label": "Wed", "value": DateTime.wednesday},
                                  {"label": "Thu", "value": DateTime.thursday},
                                  {"label": "Fri", "value": DateTime.friday},
                                  {"label": "Sat", "value": DateTime.saturday},
                                  {"label": "Sun", "value": DateTime.sunday},
                                ].map((day) {
                                  final isSelected = _selectedWeekDays.contains(
                                    day["value"],
                                  );
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedWeekDays.remove(day["value"]);
                                        } else {
                                          _selectedWeekDays.add(
                                            day["value"] as int,
                                          );
                                        }
                                      });
                                      _autosaveDraft();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.button
                                            : AppColors.button.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.button
                                              : AppColors.button.withValues(alpha: 0.15),
                                          width: 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        L10n.tr(day["label"] as String),
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.button.withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontFamily: "Quicksand",
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.button.withValues(alpha: 0.1),
                          ),
                        ),
                        // 2. Start Date (Tanggal Mulai)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 22,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Start Date"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              icon: Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: AppColors.button,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.button.withValues(alpha: 0.3),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStartDate ?? DateTime.now(),
                                  firstDate: DateTime(1990),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    selectedStartDate = picked;
                                  });
                                  _autosaveDraft();
                                }
                              },
                              label: Text(
                                selectedStartDate == null
                                    ? L10n.tr("Today")
                                    : "${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year}",
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.button.withValues(alpha: 0.1),
                          ),
                        ),
                        // 3. Time (Jam Pelaksanaan)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Image.asset(
                                    AppImage.iconduetime,
                                    height: 22,
                                    width: 22,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Time (Opt)"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (selectedTime != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedTime = null;
                                      });
                                      _autosaveDraft();
                                    },
                                  ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: AppColors.button,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.button.withValues(alpha: 0.3),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final TimeOfDay? picked =
                                        await showTimePicker(
                                          context: context,
                                          initialTime:
                                              selectedTime ?? TimeOfDay.now(),
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        selectedTime = picked;
                                      });
                                      _autosaveDraft();
                                    }
                                  },
                                  label: Text(
                                    selectedTime == null
                                        ? L10n.tr("Choose Time")
                                        : selectedTime!.format(context),
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.button.withValues(alpha: 0.1),
                          ),
                        ),
                        // 4. Finish Date (Ulang Sampai)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    color: AppColors.button,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Finish Date (opt.)"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                if (_finishDate != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _finishDate = null;
                                      });
                                      _autosaveDraft();
                                    },
                                  ),
                                OutlinedButton.icon(
                                  icon: Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: AppColors.button,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.button.withValues(alpha: 0.3),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _finishDate ?? (selectedStartDate ?? DateTime.now()),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime(2100),
                                        );
                                    if (picked != null) {
                                      setState(() {
                                        _finishDate = picked;
                                      });
                                      _autosaveDraft();
                                    }
                                  },
                                  label: Text(
                                    _finishDate == null
                                        ? L10n.tr("Choose Date")
                                        : "${_finishDate!.day}/${_finishDate!.month}/${_finishDate!.year}",
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(
                            thickness: 1,
                            color: AppColors.button.withValues(alpha: 0.1),
                          ),
                        ),
                        // 5. Reminder
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    size: 22,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      L10n.tr("Reminder"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
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
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.button.withValues(alpha: 0.15),
                                    width: 1.5,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    isExpanded: true,
                                    value: selectedReminderMinutes,
                                    dropdownColor: isDark
                                        ? Colors.grey.shade900
                                        : Colors.white,
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.bold,
                                    ),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.button,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          L10n.tr("No reminder"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 0,
                                        child: Text(
                                          L10n.tr("At task time"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 5,
                                        child: Text(
                                          L10n.tr("5 minutes before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 10,
                                        child: Text(
                                          L10n.tr("10 minutes before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 15,
                                        child: Text(
                                          L10n.tr("15 minutes before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 30,
                                        child: Text(
                                          L10n.tr("30 minutes before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 60,
                                        child: Text(
                                          L10n.tr("1 hour before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 1440,
                                        child: Text(
                                          L10n.tr("1 day before"),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    onChanged: (int? value) {
                                      setState(() {
                                        selectedReminderMinutes = value;
                                      });
                                      _autosaveDraft();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20.0,
                  left: 20,
                  right: 20,
                ),
                child: Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Image.asset(
                                  AppImage.iconpriority,
                                  height: 22,
                                  width: 22,
                                  color: AppColors.button,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    L10n.tr("Priority"),
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppColors.button,
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
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.button.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: selectedDropdown,
                                  dropdownColor: isDark
                                      ? Colors.grey.shade900
                                      : Colors.white,
                                  style: TextStyle(
                                    color: AppColors.button,
                                    fontFamily: "Nunito",
                                    fontWeight: FontWeight.bold,
                                  ),
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.button,
                                  ),
                                  items:
                                      [
                                        "Low priority",
                                        "Mid priority",
                                        "High priority",
                                      ].map((String val) {
                                        String indVal = val;
                                        if (val == "Low priority") indVal = "Prioritas Rendah";
                                        if (val == "Mid priority") indVal = "Prioritas Sedang";
                                        if (val == "High priority") indVal = "Prioritas Tinggi";
                                        return DropdownMenuItem(
                                          value: val,
                                          child: Text(
                                            L10n.tr(val, indVal),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (String? value) {
                                    setState(() {
                                      selectedDropdown = value;
                                    });
                                    _autosaveDraft();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Divider(
                          thickness: 1,
                          color: AppColors.button.withValues(alpha: 0.1),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            AppImage.iconenergylvl,
                            height: 22,
                            width: 22,
                            color: AppColors.button,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  L10n.tr("Energy level required"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.button,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    canvasColor: isDark
                                        ? Colors.grey.shade900
                                        : Colors.white,
                                  ),
                                  child: CoolDropdown(
                                    controller: energylvlController,
                                    dropdownList: energylvl,
                                    defaultItem: energylvl.firstWhere(
                                      (item) => item.value == selectedEnergy,
                                      orElse: () => energylvl.first,
                                    ),
                                    resultOptions: ResultOptions(
                                      width: double.infinity,
                                      height: 50,
                                      render: ResultRender.all,
                                      placeholder: L10n.tr('Select Energy', 'Pilih Energi'),
                                      textStyle: TextStyle(
                                        color: AppColors.button,
                                        fontFamily: "Nunito",
                                        fontWeight: FontWeight.bold,
                                      ),
                                      boxDecoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(
                                                alpha: 0.25,
                                              )
                                            : Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.button.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    dropdownOptions: DropdownOptions(
                                      width: 280,
                                      color: isDark
                                          ? Colors.grey.shade900
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    onChange: (value) {
                                      setState(() {
                                        selectedEnergy = value;
                                      });
                                      _autosaveDraft();
                                    },
                                    dropdownItemOptions: DropdownItemOptions(
                                      render: DropdownItemRender.reverse,
                                      alignment: Alignment.centerLeft,
                                      selectedBoxDecoration: BoxDecoration(
                                        color: AppColors.button.withValues(alpha: 0.1,
                                        ),
                                      ),
                                      textStyle: TextStyle(
                                        color: AppColors.button,
                                        fontFamily: "Nunito",
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 20.0,
                  left: 20,
                  right: 20,
                ),
                child: Container(
                  decoration: cardDecoration,
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                AppImage.iconsubtask,
                                height: 20,
                                width: 20,
                                color: AppColors.button,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                L10n.tr("Subtasks"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.button,
                                ),
                              ),
                              if (subtasks.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.button.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${subtasks.where((s) => s['isDone'] == true).length}/${subtasks.length}",
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.button,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (subtasks.length > 1)
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.sort_rounded,
                                    size: 20,
                                    color: AppColors.button,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: L10n.tr("Sort subtasks"),
                                  onSelected: _sortSubtasks,
                                  color: isDark
                                      ? Colors.grey.shade900
                                      : Colors.white,
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        PopupMenuItem<String>(
                                          value: 'A-Z',
                                          child: Text(
                                            L10n.tr(
                                              'Alphabetical (A-Z)',
                                              'Alfabetis (A-Z)',
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'Z-A',
                                          child: Text(
                                            L10n.tr(
                                              'Alphabetical (Z-A)',
                                              'Alfabetis (Z-A)',
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'Incomplete first',
                                          child: Text(
                                            L10n.tr(
                                              'Incomplete first',
                                              'Belum selesai dahulu',
                                            ),
                                          ),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'Completed first',
                                          child: Text(
                                            L10n.tr(
                                              'Completed first',
                                              'Selesai dahulu',
                                            ),
                                          ),
                                        ),
                                      ],
                                ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                onPressed: _showAddSubtaskDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.button,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 15),
                                label: Text(
                                  L10n.tr("Add"),
                                  style: const TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: subtasks.isEmpty
                            ? const EdgeInsets.symmetric(
                                vertical: 30,
                                horizontal: 16,
                              )
                            : const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 6,
                              ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.35),
                          border: Border.all(
                            color: AppColors.button.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: subtasks.isEmpty
                            ? Column(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 48,
                                    color: AppColors.button.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    L10n.tr("No subtasks yet"),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontFamily: "Quicksand",
                                      color: AppColors.button.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    L10n.tr("Break this task down or keep it simple!"),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: "Nunito",
                                      color: AppColors.button.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                buildDefaultDragHandles: false,
                                itemCount: subtasks.length,
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (oldIndex < newIndex) {
                                      newIndex -= 1;
                                    }
                                    final item = subtasks.removeAt(oldIndex);
                                    subtasks.insert(newIndex, item);
                                  });
                                  _autosaveDraft();
                                },
                                itemBuilder: (context, index) {
                                  final sub = subtasks[index];
                                  final isDone = sub["isDone"] ?? false;
                                  return Container(
                                    key: ValueKey(
                                      (sub["title"] ?? "") + index.toString(),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? (isDone
                                                ? Colors.black.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.25,
                                                  ))
                                          : (isDone
                                                ? Colors.white.withValues(
                                                    alpha: 0.45,
                                                  )
                                                : Colors.white.withValues(
                                                    alpha: 0.9,
                                                  )),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDone
                                            ? AppColors.button.withValues(
                                                alpha: 0.08,
                                              )
                                            : AppColors.button.withValues(
                                                alpha: 0.18,
                                              ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Drag Handle
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8.0,
                                            ),
                                            child: Icon(
                                              Icons.drag_indicator_rounded,
                                              size: 20,
                                              color: AppColors.button
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ),
                                        // Checkbox
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Checkbox(
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            activeColor: AppColors.button,
                                            checkColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            value: isDone,
                                            onChanged: (value) {
                                              setState(() {
                                                sub["isDone"] = value;
                                              });
                                              _autosaveDraft();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Subtask Title - takes ALL available remaining width
                                        Expanded(
                                          child: Text(
                                            sub["title"] ?? "",
                                            style: TextStyle(
                                              color: AppColors.button
                                                  .withValues(
                                                    alpha: isDone ? 0.5 : 1.0,
                                                  ),
                                              fontFamily: "Nunito",
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Action: Edit
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            color: AppColors.button
                                                .withValues(alpha: 0.7),
                                            size: 18,
                                          ),
                                          tooltip: L10n.tr("Edit"),
                                          onPressed: () =>
                                              _showEditSubtaskDialog(index),
                                        ),
                                        const SizedBox(width: 4),
                                        // Action: Delete
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            size: 18,
                                          ),
                                          tooltip: L10n.tr("Delete"),
                                          onPressed: () {
                                            setState(() {
                                              subtasks.removeAt(index);
                                            });
                                            _autosaveDraft();
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  bottom: 50.0,
                  left: 20,
                  right: 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(L10n.tr("Task title cannot be empty")),
                          ),
                        );
                        return;
                      }

                      // Convert string priority to int
                      int priorityVal = 1; // Default low
                      if (selectedDropdown == "Mid priority") {
                        priorityVal = 2;
                      } else if (selectedDropdown == "High priority") {
                        priorityVal = 3;
                      }

                      // Convert string energy to int (1-5)
                      int energyVal = 1; // Default low energy
                      if (selectedEnergy == "low") {
                        energyVal = 1;
                      } else if (selectedEnergy == "midlow") {
                        energyVal = 2;
                      } else if (selectedEnergy == "mid") {
                        energyVal = 3;
                      } else if (selectedEnergy == "midhigh") {
                        energyVal = 4;
                      } else if (selectedEnergy == "high") {
                        energyVal = 5;
                      }

                      final newTask = TaskCard(
                        title: title,
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                        energylvl: energyVal,
                        prioritytask: priorityVal,
                        startDate: selectedStartDate ?? DateTime.now(),
                        dueDate: _taskScheduleMode == 0
                            ? selectedDate
                            : (selectedStartDate ?? DateTime.now()),
                        dueTime: selectedTime?.format(context),
                        subtasks: subtasks,
                        reminderMinutes: selectedReminderMinutes,
                        repeatType: _taskScheduleMode == 0
                            ? RepeatType.none
                            : (_repeatType == RepeatType.none
                                ? RepeatType.daily
                                : _repeatType),
                        selectedWeekDays: _taskScheduleMode == 0
                            ? []
                            : _selectedWeekDays,
                        finishDate: _taskScheduleMode == 0 ? null : _finishDate,
                        createdAt: DateTime.now(),
                      );

                      final navigator = Navigator.of(context);
                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getInt('user_id') ?? 1;

                      final insertedId = await DBHelper().insertTask(
                        newTask,
                        userId,
                      );
                      newTask.id = insertedId;

                      if (selectedReminderMinutes != null) {
                        await NotificationHelper().scheduleTaskNotification(
                          newTask,
                        );
                      }

                      await _clearDraft();

                      navigator.pop(); // Go back to the previous screen
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      elevation: 3,
                      shadowColor: AppColors.button.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    label: Text(
                      L10n.tr("Save Task"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSubtaskDialog() {
    final subtaskcontroller = NonSelectingTextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                L10n.tr("Add Subtask"),
                style: TextStyle(
                  fontFamily: "Quicksand",
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                ),
              ),
              content: TextField(
                controller: subtaskcontroller,
                onTap: () {
                  if (!subtaskcontroller.selection.isCollapsed &&
                      subtaskcontroller.selection.isValid) {
                    subtaskcontroller.selection = TextSelection.collapsed(
                      offset: subtaskcontroller.selection.extentOffset.clamp(
                        0,
                        subtaskcontroller.text.length,
                      ),
                    );
                  }
                },
                style: TextStyle(color: AppColors.button, fontFamily: "Nunito"),
                decoration: InputDecoration(
                  hintText: L10n.tr("Eg. Read Chapter 1"),
                  hintStyle: TextStyle(color: AppColors.button.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.button, width: 2),
                  ),
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    L10n.tr("Done"),
                    style: TextStyle(color: AppColors.button.withValues(alpha: 0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final text = subtaskcontroller.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        subtasks.add({
                          "title": text,
                          "isDone": false,
                        });
                      });
                      _autosaveDraft();
                      subtaskcontroller.clear();
                      setDialogState(() {});
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(L10n.tr("Add"), style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSubtaskDialog(int index) {
    if (index < 0 || index >= subtasks.length) return;
    final sub = subtasks[index];
    final editController = NonSelectingTextEditingController(text: sub["title"]);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            L10n.tr("Edit Subtask"),
            style: TextStyle(
              fontFamily: "Quicksand",
              fontWeight: FontWeight.bold,
              color: AppColors.button,
            ),
          ),
          content: TextField(
            controller: editController,
            onTap: () {
              if (!editController.selection.isCollapsed &&
                  editController.selection.isValid) {
                editController.selection = TextSelection.collapsed(
                  offset: editController.selection.extentOffset.clamp(
                    0,
                    editController.text.length,
                  ),
                );
              }
            },
            style: TextStyle(
              color: AppColors.button,
              fontFamily: "Nunito",
            ),
            decoration: InputDecoration(
              hintText: L10n.tr("Edit subtask title"),
              hintStyle: TextStyle(
                color: AppColors.button.withValues(alpha: 0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.button,
                  width: 2,
                ),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                L10n.tr("Cancel"),
                style: TextStyle(
                  color: AppColors.button.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = editController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    sub["title"] = text;
                  });
                  _autosaveDraft();
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                L10n.tr("Save"),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  final List<CoolDropdownItem<String>> energylvl = [
    CoolDropdownItem<String>(
      icon: Image.asset(AppImage.elvllow, height: 25, width: 25),
      label: L10n.tr('Low Energy', 'Energi Rendah'),
      value: 'low',
    ),
    CoolDropdownItem<String>(
      icon: Image.asset(AppImage.elvlmidlo, height: 25, width: 25),
      label: L10n.tr('Mid-Low Energy', 'Energi Cukup Rendah'),
      value: 'midlow',
    ),
    CoolDropdownItem<String>(
      icon: Image.asset(AppImage.elvlmid, height: 25, width: 25),
      label: L10n.tr('Medium Energy', 'Energi Sedang'),
      value: 'mid',
    ),
    CoolDropdownItem<String>(
      icon: Image.asset(AppImage.elvlmidhi, height: 25, width: 25),
      label: L10n.tr('Mid-High Energy', 'Energi Cukup Tinggi'),
      value: 'midhigh',
    ),
    CoolDropdownItem<String>(
      icon: Image.asset(AppImage.elvlhi, height: 25, width: 25),
      label: L10n.tr('High Energy', 'Energi Tinggi'),
      value: 'high',
    ),
  ];
}
