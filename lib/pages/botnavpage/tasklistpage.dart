import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:kinday/pages/service/repeat_task_service.dart';
import 'package:kinday/widgets/speech_mic_button.dart';
import 'package:kinday/widgets/task_list_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class Tasklistpage extends StatefulWidget {
  const Tasklistpage({super.key});

  @override
  State<Tasklistpage> createState() => _TasklistpageState();
}

class _TasklistpageState extends State<Tasklistpage> {
  int selectedTab = 1;
  late List<TaskCard> _tasks;
  int _currentEnergyLvl = 3;
  bool _isListView = false;
  bool _isEisenhowerMode = false;

  @override
  void initState() {
    super.initState();
    _tasks = [];
    _loadTasks();
    TaskNotifier.taskUpdated.addListener(_loadTasks);
  }

  @override
  void dispose() {
    TaskNotifier.taskUpdated.removeListener(_loadTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final isListView = prefs.getBool('is_task_list_view_mode') ?? false;
    final isEisenhower = prefs.getBool('is_eisenhower_matrix_mode') ?? false;

    // Check and reset repeatable tasks for new day
    await RepeatTaskService.checkAndResetDailyRepeatTasks(userId);
    final dbTasks = await DBHelper().getTasksForUser(userId);

    final latestEnergy = await DBHelper().getLatestEnergyForUser(userId);
    if (!mounted) return;
    setState(() {
      _tasks = dbTasks;
      _isListView = isListView;
      _isEisenhowerMode = isEisenhower;
      if (latestEnergy != null) {
        _currentEnergyLvl = latestEnergy;
      }
    });
  }

  Future<void> _toggleTaskComplete(TaskCard task, bool? isCompleted) async {
    task.isCompleted = isCompleted ?? false;
    await DBHelper().updateTask(task);
    await _loadTasks();
    TaskNotifier.notify();
  }

  void _showEditTaskBottomSheet(TaskCard task) {
    final titleController = NonSelectingTextEditingController(text: task.title);
    final descController = NonSelectingTextEditingController(text: task.description ?? "");
    int tempPriority = task.prioritytask;
    int tempEnergyLvl = task.energylvl;
    int tempScheduleMode = task.repeatType == RepeatType.none ? 0 : 1;
    DateTime? tempStartDate = task.startDate ?? task.dueDate ?? task.createdAt;
    DateTime? tempDueDate = task.dueDate;
    int? tempReminderMinutes = task.reminderMinutes;
    bool tempIsCompleted = task.isCompleted;
    final List<Map<String, dynamic>> tempSubtasks = List.from(
      task.subtasks.map((e) => Map<String, dynamic>.from(e)),
    );
    final newSubtaskController = NonSelectingTextEditingController();
    RepeatType tempRepeatType = task.repeatType;
    List<int> tempSelectedWeekDays = List.from(task.selectedWeekDays);
    DateTime? tempFinishDate = task.finishDate;

    final stt.SpeechToText speech = stt.SpeechToText();
    bool isListeningTitle = false;
    bool isListeningDesc = false;

    void listenForField(
      TextEditingController controller,
      bool isTitle,
      StateSetter setModalState,
    ) async {
      final messenger = ScaffoldMessenger.of(context);

      if (isTitle ? isListeningTitle : isListeningDesc) {
        await speech.stop();
        setModalState(() {
          if (isTitle) {
            isListeningTitle = false;
          } else {
            isListeningDesc = false;
          }
        });
        return;
      }

      if (isTitle && isListeningDesc) {
        await speech.stop();
        setModalState(() {
          isListeningDesc = false;
        });
      } else if (!isTitle && isListeningTitle) {
        await speech.stop();
        setModalState(() {
          isListeningTitle = false;
        });
      }

      bool available = await speech.initialize(
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (status == 'done' || status == 'notListening') {
            setModalState(() {
              if (isTitle) {
                isListeningTitle = false;
              } else {
                isListeningDesc = false;
              }
            });
          }
        },
        onError: (error) {
          debugPrint('STT error: $error');
          setModalState(() {
            if (isTitle) {
              isListeningTitle = false;
            } else {
              isListeningDesc = false;
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
        setModalState(() {
          if (isTitle) {
            isListeningTitle = true;
          } else {
            isListeningDesc = true;
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

        speech.listen(
          listenOptions: stt.SpeechListenOptions(localeId: localeId),
          onResult: (val) {
            setModalState(() {
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
          SnackBar(
            content: Text(
              L10n.tr("Speech recognition is not available or permission denied"),
            ),
          ),
        );
      }
    }

    TimeOfDay? parseTimeOfDay(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return null;
      try {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hourPart = parts[0].trim();
          final minutePart = parts[1].trim();
          int hour = int.parse(hourPart.replaceAll(RegExp(r'\D'), ''));
          int minute = int.parse(minutePart.replaceAll(RegExp(r'\D'), ''));
          if (timeStr.toLowerCase().contains('pm') && hour < 12) {
            hour += 12;
          } else if (timeStr.toLowerCase().contains('am') && hour == 12) {
            hour = 0;
          }
          return TimeOfDay(hour: hour, minute: minute);
        }
      } catch (e) {
        debugPrint("Error parsing TimeOfDay: $e");
      }
      return null;
    }

    TimeOfDay? tempDueTime = parseTimeOfDay(task.dueTime);

    Widget buildPriorityChip({
      required String label,
      required Color color,
      required bool isSelected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag_rounded,
                size: 13,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: "Quicksand",
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildDateTimeTile({
      required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap,
      VoidCallback? onClear,
    }) {
      return Row(
        children: [
          Icon(icon, size: 16, color: AppColors.button),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: "Nunito",
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.button,
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.redAccent, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onClear,
            ),
          if (onClear != null) const SizedBox(width: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: "Nunito",
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pull handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header Row (Title & Delete Button)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                color: AppColors.button,
                                size: 26,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                L10n.tr("Edit Task Details"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 22,
                            ),
                            tooltip: L10n.tr("Delete Task"),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: Text(
                                      L10n.tr("Delete Task"),
                                      style: const TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    content: Text(
                                      L10n.tr("Are you sure you want to delete this task?"),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          L10n.tr("Cancel"),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          L10n.tr("Delete"),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirm == true) {
                                if (task.id != null) {
                                  await NotificationHelper()
                                      .cancelTaskNotification(task.id!);
                                  await DBHelper().deleteTask(task.id!);
                                }
                                await _loadTasks();
                                TaskNotifier.notify();
                                titleController.dispose();
                                descController.dispose();
                                newSubtaskController.dispose();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Card 1: Task Information (Title & Description)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: titleController,
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
                              style: const TextStyle(
                                color: Color(0xFF5852A0),
                                fontFamily: "Nunito",
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: L10n.tr("Task Title"),
                                labelStyle: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.button,
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: SpeechMicButton(
                                  isListening: isListeningTitle,
                                  onTap: () => listenForField(
                                    titleController,
                                    true,
                                    setModalState,
                                  ),
                                ),
                              ),
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
                              style: const TextStyle(
                                color: Color(0xFF5852A0),
                                fontFamily: "Nunito",
                              ),
                              decoration: InputDecoration(
                                labelText: L10n.tr("Description"),
                                labelStyle: TextStyle(
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: AppColors.button,
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: SpeechMicButton(
                                  isListening: isListeningDesc,
                                  onTap: () => listenForField(
                                    descController,
                                    false,
                                    setModalState,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card 2: Schedule & Timing
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: AppColors.button,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  L10n.tr("Schedule & Timing"),
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
                            // Mode Selector: Single Task vs Repeated Task
                            CustomSlidingSegmentedControl<int>(
                              isStretch: true,
                              decoration: BoxDecoration(
                                color: AppColors.container2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  width: 1,
                                  color: AppColors.containerline2,
                                ),
                              ),
                              thumbDecoration: BoxDecoration(
                                color: AppColors.button,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              initialValue: tempScheduleMode,
                              children: {
                                0: Text(
                                  L10n.tr("Single Task"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: tempScheduleMode == 0
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
                                    color: tempScheduleMode == 1
                                        ? Colors.white
                                        : AppColors.button,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              },
                              onValueChanged: (val) {
                                setModalState(() {
                                  tempScheduleMode = val;
                                  if (val == 0) {
                                    tempRepeatType = RepeatType.none;
                                    tempFinishDate = null;
                                    tempSelectedWeekDays = [];
                                  } else {
                                    if (tempRepeatType == RepeatType.none) {
                                      tempRepeatType = RepeatType.daily;
                                    }
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            if (tempScheduleMode == 0) ...[
                              // --- SINGLE TASK FIELDS ---
                              buildDateTimeTile(
                                icon: Icons.calendar_today_rounded,
                                label: L10n.tr("Start Date"),
                                value: tempStartDate == null
                                    ? L10n.tr("Today")
                                    : "${tempStartDate!.day}/${tempStartDate!.month}/${tempStartDate!.year}",
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempStartDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      tempStartDate = picked;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              buildDateTimeTile(
                                icon: Icons.event_available_rounded,
                                label: L10n.tr("Due Date"),
                                value: tempDueDate == null
                                    ? L10n.tr("Choose Date")
                                    : "${tempDueDate!.day}/${tempDueDate!.month}/${tempDueDate!.year}",
                                onClear: tempDueDate != null
                                    ? () {
                                        setModalState(() {
                                          tempDueDate = null;
                                          tempDueTime = null;
                                          tempReminderMinutes = null;
                                        });
                                      }
                                    : null,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempDueDate ?? (tempStartDate ?? DateTime.now()),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      tempDueDate = picked;
                                    });
                                  }
                                },
                              ),
                              if (tempDueDate != null) ...[
                                const SizedBox(height: 10),
                                buildDateTimeTile(
                                  icon: Icons.access_time_rounded,
                                  label: L10n.tr("Time"),
                                  value: tempDueTime == null
                                      ? L10n.tr("Choose Time")
                                      : tempDueTime!.format(context),
                                  onClear: tempDueTime != null
                                      ? () {
                                          setModalState(() {
                                            tempDueTime = null;
                                          });
                                        }
                                      : null,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: tempDueTime ?? TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        tempDueTime = picked;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.notifications_active_rounded,
                                          size: 16,
                                          color: AppColors.button,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          L10n.tr("Reminder"),
                                          style: TextStyle(
                                            fontFamily: "Nunito",
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.button,
                                          ),
                                        ),
                                      ],
                                    ),
                                    DropdownButton<int?>(
                                      value: tempReminderMinutes,
                                      dropdownColor: Colors.white,
                                      style: TextStyle(
                                        color: AppColors.button,
                                        fontFamily: "Nunito",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(L10n.tr("None")),
                                        ),
                                        DropdownMenuItem(
                                          value: 0,
                                          child: Text(L10n.tr("At due time")),
                                        ),
                                        DropdownMenuItem(
                                          value: 5,
                                          child: Text(L10n.tr("5 minutes before")),
                                        ),
                                        DropdownMenuItem(
                                          value: 10,
                                          child: Text(L10n.tr("10 minutes before")),
                                        ),
                                        DropdownMenuItem(
                                          value: 15,
                                          child: Text(L10n.tr("15 minutes before")),
                                        ),
                                        DropdownMenuItem(
                                          value: 30,
                                          child: Text(L10n.tr("30 minutes before")),
                                        ),
                                        DropdownMenuItem(
                                          value: 60,
                                          child: Text(L10n.tr("1 hour before")),
                                        ),
                                        DropdownMenuItem(
                                          value: 1440,
                                          child: Text(L10n.tr("1 day before")),
                                        ),
                                      ],
                                      onChanged: (int? value) {
                                        setModalState(() {
                                          tempReminderMinutes = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ] else ...[
                              // --- REPEATED TASK FIELDS ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.repeat_rounded,
                                        size: 16,
                                        color: AppColors.button,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        L10n.tr("Repeat"),
                                        style: TextStyle(
                                          fontFamily: "Nunito",
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.button,
                                        ),
                                      ),
                                    ],
                                  ),
                                  DropdownButton<RepeatType>(
                                    value: tempRepeatType == RepeatType.none
                                        ? RepeatType.daily
                                        : tempRepeatType,
                                    dropdownColor: Colors.white,
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: RepeatType.daily,
                                        child: Text(L10n.tr("Every Day")),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.selectedDays,
                                        child: Text(
                                          L10n.tr("Every Few Days"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.weekly,
                                        child: Text(L10n.tr("Every Week")),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.monthly,
                                        child: Text(L10n.tr("Every Month")),
                                      ),
                                      DropdownMenuItem(
                                        value: RepeatType.yearly,
                                        child: Text(L10n.tr("Every Year")),
                                      ),
                                    ],
                                    onChanged: (RepeatType? value) {
                                      setModalState(() {
                                        tempRepeatType = value ?? RepeatType.daily;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              if (tempRepeatType == RepeatType.selectedDays) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    {"label": "Mon", "value": DateTime.monday},
                                    {"label": "Tue", "value": DateTime.tuesday},
                                    {"label": "Wed", "value": DateTime.wednesday},
                                    {"label": "Thu", "value": DateTime.thursday},
                                    {"label": "Fri", "value": DateTime.friday},
                                    {"label": "Sat", "value": DateTime.saturday},
                                    {"label": "Sun", "value": DateTime.sunday},
                                  ].map((day) {
                                    final isSelected = tempSelectedWeekDays
                                        .contains(day["value"]);
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected) {
                                            tempSelectedWeekDays.remove(
                                              day["value"],
                                            );
                                          } else {
                                            tempSelectedWeekDays.add(
                                              day["value"] as int,
                                            );
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.button
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.button
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          L10n.tr(day["label"] as String),
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: "Quicksand",
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 10),
                              buildDateTimeTile(
                                icon: Icons.calendar_today_rounded,
                                label: L10n.tr("Start Date"),
                                value: tempStartDate == null
                                    ? L10n.tr("Today")
                                    : "${tempStartDate!.day}/${tempStartDate!.month}/${tempStartDate!.year}",
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempStartDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      tempStartDate = picked;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              buildDateTimeTile(
                                icon: Icons.access_time_rounded,
                                label: L10n.tr("Time"),
                                value: tempDueTime == null
                                    ? L10n.tr("Choose Time")
                                    : tempDueTime!.format(context),
                                onClear: tempDueTime != null
                                    ? () {
                                        setModalState(() {
                                          tempDueTime = null;
                                        });
                                      }
                                    : null,
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: tempDueTime ?? TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      tempDueTime = picked;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              buildDateTimeTile(
                                icon: Icons.event_busy_rounded,
                                label: L10n.tr("Finish Date"),
                                value: tempFinishDate == null
                                    ? L10n.tr("Choose Date")
                                    : "${tempFinishDate!.day}/${tempFinishDate!.month}/${tempFinishDate!.year}",
                                onClear: tempFinishDate != null
                                    ? () {
                                        setModalState(() {
                                          tempFinishDate = null;
                                        });
                                      }
                                    : null,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tempFinishDate ??
                                        (tempStartDate ?? DateTime.now()),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      tempFinishDate = picked;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.notifications_active_rounded,
                                        size: 16,
                                        color: AppColors.button,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        L10n.tr("Reminder"),
                                        style: TextStyle(
                                          fontFamily: "Nunito",
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.button,
                                        ),
                                      ),
                                    ],
                                  ),
                                  DropdownButton<int?>(
                                    value: tempReminderMinutes,
                                    dropdownColor: Colors.white,
                                    style: TextStyle(
                                      color: AppColors.button,
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(L10n.tr("None")),
                                      ),
                                      DropdownMenuItem(
                                        value: 0,
                                        child: Text(
                                          L10n.tr("At task time"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 5,
                                        child: Text(
                                          L10n.tr("5 minutes before"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 10,
                                        child: Text(
                                          L10n.tr("10 minutes before"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 15,
                                        child: Text(
                                          L10n.tr("15 minutes before"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 30,
                                        child: Text(
                                          L10n.tr("30 minutes before"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 60,
                                        child: Text(
                                          L10n.tr("1 hour before"),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 1440,
                                        child: Text(
                                          L10n.tr("1 day before"),
                                        ),
                                      ),
                                    ],
                                    onChanged: (int? value) {
                                      setModalState(() {
                                        tempReminderMinutes = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card 3: Priority & Energy Level
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.flag_rounded,
                                      size: 18,
                                      color: AppColors.button,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      L10n.tr("Priority"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    buildPriorityChip(
                                      label: L10n.tr("Low"),
                                      color: Colors.green,
                                      isSelected: tempPriority == 1,
                                      onTap: () => setModalState(() => tempPriority = 1),
                                    ),
                                    const SizedBox(width: 6),
                                    buildPriorityChip(
                                      label: L10n.tr("Mid"),
                                      color: Colors.orange,
                                      isSelected: tempPriority == 2,
                                      onTap: () => setModalState(() => tempPriority = 2),
                                    ),
                                    const SizedBox(width: 6),
                                    buildPriorityChip(
                                      label: L10n.tr("High"),
                                      color: Colors.red,
                                      isSelected: tempPriority == 3,
                                      onTap: () => setModalState(() => tempPriority = 3),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            // Energy Level
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 20,
                                      color: AppColors.button,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      L10n.tr("Energy Level"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.button,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.button.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.button.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    "${L10n.tr('Level', 'Level')} $tempEnergyLvl • ${_getEnergyLabel(tempEnergyLvl)}",
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.button,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Responsive 5-segment energy level rating
                            Row(
                              children: List.generate(5, (index) {
                                final lvl = index + 1;
                                final isSelected = tempEnergyLvl == lvl;
                                final isFilled = tempEnergyLvl >= lvl;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          tempEnergyLvl = lvl;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.button
                                              : isFilled
                                                  ? AppColors.button.withValues(alpha: 0.12)
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.button
                                                : isFilled
                                                    ? AppColors.button.withValues(alpha: 0.3)
                                                    : Colors.grey.shade300,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.energy_savings_leaf_rounded,
                                              size: 20,
                                              color: isSelected
                                                  ? Colors.white
                                                  : isFilled
                                                      ? AppColors.button
                                                      : Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "$lvl",
                                              style: TextStyle(
                                                fontFamily: "Quicksand",
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : isFilled
                                                        ? AppColors.button
                                                        : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card 4: Subtasks
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 18,
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
                                  ],
                                ),
                                if (tempSubtasks.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.button.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${tempSubtasks.where((s) => s['isDone'] == true).length}/${tempSubtasks.length}",
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.button,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Add new subtask inline
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: newSubtaskController,
                                    onTap: () {
                                      if (!newSubtaskController.selection.isCollapsed &&
                                          newSubtaskController.selection.isValid) {
                                        newSubtaskController.selection =
                                            TextSelection.collapsed(
                                          offset: newSubtaskController
                                              .selection.extentOffset
                                              .clamp(
                                            0,
                                            newSubtaskController.text.length,
                                          ),
                                        );
                                      }
                                    },
                                    style: const TextStyle(
                                      color: Color(0xFF5852A0),
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: L10n.tr("Add new subtask..."),
                                      hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: AppColors.button,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    final text = newSubtaskController.text.trim();
                                    if (text.isNotEmpty) {
                                      setModalState(() {
                                        tempSubtasks.add({
                                          "title": text,
                                          "isDone": false,
                                        });
                                        newSubtaskController.clear();
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.button,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Icon(Icons.add, size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (tempSubtasks.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  L10n.tr("No subtasks yet"),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 220),
                                child: ReorderableListView.builder(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: tempSubtasks.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setModalState(() {
                                      if (oldIndex < newIndex) {
                                        newIndex -= 1;
                                      }
                                      final item = tempSubtasks.removeAt(oldIndex);
                                      tempSubtasks.insert(newIndex, item);
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final sub = tempSubtasks[index];
                                    return Container(
                                      key: ValueKey(
                                        (sub["title"] ?? "") + index.toString(),
                                      ),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        leading: Checkbox(
                                          activeColor: AppColors.button,
                                          value: sub["isDone"] ?? false,
                                          onChanged: (val) {
                                            setModalState(() {
                                              sub["isDone"] = val;
                                            });
                                          },
                                        ),
                                        title: Text(
                                          sub["title"] ?? "",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontFamily: "Nunito",
                                            color: const Color(0xFF5852A0),
                                            decoration: (sub["isDone"] ?? false)
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                color: AppColors.button,
                                                size: 18,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                final editController =
                                                    NonSelectingTextEditingController(
                                                  text: sub["title"],
                                                );
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        20,
                                                      ),
                                                    ),
                                                    title: Text(
                                                      L10n.tr("Edit Subtask"),
                                                      style: const TextStyle(
                                                        fontFamily: "Quicksand",
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    content: TextField(
                                                      controller:
                                                          editController,
                                                      onTap: () {
                                                        if (!editController
                                                                .selection
                                                                .isCollapsed &&
                                                            editController
                                                                .selection
                                                                .isValid) {
                                                          editController
                                                                  .selection =
                                                              TextSelection
                                                                  .collapsed(
                                                            offset:
                                                                editController
                                                                    .selection
                                                                    .extentOffset
                                                                    .clamp(
                                                              0,
                                                              editController
                                                                  .text.length,
                                                            ),
                                                          );
                                                        }
                                                      },
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: L10n.tr("Edit subtask title"),
                                                      ),
                                                      autofocus: true,
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                          context,
                                                        ),
                                                        child: Text(
                                                          L10n.tr("Cancel"),
                                                        ),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          final text =
                                                              editController
                                                                  .text
                                                                  .trim();
                                                          if (text.isNotEmpty) {
                                                            setModalState(() {
                                                              sub["title"] =
                                                                  text;
                                                            });
                                                          }
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                        },
                                                        style:
                                                            ElevatedButton
                                                                .styleFrom(
                                                          backgroundColor:
                                                              AppColors.button,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                              12,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          L10n.tr("Save"),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.redAccent,
                                                size: 18,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () {
                                                setModalState(() {
                                                  tempSubtasks.removeAt(index);
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6.0,
                                                ),
                                                child: Icon(
                                                  Icons.drag_handle_rounded,
                                                  color: Colors.grey,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card 5: Completion Status
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 20,
                                  color: tempIsCompleted
                                      ? Colors.green
                                      : AppColors.button,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  L10n.tr("Completed"),
                                  style: TextStyle(
                                    fontFamily: "Quicksand",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.button,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: tempIsCompleted,
                              activeThumbColor: AppColors.button,
                              activeTrackColor: AppColors.button.withValues(
                                alpha: 0.5,
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  tempIsCompleted = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons (Cancel & Save)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                titleController.dispose();
                                descController.dispose();
                                newSubtaskController.dispose();
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.button,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                L10n.tr("Cancel"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  task.title = titleController.text.trim();
                                  task.description = descController.text.trim();
                                  task.prioritytask = tempPriority;
                                  task.energylvl = tempEnergyLvl;
                                  task.startDate =
                                      tempStartDate ?? DateTime.now();
                                  task.dueDate = tempScheduleMode == 0
                                      ? tempDueDate
                                      : (tempStartDate ?? DateTime.now());
                                  task.dueTime = tempDueTime?.format(context);
                                  task.isCompleted = tempIsCompleted;
                                  task.subtasks =
                                      tempSubtasks; // Commit subtasks
                                  task.reminderMinutes = tempReminderMinutes;
                                  task.repeatType = tempScheduleMode == 0
                                      ? RepeatType.none
                                      : (tempRepeatType == RepeatType.none
                                          ? RepeatType.daily
                                          : tempRepeatType);
                                  task.selectedWeekDays = tempScheduleMode == 0
                                      ? []
                                      : tempSelectedWeekDays;
                                  task.finishDate = tempScheduleMode == 0
                                      ? null
                                      : tempFinishDate;
                                });
                                await DBHelper().updateTask(task);
                                await _loadTasks();
                                TaskNotifier.notify();

                                // Manage Scheduled Notification
                                if (task.reminderMinutes != null &&
                                    !task.isCompleted) {
                                  await NotificationHelper()
                                      .scheduleTaskNotification(task);
                                } else {
                                  if (task.id != null) {
                                    await NotificationHelper()
                                        .cancelTaskNotification(task.id!);
                                  }
                                }

                                titleController.dispose();
                                descController.dispose();
                                newSubtaskController.dispose();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.button,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 1,
                              ),
                              child: Text(
                                L10n.tr("Save"),
                                style: const TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      speech.stop();
    });
  }

  String _getEnergyLabel(int level) {
    switch (level) {
      case 5:
        return L10n.tr("High");
      case 4:
        return L10n.tr("Mid-High");
      case 3:
        return L10n.tr("Mid");
      case 2:
        return L10n.tr("Mid-Low");
      default:
        return L10n.tr("Low");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BgContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(L10n.tr("Tasks"), style: AppTextStyles.greeting),
                      Transform.translate(
                        offset: const Offset(0, -5),
                        child: Text(
                          L10n.tr("Organized around your energy"),
                          style: AppTextStyles.affirmation,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Image.asset(AppImage.mascotfocus, height: 120),
                ],
              ),
            ),
            CustomSlidingSegmentedControl<int>(
              isStretch: true,
              decoration: BoxDecoration(
                color: AppColors.container2,
                border: Border.all(
                  width: 1,
                  style: BorderStyle.solid,
                  color: AppColors.containerline2,
                ),
              ),
              thumbDecoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(10),
              ),
              initialValue: selectedTab,
              children: {
                1: Text(
                  L10n.tr("Energy"),
                  style: TextStyle(
                    fontFamily: "Quicksand",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selectedTab == 1 ? Colors.white : AppColors.button,
                  ),
                ),
                2: Text(
                  L10n.tr("Due Date"),
                  style: TextStyle(
                    fontFamily: "Quicksand",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selectedTab == 2 ? Colors.white : AppColors.button,
                  ),
                ),
                3: Text(
                  L10n.tr("Priority"),
                  style: TextStyle(
                    fontFamily: "Quicksand",
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selectedTab == 3 ? Colors.white : AppColors.button,
                  ),
                ),
              },
              onValueChanged: (value) {
                setState(() {
                  selectedTab = value;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  if (selectedTab == 3) ...[
                    GestureDetector(
                      onTap: () async {
                        final newEisenhower = !_isEisenhowerMode;
                        setState(() {
                          _isEisenhowerMode = newEisenhower;
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_eisenhower_matrix_mode', newEisenhower);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isEisenhowerMode
                              ? AppColors.button
                              : AppColors.button.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.button.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isEisenhowerMode
                                  ? Icons.grid_view_rounded
                                  : Icons.flag_outlined,
                              size: 13,
                              color: _isEisenhowerMode
                                  ? Colors.white
                                  : AppColors.button,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isEisenhowerMode
                                  ? L10n.tr("Eisenhower Matrix")
                                  : L10n.tr("Priority Levels"),
                              style: TextStyle(
                                fontFamily: "Quicksand",
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _isEisenhowerMode
                                    ? Colors.white
                                    : AppColors.button,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(
                      _isListView
                          ? Icons.format_list_bulleted_rounded
                          : Icons.view_agenda_rounded,
                      size: 15,
                      color: AppColors.button.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isListView
                          ? L10n.tr("List View")
                          : L10n.tr("Card View"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.button.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final newMode = !_isListView;
                      setState(() {
                        _isListView = newMode;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('is_task_list_view_mode', newMode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.button.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.button.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isListView
                                ? Icons.view_agenda_rounded
                                : Icons.format_list_bulleted_rounded,
                            size: 13,
                            color: AppColors.button,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isListView
                                ? L10n.tr("Cards")
                                : L10n.tr("List"),
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppColors.button,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedTab == 1
                  ? EnergyLevelView(
                      tasks: _tasks,
                      userEnergy: _currentEnergyLvl,
                      onEdit: _showEditTaskBottomSheet,
                      isListView: _isListView,
                      onToggleComplete: _toggleTaskComplete,
                    )
                  : selectedTab == 2
                  ? DueDateView(
                      tasks: _tasks,
                      onEdit: _showEditTaskBottomSheet,
                      isListView: _isListView,
                      onToggleComplete: _toggleTaskComplete,
                    )
                  : PriorityView(
                      tasks: _tasks,
                      onEdit: _showEditTaskBottomSheet,
                      isListView: _isListView,
                      isEisenhowerMode: _isEisenhowerMode,
                      onToggleComplete: _toggleTaskComplete,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Category Task berdasarkan Energy Level
class EnergyLevelView extends StatelessWidget {
  const EnergyLevelView({
    super.key,
    required this.tasks,
    required this.userEnergy,
    required this.onEdit,
    this.isListView = false,
    this.onToggleComplete,
  });

  final List<TaskCard> tasks;
  final int userEnergy;
  final Function(TaskCard) onEdit;
  final bool isListView;
  final Function(TaskCard, bool?)? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeTasks = tasks
        .where(
          (t) =>
              !t.isCompleted &&
              RepeatTaskService.shouldShowTaskOnDate(t, today),
        )
        .toList();
    final recommendedTasks = activeTasks
        .where((t) => t.energylvl <= userEnergy)
        .toList();

    recommendedTasks.sort((a, b) {
      final dtA = RepeatTaskService.getEffectiveDueDateTime(a, referenceDate: today);
      final dtB = RepeatTaskService.getEffectiveDueDateTime(b, referenceDate: today);
      final dtCompare = dtA.compareTo(dtB);
      if (dtCompare != 0) {
        return dtCompare;
      }
      return b.prioritytask.compareTo(a.prioritytask);
    });

    final lowEnergyTasks = activeTasks.where((t) => t.energylvl <= 2).toList();
    final highFocusTasks = activeTasks.where((t) => t.energylvl >= 4).toList()
      ..sort((a, b) => b.energylvl.compareTo(a.energylvl));

    Widget buildTaskCard(TaskCard task) {
      task.onTap = () => onEdit(task);
      return task;
    }

    Widget buildTaskList(List<TaskCard> taskList) {
      if (taskList.isEmpty) return const SizedBox.shrink();
      if (isListView) {
        return Column(
          children: taskList.map((t) => TaskListItem(
            task: t,
            onTap: () => onEdit(t),
            onCompletedChanged: onToggleComplete != null
                ? (val) => onToggleComplete!(t, val)
                : null,
          )).toList(),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: taskList.map(buildTaskCard).toList(),
        ),
      );
    }

    Widget buildEmptyState(String message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/lavender_bunny/Tidakadatugas.gif",
                height: 100,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontFamily: "Nunito",
                  fontSize: 12,
                  color: AppColors.normaltext.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.recommend, size: 20, color: AppColors.button),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Recommended Task"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (recommendedTasks.isEmpty)
                buildEmptyState(L10n.tr("No recommended tasks"))
              else
                buildTaskList(recommendedTasks),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.favorite, size: 20, color: AppColors.button),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Low Energy Task"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (lowEnergyTasks.isEmpty)
                buildEmptyState(L10n.tr("No low energy tasks"))
              else
                buildTaskList(lowEnergyTasks),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 20,
                      color: AppColors.button,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("High Focus Task"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (highFocusTasks.isEmpty)
                buildEmptyState(L10n.tr("No high focus tasks"))
              else
                buildTaskList(highFocusTasks),
            ],
          ),
        ),
      ],
    );
  }
}

// Category Task berdasarkan Due Date
class DueDateView extends StatelessWidget {
  const DueDateView({
    super.key,
    required this.tasks,
    required this.onEdit,
    this.isListView = false,
    this.onToggleComplete,
  });

  final List<TaskCard> tasks;
  final Function(TaskCard) onEdit;
  final bool isListView;
  final Function(TaskCard, bool?)? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = todayDate.add(const Duration(days: 1));

    // Non-completed tasks
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();

    final todayTasks = activeTasks.where((t) {
      return RepeatTaskService.shouldShowTaskOnDate(t, todayDate);
    }).toList();

    final tomorrowTasks = activeTasks.where((t) {
      return RepeatTaskService.shouldShowTaskOnDate(t, tomorrowDate);
    }).toList();

    final upcomingTasks = activeTasks.where((t) {
      if (t.repeatType != RepeatType.none) {
        final next = RepeatTaskService.getNextOccurrenceDate(
          t,
          fromDate: tomorrowDate.add(const Duration(days: 1)),
        );
        return next != null;
      }
      if (t.dueDate == null) return false;
      final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return d.isAfter(tomorrowDate);
    }).toList();

    final completedTasks = tasks.where((t) => t.isCompleted).toList();

    Widget buildTaskCard(TaskCard task) {
      task.onTap = () => onEdit(task);
      return task;
    }

    Widget buildTaskList(List<TaskCard> taskList) {
      if (taskList.isEmpty) return const SizedBox.shrink();
      if (isListView) {
        return Column(
          children: taskList.map((t) => TaskListItem(
            task: t,
            onTap: () => onEdit(t),
            onCompletedChanged: onToggleComplete != null
                ? (val) => onToggleComplete!(t, val)
                : null,
          )).toList(),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: taskList.map(buildTaskCard).toList(),
        ),
      );
    }

    Widget buildEmptyState(String message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/lavender_bunny/Tidakadatugas.gif",
                height: 100,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontFamily: "Nunito",
                  fontSize: 12,
                  color: AppColors.normaltext.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.today, size: 20, color: AppColors.button),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Today"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (todayTasks.isEmpty)
                buildEmptyState(L10n.tr("No tasks today"))
              else
                buildTaskList(todayTasks),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: AppColors.button),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Tomorrow"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (tomorrowTasks.isEmpty)
                buildEmptyState(L10n.tr("No tasks tomorrow"))
              else
                buildTaskList(tomorrowTasks),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(Icons.upcoming, size: 20, color: AppColors.button),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Upcoming"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (upcomingTasks.isEmpty)
                buildEmptyState(L10n.tr("No upcoming tasks"))
              else
                buildTaskList(upcomingTasks),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: AppColors.button,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Completed"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (completedTasks.isEmpty)
                buildEmptyState(L10n.tr("No completed tasks"))
              else
                buildTaskList(completedTasks),
            ],
          ),
        ),
      ],
    );
  }
}

// Category Task berdasarkan priority & Eisenhower Matrix
class PriorityView extends StatelessWidget {
  const PriorityView({
    super.key,
    required this.tasks,
    required this.onEdit,
    this.isListView = false,
    this.isEisenhowerMode = false,
    this.onToggleComplete,
  });

  final List<TaskCard> tasks;
  final Function(TaskCard) onEdit;
  final bool isListView;
  final bool isEisenhowerMode;
  final Function(TaskCard, bool?)? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks
        .where(
          (t) =>
              !t.isCompleted &&
              (t.repeatType == RepeatType.none ||
                  RepeatTaskService.shouldShowTaskOnDate(t, DateTime.now())),
        )
        .toList();

    Widget buildTaskCard(TaskCard task) {
      task.onTap = () => onEdit(task);
      return task;
    }

    Widget buildTaskList(List<TaskCard> taskList) {
      if (taskList.isEmpty) return const SizedBox.shrink();
      if (isListView) {
        return Column(
          children: taskList.map((t) => TaskListItem(
            task: t,
            onTap: () => onEdit(t),
            onCompletedChanged: onToggleComplete != null
                ? (val) => onToggleComplete!(t, val)
                : null,
          )).toList(),
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: taskList.map(buildTaskCard).toList(),
        ),
      );
    }

    Widget buildEmptyState(String message) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/lavender_bunny/Tidakadatugas.gif",
                height: 100,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(
                  fontFamily: "Nunito",
                  fontSize: 12,
                  color: AppColors.normaltext.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- EISENHOWER MATRIX MODE ---
    if (isEisenhowerMode) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      bool isUrgent(TaskCard t) {
        if (t.repeatType != RepeatType.none) {
          return RepeatTaskService.shouldShowTaskOnDate(t, today) ||
              RepeatTaskService.shouldShowTaskOnDate(t, tomorrow);
        }
        if (t.dueDate == null) return false;
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        return due.isBefore(tomorrow.add(const Duration(days: 1)));
      }

      bool isImportant(TaskCard t) {
        return t.prioritytask >= 2; // High (3) or Mid (2)
      }

      final q1DoFirst =
          activeTasks.where((t) => isImportant(t) && isUrgent(t)).toList();
      final q2Schedule =
          activeTasks.where((t) => isImportant(t) && !isUrgent(t)).toList();
      final q3Delegate =
          activeTasks.where((t) => !isImportant(t) && isUrgent(t)).toList();
      final q4Eliminate =
          activeTasks.where((t) => !isImportant(t) && !isUrgent(t)).toList();

      Widget buildQuadrantCard({
        required String title,
        required String subtitle,
        required String code,
        required Color color,
        required IconData icon,
        required List<TaskCard> taskList,
        required String emptyText,
      }) {
        return Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            code,
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: "Quicksand",
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.button,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontFamily: "Nunito",
                              fontSize: 10.5,
                              color: AppColors.normaltext.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.button.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${taskList.length}",
                        style: TextStyle(
                          fontFamily: "Nunito",
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.button,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (taskList.isEmpty)
                buildEmptyState(emptyText)
              else
                buildTaskList(taskList),
            ],
          ),
        );
      }

      return ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 20),
        children: [
          // 2x2 Matrix Overview Summary Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.containerline1,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 14,
                        color: AppColors.button,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        L10n.tr("Eisenhower Matrix Overview"),
                        style: TextStyle(
                          fontFamily: "Quicksand",
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.button,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Q1 • Do First"),
                                style: const TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                "${q1DoFirst.length} ${L10n.tr("tasks")}",
                                style: TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 10,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Q2 • Schedule"),
                                style: const TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                "${q2Schedule.length} ${L10n.tr("tasks")}",
                                style: TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Q3 • Delegate"),
                                style: const TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.orange,
                                ),
                              ),
                              Text(
                                "${q3Delegate.length} ${L10n.tr("tasks")}",
                                style: TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blueGrey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Q4 • Eliminate"),
                                style: const TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              Text(
                                "${q4Eliminate.length} ${L10n.tr("tasks")}",
                                style: TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 10,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Q1: Do First
          buildQuadrantCard(
            title: L10n.tr("Do First"),
            subtitle: L10n.tr("Important & Urgent — Focus on these today!"),
            code: "Q1",
            color: Colors.red.shade400,
            icon: Icons.local_fire_department_rounded,
            taskList: q1DoFirst,
            emptyText: L10n.tr("No urgent & important tasks!"),
          ),

          // Q2: Schedule
          buildQuadrantCard(
            title: L10n.tr("Schedule & Plan"),
            subtitle: L10n.tr("Important, Not Urgent — High long-term value."),
            code: "Q2",
            color: Colors.blue.shade500,
            icon: Icons.calendar_month_rounded,
            taskList: q2Schedule,
            emptyText: L10n.tr("No scheduled important tasks."),
          ),

          // Q3: Delegate / Quick
          buildQuadrantCard(
            title: L10n.tr("Delegate / Quick Finish"),
            subtitle: L10n.tr("Urgent, Less Important — Finish fast or delegate."),
            code: "Q3",
            color: Colors.orange.shade500,
            icon: Icons.bolt_rounded,
            taskList: q3Delegate,
            emptyText: L10n.tr("No quick urgent tasks."),
          ),

          // Q4: Eliminate / Backlog
          buildQuadrantCard(
            title: L10n.tr("Don't Do / Backlog"),
            subtitle: L10n.tr("Not Urgent & Low Priority — Drop or save for later."),
            code: "Q4",
            color: Colors.blueGrey.shade400,
            icon: Icons.inventory_2_outlined,
            taskList: q4Eliminate,
            emptyText: L10n.tr("No backlog tasks."),
          ),
        ],
      );
    }

    // --- STANDARD PRIORITY LEVELS MODE ---
    final highPriority = activeTasks.where((t) => t.prioritytask == 3).toList();
    final midPriority = activeTasks.where((t) => t.prioritytask == 2).toList();
    final lowPriority = activeTasks
        .where((t) => t.prioritytask == 1 || t.prioritytask == 0)
        .toList();

    return ListView(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      children: [
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.red, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("High Priority Tasks"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (highPriority.isEmpty)
                buildEmptyState(L10n.tr("No high priority tasks"))
              else
                buildTaskList(highPriority),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Medium Priority Tasks"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (midPriority.isEmpty)
                buildEmptyState(L10n.tr("No medium priority tasks"))
              else
                buildTaskList(midPriority),
            ],
          ),
        ),
        Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr("Low Priority Tasks"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        color: AppColors.button,
                      ),
                    ),
                  ],
                ),
              ),
              if (lowPriority.isEmpty)
                buildEmptyState(L10n.tr("No low priority tasks"))
              else
                buildTaskList(lowPriority),
            ],
          ),
        ),
      ],
    );
  }
}


