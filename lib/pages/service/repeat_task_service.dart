import 'package:flutter/material.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';

class RepeatTaskService {
  /// Checks if a [task] should appear on a specific [targetDate].
  static bool shouldShowTaskOnDate(TaskCard task, DateTime targetDate) {
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (task.repeatType == RepeatType.none) {
      final start = task.startDate ?? task.dueDate ?? task.createdAt;
      final startDay = DateTime(start.year, start.month, start.day);

      // If looking at a date before start date, do not show
      if (targetDay.isBefore(startDay)) {
        return false;
      }

      // If no due date, show on start date or if still active today
      if (task.dueDate == null) {
        if (isSameDay(startDay, targetDay)) return true;
        return isSameDay(targetDay, today) && !task.isCompleted;
      }

      final dueDay = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);

      // If targetDay is today and task is overdue (dueDay < today) and not completed, show today
      if (isSameDay(targetDay, today) && !task.isCompleted && dueDay.isBefore(today)) {
        return true;
      }

      // Target is on or between startDay and dueDay
      return (targetDay.isAtSameMomentAs(startDay) || targetDay.isAfter(startDay)) &&
          (targetDay.isAtSameMomentAs(dueDay) || targetDay.isBefore(dueDay));
    }

    // For repeatable tasks
    final start = task.startDate ?? task.dueDate ?? task.createdAt;
    final startDay = DateTime(start.year, start.month, start.day);

    if (targetDay.isBefore(startDay)) {
      return false;
    }

    if (task.finishDate != null) {
      final finishDay = DateTime(task.finishDate!.year, task.finishDate!.month, task.finishDate!.day);
      if (targetDay.isAfter(finishDay)) {
        return false;
      }
    }

    switch (task.repeatType) {
      case RepeatType.daily:
        return true;
      case RepeatType.selectedDays:
        return task.selectedWeekDays.contains(targetDay.weekday);
      case RepeatType.weekly:
        return targetDay.weekday == startDay.weekday;
      case RepeatType.monthly:
        return targetDay.day == startDay.day;
      case RepeatType.yearly:
        return targetDay.day == startDay.day && targetDay.month == startDay.month;
      case RepeatType.none:
        return false;
    }
  }

  /// Calculates the effective due date for a [task] relative to [referenceDate].
  static DateTime getEffectiveDueDate(TaskCard task, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final refDay = DateTime(ref.year, ref.month, ref.day);

    if (task.repeatType == RepeatType.none) {
      if (task.dueDate != null) {
        return DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      }
      final start = task.startDate ?? task.createdAt;
      return DateTime(start.year, start.month, start.day);
    }

    // For repeated task
    if (shouldShowTaskOnDate(task, refDay)) {
      return refDay;
    }

    final nextDate = getNextOccurrenceDate(task, fromDate: refDay);
    if (nextDate != null) {
      return nextDate;
    }

    final start = task.startDate ?? task.dueDate ?? task.createdAt;
    return DateTime(start.year, start.month, start.day);
  }

  /// Calculates the effective due date and time for a [task].
  static DateTime getEffectiveDueDateTime(TaskCard task, {DateTime? referenceDate}) {
    final effDate = getEffectiveDueDate(task, referenceDate: referenceDate);
    final timeOfDay = parseTimeOfDay(task.dueTime);
    if (timeOfDay == null) {
      return DateTime(effDate.year, effDate.month, effDate.day, 23, 59, 59);
    }
    return DateTime(effDate.year, effDate.month, effDate.day, timeOfDay.hour, timeOfDay.minute);
  }

  /// Finds the next occurrence date on or after [fromDate].
  static DateTime? getNextOccurrenceDate(TaskCard task, {DateTime? fromDate}) {
    final startFrom = fromDate ?? DateTime.now();
    DateTime current = DateTime(startFrom.year, startFrom.month, startFrom.day);

    // Look ahead up to 366 days
    for (int i = 0; i <= 366; i++) {
      final candidate = current.add(Duration(days: i));
      if (shouldShowTaskOnDate(task, candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// Parses a string time representation into [TimeOfDay].
  static TimeOfDay? parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final clean = timeStr.trim();
      final parts = clean.split(RegExp(r'[:.]'));
      if (parts.length >= 2) {
        final hourPart = parts[0].replaceAll(RegExp(r'\D'), '');
        final minutePart = parts[1].replaceAll(RegExp(r'\D'), '');
        if (hourPart.isEmpty || minutePart.isEmpty) return null;

        int hour = int.parse(hourPart);
        int minute = int.parse(minutePart);

        final lower = clean.toLowerCase();
        if (lower.contains('pm') && hour < 12) {
          hour += 12;
        } else if (lower.contains('am') && hour == 12) {
          hour = 0;
        }
        return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
      }
    } catch (e) {
      debugPrint("Error parsing TimeOfDay ($timeStr): $e");
    }
    return null;
  }

  /// Returns a human-friendly localized description of the task's repeat schedule.
  static String getRepeatSubtitle(TaskCard task) {
    String timeStr = task.dueTime != null && task.dueTime!.isNotEmpty ? " ${task.dueTime}" : "";
    switch (task.repeatType) {
      case RepeatType.daily:
        return "${L10n.tr("Every Day")}$timeStr";
      case RepeatType.selectedDays:
        final days = task.selectedWeekDays.map((d) {
          switch (d) {
            case 1:
              return L10n.tr("Mon");
            case 2:
              return L10n.tr("Tue");
            case 3:
              return L10n.tr("Wed");
            case 4:
              return L10n.tr("Thu");
            case 5:
              return L10n.tr("Fri");
            case 6:
              return L10n.tr("Sat");
            case 7:
              return L10n.tr("Sun");
            default:
              return "";
          }
        }).join(", ");
        return "${days.isEmpty ? L10n.tr('Repeat', 'Ulang') : days}$timeStr";
      case RepeatType.weekly:
        return "${L10n.tr("Every Week")}$timeStr";
      case RepeatType.monthly:
        return "${L10n.tr("Every Month")}$timeStr";
      case RepeatType.yearly:
        return "${L10n.tr("Every Year")}$timeStr";
      case RepeatType.none:
        return "";
    }
  }

  /// Centralized daily reset check for all recurring tasks belonging to [userId].
  static Future<void> checkAndResetDailyRepeatTasks(int userId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final dbTasks = await DBHelper().getTasksForUser(userId);

      for (var task in dbTasks) {
        if (task.repeatType != RepeatType.none) {
          final lastOccur = task.lastOccurrenceDate;
          if (lastOccur == null) {
            task.lastOccurrenceDate = now;
            await DBHelper().updateTask(task);
          } else {
            final lastOccurDay = DateTime(
              lastOccur.year,
              lastOccur.month,
              lastOccur.day,
            );
            if (lastOccurDay.isBefore(todayStart)) {
              task.isCompleted = false;
              for (var sub in task.subtasks) {
                sub['isDone'] = false;
                sub['isCompleted'] = false;
              }
              task.lastOccurrenceDate = now;
              await DBHelper().updateTask(task);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error resetting daily repeat tasks: $e");
    }
  }

  static bool isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
