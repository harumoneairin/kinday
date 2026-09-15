import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_textstyle.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/database/db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class EnergyPage extends StatefulWidget {
  const EnergyPage({super.key});

  @override
  State<EnergyPage> createState() => _EnergyPageState();
}

class EnergyLogData {
  final double energy;
  final double hour;

  EnergyLogData({required this.energy, required this.hour});
}

class _EnergyPageState extends State<EnergyPage> {
  int? _userId;
  int _currentEnergyLvl = 3;
  List<EnergyLogData> scatterData = [];
  List<EnergyLogData> averageCurveData = [];

  // Insight computed states
  String _highestEnergyHourStr = "09:00";
  String _lowestEnergyHourStr = "15:00";
  String _productivityDropDay = "Friday";
  double _avgEnergyThisWeek = 3.6;
  double _avgEnergyLastWeek = 3.2;
  String _energyComparisonStr = "stable";
  bool _hasHourlyEnergyData = false;
  bool _hasProductivityData = false;
  bool _hasWeeklyEnergyData = false;


  @override
  void initState() {
    super.initState();
    _loadEnergyLogs();
  }

  Future<void> _loadEnergyLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;

    final dbHelper = DBHelper();
    final latestEnergy = await dbHelper.getLatestEnergyForUser(userId);
    final dbLogs = await dbHelper.getEnergyLogsForUser(userId);

    final List<EnergyLogData> loadedLogs = [];
    for (var log in dbLogs) {
      try {
        final timestampStr = log['timestamp'] as String;
        final dt = DateTime.parse(timestampStr);
        final hourDouble = dt.hour + (dt.minute / 60.0);
        loadedLogs.add(
          EnergyLogData(
            energy: (log['energy'] as int).toDouble(),
            hour: double.parse(hourDouble.toStringAsFixed(2)),
          ),
        );
      } catch (e) {
        debugPrint("Error parsing energy log timestamp: $e");
      }
    }

    // --- 1. Peak & Valley Hours calculation & Average Rhythm Curve ---
    String highestHourStr = "09:00";
    String lowestHourStr = "15:00";
    final List<EnergyLogData> avgCurve = [];

    if (dbLogs.isNotEmpty) {
      final Map<int, List<int>> energyByHour = {};
      for (var log in dbLogs) {
        try {
          final timestampStr = log['timestamp'] as String;
          final dt = DateTime.parse(timestampStr);
          final hour = dt.hour;
          final energy = log['energy'] as int;
          energyByHour.putIfAbsent(hour, () => []).add(energy);
        } catch (_) {}
      }

      if (energyByHour.isNotEmpty) {
        int maxHour = -1;
        double maxAvg = -1.0;
        int minHour = -1;
        double minAvg = 99.0;

        energyByHour.forEach((hour, list) {
          final double avg = list.reduce((a, b) => a + b) / list.length;
          if (avg > maxAvg) {
            maxAvg = avg;
            maxHour = hour;
          }
          if (avg < minAvg) {
            minAvg = avg;
            minHour = hour;
          }

          avgCurve.add(
            EnergyLogData(
              hour: hour.toDouble(),
              energy: double.parse(avg.toStringAsFixed(2)),
            ),
          );
        });

        avgCurve.sort((a, b) => a.hour.compareTo(b.hour));

        if (maxHour != -1) {
          highestHourStr = "${maxHour.toString().padLeft(2, '0')}:00";
        }
        if (minHour != -1) {
          lowestHourStr = "${minHour.toString().padLeft(2, '0')}:00";
        }
      }
    }

    // --- 2. Productivity drop day calculation ---
    final dbTasks = await dbHelper.getTasksForUser(userId);
    String worstProductivityDay = L10n.tr("Friday");
    bool hasProductivityData = false;
    if (dbTasks.isNotEmpty) {
      final Map<int, List<TaskCard>> tasksByDay = {};
      for (var task in dbTasks) {
        if (task.dueDate != null) {
          final dayOfWeek = task.dueDate!.weekday; // 1 = Monday, 7 = Sunday
          tasksByDay.putIfAbsent(dayOfWeek, () => []).add(task);
        }
      }

      if (tasksByDay.isNotEmpty) {
        int worstDay = -1;
        double lowestRate = 2.0;

        tasksByDay.forEach((day, list) {
          final int completed = list.where((t) => t.isCompleted).length;
          final double rate = completed / list.length;
          if (rate < lowestRate) {
            lowestRate = rate;
            worstDay = day;
          }
        });

        if (worstDay != -1) {
          final dayNames = {
            1: L10n.tr("Monday"),
            2: L10n.tr("Tuesday"),
            3: L10n.tr("Wednesday"),
            4: L10n.tr("Thursday"),
            5: L10n.tr("Friday"),
            6: L10n.tr("Saturday"),
            7: L10n.tr("Sunday"),
          };
          worstProductivityDay =
              dayNames[worstDay] ?? L10n.tr("Friday");
          hasProductivityData = true;
        }
      }
    }

    // --- 3. Week-over-week comparison calculation ---
    final now = DateTime.now();
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfThisWeekDate = DateTime(
      startOfThisWeek.year,
      startOfThisWeek.month,
      startOfThisWeek.day,
    );
    final startOfLastWeekDate = startOfThisWeekDate.subtract(
      const Duration(days: 7),
    );

    final List<int> energyThisWeekList = [];
    final List<int> energyLastWeekList = [];

    for (var log in dbLogs) {
      try {
        final timestampStr = log['timestamp'] as String;
        final dt = DateTime.parse(timestampStr);
        final energy = log['energy'] as int;
        if (dt.isAfter(startOfThisWeekDate) ||
            dt.isAtSameMomentAs(startOfThisWeekDate)) {
          energyThisWeekList.add(energy);
        } else if (dt.isAfter(startOfLastWeekDate) &&
            dt.isBefore(startOfThisWeekDate)) {
          energyLastWeekList.add(energy);
        }
      } catch (_) {}
    }

    double thisWeekAvg = 3.6;
    double lastWeekAvg = 3.2;

    if (energyThisWeekList.isNotEmpty) {
      thisWeekAvg =
          energyThisWeekList.reduce((a, b) => a + b) /
          energyThisWeekList.length;
    }
    if (energyLastWeekList.isNotEmpty) {
      lastWeekAvg =
          energyLastWeekList.reduce((a, b) => a + b) /
          energyLastWeekList.length;
    }

    final double diff = thisWeekAvg - lastWeekAvg;
    String comparisonStr = L10n.tr("stable");
    if (diff > 0) {
      comparisonStr = L10n.tr("increased by ${diff.toStringAsFixed(1)} levels from last week");
    } else if (diff < 0) {
      comparisonStr = L10n.tr("decreased by ${diff.abs().toStringAsFixed(1)} levels from last week");
    } else {
      comparisonStr = L10n.tr("stable same as last week");
    }

    if (!mounted) return;
    setState(() {
      _userId = userId;
      if (latestEnergy != null) {
        _currentEnergyLvl = latestEnergy;
      }
      scatterData = loadedLogs;
      averageCurveData = avgCurve;
      _highestEnergyHourStr = highestHourStr;
      _lowestEnergyHourStr = lowestHourStr;
      _productivityDropDay = worstProductivityDay;
      _avgEnergyThisWeek = thisWeekAvg;
      _avgEnergyLastWeek = lastWeekAvg;
      _energyComparisonStr = comparisonStr;
      _hasHourlyEnergyData = dbLogs.isNotEmpty;
      _hasProductivityData = hasProductivityData;
      _hasWeeklyEnergyData = energyThisWeekList.isNotEmpty && energyLastWeekList.isNotEmpty;
    });
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

  Widget _buildInsightRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.containerline2.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.button,
                    fontFamily: "Quicksand",
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.normaltext.withValues(alpha: 0.9),
                    fontFamily: "Nunito",
                    height: 1.35,
                  ),
                ),
              ],
            ),
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
                        Text(
                          L10n.tr("Energy Log"),
                          style: AppTextStyles.greeting,
                        ),
                        Transform.translate(
                          offset: const Offset(0, -5),
                          child: Text(
                            L10n.tr("Understand your rhythm"),
                            style: AppTextStyles.affirmation,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Image.asset(AppImage.mascotstar, height: 120),
                  ],
                ),
              ),

              Container3(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Current Energy"),
                                style: TextStyle(
                                  color: AppColors.button,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: "Quicksand",
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getEnergyLabel(_currentEnergyLvl),
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                  fontFamily: "Quicksand",
                                ),
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          AppImage.iconenergy,
                          height: 48,
                          width: 48,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    EnergyIndicator(level: _currentEnergyLvl),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        int tempEnergyLvl =
                            _currentEnergyLvl; // Set to current selection
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
                                          children: List.generate(5, (index) {
                                            final lvl = index + 1;
                                            final isActive =
                                                tempEnergyLvl >= lvl;
                                            return IconButton(
                                              iconSize: 32,
                                              icon: Icon(
                                                Icons.energy_savings_leaf_rounded,
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
                                    style: const TextStyle(color: Colors.grey),
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
                                      await _loadEnergyLogs();
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.button,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
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
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(
                        L10n.tr("Update Energy Log"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              Container1(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insights,
                          color: AppColors.button,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          L10n.tr("Daily Energy Rhythm"),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.button,
                            fontFamily: "Quicksand",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        margin: EdgeInsets.zero,
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          header: '',
                          activationMode: ActivationMode.singleTap,
                          builder: (dynamic data, dynamic point, dynamic series,
                              int pointIndex, int seriesIndex) {
                            final logData = data as EnergyLogData;
                            final hourInt = logData.hour.toInt();
                            final minInt = ((logData.hour - hourInt) * 60).round();
                            final timeStr =
                                "${hourInt.toString().padLeft(2, '0')}:${minInt.toString().padLeft(2, '0')}";
                            final energyLabel = _getEnergyLabel(logData.energy.round());
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.button,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Text(
                                "$timeStr - $energyLabel",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Quicksand',
                                ),
                              ),
                            );
                          },
                        ),
                        primaryXAxis: NumericAxis(
                          minimum: 0,
                          maximum: 24,
                          interval: 4,
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          majorGridLines: const MajorGridLines(width: 0),
                          axisLabelFormatter: (args) {
                            final hr = args.value.toInt();
                            final displayHour = "${hr.toString().padLeft(2, '0')}:00";
                            return ChartAxisLabel(
                              displayHour,
                              TextStyle(
                                color: AppColors.button,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                fontFamily: 'Quicksand',
                              ),
                            );
                          },
                        ),
                        primaryYAxis: NumericAxis(
                          minimum: 1,
                          maximum: 5,
                          interval: 1,
                          axisLine: const AxisLine(width: 0),
                          majorTickLines: const MajorTickLines(size: 0),
                          majorGridLines: MajorGridLines(
                            width: 1,
                            color: AppColors.containerline2.withValues(alpha: 0.15),
                            dashArray: const [4, 4],
                          ),
                          axisLabelFormatter: (args) {
                            String label = '';
                            switch (args.value.toInt()) {
                              case 1:
                                label = L10n.tr('Low', 'Rendah');
                                break;
                              case 2:
                                label = L10n.tr('Mid-Low', 'Cukup Rendah');
                                break;
                              case 3:
                                label = L10n.tr('Medium', 'Sedang');
                                break;
                              case 4:
                                label = L10n.tr('Mid-High', 'Cukup Tinggi');
                                break;
                              case 5:
                                label = L10n.tr('High', 'Tinggi');
                                break;
                            }
                            return ChartAxisLabel(
                              label,
                              TextStyle(
                                color: AppColors.button,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                fontFamily: 'Quicksand',
                              ),
                            );
                          },
                        ),
                        series: <CartesianSeries<EnergyLogData, double>>[
                          if (averageCurveData.length >= 2)
                            SplineAreaSeries<EnergyLogData, double>(
                              dataSource: averageCurveData,
                              xValueMapper: (data, _) => data.hour,
                              yValueMapper: (data, _) => data.energy,
                              name: L10n.tr("Average Rhythm"),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.button.withValues(alpha: 0.35),
                                  AppColors.button.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderColor: AppColors.button,
                              borderWidth: 3,
                            ),
                          ScatterSeries<EnergyLogData, double>(
                            dataSource: scatterData,
                            xValueMapper: (data, _) => data.hour,
                            yValueMapper: (data, _) => data.energy,
                            name: L10n.tr("Logs"),
                            markerSettings: MarkerSettings(
                              isVisible: true,
                              shape: DataMarkerType.circle,
                              width: 10,
                              height: 10,
                              color: AppColors.container2,
                              borderColor: AppColors.button,
                              borderWidth: 2.5,
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
                        Icon(Icons.insights, color: AppColors.button, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          L10n.tr("Energy & Productivity Insights"),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.button,
                            fontFamily: "Quicksand",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInsightRow(
                      icon: Icons.access_time_filled_rounded,
                      iconColor: Colors.orangeAccent,
                      title: L10n.tr("Highest & Lowest Energy Hours"),
                      description: _hasHourlyEnergyData
                          ? L10n.tr("Your energy tends to peak at $_highestEnergyHourStr and reach its lowest point at $_lowestEnergyHourStr.")
                          : L10n.tr("No data yet"),
                    ),
                    _buildInsightRow(
                      icon: Icons.trending_down_rounded,
                      iconColor: Colors.redAccent,
                      title: L10n.tr("Productivity Drop"),
                      description: _hasProductivityData
                          ? L10n.tr("Based on your daily task completion rate, your productivity tends to drop on $_productivityDropDay.")
                          : L10n.tr("No data yet"),
                    ),
                    _buildInsightRow(
                      icon: Icons.compare_arrows_rounded,
                      iconColor: Colors.blueAccent,
                      title: L10n.tr("Weekly Energy Trend"),
                      description: _hasWeeklyEnergyData
                          ? L10n.tr("Your average energy level this week (${_avgEnergyThisWeek.toStringAsFixed(1)}) is $_energyComparisonStr compared to last week (${_avgEnergyLastWeek.toStringAsFixed(1)}).")
                          : L10n.tr("No data yet"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
