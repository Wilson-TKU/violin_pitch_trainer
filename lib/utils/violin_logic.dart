import 'dart:math';
import '../models/note.dart';
import '../models/scale_data.dart'; // 確保能讀取到 allNotes

class ViolinLogic {
  static const double openStringLength = 325.0; // 有效弦長 (mm)
  static const List<double> openFreqs = [
    196.00,
    293.66,
    440.00,
    659.25,
  ]; // G, D, A, E

  /// 計算物理距離 (mm)
  static double calculatePositionMm(int semitonesFromOpen) {
    if (semitonesFromOpen <= 0) return -12.0;
    return openStringLength * (1 - 1 / pow(2, semitonesFromOpen / 12.0));
  }

  /// [NEW] 根據把位，決定要繪製的半音範圍
  /// 第一把位：畫 0~8 (空弦到小指)
  /// 第三把位：畫 4~13 (從第一把位的3指位置開始畫)
  static ({int start, int end}) getScanRange(ViolinPosition pos) {
    switch (pos) {
      case ViolinPosition.first:
        return (start: 0, end: 8);
      case ViolinPosition.third:
        return (start: 4, end: 13);
    }
  }

  /// [NEW] 根據把位，計算指法數字 (1, 2, 3, 4)
  static int calcFingerNum(int semitones, ViolinPosition pos) {
    if (semitones == 0) return 0; // 空弦

    if (pos == ViolinPosition.first) {
      // --- 第一把位邏輯 ---
      if (semitones <= 2) return 1; // 1-2半音 -> 1指
      if (semitones <= 4) return 2; // 3-4半音 -> 2指
      if (semitones <= 6) return 3; // 5-6半音 -> 3指
      return 4; // 7-8半音 -> 4指
    } else {
      // --- 第三把位邏輯 ---
      // 基準點上移：原本第5半音的位置變成1指
      // 公式：相對位置 = 絕對半音 - 4
      int relative = semitones - 4;

      if (relative <= 0) return 1; // 延伸指
      if (relative <= 2) return 1;
      if (relative <= 4) return 2;
      if (relative <= 6) return 3;
      return 4;
    }
  }

  /// 分析頻率對應的音
  static ({ViolinNote? note, bool isInKey, int semitones}) analyzeFrequency(
    double freq,
    int stringIdx,
    MusicalKey currentKey,
  ) {
    double openFreq = openFreqs[stringIdx];
    if (freq < openFreq * 0.98)
      return (note: null, isInKey: false, semitones: -1);

    double ratio = freq / openFreq;
    double semitonesFloat = (log(ratio) / log(2) * 12);
    int semitones = semitonesFloat.round();

    ViolinNote? foundNote;
    for (var n in allNotes) {
      if ((n.frequency - freq).abs() < 1.0) {
        foundNote = n;
        break;
      }
    }

    if (foundNote == null)
      return (note: null, isInKey: false, semitones: semitones);

    bool isInKey = false;
    Set<String> validBaseNames = keyNotesMap[currentKey] ?? {};

    if (validBaseNames.contains(foundNote.baseName)) {
      isInKey = true;
    } else {
      if (currentKey == MusicalKey.F_Sharp_Major && foundNote.baseName == 'F')
        isInKey = true;
      if (currentKey == MusicalKey.C_Sharp_Major &&
          (foundNote.baseName == 'F' || foundNote.baseName == 'C'))
        isInKey = true;
      if (currentKey == MusicalKey.Cb_Major &&
          (foundNote.baseName == 'B' || foundNote.baseName == 'E'))
        isInKey = true;
    }

    return (note: foundNote, isInKey: isInKey, semitones: semitones);
  }
}
