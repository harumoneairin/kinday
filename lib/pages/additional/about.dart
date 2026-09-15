import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_image.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.button),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          L10n.tr("About Kinday"),
          style: TextStyle(
            fontFamily: "Quicksand",
            fontWeight: FontWeight.bold,
            color: AppColors.button,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: BgContainer(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Mascot/Logo Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(15.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        AppImage.mascotlogin,
                        height: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // App Name
                  Text(
                    "Kinday",
                    style: TextStyle(
                      fontFamily: "Super",
                      fontSize: 38,
                      letterSpacing: 4,
                      color: AppColors.button,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Tagline
                  Text(
                    L10n.tr("Let's make today manageable"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: AppColors.button,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Version
                  const Text(
                    "Version 1.0.0",
                    style: TextStyle(
                      fontFamily: "Nunito",
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Main description
                  Container1(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.tr("What is Kinday?"),
                          style: TextStyle(
                            fontFamily: "Quicksand",
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.button,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          L10n.tr("Kinday is a mindful task management application designed to help you balance your energy levels and boost daily focus. Instead of piling up infinite lists, Kinday guides you to plan based on actual capacity, break down intimidating goals with AI, and complete tasks in structured Pomodoro sessions."),
                          style: const TextStyle(
                            fontFamily: "Nunito",
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Key Features Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Text(
                        L10n.tr("Key Features"),
                        style: TextStyle(
                          fontFamily: "Quicksand",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.button,
                        ),
                      ),
                    ),
                  ),

                  // Feature Cards
                  Container2(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.bolt, color: AppColors.button, size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Energy-based Scheduling"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                L10n.tr("Assign energy points (Low to High) to matches your real-life mental and physical focus capacity."),
                                style: const TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Container3(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.psychology, color: AppColors.button, size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("AI Task Breakdown"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                L10n.tr("Overwhelmed by huge tasks? Let the built-in AI assistant automatically suggest manageable subtasks."),
                                style: const TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.3,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.timer, color: AppColors.button, size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L10n.tr("Pomodoro Focus Timer"),
                                style: TextStyle(
                                  fontFamily: "Quicksand",
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.button,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                L10n.tr("Block distractions with an immersive focus timer complete with customizable background soundscapes."),
                                style: const TextStyle(
                                  fontFamily: "Nunito",
                                  fontSize: 13,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  // Footer section
                  Text(
                    L10n.tr("Designed and developed with ❤️"),
                    style: const TextStyle(
                      fontFamily: "Nunito",
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    L10n.tr("by the Kinday Team"),
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.button,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
