enum ViolinString { G, D, A, E }

enum PracticeMode { staffToFinger, fingerToStaff, earTraining }

enum MusicalKey {
  C_Major("C", 0),
  G_Major("G", 1),
  D_Major("D", 2),
  A_Major("A", 3),
  E_Major("E", 4),
  B_Major("B", 5),
  F_Sharp_Major("F#", 6),
  C_Sharp_Major("C#", 7),
  F_Major("F", -1),
  Bb_Major("Bb", -2),
  Eb_Major("Eb", -3),
  Ab_Major("Ab", -4),
  Db_Major("Db", -5),
  Gb_Major("Gb", -6),
  Cb_Major("Cb", -7);

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
