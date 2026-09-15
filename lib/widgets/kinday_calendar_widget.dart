import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/pages/service/google_calendar_service.dart';
import 'package:kinday/pages/service/repeat_task_service.dart';

class KinDayCalendarWidget extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<TaskCard> tasks;
  final List<CalendarEventItem> gcalEvents;
  final bool isMonthlyMode;

  const KinDayCalendarWidget({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.tasks = const [],
    this.gcalEvents = const [],
    this.isMonthlyMode = false,
  });

  @override
  State<KinDayCalendarWidget> createState() => _KinDayCalendarWidgetState();
}

class _KinDayCalendarWidgetState extends State<KinDayCalendarWidget> {
  late DateTime _focusedDate;

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(covariant KinDayCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _focusedDate = widget.selectedDate;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasTasksOnDate(DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    for (final task in widget.tasks) {
      if (task.isCompleted) continue;
      if (RepeatTaskService.shouldShowTaskOnDate(task, targetDay)) {
        return true;
      }
    }
    return false;
  }

  bool _hasGcalEventsOnDate(DateTime date) {
    final targetDay = DateTime(date.year, date.month, date.day);
    for (final event in widget.gcalEvents) {
      final eventDay = DateTime(
        event.startDateTime.year,
        event.startDateTime.month,
        event.startDateTime.day,
      );
      if (_isSameDay(eventDay, targetDay)) {
        return true;
      }
    }
    return false;
  }

  List<DateTime> _getDaysInWeek(DateTime date) {
    // Start week on Monday
    final int weekday = date.weekday; // 1 = Mon, 7 = Sun
    final DateTime monday = date.subtract(Duration(days: weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  List<DateTime?> _getDaysInMonthGrid(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final lastDayOfMonth = DateTime(date.year, date.month + 1, 0);

    final int startOffset = firstDayOfMonth.weekday - 1; // 0 for Monday
    final int totalDays = lastDayOfMonth.day;

    final List<DateTime?> grid = [];
    for (int i = 0; i < startOffset; i++) {
      grid.add(null);
    }
    for (int i = 1; i <= totalDays; i++) {
      grid.add(DateTime(date.year, date.month, i));
    }
    return grid;
  }

  void _previous() {
    setState(() {
      if (widget.isMonthlyMode) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1, 1);
      } else {
        _focusedDate = _focusedDate.subtract(const Duration(days: 7));
      }
    });
  }

  void _next() {
    setState(() {
      if (widget.isMonthlyMode) {
        _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1, 1);
      } else {
        _focusedDate = _focusedDate.add(const Duration(days: 7));
      }
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDate = now;
    });
    widget.onDateSelected(now);
  }

  String _formatMonthYear(DateTime date) {
    const monthKeys = [
      "",
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    if (L10n.isJa) {
      return "${date.year}年${date.month}月";
    }
    final mKey = date.month >= 1 && date.month <= 12 ? monthKeys[date.month] : "";
    return "${L10n.tr(mKey)} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : AppColors.container2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1,
          color: isDark
              ? AppColors.button.withValues(alpha: 0.15)
              : AppColors.containerline2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Month, Navigation & Today jump
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatMonthYear(_focusedDate),
                  style: TextStyle(
                    fontFamily: "Quicksand",
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.button,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_isSameDay(_focusedDate, now))
                GestureDetector(
                  onTap: _jumpToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: AppColors.button.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      L10n.tr("Today"),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: AppColors.button,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: AppColors.button,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _previous,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.button,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _next,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Weekday Labels (Mon to Sun) - 7 equal columns
          Row(
            children: (L10n.isJa
                ? const ["月", "火", "水", "木", "金", "土", "日"]
                : (L10n.isId
                    ? const ["S", "S", "R", "K", "J", "S", "M"]
                    : const ["M", "T", "W", "T", "F", "S", "S"])).map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.button.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Date Cells
          if (!widget.isMonthlyMode)
            _buildWeeklyView()
          else
            _buildMonthlyView(),
        ],
      ),
    );
  }

  Widget _buildWeeklyView() {
    final days = _getDaysInWeek(_focusedDate);
    return Row(
      children: days.map((date) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _buildDayCell(date, height: 48),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthlyView() {
    final grid = _getDaysInMonthGrid(_focusedDate);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: grid.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 2,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final date = grid[index];
        if (date == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: _buildDayCell(date),
        );
      },
    );
  }

  Widget _buildDayCell(DateTime date, {double? height}) {
    final isSelected = _isSameDay(date, widget.selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final hasTasks = _hasTasksOnDate(date);
    final hasGcal = _hasGcalEventsOnDate(date);

    return GestureDetector(
      onTap: () {
        setState(() {
          _focusedDate = date;
        });
        widget.onDateSelected(date);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: height,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.button : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(
                  color: AppColors.button.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${date.day}",
              style: TextStyle(
                fontFamily: "Quicksand",
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected
                    ? Colors.white
                    : (isToday
                        ? AppColors.button
                        : AppColors.button.withValues(alpha: 0.85)),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasTasks)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : AppColors.button,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasGcal)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.lightBlueAccent
                          : const Color(0xFF4285F4),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (!hasTasks && !hasGcal)
                  const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
