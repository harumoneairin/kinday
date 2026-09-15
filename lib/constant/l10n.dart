import 'package:flutter/material.dart';
import 'package:kinday/constant/app_dictionary.dart';
import 'package:kinday/database/preference_handler.dart';

class L10n {
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>("en");

  static void init() {
    languageNotifier.value = PreferenceHandler.language;
  }

  static String get lang => languageNotifier.value;
  
  static bool get isEn => lang == "en";
  static bool get isId => lang == "id";
  static bool get isJa => lang == "ja";

  static String tr(String enVal, [String? idVal]) {
    if (isEn) return enVal;
    final dictTranslation = AppDictionary.translate(enVal, lang);
    if (dictTranslation != null) return dictTranslation;

    final patterns = _getRegexTranslations(lang);
    for (final entry in patterns.entries) {
      final reg = RegExp(entry.key);
      final match = reg.firstMatch(enVal);
      if (match != null) {
        String template = entry.value;
        for (int i = 1; i <= match.groupCount; i++) {
          template = template.replaceAll('\$$i', match.group(i) ?? '');
        }
        return template;
      }
    }

    if (isId) return idVal ?? enVal;
    return enVal;
  }

  static Map<String, String> _getRegexTranslations(String lang) {
    if (lang == "ja") {
      return {
        r'^(\d+)\s*mins?$': r'$1分',
        r'^(\d+)\s*min$': r'$1分',
        r'^(\d+)\s*Days?$': r'$1日',
        r'^(\d+)\s*out\s+of\s+(\d+)\s+tasks\s+completed$': r'$2個中$1個のタスク完了',
        r'^(\d+)\s*out\s+of\s+(\d+)\s+tasks$': r'$2個中$1個のタスク',
        r'^(\d+)\s+of\s+(\d+)\s+selected$': r'$2個中$1個選択中',
        r'^(\d+)\s+subtask\(s\)\s+added\s+successfully!$': r'$1個のサブタスクを追加しました！',
        r'^Delete\s+failed:\s*(.+)$': r'削除失敗: $1',
        r'^An\s+error\s+occurred:\s*(.+)$': r'エラーが発生しました: $1',
        r'^Speech\s+recognition\s+error:\s*(.+)$': r'音声認識エラー: $1',
        r'^Failed\s+to\s+break\s+down\s+task:\s*(.+)$': r'タスクの細分化に失敗しました: $1',
        r'^Your\s+daily\s+AI\s+limit\s+of\s+(\d+)\s+breakdowns\s+has\s+been\s+reached!\s+Try\s+again\s+tomorrow\.$':
            r'1日のAI上限（$1回）に達しました！ 明日もう一度お試しください。',
        r'^Add\s*\((\d+)\)$': r'追加 ($1)',
        r'^Resend\s+in\s+(\d+)s$': r'$1秒後に再送信',
        // Energy Log Insights
        r'^Your\s+energy\s+tends\s+to\s+peak\s+at\s+(\d{2}:\d{2})\s+and\s+reach\s+its\s+lowest\s+point\s+at\s+(\d{2}:\d{2})\.$':
            r'エネルギーは $1 にピークに達し、$2 に最低値になる傾向があります。',
        r'^Based\s+on\s+your\s+daily\s+task\s+completion\s+rate,\s+your\s+productivity\s+tends\s+to\s+drop\s+on\s+(.+)\.$':
            r'日々のタスク完了率に基づくと、生産性は $1 に低下する傾向があります。',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+increased\s+by\s+(\d+\.\d+)\s+levels\s+from\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'今週の平均エネルギーレベル（$1）は、先週（$3）と比べて $2 レベル上昇しました。',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+decreased\s+by\s+(\d+\.\d+)\s+levels\s+from\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'今週の平均エネルギーレベル（$1）は、先週（$3）と比べて $2 レベル低下しました。',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+stable\s+same\s+as\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'今週の平均エネルギーレベル（$1）は、先週（$2）と同様に安定しています。',
      };
    }
    if (lang == "id") {
      return {
        r'^(\d+)\s*mins?$': r'$1 menit',
        r'^(\d+)\s*min$': r'$1 menit',
        r'^(\d+)\s*Days?$': r'$1 Hari',
        r'^(\d+)\s*out\s+of\s+(\d+)\s+tasks\s+completed$': r'$1 dari $2 tugas selesai',
        r'^(\d+)\s*out\s+of\s+(\d+)\s+tasks$': r'$1 dari $2 tugas',
        r'^(\d+)\s+of\s+(\d+)\s+selected$': r'$1 dari $2 dipilih',
        r'^(\d+)\s+subtask\(s\)\s+added\s+successfully!$': r'$1 sub-tugas berhasil ditambahkan!',
        r'^Delete\s+failed:\s*(.+)$': r'Gagal menghapus: $1',
        r'^An\s+error\s+occurred:\s*(.+)$': r'Terjadi kesalahan: $1',
        r'^Speech\s+recognition\s+error:\s*(.+)$': r'Kesalahan pengenalan suara: $1',
        r'^Failed\s+to\s+break\s+down\s+task:\s*(.+)$': r'Gagal memecah tugas: $1',
        r'^Your\s+daily\s+AI\s+limit\s+of\s+(\d+)\s+breakdowns\s+has\s+been\s+reached!\s+Try\s+again\s+tomorrow\.$':
            r'Batas harian $1 kali pemecahan AI Anda telah tercapai! Coba lagi besok.',
        r'^Add\s*\((\d+)\)$': r'Tambah ($1)',
        r'^Resend\s+in\s+(\d+)s$': r'Kirim ulang dalam $1 detik',
        // Energy Log Insights
        r'^Your\s+energy\s+tends\s+to\s+peak\s+at\s+(\d{2}:\d{2})\s+and\s+reach\s+its\s+lowest\s+point\s+at\s+(\d{2}:\d{2})\.$':
            r'Energi Anda cenderung berada di puncak pada pukul $1 dan di titik terendah pada pukul $2.',
        r'^Based\s+on\s+your\s+daily\s+task\s+completion\s+rate,\s+your\s+productivity\s+tends\s+to\s+drop\s+on\s+(.+)\.$':
            r'Berdasarkan tingkat penyelesaian tugas harian, produktivitas Anda cenderung menurun pada hari $1.',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+increased\s+by\s+(\d+\.\d+)\s+levels\s+from\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'Rata-rata level energi Anda minggu ini ($1) naik $2 tingkat dibanding minggu lalu ($3).',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+decreased\s+by\s+(\d+\.\d+)\s+levels\s+from\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'Rata-rata level energi Anda minggu ini ($1) turun $2 tingkat dibanding minggu lalu ($3).',
        r'^Your\s+average\s+energy\s+level\s+this\s+week\s+\((\d+\.\d+)\)\s+is\s+stable\s+same\s+as\s+last\s+week\s+compared\s+to\s+last\s+week\s+\((\d+\.\d+)\)\.$':
            r'Rata-rata level energi Anda minggu ini ($1) stabil sama dengan minggu lalu ($2).',
      };
    }
    return {};
  }

  static void setLanguage(String code) {
    PreferenceHandler.setLanguage(code);
    languageNotifier.value = code;
  }
}
