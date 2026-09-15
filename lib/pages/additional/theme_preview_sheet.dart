import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/pages/botnavpage/energylog.dart';
import 'package:kinday/pages/botnavpage/homepage.dart';
import 'package:kinday/pages/botnavpage/pomodoropage.dart';
import 'package:kinday/pages/botnavpage/setting_profile.dart';
import 'package:kinday/pages/botnavpage/tasklistpage.dart';

class ThemePreviewSheet extends StatefulWidget {
  final String themeName;
  final String previousTheme;
  final String userName;
  final VoidCallback onCancel;

  const ThemePreviewSheet({
    super.key,
    required this.themeName,
    required this.previousTheme,
    required this.userName,
    required this.onCancel,
  });

  @override
  State<ThemePreviewSheet> createState() => _ThemePreviewSheetState();
}

class _ThemePreviewSheetState extends State<ThemePreviewSheet> {
  int _selectedPageIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  static const List<String> _tabKeys = [
    "Home",
    "Tasks",
    "Timer",
    "Energy",
    "Profile",
  ];

  static const List<IconData> _tabIcons = [
    Icons.home,
    Icons.task_alt,
    Icons.timer,
    Icons.electric_bolt_rounded,
    Icons.person,
  ];

  String _getThemeEmoji(String name) {
    switch (name) {
      case "Lavender Dreams":
        return "💜";
      case "Sakura Bloom":
        return "🌸";
      case "Matcha Garden":
        return "🌿";
      case "Sky Blue":
        return "☁️";
      case "Peach Cream":
        return "🍑";
      case "Moonlight Lavender":
        return "🌙";
      case "Twilight Blue":
        return "🌌";
      case "Midnight Forest":
        return "🌲";
      default:
        return "🎨";
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedPageIndex = index;
    });
    final CurvedNavigationBarState? navBarState =
        _bottomNavigationKey.currentState;
    navBarState?.setPage(index);
  }

  void _showUnavailableAlert(BuildContext context, AppThemeData themeData) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: themeData.background2,
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: themeData.button, size: 24),
            const SizedBox(width: 8),
            Text(
              L10n.tr("Information"),
              style: TextStyle(
                fontFamily: "Quicksand",
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: themeData.normaltext,
              ),
            ),
          ],
        ),
        content: Text(
          L10n.tr("Feature unavailable at the moment"),
          style: TextStyle(
            fontFamily: "Nunito",
            color: themeData.normaltext.withValues(alpha: 0.9),
            fontSize: 14,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeData.button,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              L10n.tr("OK"),
              style: const TextStyle(
                fontFamily: "Quicksand",
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeData = AppColors.themes[widget.themeName] ??
        AppColors.themes["Lavender Dreams"]!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onCancel();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: themeData.background2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 14, spreadRadius: 3),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle indicator
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${_getThemeEmoji(widget.themeName)} ${widget.themeName}",
                              style: TextStyle(
                                fontFamily: "Quicksand",
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeData.normaltext,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          L10n.tr("Tap tabs or swipe to preview pages"),
                          style: TextStyle(
                            fontFamily: "Nunito",
                            fontSize: 12,
                            color: themeData.normaltext.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: themeData.button.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeData.button.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "Rp 3.000",
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: themeData.button,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Page Tabs Selector
              _buildTabSelector(themeData),
              const SizedBox(height: 14),

              // Actual Scaled Mini Phone Mockup
              _buildLivePhoneMockup(themeData),
              const SizedBox(height: 18),

              // Action Buttons (Cancel / Buy)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: themeData.button, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        L10n.tr("Cancel"),
                        style: TextStyle(
                          fontFamily: "Quicksand",
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: themeData.button,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showUnavailableAlert(context, themeData),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: themeData.button,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        L10n.tr("Buy Rp 3.000"),
                        style: const TextStyle(
                          fontFamily: "Quicksand",
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
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
  }

  Widget _buildTabSelector(AppThemeData themeData) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_tabKeys.length, (index) {
          final isSelected = _selectedPageIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => _onTabSelected(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? themeData.button
                      : themeData.container1.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? themeData.button
                        : themeData.containerline1.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _tabIcons[index],
                      size: 13,
                      color: isSelected ? Colors.white : themeData.normaltext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      L10n.tr(_tabKeys[index]),
                      style: TextStyle(
                        fontFamily: "Quicksand",
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isSelected ? Colors.white : themeData.normaltext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLivePhoneMockup(AppThemeData themeData) {
    const double virtualWidth = 390.0;
    const double virtualHeight = 780.0;
    const double frameWidth = 260.0;
    const double frameHeight = 520.0;

    return Center(
      child: Container(
        width: frameWidth,
        height: frameHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.8),
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: themeData.button.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Scaled Real Pages & Bottom Navigation Bar
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: virtualWidth,
                    height: virtualHeight,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: const Size(virtualWidth, virtualHeight),
                        padding: const EdgeInsets.only(top: 36, bottom: 16),
                        viewPadding: const EdgeInsets.only(top: 36, bottom: 16),
                      ),
                      child: Scaffold(
                        body: IgnorePointer(
                          child: IndexedStack(
                            key: ValueKey("preview_stack_${L10n.lang}"),
                            index: _selectedPageIndex,
                            children: [
                              Homepage(key: ValueKey("preview_home_${L10n.lang}")),
                              Tasklistpage(key: ValueKey("preview_task_${L10n.lang}")),
                              Pomodoropage(key: ValueKey("preview_pomodoro_${L10n.lang}")),
                              EnergyPage(key: ValueKey("preview_energy_${L10n.lang}")),
                              SettingProfile(key: ValueKey("preview_setting_${L10n.lang}")),
                            ],
                          ),
                        ),
                        bottomNavigationBar: CurvedNavigationBar(
                          key: _bottomNavigationKey,
                          color: themeData.background2,
                          index: _selectedPageIndex,
                          backgroundColor: themeData.button,
                          items: <Widget>[
                            Icon(Icons.home, size: 30, color: themeData.button),
                            Icon(Icons.task_alt, size: 30, color: themeData.button),
                            Icon(Icons.timer, size: 30, color: themeData.button),
                            Icon(
                              Icons.electric_bolt_rounded,
                              size: 30,
                              color: themeData.button,
                            ),
                            Icon(Icons.person, size: 30, color: themeData.button),
                          ],
                          onTap: (index) {
                            setState(() {
                              _selectedPageIndex = index;
                            });
                          },
                        ),
                        floatingActionButton: FloatingActionButton(
                          backgroundColor: themeData.button,
                          onPressed: () {},
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Mini Top Notch / Dynamic Island indicator
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
