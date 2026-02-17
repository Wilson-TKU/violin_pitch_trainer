import 'dart:math';
import '../models/note.dart';
import '../models/scale_data.dart';

class ViolinLogic {
  static const double openStringLength = 325.0;
  static const List<double> openFreqs = [196.00, 293.66, 440.00, 659.25];

  // [NEW] 方便取得總音符數量
  static int get totalNotesCount => allNotes.length;

  static double calculatePositionMm(int semitonesFromOpen) {
    if (semitonesFromOpen <= 0) return -12.0;
    return openStringLength * (1 - 1 / pow(2, semitonesFromOpen / 12.0));
  }

  static ({int start, int end}) getScanRange(ViolinPosition pos) {
    switch (pos) {
      case ViolinPosition.first:
        return (start: 0, end: 8);
      case ViolinPosition.third:
        return (start: 4, end: 13);
    }
  }

  static ({int minIndex, int maxIndex}) getPositionIndexRange(
    ViolinPosition pos,
  ) {
    switch (pos) {
      case ViolinPosition.first:
        return (minIndex: 0, maxIndex: 28); // G3 ~ B5
      case ViolinPosition.third:
        return (minIndex: 5, maxIndex: 37); // C4 ~ E6
    }
  }

  static bool isNoteInPosition(ViolinNote note, ViolinPosition pos) {
    int index = allNotes.indexOf(note);
    if (index == -1) return false;

    var range = getPositionIndexRange(pos);
    return index >= range.minIndex && index <= range.maxIndex;
  }

  static int calcFingerNum(int semitones, ViolinPosition pos) {
    if (semitones == 0) return 0;

    if (pos == ViolinPosition.first) {
      if (semitones <= 2) return 1;
      if (semitones <= 4) return 2;
      if (semitones <= 6) return 3;
      return 4;
    } else {
      int relative = semitones - 4;
      if (relative <= 0) return 1;
      if (relative <= 2) return 1;
      if (relative <= 4) return 2;
      if (relative <= 6) return 3;
      return 4;
    }
  }

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
