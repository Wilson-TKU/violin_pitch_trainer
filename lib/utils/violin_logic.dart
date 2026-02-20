import 'dart:math';
import '../models/note.dart';
import '../models/scale_data.dart';

class ViolinLogic {
  static const double openStringLength = 325.0;
  static const List<double> openFreqs = [196.00, 293.66, 440.00, 659.25];

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
        return (minIndex: 0, maxIndex: 28);
      case ViolinPosition.third:
        return (minIndex: 5, maxIndex: 33);
    }
  }

  static bool isNoteInPosition(ViolinNote note, ViolinPosition pos) {
    int index = allNotes.indexOf(note);
    if (index == -1) return false;
    var range = getPositionIndexRange(pos);
    return index >= range.minIndex && index <= range.maxIndex;
  }

  // [NEW] 檢查音符是否屬於該調性 (處理同音異名 A# == Bb)
  static bool isNoteInKey(ViolinNote note, MusicalKey key) {
    Set<String> validNames = keyNotesMap[key] ?? {};

    // 直接比對
    if (validNames.contains(note.baseName)) return true;

    // 處理同音異名 (Enharmonics)
    // 資料庫存的是升記號為主 (A#, C#)，但調性可能要求降記號 (Bb, Db)
    String enharmonic = _getEnharmonic(note.baseName);
    if (validNames.contains(enharmonic)) return true;

    // 特殊處理 F# Major 的 E# (即 F)
    if (key == MusicalKey.F_Sharp_Major && note.baseName == 'F') return true;
    if (key == MusicalKey.C_Sharp_Major &&
        (note.baseName == 'F' || note.baseName == 'C'))
      return true;
    if (key == MusicalKey.Cb_Major &&
        (note.baseName == 'B' || note.baseName == 'E'))
      return true;

    return false;
  }

  static String _getEnharmonic(String base) {
    switch (base) {
      case 'A#':
        return 'Bb';
      case 'C#':
        return 'Db';
      case 'D#':
        return 'Eb';
      case 'F#':
        return 'Gb';
      case 'G#':
        return 'Ab';
      // 反向
      case 'Bb':
        return 'A#';
      case 'Db':
        return 'C#';
      case 'Eb':
        return 'D#';
      case 'Gb':
        return 'F#';
      case 'Ab':
        return 'G#';
      default:
        return base;
    }
  }

  static int calcFingerNum(int semitones, ViolinPosition pos) {
    if (semitones == 0) return 0;
    if (pos == ViolinPosition.first) {
      if (semitones <= 2) return 1;
      if (semitones <= 4) return 2;
      if (semitones <= 6) return 3;
      return 4;
    } else {
      // ViolinPosition.third
      // Standard fingering for 3rd position.
      // 1st finger is on the 5th semitone (e.g. C on G string).
      // It can extend back to the 4th semitone.
      if (semitones <= 5) return 1; // Semitones 4 (extension) and 5
      if (semitones <= 7) return 2; // Semitones 6 and 7
      if (semitones <= 9) return 3; // Semitones 8 and 9
      return 4; // Semitones 10 and above
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

    // 使用新的嚴格檢查
    bool isInKey = isNoteInKey(foundNote, currentKey);

    return (note: foundNote, isInKey: isInKey, semitones: semitones);
  }

  // [NEW] Gets the 8 notes for a one-octave major scale for a given key.
  static List<ViolinNote> getScaleNotes(MusicalKey key) {
    // 1. Get the valid note base names for the key.
    final validBaseNames = keyNotesMap[key];
    if (validBaseNames == null || validBaseNames.isEmpty) return [];

    // 2. Find the root note's base name (e.g., "C#" for C_Sharp_Major)
    final rootBaseName = key.name.split('_')[0].replaceAll('Sharp', '#');

    // 3. Find the lowest-octave root note available in allNotes.
    ViolinNote? startNote;
    for (final note in allNotes) {
      if (note.baseName == rootBaseName) {
        startNote = note;
        break;
      }
    }
    if (startNote == null) return []; // Should not happen

    // 4. Iterate from the start note to find all 8 scale notes.
    final scale = <ViolinNote>[];
    int startIndex = allNotes.indexOf(startNote);

    for (int i = startIndex; i < allNotes.length && scale.length < 8; i++) {
      final currentNote = allNotes[i];
      // Use the existing isNoteInKey logic to correctly handle enharmonics
      if (isNoteInKey(currentNote, key)) {
        // Avoid adding duplicate scale degrees (e.g. both G and G#)
        if (scale.isEmpty || scale.last.solfege != currentNote.solfege) {
          scale.add(currentNote);
        }
      }
    }

    if (scale.length == 8) {
      return scale;
    } else {
      // If the scale runs out of notes at the top, try starting an octave lower if possible.
      // This is a fallback and might not be needed with complete note data.
      return [];
    }
  }

  static List<ViolinNote> getScaleNotesForPosition({
    required MusicalKey key,
    required ViolinPosition position,
  }) {
    final range = getPositionIndexRange(position);
    final List<ViolinNote> positionNotes = allNotes.sublist(
      range.minIndex,
      range.maxIndex + 1,
    );

    final List<ViolinNote> scaleNotes = positionNotes.where((note) {
      return isNoteInKey(note, key);
    }).toList();

    return scaleNotes;
  }
}
