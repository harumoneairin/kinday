import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/firebase_backup_service.dart';
import 'package:kinday/database/preference_handler.dart';
import 'package:kinday/pages/additional/createtask.dart';
import 'package:kinday/pages/botnavpage/pomodoropage.dart';
import 'package:kinday/pages/mainpage.dart';
import 'package:kinday/pages/service/google_calendar_service.dart';
import 'package:kinday/pages/service/repeat_task_service.dart';
import 'package:kinday/widgets/calendar_event_card.dart';
import 'package:kinday/widgets/kinday_calendar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final breakdowncontroller = TextEditingController();

  int? _userId;
  String _name = "User";
  int _currentEnergyLvl = 3;
  DateTime? _lastUpdatedTime;
  bool _hasLogs = false;
  TaskCard? _suggestedTask;
  int _totalTasks = 0;
  int _completedTasksCount = 0;
  bool _isLoadingAI = false;

  DateTime _dashboardSelectedDate = DateTime.now();
  List<TaskCard> _allUserTasks = [];
  List<CalendarEventItem> _gcalEvents = [];
  bool _isGcalConnected = false;
  bool _isCalendarMonthly = false;
  bool _isAgendaVisible = true;

  @override
  void initState() {
    super.initState();
    _loadHomepageData();
    TaskNotifier.taskUpdated.addListener(_loadHomepageData);
  }

  @override
  void dispose() {
    TaskNotifier.taskUpdated.removeListener(_loadHomepageData);
    breakdowncontroller.dispose();
    super.dispose();
  }

  Future<void> _loadHomepageData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final name = prefs.getString('user_name') ?? "User";

    // Trigger silent weekly auto-backup
    FirebaseBackupService().checkAndRunAutoBackup(userId);

    // Reset daily recurring tasks if a new day has arrived
    await RepeatTaskService.checkAndResetDailyRepeatTasks(userId);

    final dbHelper = DBHelper();
    final latestEnergy = await dbHelper.getLatestEnergyForUser(userId);
    final userTasks = await dbHelper.getTasksForUser(userId);

    final logs = await dbHelper.getEnergyLogsForUser(userId);
    final hasLogs = logs.isNotEmpty;
    DateTime? lastUpdatedTime;
    if (hasLogs) {
      try {
        lastUpdatedTime = DateTime.parse(logs.last['timestamp'] as String);
      } catch (_) {}
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = userTasks.where((t) {
      return RepeatTaskService.shouldShowTaskOnDate(t, today);
    }).toList();

    final activeTasks = todayTasks.where((t) => !t.isCompleted).toList();

    TaskCard? suggested;
    final userEnergy = latestEnergy ?? 3;
    final filteredTasks = activeTasks.where((t) {
      final isUrgent = _isTaskUrgent(t);
      final isEnergyMatch = t.energylvl <= userEnergy;
      return isEnergyMatch || isUrgent;
    }).toList();

    if (filteredTasks.isNotEmpty) {
      filteredTasks.sort((a, b) {
        final aUrgent = _isTaskUrgent(a);
        final bUrgent = _isTaskUrgent(b);

        // 1. Urgent tasks first
        if (aUrgent && !bUrgent) return -1;
        if (!aUrgent && bUrgent) return 1;

        // 2. Highest priority first
        final priorityCompare = b.prioritytask.compareTo(a.prioritytask);
        if (priorityCompare != 0) return priorityCompare;

        // 3. Closest energy match
        final aDiff = (a.energylvl - userEnergy).abs();
        final bDiff = (b.energylvl - userEnergy).abs();
        return aDiff.compareTo(bDiff);
      });
      suggested = filteredTasks.first;
    }

    // Check Google Calendar connection and load events for selected date
    final isGcal = await GoogleCalendarService().isConnected();
    List<CalendarEventItem> gcalEvents = [];
    if (isGcal) {
      gcalEvents = await GoogleCalendarService().fetchEventsForDate(_dashboardSelectedDate);
    }

    final isCalendarMonthly = prefs.getBool('is_calendar_monthly') ?? false;
    final isAgendaVisible = prefs.getBool('is_dashboard_agenda_visible') ?? true;

    if (!mounted) return;
    setState(() {
      _userId = userId;
      _name = name;
      if (latestEnergy != null) {
        _currentEnergyLvl = latestEnergy;
      }
      _lastUpdatedTime = lastUpdatedTime;
      _hasLogs = hasLogs;
      _suggestedTask = suggested;
      _allUserTasks = userTasks;
      _totalTasks = todayTasks.length;
      _completedTasksCount = todayTasks.where((t) => t.isCompleted).length;
      _isGcalConnected = isGcal;
      _gcalEvents = gcalEvents;
      _isCalendarMonthly = isCalendarMonthly;
      _isAgendaVisible = isAgendaVisible;
    });
  }

  void _onDateSelected(DateTime date) async {
    setState(() {
      _dashboardSelectedDate = date;
    });
    if (_isGcalConnected) {
      final events = await GoogleCalendarService().fetchEventsForDate(date);
      if (mounted) {
        setState(() {
          _gcalEvents = events;
        });
      }
    }
  }

  bool _isTaskUrgent(TaskCard t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateTime = RepeatTaskService.getEffectiveDueDateTime(t, referenceDate: today);
    final difference = dueDateTime.difference(now);
    return difference.inMinutes <= 180 && difference.inMinutes >= -720;
  }

  String _getEnergyLabel(int level) {
    switch (level) {
      case 5:
        return L10n.tr("High");
      case 4:
        return L10n.tr("Mid-High");
      case 3:
        return L10n.tr("Medium");
      case 2:
        return L10n.tr("Mid-Low");
      default:
        return L10n.tr("Low");
    }
  }

  Future<void> _breakDownTaskWithAI() async {
    final taskTitle = breakdowncontroller.text.trim();
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
        final List<Map<String, dynamic>> subtaskMaps = [];
        for (var subtaskTitle in decodedList) {
          if (subtaskTitle is String && subtaskTitle.trim().isNotEmpty) {
            subtaskMaps.add({"title": subtaskTitle.trim(), "isDone": false});
          }
        }

        breakdowncontroller.clear();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTaskPage(
                initialTitle: taskTitle,
                initialSubtasks: subtaskMaps,
              ),
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BgContainer(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 1. Fixed Header Section (Does not scroll)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            () {
                              final hour = DateTime.now().hour;
                              if (hour >= 5 && hour < 12) {
                                return L10n.tr("Good Morning,");
                              } else if (hour >= 12 && hour < 17) {
                                return L10n.tr("Good Afternoon,");
                              } else if (hour >= 17 && hour < 21) {
                                return L10n.tr("Good Evening,");
                              } else {
                                return L10n.tr("Good Night,");
                              }
                            }(),
                            style: AppTextStyles.greeting,
                          ),
                          Transform.translate(
                            offset: const Offset(0, -5),
                            child: Text(
                              _name,
                              style: AppTextStyles.username.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: "Quicksand",
                                color: AppColors.button,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, -2),
                            child: Text(
                              () {
                                final hour = DateTime.now().hour;
                                if (hour < 12) {
                                  return L10n.tr("Let's start a new day!");
                                } else if (hour < 17) {
                                  return L10n.tr("Don't forget to take a break");
                                } else {
                                  return L10n.tr("You've done your best today!");
                                }
                              }(),
                              style: AppTextStyles.affirmation,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Image.asset(AppImage.mascottask, height: 120),
                  ],
                ),
              ),
              // 2. Content Column
              Column(
                children: [
                  Container3(
                    width: double.infinity,
                    child: Row(
                      children: [
                        Image.asset(AppImage.iconenergy, height: 50, width: 50),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Current Energy"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.button,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getEnergyLabel(_currentEnergyLvl),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                !_hasLogs
                                    ? L10n.tr("No logs yet")
                                    : _lastUpdatedTime != null
                                        ? "${L10n.tr("Last Updated")} ${_lastUpdatedTime!.hour.toString().padLeft(2, '0')}:${_lastUpdatedTime!.minute.toString().padLeft(2, '0')}"
                                        : L10n.tr("Last Updated"),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.button.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontFamily: "Nunito",
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            int tempEnergyLvl = _currentEnergyLvl;
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  title: Text(
                                    L10n.tr("What's your energy level?"),
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.button,
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: StatefulBuilder(
                                      builder: (context, setModalState) {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: List.generate(5, (
                                                index,
                                              ) {
                                                final lvl = index + 1;
                                                final isActive =
                                                    tempEnergyLvl >= lvl;
                                                return IconButton(
                                                  iconSize: 32,
                                                  icon: Icon(
                                                    Icons
                                                        .energy_savings_leaf_rounded,
                                                    color: isActive
                                                        ? AppColors.button
                                                        : Colors.grey.shade300,
                                                  ),
                                                  onPressed: () {
                                                    setModalState(() {
                                                      tempEnergyLvl = lvl;
                                                    });
                                                  },
                                                );
                                              }),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        L10n.tr("Cancel"),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (_userId != null) {
                                          await DBHelper().insertEnergyLog(
                                            _userId!,
                                            tempEnergyLvl,
                                            DateTime.now().toIso8601String(),
                                          );
                                          await _loadHomepageData();
                                        }
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.button,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        L10n.tr("Save"),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.button,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                L10n.tr("Log"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container1(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.container2.withValues(
                                alpha: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                width: 1,
                                color: AppColors.containerline2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: AppColors.normaltext,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  L10n.tr("Suggested for now"),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.normaltext,
                                    fontFamily: "Quicksand",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                AppImage.icontask,
                                height: 64,
                                width: 64,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _suggestedTask?.title ??
                                        L10n.tr("No Suggested Task"),
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppColors.button,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _suggestedTask?.description ??
                                        L10n.tr("No description"),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.normaltext.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontFamily: "Nunito",
                                    ),
                                  ),
                                  if (_suggestedTask != null) ...[
                                    const SizedBox(height: 8),
                                    if (_suggestedTask!.energylvl > _currentEnergyLvl) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 14,
                                              color: Colors.amber.shade800,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                L10n.tr("Your energy is low, but this task is urgent!"),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber.shade900,
                                                  fontFamily: "Nunito",
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_suggestedTask!.repeatType != RepeatType.none) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.repeat,
                                            size: 14,
                                            color: AppColors.button,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              RepeatTaskService.getRepeatSubtitle(_suggestedTask!),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.button,
                                                fontFamily: "Nunito",
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ] else if (_suggestedTask!.dueDate != null) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 13,
                                            color: AppColors.button,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _suggestedTask!.dueTime != null &&
                                                      _suggestedTask!
                                                          .dueTime!
                                                          .isNotEmpty
                                                  ? "${_suggestedTask!.dueDate!.day}/${_suggestedTask!.dueDate!.month}/${_suggestedTask!.dueDate!.year}  ${_suggestedTask!.dueTime}"
                                                  : "${_suggestedTask!.dueDate!.day}/${_suggestedTask!.dueDate!.month}/${_suggestedTask!.dueDate!.year}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.button,
                                                fontFamily: "Nunito",
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ] else if (_suggestedTask!.startDate != null) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.play_circle_outline,
                                            size: 14,
                                            color: AppColors.button,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "${_suggestedTask!.startDate!.day}/${_suggestedTask!.startDate!.month}/${_suggestedTask!.startDate!.year}",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.button,
                                                fontFamily: "Nunito",
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.energy_savings_leaf_rounded,
                                          size: 15,
                                          color: AppColors.button,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getEnergyLabel(
                                            _suggestedTask!.energylvl,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.normaltext,
                                            fontFamily: "Nunito",
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        PriorityIndicator(
                                          priority:
                                              _suggestedTask!.prioritytask,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: () {
                            if (_suggestedTask != null) {
                              TaskCard.activePomodoroTask = _suggestedTask;
                              final mainState = context
                                  .findAncestorStateOfType<MainpageState>();
                              if (mainState != null) {
                                mainState.changeTab(2);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Pomodoropage(task: _suggestedTask),
                                  ),
                                ).then((_) {
                                  _loadHomepageData();
                                });
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    L10n.tr("No suggested task available."),
                                    style: TextStyle(color: AppColors.button),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.button,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                L10n.tr("Start Focus Session"),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container2(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              AppImage.iconprogress,
                              height: 50,
                              width: 50,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L10n.tr("Today's Progress"),
                                    style: TextStyle(
                                      fontFamily: "Quicksand",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.button,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    L10n.tr("$_completedTasksCount out of $_totalTasks tasks"),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.normaltext,
                                      fontFamily: "Nunito",
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_totalTasks > 0) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_completedTasksCount / _totalTasks).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.button,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container3(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr("Turn big tasks into small, doable steps"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.button,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: breakdowncontroller,
                          maxLines: 2,
                          style: TextStyle(
                            color: AppColors.button,
                            fontFamily: "Nunito",
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: L10n.tr("Let AI break down your task..."),
                            hintStyle: TextStyle(
                              color: AppColors.button.withValues(alpha: 0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: AppColors.button,
                                width: 1.5,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.6),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              : ElevatedButton.icon(
                                  onPressed: _breakDownTaskWithAI,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.button,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: Image.asset(
                                    AppImage.iconsubtask,
                                    width: 18,
                                    height: 18,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    L10n.tr("Break down task"),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // 7. Schedule & Calendar Section at the very bottom
                  () {
                    final selectedDateTasks = _allUserTasks.where((t) {
                      if (t.isCompleted) return false;
                      return RepeatTaskService.shouldShowTaskOnDate(
                        t,
                        _dashboardSelectedDate,
                      );
                    }).toList();

                    return Container1(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with Title & Mode Toggle
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 20,
                                color: AppColors.button,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      L10n.tr("Schedule & Calendar"),
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.button,
                                      ),
                                    ),
                                    Text(
                                      L10n.tr("Plan your days gently"),
                                      style: TextStyle(
                                        fontFamily: "Nunito",
                                        fontSize: 12,
                                        color: AppColors.normaltext.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: _isCalendarMonthly
                                    ? L10n.tr("Switch to Weekly View")
                                    : L10n.tr("Switch to Monthly View"),
                                icon: Icon(
                                  _isCalendarMonthly
                                      ? Icons.view_week_rounded
                                      : Icons.calendar_month_rounded,
                                  color: AppColors.button,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  final newMode = !_isCalendarMonthly;
                                  setState(() {
                                    _isCalendarMonthly = newMode;
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool(
                                    'is_calendar_monthly',
                                    newMode,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // The Calendar Widget
                          KinDayCalendarWidget(
                            selectedDate: _dashboardSelectedDate,
                            onDateSelected: _onDateSelected,
                            tasks: _allUserTasks,
                            gcalEvents: _gcalEvents,
                            isMonthlyMode: _isCalendarMonthly,
                          ),
                          const SizedBox(height: 16),

                          // Selected Date Header with Toggle Expand/Collapse
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final newVisible = !_isAgendaVisible;
                              setState(() {
                                _isAgendaVisible = newVisible;
                              });
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'is_dashboard_agenda_visible',
                                newVisible,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    size: 16,
                                    color: AppColors.button,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "${L10n.tr("Agenda for")} ${_dashboardSelectedDate.day}/${_dashboardSelectedDate.month}/${_dashboardSelectedDate.year}",
                                      style: TextStyle(
                                        fontFamily: "Quicksand",
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.button,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${selectedDateTasks.length + _gcalEvents.length} ${L10n.tr("items")}",
                                    style: TextStyle(
                                      fontFamily: "Nunito",
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppColors.button.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _isAgendaVisible
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: AppColors.button,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_isAgendaVisible) ...[
                            const SizedBox(height: 10),

                            // Google Calendar events for selected date
                            if (_gcalEvents.isNotEmpty) ...[
                              ..._gcalEvents.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: CalendarEventCard(
                                    event: e,
                                    onConverted: _loadHomepageData,
                                  ),
                                ),
                              ),
                            ],

                            // Tasks for selected date
                            if (selectedDateTasks.isNotEmpty) ...[
                              ...selectedDateTasks.map(
                                (t) => _buildDashboardTaskItem(t),
                              ),
                            ],

                            // Empty State if no tasks and no gcal events
                            if (selectedDateTasks.isEmpty &&
                                _gcalEvents.isEmpty) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        "assets/images/lavender_bunny/Tidakadatugas.gif",
                                        height: 80,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        L10n.tr("No tasks or events on this date!"),
                                        style: TextStyle(
                                          fontFamily: "Nunito",
                                          fontSize: 12,
                                          color: AppColors.normaltext
                                              .withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  }(),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTaskItem(TaskCard task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.containerline1,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.prioritytask == 3
                  ? Colors.redAccent
                  : task.prioritytask == 2
                      ? Colors.orangeAccent
                      : Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontFamily: "Quicksand",
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.button,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.energy_savings_leaf_rounded,
                      size: 12,
                      color: AppColors.button,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _getEnergyLabel(task.energylvl),
                      style: TextStyle(
                        fontFamily: "Nunito",
                        fontSize: 11,
                        color: AppColors.normaltext.withValues(alpha: 0.75),
                      ),
                    ),
                    if (task.dueTime != null && task.dueTime!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: AppColors.button,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        task.dueTime!,
                        style: TextStyle(
                          fontFamily: "Nunito",
                          fontSize: 11,
                          color: AppColors.normaltext.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.button,
              size: 26,
            ),
            tooltip: L10n.tr("Start Focus"),
            onPressed: () {
              TaskCard.activePomodoroTask = task;
              final mainState = context.findAncestorStateOfType<MainpageState>();
              if (mainState != null) {
                mainState.changeTab(2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Pomodoropage(task: task),
                  ),
                ).then((_) => _loadHomepageData());
              }
            },
          ),
        ],
      ),
    );
  }
}
