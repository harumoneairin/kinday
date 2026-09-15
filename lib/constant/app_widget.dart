import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/pages/botnavpage/pomodoropage.dart';
import 'package:kinday/pages/mainpage.dart';

// Gradient BG
class BgContainer extends StatelessWidget {
  const BgContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, AppColors.background2],
        ),
      ),
      // height: double.infinity,
      // width: double.infinity,
      child: child,
    );
  }
}

// Dark Purple Button
class AccButton extends StatelessWidget {
  const AccButton({
    super.key,
    this.sign = " ",
    required this.warnaBox,
    required this.destination,
    this.leadImage,
    this.buttonSize = 16,
    required this.textbuttoncolor,
    this.onPressed,
  });

  final String sign;
  final Color warnaBox;
  final Color textbuttoncolor;
  final double buttonSize;
  final Widget destination;
  final String? leadImage;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // width: double.infinity,
      child: ElevatedButton(
        onPressed:
            onPressed ??
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              );
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: warnaBox,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadImage != null) ...[
              Image.asset(
                leadImage!,
                width: 24,
                height: 24,
                alignment: AlignmentGeometry.center,
              ),
            ],
            SizedBox(width: leadImage != null ? 10 : 0),
            Text(
              sign,
              style: TextStyle(color: textbuttoncolor, fontSize: buttonSize),
            ),
          ],
        ),
      ),
    );
  }
}

// small button
class SmallButton extends StatelessWidget {
  const SmallButton({
    super.key,
    required this.sign,
    required this.warnaBox,
    this.destination,
    this.leadImage,
    this.buttonSize = 16,
    required this.textbuttoncolor,
    this.onPressed,
  });

  final String sign;
  final Color warnaBox;
  final Color textbuttoncolor;
  final double buttonSize;
  final Widget? destination;
  final String? leadImage;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // width: double.infinity,
      child: ElevatedButton(
        onPressed:
            onPressed ??
            () {
              if (destination != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => destination!),
                );
              }
            },
        style: ElevatedButton.styleFrom(
          backgroundColor: warnaBox,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadImage != null) ...[
              Image.asset(leadImage!, width: 24, height: 24),
              const SizedBox(width: 10),
            ],
            Text(
              sign,
              style: TextStyle(color: textbuttoncolor, fontSize: buttonSize),
            ),
          ],
        ),
      ),
    );
  }
}

//form field login. register
class InputField extends StatefulWidget {
  const InputField({
    super.key,
    required this.hint,
    required this.icon,
    this.pwhide = false,
    this.controller,
    this.validator,
    this.focusNode,
  });

  final String hint;
  final IconData icon;
  final bool pwhide;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.pwhide;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: const TextStyle(color: Color(0xFF5852A0)),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Icon(widget.icon, color: AppColors.background),
        ),
        suffixIcon: widget.pwhide
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.background,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : null,
        hintText: widget.hint,
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
          borderSide: BorderSide(color: Colors.indigo.shade200, width: 1.5),
        ),

        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      obscureText: _obscureText,
      validator: widget.validator,
    );
  }
}

// TextEditingController that prevents accidental text selection on cursor drag/tap
class NonSelectingTextEditingController extends TextEditingController {
  NonSelectingTextEditingController({super.text});

  @override
  set value(TextEditingValue newValue) {
    if (!newValue.selection.isCollapsed && newValue.selection.isValid) {
      // Allow Select All if explicitly triggered (covers the entire text)
      if (newValue.selection.baseOffset == 0 &&
          newValue.selection.extentOffset == newValue.text.length &&
          newValue.text.length > 1) {
        super.value = newValue;
        return;
      }

      // Collapse partial selection to extentOffset (where the user's cursor/finger is)
      final safeOffset = newValue.selection.extentOffset.clamp(
        0,
        newValue.text.length,
      );
      super.value = newValue.copyWith(
        selection: TextSelection.collapsed(offset: safeOffset),
      );
      return;
    }
    super.value = newValue;
  }
}

// Container white
class Container1 extends StatelessWidget {
  const Container1({super.key, this.height, this.width, required this.child});

  final double? height;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 20, left: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1,
          style: BorderStyle.solid,
          color: AppColors.background,
        ),
      ),
      height: height,
      child: child,
    );
  }
}

//container leaning blue
class Container2 extends StatelessWidget {
  const Container2({super.key, this.height, this.width, required this.child});

  final double? height;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 20, left: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.container2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1,
          style: BorderStyle.solid,
          color: AppColors.containerline2,
        ),
      ),
      height: height,
      child: child,
    );
  }
}

//container leaning pink
class Container3 extends StatelessWidget {
  const Container3({super.key, this.height, this.width, required this.child});

  final double? height;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 20, left: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.container1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          width: 1,
          style: BorderStyle.solid,
          color: AppColors.containerline1,
        ),
      ),
      height: height,
      child: child,
    );
  }
}

//Energy Indicator
class EnergyIndicator extends StatelessWidget {
  final int level;

  const EnergyIndicator({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (index) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            width: 12,
            height: 10,
            decoration: BoxDecoration(
              color: index < level ? AppColors.button : Colors.grey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}

enum RepeatType { none, daily, selectedDays, weekly, monthly, yearly }

// ignore: must_be_immutable
class TaskCard extends StatelessWidget {
  TaskCard({
    super.key,
    this.id,
    required this.title,
    this.description,
    required this.energylvl,
    this.prioritytask = 1,
    DateTime? startDate,
    this.dueDate,
    this.dueTime,
    this.onTap,
    this.isCompleted = false,
    this.maxlinesdesc = 1,
    this.maxlinestitle = 2,
    this.reminderMinutes,
    List<Map<String, dynamic>>? subtasks,
    this.repeatType = RepeatType.none,
    List<int>? selectedWeekDays,
    this.finishDate,
    DateTime? createdAt,
    this.lastOccurrenceDate,
  }) : subtasks = subtasks ?? [],
       selectedWeekDays = selectedWeekDays ?? [],
       createdAt = createdAt ?? DateTime.now(),
       startDate = startDate ?? (dueDate ?? DateTime.now());

  static TaskCard? activePomodoroTask;

  int? id;
  String title;
  String? description;
  int energylvl;
  int prioritytask;
  DateTime? startDate;
  DateTime? dueDate;
  String? dueTime;
  VoidCallback? onTap;
  bool isCompleted;
  int maxlinesdesc;
  int maxlinestitle;
  int? reminderMinutes;
  List<Map<String, dynamic>> subtasks;
  RepeatType repeatType;
  List<int> selectedWeekDays;
  DateTime? finishDate;
  DateTime createdAt;
  DateTime? lastOccurrenceDate;

  String get _energyLabel {
    switch (energylvl) {
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

  String _getRepeatLabel() {
    String timeStr = dueTime != null && dueTime!.isNotEmpty ? " $dueTime" : "";
    switch (repeatType) {
      case RepeatType.daily:
        return "${L10n.tr("Every Day")}$timeStr";
      case RepeatType.selectedDays:
        final days = selectedWeekDays.map((d) {
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
        return "${days.isEmpty ? L10n.tr('Repeat') : days}$timeStr";
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        height: 240,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: Colors.white70,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: 1,
            style: BorderStyle.solid,
            color: AppColors.background,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (repeatType != RepeatType.none) ...[
                  Icon(Icons.repeat, size: 12, color: AppColors.button),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getRepeatLabel(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (dueDate != null) ...[
                  Icon(Icons.calendar_today, size: 11, color: AppColors.button),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dueTime != null && dueTime!.isNotEmpty
                          ? "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}  $dueTime"
                          : "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (startDate != null) ...[
                  Icon(Icons.play_circle_outline, size: 11, color: AppColors.button),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.button,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: maxlinestitle,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              description ?? "",
              style: AppTextStyles.bodytext.copyWith(fontSize: 13),
              maxLines: maxlinesdesc,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Spacer(),

            Row(
              children: [
                Icon(
                  Icons.energy_savings_leaf,
                  size: 15,
                  color: AppColors.button,
                ),
                const SizedBox(width: 4),
                Text(_energyLabel, style: const TextStyle(fontSize: 12)),
                Spacer(),
                Container(
                  width: 60,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AppColors.button,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: PriorityIndicator(priority: prioritytask),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                onPressed: () {
                  TaskCard.activePomodoroTask = this;
                  final mainState = context
                      .findAncestorStateOfType<MainpageState>();
                  if (mainState != null) {
                    mainState.changeTab(2);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Pomodoropage(task: this),
                      ),
                    );
                  }
                },
                child: Text(
                  L10n.tr("Start Focus"),
                  style: const TextStyle(
                    fontFamily: "Nunito",
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PriorityIndicator extends StatelessWidget {
  final int priority;

  const PriorityIndicator({super.key, required this.priority});

  Color flagColor() {
    switch (priority) {
      case 3:
        return Colors.red; // High
      case 2:
        return Colors.orange; // Medium
      default:
        return Colors.green; // Low
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        priority,
        (index) => Icon(Icons.flag, size: 15, color: flagColor()),
      ),
    );
  }
}

class EnergyLevel extends StatelessWidget {
  final int energy;

  const EnergyLevel({super.key, required this.energy});

  String energyConvert() {
    switch (energy) {
      case 5:
        return L10n.tr("High");
      case 4:
        return L10n.tr("Mid-High");
      case 3:
        return L10n.tr("Mid");
      case 2:
        return L10n.tr("Mid-Low");
      case 1:
        return L10n.tr("Low");
      default:
        return L10n.tr("Low");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(Icons.energy_savings_leaf), Text(energyConvert())],
    );
  }
}
