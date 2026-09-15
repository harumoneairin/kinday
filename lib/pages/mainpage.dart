import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/l10n.dart';
import 'package:kinday/constant/task_notifier.dart';
import 'package:kinday/database/notification_helper.dart';
import 'package:kinday/pages/additional/createtask.dart';
import 'package:kinday/pages/botnavpage/energylog.dart';
import 'package:kinday/pages/botnavpage/homepage.dart';
import 'package:kinday/pages/botnavpage/pomodoropage.dart';
import 'package:kinday/pages/botnavpage/setting_profile.dart';
import 'package:kinday/pages/botnavpage/tasklistpage.dart';

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => MainpageState();
}

class MainpageState extends State<Mainpage> {
  int selectedIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHelper().requestPermissions();
    });
  }

  void changeTab(int index) {
    setState(() {
      selectedIndex = index;
    });
    final CurvedNavigationBarState? navBarState =
        _bottomNavigationKey.currentState;
    navBarState?.setPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L10n.languageNotifier,
      builder: (context, lang, child) {
        return ValueListenableBuilder<String>(
          valueListenable: AppColors.themeNotifier,
          builder: (context, theme, child) {
            final List<Widget> pages = [
              Homepage(key: ValueKey("home_$lang")),
              Tasklistpage(key: ValueKey("task_$lang")),
              Pomodoropage(key: ValueKey("pomodoro_$lang")),
              EnergyPage(key: ValueKey("energy_$lang")),
              SettingProfile(key: ValueKey("setting_$lang")),
            ];

            return Scaffold(
              body: IndexedStack(
                key: ValueKey("stack_$lang"),
                index: selectedIndex,
                children: pages,
              ),
              bottomNavigationBar: CurvedNavigationBar(
                color: AppColors.background2,
                key: _bottomNavigationKey,
                index: selectedIndex,
                backgroundColor: AppColors.button,
                items: <Widget>[
                  Icon(Icons.home, size: 30, color: AppColors.button),
                  Icon(Icons.task_alt, size: 30, color: AppColors.button),
                  Icon(Icons.timer, size: 30, color: AppColors.button),
                  Icon(
                    Icons.electric_bolt_rounded,
                    size: 30,
                    color: AppColors.button,
                  ),
                  Icon(Icons.person, size: 30, color: AppColors.button),
                ],
                onTap: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
              ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: AppColors.button,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateTaskPage()),
                  );
                  TaskNotifier.notify();
                },
                child: const Icon(Icons.add, color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }
}
