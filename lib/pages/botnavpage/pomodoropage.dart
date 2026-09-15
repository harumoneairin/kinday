import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:just_audio/just_audio.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Pomodoropage extends StatefulWidget {
  final TaskCard? task;
  const Pomodoropage({super.key, this.task});

  @override
  State<Pomodoropage> createState() => _PomodoropageState();
}

class _PomodoropageState extends State<Pomodoropage> {
  final AudioPlayer player = AudioPlayer();
  Timer? timer;
  bool isRunning = false;
  bool isFocusTime = true;
  int focusDuration = 25 * 60;
  int breakDuration = 5 * 60;
  late int totalSeconds;
  late int secondsRemaining;
  late TaskCard? activeTask;
  final TextEditingController _pomodoroSubtaskController =
      TextEditingController();
  String _selectedSound = "Fireplace";

  String get taskName =>
      activeTask?.title ?? L10n.tr("Learn Flutter");

  double get progress {
    return secondsRemaining / totalSeconds;
  }

  String formatTime() {
    int minutes = secondsRemaining ~/ 60;
    int seconds = secondsRemaining % 60;

    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    activeTask = TaskCard.activePomodoroTask ?? widget.task;
    _loadFocusSettings();
    _loadActiveTask();
    totalSeconds = focusDuration;
    secondsRemaining = focusDuration;
    TaskNotifier.taskUpdated.addListener(_loadActiveTask);
  }

  Future<void> _loadActiveTask() async {
    if (activeTask != null) return;
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    final dbHelper = DBHelper();
    final userTasks = await dbHelper.getTasksForUser(userId);
    final activeTasks = userTasks.where((t) => !t.isCompleted).toList();
    if (mounted) {
      setState(() {
        if (activeTasks.isNotEmpty) {
          activeTask = activeTasks.first;
        } else if (userTasks.isNotEmpty) {
          activeTask = userTasks.first;
        }
      });
    }
  }

  Future<void> _loadFocusSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDuration = prefs.getInt('focus_duration') ?? 25;
    final savedBreakDuration = prefs.getInt('break_duration') ?? 5;
    String savedSound = prefs.getString('focus_sound') ?? "Fireplace";
    if (savedSound == "Rain") savedSound = "Gentle Rain";
    if (savedSound == "White Noise") savedSound = "None";

    setState(() {
      focusDuration = savedDuration * 60;
      breakDuration = savedBreakDuration * 60;
      if (!isRunning) {
        if (isFocusTime) {
          totalSeconds = focusDuration;
          secondsRemaining = focusDuration;
        } else {
          totalSeconds = breakDuration;
          secondsRemaining = breakDuration;
        }
      }
      _selectedSound = savedSound;
    });

    _playBackgroundSound();
  }

  Future<void> _playBackgroundSound() async {
    if (_selectedSound == "None" || !isRunning) {
      try {
        await player.stop();
      } catch (e) {
        debugPrint("Error stopping background sound: $e");
      }
      return;
    }

    String assetPath = "";
    switch (_selectedSound) {
      case "Fireplace":
        assetPath = "assets/audio/fireplace.mp3";
        break;
      case "Forest":
        assetPath = "assets/audio/forest.mp3";
        break;
      case "Gentle Rain":
        assetPath = "assets/audio/gentle-rain.mp3";
        break;
      case "Heavy Rain":
        assetPath = "assets/audio/heavy-rain.mp3";
        break;
      case "Night Ambience":
        assetPath = "assets/audio/night-ambience.mp3";
        break;
      case "Ocean Waves":
        assetPath = "assets/audio/ocean-waves.mp3";
        break;
      case "Stream":
        assetPath = "assets/audio/stream.mp3";
        break;
      case "Underwater Ambience":
        assetPath = "assets/audio/underwater-ambience.mp3";
        break;
      default:
        return;
    }

    try {
      if (!mounted) return;
      await player.setAsset(assetPath);
      if (!mounted) return;
      await player.setLoopMode(LoopMode.all);
      if (!mounted) return;
      await player.play();
    } catch (e) {
      debugPrint("Error playing background sound: $e");
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    TaskNotifier.taskUpdated.removeListener(_loadActiveTask);
    _pomodoroSubtaskController.dispose();
    player.dispose();
    super.dispose();
  }

  void _sortSubtasks(String criteria, VoidCallback setSubtaskState) async {
    if (activeTask == null) return;
    setState(() {
      if (criteria == 'A-Z') {
        activeTask!.subtasks.sort(
          (a, b) => (a['title'] as String).toLowerCase().compareTo(
            (b['title'] as String).toLowerCase(),
          ),
        );
      } else if (criteria == 'Z-A') {
        activeTask!.subtasks.sort(
          (a, b) => (b['title'] as String).toLowerCase().compareTo(
            (a['title'] as String).toLowerCase(),
          ),
        );
      } else if (criteria == 'Incomplete first') {
        activeTask!.subtasks.sort((a, b) {
          final aDone = a['isDone'] ?? false;
          final bDone = b['isDone'] ?? false;
          if (aDone == bDone) return 0;
          return aDone ? 1 : -1;
        });
      } else if (criteria == 'Completed first') {
        activeTask!.subtasks.sort((a, b) {
          final aDone = a['isDone'] ?? false;
          final bDone = b['isDone'] ?? false;
          if (aDone == bDone) return 0;
          return aDone ? -1 : 1;
        });
      }
    });
    await DBHelper().updateTask(activeTask!);
    setSubtaskState();
  }

  Widget _buildSubtasksSection() {
    final subtasks = activeTask?.subtasks ?? [];
    final total = subtasks.length;
    final completed = subtasks.where((sub) => sub["isDone"] == true).length;
    final progressPercent = total > 0 ? (completed / total) : 0.0;

    return StatefulBuilder(
      builder: (context, setSubtaskState) {
        return Container1(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        color: AppColors.button,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        L10n.tr("Subtasks"),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.button,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.sort,
                          size: 20,
                          color: AppColors.button,
                        ),
                        tooltip: L10n.tr("Sort subtasks"),
                        onSelected: (criteria) => _sortSubtasks(
                          criteria,
                          () => setSubtaskState(() {}),
                        ),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'A-Z',
                                child: Text(L10n.tr('Alphabetical (A-Z)', 'Alfabetis (A-Z)')),
                              ),
                              PopupMenuItem<String>(
                                value: 'Z-A',
                                child: Text(L10n.tr('Alphabetical (Z-A)', 'Alfabetis (Z-A)')),
                              ),
                              PopupMenuItem<String>(
                                value: 'Incomplete first',
                                child: Text(L10n.tr('Incomplete first', 'Belum selesai dahulu')),
                              ),
                              PopupMenuItem<String>(
                                value: 'Completed first',
                                child: Text(L10n.tr('Completed first', 'Selesai dahulu')),
                              ),
                            ],
                      ),
                      Text(
                        "$completed/$total",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.button,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Linear Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressPercent,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.button),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 15),
              // List of subtasks
              if (subtasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Center(
                    child: Text(
                      L10n.tr("No subtasks yet"),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: subtasks.length,
                  onReorder: (oldIndex, newIndex) async {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = subtasks.removeAt(oldIndex);
                      subtasks.insert(newIndex, item);
                    });
                    if (activeTask != null) {
                      await DBHelper().updateTask(activeTask!);
                    }
                    setSubtaskState(() {});
                  },
                  itemBuilder: (context, index) {
                    final sub = subtasks[index];
                    final isDone = sub["isDone"] ?? false;
                    return Container(
                      key: ValueKey((sub["title"] ?? "") + index.toString()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                setState(() {
                                  sub["isDone"] = !isDone;
                                });
                                if (activeTask != null) {
                                  await DBHelper().updateTask(activeTask!);
                                }
                                // Also update state of StatefulBuilder
                                setSubtaskState(() {});
                              },
                              child: Icon(
                                isDone
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isDone
                                    ? AppColors.button
                                    : Colors.grey.shade400,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  setState(() {
                                    sub["isDone"] = !isDone;
                                  });
                                  if (activeTask != null) {
                                    await DBHelper().updateTask(activeTask!);
                                  }
                                  // Also update state of StatefulBuilder
                                  setSubtaskState(() {});
                                },
                                child: Text(
                                  sub["title"] ?? "",
                                  style: TextStyle(
                                    fontSize: 14,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDone
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: AppColors.button,
                                size: 18,
                              ),
                              onPressed: () {
                                final editController = TextEditingController(
                                  text: sub["title"],
                                );
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(L10n.tr("Edit Subtask")),
                                    content: TextField(
                                      controller: editController,
                                      decoration: InputDecoration(
                                        hintText: L10n.tr("Edit subtask title"),
                                      ),
                                      autofocus: true,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(L10n.tr("Cancel")),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          final text = editController.text
                                              .trim();
                                          if (text.isNotEmpty) {
                                            setState(() {
                                              sub["title"] = text;
                                            });
                                            if (activeTask != null) {
                                              await DBHelper().updateTask(
                                                activeTask!,
                                              );
                                            }
                                            setSubtaskState(() {});
                                          }
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: Text(L10n.tr("Save")),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () async {
                                setState(() {
                                  subtasks.removeAt(index);
                                });
                                if (activeTask != null) {
                                  await DBHelper().updateTask(activeTask!);
                                }
                                setSubtaskState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const Divider(height: 25),
              // Add subtask inline input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pomodoroSubtaskController,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.button,
                        fontFamily: "Nunito",
                      ),
                      decoration: InputDecoration(
                        hintText: L10n.tr("Add quick subtask..."),
                        hintStyle: TextStyle(
                          color: AppColors.button.withValues(alpha: 0.4),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.containerline1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.containerline1.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.button),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final text = _pomodoroSubtaskController.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          subtasks.add({"title": text, "isDone": false});
                        });
                        if (activeTask != null) {
                          await DBHelper().updateTask(activeTask!);
                        }
                        setSubtaskState(() {});
                        _pomodoroSubtaskController.clear();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSection() {
    return Container2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined, color: AppColors.button),
              const SizedBox(width: 8),
              Text(
                L10n.tr("Focus Settings"),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                  fontFamily: "Quicksand",
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(
            height: 1,
            color: AppColors.containerline2.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                L10n.tr("Focus Session Duration"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                  fontFamily: "Quicksand",
                ),
              ),
              Text(
                L10n.tr("${focusDuration ~/ 60} mins"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                  fontFamily: "Nunito",
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.button,
              inactiveTrackColor: AppColors.button.withValues(alpha: 0.15),
              thumbColor: AppColors.button,
              overlayColor: AppColors.button.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: (focusDuration ~/ 60).toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('focus_duration', val.round());
                setState(() {
                  focusDuration = val.round() * 60;
                  if (!isRunning && isFocusTime) {
                    totalSeconds = focusDuration;
                    secondsRemaining = focusDuration;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: AppColors.containerline2.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                L10n.tr("Break Session Duration"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                  fontFamily: "Quicksand",
                ),
              ),
              Text(
                L10n.tr("${breakDuration ~/ 60} mins"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.button,
                  fontFamily: "Nunito",
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.button,
              inactiveTrackColor: AppColors.button.withValues(alpha: 0.15),
              thumbColor: AppColors.button,
              overlayColor: AppColors.button.withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: (breakDuration ~/ 60).toDouble(),
              min: 5,
              max: 30,
              divisions: 5,
              onChanged: (val) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('break_duration', val.round());
                setState(() {
                  breakDuration = val.round() * 60;
                  if (!isRunning && !isFocusTime) {
                    totalSeconds = breakDuration;
                    secondsRemaining = breakDuration;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: AppColors.containerline2.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  L10n.tr("Background Sound"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.button,
                    fontFamily: "Quicksand",
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedSound,
                dropdownColor: Colors.white,
                iconEnabledColor: AppColors.button,
                style: TextStyle(
                  color: AppColors.button,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Quicksand",
                ),
                underline: const SizedBox(),
                items:
                    const [
                          "None",
                          "Fireplace",
                          "Forest",
                          "Gentle Rain",
                          "Heavy Rain",
                          "Night Ambience",
                          "Ocean Waves",
                          "Stream",
                          "Underwater Ambience",
                        ]
                        .map(
                          (val) =>
                              DropdownMenuItem(value: val, child: Text(L10n.tr(val))),
                        )
                        .toList(),
                onChanged: (value) async {
                  if (value != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('focus_sound', value);
                    setState(() {
                      _selectedSound = value;
                    });
                    _playBackgroundSound();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BgContainer(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Center(
                        child: Text(
                          taskName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.normaltext,
                            fontFamily: "Quicksand",
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularPercentIndicator(
                      radius: 130,
                      lineWidth: 12,
                      percent: progress,
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: Colors.white38,
                      progressColor: isFocusTime
                          ? AppColors.button
                          : Colors.white,
                    ),

                    isFocusTime
                        ? SpinKitRipple(size: 260, color: Colors.white24)
                        : SpinKitPouringHourGlass(
                            size: 200,
                            color: Colors.white24,
                          ),

                    Positioned(
                      top: 50,
                      child: Text(
                        isFocusTime
                            ? L10n.tr("Focus Time")
                            : L10n.tr("Break Time"),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.normaltext,
                          fontFamily: "Quicksand",
                        ),
                      ),
                    ),

                    Positioned(
                      top: 80,
                      child: Text(
                        formatTime(),
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: AppColors.normaltext,
                          fontFamily: "Nunito",
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: 45,
                      child: GestureDetector(
                        onTap: toggleTimer,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.button,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.button.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Center(
                child: TextButton.icon(
                  onPressed: resetTimer,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.button,
                    size: 18,
                  ),
                  label: Text(
                    L10n.tr("Reset Timer"),
                    style: TextStyle(
                      color: AppColors.button,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Quicksand",
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),

              if (activeTask != null) ...[
                const SizedBox(height: 10),
                _buildSubtasksSection(),
              ],

              const SizedBox(height: 10),
              _buildSettingsSection(),
            ],
          ),
        ),
      ),
    );
  }

  void _schedulePomodoroNotifications() {
    NotificationHelper().cancelPomodoroNotifications();

    if (isFocusTime) {
      if (secondsRemaining > 300) {
        NotificationHelper().schedulePomodoroNotification(
          id: 9990,
          title: L10n.tr("Focus Time Almost Over"),
          body: L10n.tr("5 minutes left before break time starts."),
          seconds: secondsRemaining - 300,
        );
      }
      NotificationHelper().schedulePomodoroNotification(
        id: 9991,
        title: L10n.tr("Focus Time Ended"),
        body: L10n.tr("Great job! Now take a break."),
        seconds: secondsRemaining,
      );
    } else {
      if (secondsRemaining > 60) {
        NotificationHelper().schedulePomodoroNotification(
          id: 9992,
          title: L10n.tr("Break Time Almost Over"),
          body: L10n.tr("1 minute left before focus time starts."),
          seconds: secondsRemaining - 60,
        );
      }
      NotificationHelper().schedulePomodoroNotification(
        id: 9993,
        title: L10n.tr("Break Time Ended"),
        body: L10n.tr("Time to focus again! Let's get back to work."),
        seconds: secondsRemaining,
      );
    }
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (secondsRemaining > 0) {
        setState(() {
          secondsRemaining--;
        });
      } else {
        switchMode();
      }
    });
  }

  void pauseTimer() {
    timer?.cancel();
    NotificationHelper().cancelPomodoroNotifications();
    setState(() {
      isRunning = false;
    });
    _playBackgroundSound();
  }

  void resumeTimer() {
    setState(() {
      isRunning = true;
    });
    startTimer();
    _schedulePomodoroNotifications();
    _playBackgroundSound();
  }

  void toggleTimer() {
    if (isRunning) {
      pauseTimer();
    } else {
      resumeTimer();
    }
  }

  void switchMode() {
    final bool completedFocus = isFocusTime;
    setState(() {
      isFocusTime = !isFocusTime;

      if (isFocusTime) {
        totalSeconds = focusDuration;
        secondsRemaining = focusDuration;
      } else {
        totalSeconds = breakDuration;
        secondsRemaining = breakDuration;
      }
    });
    _schedulePomodoroNotifications();

    if (completedFocus) {
      _saveFocusSession(focusDuration ~/ 60);
      NotificationHelper().showInstantPomodoroNotification(
        id: 9994,
        title: L10n.tr("Focus Time Ended"),
        body: L10n.tr("Great job! Now take a break."),
      );
    } else {
      NotificationHelper().showInstantPomodoroNotification(
        id: 9995,
        title: L10n.tr("Break Time Ended"),
        body: L10n.tr("Time to focus again! Let's get back to work."),
      );
    }
  }

  Future<void> _saveFocusSession(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 1;
      await DBHelper().insertFocusSession(userId, minutes);
      TaskNotifier.notify();
    } catch (e) {
      debugPrint("Error saving focus session: $e");
    }
  }

  void resetTimer() {
    timer?.cancel();
    NotificationHelper().cancelPomodoroNotifications();
    setState(() {
      isRunning = false;
      isFocusTime = true;

      totalSeconds = focusDuration;
      secondsRemaining = focusDuration;
    });
    _playBackgroundSound();
  }
}
