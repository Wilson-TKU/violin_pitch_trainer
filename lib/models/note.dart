enum ViolinString { G, D, A, E }

enum PracticeMode { staffToFinger, fingerToStaff, earTraining }

// [NEW] 新增把位定義
enum ViolinPosition {
  first("First Pos (第一把位)"),
  third("Third Pos (第三把位)");

  final String label;
  const ViolinPosition(this.label);
}

// ... (MusicalKey 和 ViolinNote 保持不變，可以直接保留你原本的內容)
// 為確保完整性，若你需要可再次貼上，否則保留原檔即可。
enum MusicalKey {
  C_Major("C Major", 0),
  G_Major("G Major", 1),
  D_Major("D Major", 2),
  A_Major("A Major", 3),
  E_Major("E Major", 4),
  B_Major("B Major", 5),
  F_Sharp_Major("F# Major", 6),
  C_Sharp_Major("C# Major", 7),
  F_Major("F Major", -1),
  Bb_Major("Bb Major", -2),
  Eb_Major("Eb Major", -3),
  Ab_Major("Ab Major", -4),
  Db_Major("Db Major", -5),
  Gb_Major("Gb Major", -6),
  Cb_Major("Cb Major", -7);

  final String label;
  final int accidentals;
  const MusicalKey(this.label, this.accidentals);

  String get accidentalLabel {
    if (accidentals == 0) return "♮";
    return "${accidentals.abs()}${accidentals > 0 ? '#' : 'b'}";
  }
}

class ViolinNote {
  final String baseName;
  final int octave;
  final String solfege;
  final double frequency;
  final int staffIndex;

  String get noteName => "$baseName$octave";

  const ViolinNote({
    required this.baseName,
    required this.octave,
    required this.solfege,
    required this.frequency,
    required this.staffIndex,
  });

  String getDisplayName(MusicalKey key) {
    String displayBase = baseName;
    if (key.accidentals < 0) {
      switch (baseName) {
        case 'A#':
          displayBase = 'Bb';
          break;
        case 'C#':
          displayBase = 'Db';
          break;
        case 'D#':
          displayBase = 'Eb';
          break;
        case 'F#':
          displayBase = 'Gb';
          break;
        case 'G#':
          displayBase = 'Ab';
          break;
        case 'B':
          if (key == MusicalKey.Gb_Major || key == MusicalKey.Cb_Major)
            displayBase = 'Cb';
          break;
        case 'E':
          if (key == MusicalKey.Cb_Major) displayBase = 'Fb';
          break;
      }
    } else {
      if (key == MusicalKey.F_Sharp_Major || key == MusicalKey.C_Sharp_Major) {
        if (baseName == 'F') displayBase = 'E#';
      }
      if (key == MusicalKey.C_Sharp_Major) {
        if (baseName == 'C') displayBase = 'B#';
      }
    }
    return "$displayBase$octave\n$solfege";
  }
}
