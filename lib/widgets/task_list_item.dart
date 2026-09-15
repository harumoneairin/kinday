import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/pages/botnavpage/pomodoropage.dart';
import 'package:kinday/pages/mainpage.dart';
import 'package:kinday/pages/service/repeat_task_service.dart';

class TaskListItem extends StatelessWidget {
  final TaskCard task;
  final VoidCallback onTap;
  final ValueChanged<bool?>? onCompletedChanged;

  const TaskListItem({
    super.key,
    required this.task,
    required this.onTap,
    this.onCompletedChanged,
  });

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

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      default:
        return Colors.teal.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(task.prioritytask);
    final completedSubtasks =
        task.subtasks.where((s) => s['is_completed'] == 1 || s['is_completed'] == true).length;
    final totalSubtasks = task.subtasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E202E)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.containerline1,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Completion Checkbox
                if (onCompletedChanged != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: task.isCompleted,
                        onChanged: onCompletedChanged,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        activeColor: AppColors.button,
                        side: BorderSide(
                          color: AppColors.button.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                // 2. Priority indicator vertical line
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Task Title, Description & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        task.title,
                        style: TextStyle(
                          fontFamily: "Quicksand",
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark
                              ? (task.isCompleted ? Colors.white38 : Colors.white)
                              : (task.isCompleted
                                  ? AppColors.normaltext.withValues(alpha: 0.45)
                                  : AppColors.button),
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Description preview if available
                      if (task.description != null &&
                          task.description!.trim().isNotEmpty &&
                          !task.isCompleted) ...[
                        const SizedBox(height: 2),
                        Text(
                          task.description!.trim(),
                          style: TextStyle(
                            fontFamily: "Nunito",
                            fontSize: 11,
                            color: AppColors.normaltext.withValues(alpha: 0.65),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 4),

                      // Metadata Tags Row (Energy, Due Date / Repeat, Subtasks)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Energy Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.button.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.energy_savings_leaf_rounded,
                                  size: 11,
                                  color: AppColors.button,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "${_getEnergyLabel(task.energylvl)} (${task.energylvl})",
                                  style: TextStyle(
                                    fontFamily: "Nunito",
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: AppColors.button,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Due Date or Repeat Tag
                          if (task.repeatType != RepeatType.none)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 11,
                                  color: AppColors.button.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  RepeatTaskService.getRepeatSubtitle(task),
                                  style: TextStyle(
                                    fontFamily: "Nunito",
                                    fontSize: 10,
                                    color: AppColors.button.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else if (task.dueDate != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 10,
                                  color: AppColors.button.withValues(alpha: 0.75),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  task.dueTime != null && task.dueTime!.isNotEmpty
                                      ? "${task.dueDate!.day}/${task.dueDate!.month} • ${task.dueTime}"
                                      : "${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}",
                                  style: TextStyle(
                                    fontFamily: "Nunito",
                                    fontSize: 10,
                                    color: AppColors.button.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                          // Subtasks count badge if any
                          if (totalSubtasks > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 11,
                                  color: AppColors.normaltext.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "$completedSubtasks/$totalSubtasks",
                                  style: TextStyle(
                                    fontFamily: "Nunito",
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.normaltext.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // 4. Quick Pomodoro / Focus Button
                if (!task.isCompleted)
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 24,
                      color: AppColors.button,
                    ),
                    tooltip: L10n.tr("Start Focus Session"),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      TaskCard.activePomodoroTask = task;
                      final mainState =
                          context.findAncestorStateOfType<MainpageState>();
                      if (mainState != null) {
                        mainState.changeTab(2);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Pomodoropage(task: task),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
