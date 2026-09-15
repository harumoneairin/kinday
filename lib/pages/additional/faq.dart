import 'package:flutter/material.dart';
import 'package:kinday/constant/app_colors.dart';
import 'package:kinday/constant/app_widget.dart';
import 'package:kinday/constant/l10n.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class FaqData {
  final String questionEn;
  final String questionId;
  final String answerEn;
  final String answerId;

  FaqData({
    required this.questionEn,
    required this.questionId,
    required this.answerEn,
    required this.answerId,
  });
}

class _FaqPageState extends State<FaqPage> {
  final TextEditingController _searchController = TextEditingController();
  
  final List<FaqData> _allFaqs = [
    FaqData(
      questionEn: "What is Kinday?",
      questionId: "Apa itu Kinday?",
      answerEn: "Kinday is a mindful task manager that focuses on energy level scheduling, structured focus timer (Pomodoro), and smart AI task breakdown helper.",
      answerId: "Kinday adalah pengelola tugas sadar yang berfokus pada penjadwalan tingkat energi, pengukur waktu fokus terstruktur (Pomodoro), dan asisten pemecah tugas pintar AI."
    ),
    FaqData(
      questionEn: "What are Energy Levels?",
      questionId: "Apa itu Tingkat Energi?",
      answerEn: "Instead of strict hours, Kinday lets you label tasks based on the focus they require: High (demanding tasks), Mid, or Low (easy tasks). This helps you work on the right task at the right time.",
      answerId: "Alih-alih jam yang kaku, Kinday memungkinkan Anda memberi label pada tugas berdasarkan fokus yang dibutuhkan: Tinggi (tugas berat), Sedang, atau Rendah (tugas mudah). Ini membantu Anda mengerjakan tugas yang tepat di waktu yang tepat."
    ),
    FaqData(
      questionEn: "How does the Pomodoro timer work?",
      questionId: "Bagaimana cara kerja timer Pomodoro?",
      answerEn: "Select any task and press 'Start Focus'. It starts a 25-minute timer with customizable ambient background audio to keep you in the zone, followed by short rest breaks.",
      answerId: "Pilih tugas apa saja dan tekan 'Mulai Fokus'. Ini akan memulai timer 25 menit dengan audio latar ambient yang dapat disesuaikan untuk menjaga fokus Anda, diikuti oleh jeda istirahat singkat."
    ),
    FaqData(
      questionEn: "What is the AI Task Breakdown?",
      questionId: "Apa itu AI Task Breakdown?",
      answerEn: "Kinday includes an AI helper that breaks down a complex task into smaller subtasks. You can choose the level of detail (Simple, Balanced, Detailed) under Settings.",
      answerId: "Kinday menyertakan asisten AI yang memecah tugas rumit menjadi sub-tugas yang lebih kecil. Anda dapat memilih tingkat detailnya (Sederhana, Seimbang, Detail) di bawah Pengaturan."
    ),
    FaqData(
      questionEn: "How to backup/restore my data?",
      questionId: "Bagaimana cara mencadangkan/memulihkan data saya?",
      answerEn: "Go to settings page, scroll down to Data Backup & Restore. Click 'Backup' to create a snapshot of your local tasks/settings, or 'Restore' to load the last backup.",
      answerId: "Buka halaman pengaturan, gulir ke bawah ke Pencadangan & Pemulihan Data. Klik 'Cadangkan' untuk membuat snapshot tugas/pengaturan lokal Anda, atau 'Pulihkan' untuk memuat cadangan terakhir."
    ),
    FaqData(
      questionEn: "Can I change my password?",
      questionId: "Apakah saya bisa mengubah kata sandi?",
      answerEn: "Yes! Click 'Change Password' on the Settings page, verify your current password, and enter a new password of at least 6 characters.",
      answerId: "Ya! Klik 'Ubah Kata Sandi' di halaman Pengaturan, verifikasi kata sandi saat ini, lalu masukkan kata sandi baru minimal 6 karakter."
    ),
  ];

  List<FaqData> _filteredFaqs = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _filteredFaqs = List.from(_allFaqs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFaqs(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      if (_searchQuery.isEmpty) {
        _filteredFaqs = List.from(_allFaqs);
      } else {
        _filteredFaqs = _allFaqs.where((faq) {
          final qEn = faq.questionEn.toLowerCase();
          final qId = faq.questionId.toLowerCase();
          final aEn = faq.answerEn.toLowerCase();
          final aId = faq.answerId.toLowerCase();
          return qEn.contains(_searchQuery) ||
              qId.contains(_searchQuery) ||
              aEn.contains(_searchQuery) ||
              aId.contains(_searchQuery);
        }).toList();
      }
    });
  }

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
          L10n.tr("Help & FAQ"),
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
          child: Column(
            children: [
              // Search input container
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterFaqs,
                  style: const TextStyle(color: Color(0xFF5852A0)),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.background),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppColors.background),
                            onPressed: () {
                              _searchController.clear();
                              _filterFaqs("");
                            },
                          )
                        : null,
                    hintText: L10n.tr("Search questions..."),
                    hintStyle: TextStyle(color: AppColors.background),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: AppColors.containerline1, width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white70,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // FAQ List
              Expanded(
                child: _filteredFaqs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.help_outline, size: 64, color: AppColors.button),
                            const SizedBox(height: 16),
                            Text(
                              L10n.tr("No results found."),
                              style: TextStyle(
                                fontFamily: "Quicksand",
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.button,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                        itemCount: _filteredFaqs.length,
                        itemBuilder: (context, index) {
                          final faq = _filteredFaqs[index];
                          return FaqItemCard(
                            question: L10n.tr(faq.questionEn),
                            answer: L10n.tr(faq.answerEn),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FaqItemCard extends StatefulWidget {
  final String question;
  final String answer;

  const FaqItemCard({
    super.key,
    required this.question,
    required this.answer,
  });

  @override
  State<FaqItemCard> createState() => _FaqItemCardState();
}

class _FaqItemCardState extends State<FaqItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12, right: 20, left: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isExpanded ? Colors.white : Colors.white70,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          width: 1,
          color: _isExpanded ? AppColors.containerline1 : AppColors.background,
        ),
        boxShadow: _isExpanded
            ? [
                BoxShadow(
                  color: AppColors.button.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: TextStyle(
                      fontFamily: "Quicksand",
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.button,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.button,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, color: Colors.black12),
            ),
            Text(
              widget.answer,
              style: const TextStyle(
                fontFamily: "Nunito",
                fontSize: 13.5,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
