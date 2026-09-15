import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:kinday/pages/service/google_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarEventCard extends StatelessWidget {
  final CalendarEventItem event;
  final VoidCallback? onConverted;

  const CalendarEventCard({
    super.key,
    required this.event,
    this.onConverted,
  });

  void _showConvertToTaskDialog(BuildContext context) {
    int selectedEnergy = 3;
    int selectedPriority = 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.button.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.button,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          L10n.tr("Convert to KinDay Task"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.button,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppColors.button.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        event.formattedTimeRange,
                        style: TextStyle(
                          fontFamily: "Nunito",
                          fontSize: 13,
                          color: AppColors.button.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    L10n.tr("Estimated Energy Level"),
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.button,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      final lvl = index + 1;
                      final isSelected = selectedEnergy == lvl;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedEnergy = lvl;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.button
                                : AppColors.button.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.button
                                  : AppColors.button.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.energy_savings_leaf_rounded,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.button,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "$lvl",
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.button,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final userId = prefs.getInt('user_id') ?? 1;

                      final String? dueTimeStr = event.isAllDay
                          ? null
                          : "${event.startDateTime.hour.toString().padLeft(2, '0')}:${event.startDateTime.minute.toString().padLeft(2, '0')}";

                      final newTask = TaskCard(
                        title: event.title,
                        description: event.description,
                        energylvl: selectedEnergy,
                        prioritytask: selectedPriority,
                        startDate: event.startDateTime,
                        dueDate: event.startDateTime,
                        dueTime: dueTimeStr,
                        repeatType: RepeatType.none,
                        createdAt: DateTime.now(),
                      );

                      final insertedId = await DBHelper().insertTask(
                        newTask,
                        userId,
                      );
                      newTask.id = insertedId;

                      await GoogleCalendarService().markEventAsConverted(
                        event.id,
                        insertedId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      TaskNotifier.notify();
                      onConverted?.call();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              L10n.tr("Event converted to KinDay Task!"),
                            ),
                            backgroundColor: AppColors.button,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      L10n.tr("Save as Task"),
                      style: const TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E2235)
            : (event.isGoogleTask
                ? const Color(0xFFEDF8F2) // Soft pastel green for Google Tasks
                : const Color(0xFFEBF3FC)), // Soft pastel blue for Calendar
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: event.isGoogleTask
              ? const Color(0xFF34A853).withValues(alpha: 0.35)
              : const Color(0xFF8BB7F0).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: event.isGoogleTask
                        ? const Color(0xFF0F9D58).withValues(alpha: 0.12)
                        : const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        event.isGoogleTask
                            ? Icons.task_alt_rounded
                            : Icons.event_note_rounded,
                        size: 13,
                        color: event.isGoogleTask
                            ? const Color(0xFF0F9D58)
                            : const Color(0xFF4285F4),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.isGoogleTask
                              ? (event.calendarName != null && event.calendarName!.trim().isNotEmpty
                                  ? "GTasks • ${event.calendarName}"
                                  : "Google Tasks")
                              : (event.calendarName != null && event.calendarName!.trim().isNotEmpty
                                  ? "GCal • ${event.calendarName}"
                                  : "Google Calendar"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: event.isGoogleTask
                                ? const Color(0xFF0F9D58)
                                : const Color(0xFF4285F4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.normaltext.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.formattedTimeRange,
                    style: TextStyle(
                      fontFamily: "Nunito",
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.normaltext.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.title,
            style: TextStyle(
              fontFamily: "Quicksand",
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.button,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (event.description != null && event.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description!.trim(),
              style: TextStyle(
                fontFamily: "Nunito",
                fontSize: 12,
                color: AppColors.normaltext.withValues(alpha: 0.65),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: event.isConvertedToTask
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          L10n.tr("Added to KinDay"),
                          style: const TextStyle(
                            fontFamily: "Quicksand",
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _showConvertToTaskDialog(context),
                    icon: const Icon(Icons.add_task_rounded, size: 14),
                    label: Text(
                      L10n.tr("+ Make KinDay Task"),
                      style: const TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.button,
                      side: BorderSide(
                        color: AppColors.button.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
