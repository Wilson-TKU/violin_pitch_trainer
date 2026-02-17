import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(home: ViolinApp()));
}

// ---------------------------------------------------------
// 1. 資料結構與常數定義
// ---------------------------------------------------------

enum ViolinString { G, D, A, E }

enum PracticeMode {
  staffToFinger, // 看譜找指位
  fingerToStaff, // 看指位猜音
  earTraining, // 聽音辨音高
}

// 完整定義 15 個大調
enum MusicalKey {
  // --- Naturals ---
  C_Major("C Major", 0),

  // --- Sharps (1# ~ 7#) ---
  G_Major("G Major", 1),
  D_Major("D Major", 2),
  A_Major("A Major", 3),
  E_Major("E Major", 4),
  B_Major("B Major", 5),
  F_Sharp_Major("F# Major", 6),
  C_Sharp_Major("C# Major", 7),

  // --- Flats (1b ~ 7b) ---
  F_Major("F Major", -1),
  Bb_Major("Bb Major", -2),
  Eb_Major("Eb Major", -3),
  Ab_Major("Ab Major", -4),
  Db_Major("Db Major", -5),
  Gb_Major("Gb Major", -6),
  Cb_Major("Cb Major", -7);

  final String label;
  final int accidentals; // + for sharps, - for flats
  const MusicalKey(this.label, this.accidentals);

  // 取得顯示用的簡寫，例如 "2#" 或 "3b"
  String get accidentalLabel {
    if (accidentals == 0) return "♮"; // Natural
    return "${accidentals.abs()}${accidentals > 0 ? '#' : 'b'}";
  }
}

// 題庫設定：定義每個調性的合法音
const Map<MusicalKey, Set<String>> keyNotesMap = {
  MusicalKey.C_Major: {'C', 'D', 'E', 'F', 'G', 'A', 'B'},

  // Sharps
  MusicalKey.G_Major: {'G', 'A', 'B', 'C', 'D', 'E', 'F#'},
  MusicalKey.D_Major: {'D', 'E', 'F#', 'G', 'A', 'B', 'C#'},
  MusicalKey.A_Major: {'A', 'B', 'C#', 'D', 'E', 'F#', 'G#'},
  MusicalKey.E_Major: {'E', 'F#', 'G#', 'A', 'B', 'C#', 'D#'},
  MusicalKey.B_Major: {'B', 'C#', 'D#', 'E', 'F#', 'G#', 'A#'},
  MusicalKey.F_Sharp_Major: {'F#', 'G#', 'A#', 'B', 'C#', 'D#', 'E#'},
  MusicalKey.C_Sharp_Major: {'C#', 'D#', 'E#', 'F#', 'G#', 'A#', 'B#'},

  // Flats
  MusicalKey.F_Major: {'F', 'G', 'A', 'A#', 'C', 'D', 'E'},
  MusicalKey.Bb_Major: {'A#', 'C', 'D', 'D#', 'F', 'G', 'A'},
  MusicalKey.Eb_Major: {'D#', 'F', 'G', 'G#', 'A#', 'C', 'D'},
  MusicalKey.Ab_Major: {'G#', 'A#', 'C', 'C#', 'D#', 'F', 'G'},
  MusicalKey.Db_Major: {'C#', 'D#', 'F', 'F#', 'G#', 'A#', 'C'},
  MusicalKey.Gb_Major: {'F#', 'G#', 'A#', 'B', 'C#', 'D#', 'F'},
  MusicalKey.Cb_Major: {'B', 'C#', 'D#', 'E', 'F#', 'G#', 'A#'},
};

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

  // 智慧顯示：根據調性決定顯示 # 或 b 或 等音
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

// 完整題庫 (內部統一用 # 儲存)
final List<ViolinNote> allNotes = [
  // G String
  const ViolinNote(
    baseName: 'G',
    octave: 3,
    solfege: 'Sol',
    frequency: 196.00,
    staffIndex: -5,
  ),
  const ViolinNote(
    baseName: 'G#',
    octave: 3,
    solfege: 'Sol#',
    frequency: 207.65,
    staffIndex: -5,
  ),
  const ViolinNote(
    baseName: 'A',
    octave: 3,
    solfege: 'La',
    frequency: 220.00,
    staffIndex: -4,
  ),
  const ViolinNote(
    baseName: 'A#',
    octave: 3,
    solfege: 'La#',
    frequency: 233.08,
    staffIndex: -4,
  ),
  const ViolinNote(
    baseName: 'B',
    octave: 3,
    solfege: 'Si',
    frequency: 246.94,
    staffIndex: -3,
  ),
  const ViolinNote(
    baseName: 'C',
    octave: 4,
    solfege: 'Do',
    frequency: 261.63,
    staffIndex: -2,
  ),
  const ViolinNote(
    baseName: 'C#',
    octave: 4,
    solfege: 'Do#',
    frequency: 277.18,
    staffIndex: -2,
  ),
  // D String
  const ViolinNote(
    baseName: 'D',
    octave: 4,
    solfege: 'Re',
    frequency: 293.66,
    staffIndex: -1,
  ),
  const ViolinNote(
    baseName: 'D#',
    octave: 4,
    solfege: 'Re#',
    frequency: 311.13,
    staffIndex: -1,
  ),
  const ViolinNote(
    baseName: 'E',
    octave: 4,
    solfege: 'Mi',
    frequency: 329.63,
    staffIndex: 0,
  ),
  const ViolinNote(
    baseName: 'F',
    octave: 4,
    solfege: 'Fa',
    frequency: 349.23,
    staffIndex: 1,
  ),
  const ViolinNote(
    baseName: 'F#',
    octave: 4,
    solfege: 'Fa#',
    frequency: 369.99,
    staffIndex: 1,
  ),
  const ViolinNote(
    baseName: 'G',
    octave: 4,
    solfege: 'Sol',
    frequency: 392.00,
    staffIndex: 2,
  ),
  const ViolinNote(
    baseName: 'G#',
    octave: 4,
    solfege: 'Sol#',
    frequency: 415.30,
    staffIndex: 2,
  ),
  // A String
  const ViolinNote(
    baseName: 'A',
    octave: 4,
    solfege: 'La',
    frequency: 440.00,
    staffIndex: 3,
  ),
  const ViolinNote(
    baseName: 'A#',
    octave: 4,
    solfege: 'La#',
    frequency: 466.16,
    staffIndex: 3,
  ),
  const ViolinNote(
    baseName: 'B',
    octave: 4,
    solfege: 'Si',
    frequency: 493.88,
    staffIndex: 4,
  ),
  const ViolinNote(
    baseName: 'C',
    octave: 5,
    solfege: 'Do',
    frequency: 523.25,
    staffIndex: 5,
  ),
  const ViolinNote(
    baseName: 'C#',
    octave: 5,
    solfege: 'Do#',
    frequency: 554.37,
    staffIndex: 5,
  ),
  const ViolinNote(
    baseName: 'D',
    octave: 5,
    solfege: 'Re',
    frequency: 587.33,
    staffIndex: 6,
  ),
  const ViolinNote(
    baseName: 'D#',
    octave: 5,
    solfege: 'Re#',
    frequency: 622.25,
    staffIndex: 6,
  ),
  // E String
  const ViolinNote(
    baseName: 'E',
    octave: 5,
    solfege: 'Mi',
    frequency: 659.25,
    staffIndex: 7,
  ),
  const ViolinNote(
    baseName: 'F',
    octave: 5,
    solfege: 'Fa',
    frequency: 698.46,
    staffIndex: 8,
  ),
  const ViolinNote(
    baseName: 'F#',
    octave: 5,
    solfege: 'Fa#',
    frequency: 739.99,
    staffIndex: 8,
  ),
  const ViolinNote(
    baseName: 'G',
    octave: 5,
    solfege: 'Sol',
    frequency: 783.99,
    staffIndex: 9,
  ),
  const ViolinNote(
    baseName: 'G#',
    octave: 5,
    solfege: 'Sol#',
    frequency: 830.61,
    staffIndex: 9,
  ),
  const ViolinNote(
    baseName: 'A',
    octave: 5,
    solfege: 'La',
    frequency: 880.00,
    staffIndex: 10,
  ),
  const ViolinNote(
    baseName: 'A#',
    octave: 5,
    solfege: 'La#',
    frequency: 932.33,
    staffIndex: 10,
  ),
  const ViolinNote(
    baseName: 'B',
    octave: 5,
    solfege: 'Si',
    frequency: 987.77,
    staffIndex: 11,
  ),
  const ViolinNote(
    baseName: 'C',
    octave: 6,
    solfege: 'Do',
    frequency: 1046.50,
    staffIndex: 12,
  ),
  const ViolinNote(
    baseName: 'C#',
    octave: 6,
    solfege: 'Do#',
    frequency: 1108.73,
    staffIndex: 12,
  ),
];

// ---------------------------------------------------------
// 2. 核心邏輯 UI
// ---------------------------------------------------------
class ViolinApp extends StatefulWidget {
  const ViolinApp({super.key});

  @override
  State<ViolinApp> createState() => _ViolinAppState();
}

class _ViolinAppState extends State<ViolinApp> {
  final AudioPlayer _player = AudioPlayer();
  final Random _rng = Random();

  ViolinNote? _currentNote;
  bool _isPlaying = false;
  bool _isAnswerVisible = false;

  // --- 設定變數 ---
  double _referencePitch = 442.0;
  Set<MusicalKey> _selectedKeys = {MusicalKey.D_Major}; // 預設單選 D 大調
  bool _isMultiSelectMode = false; // 新增：是否為多選模式

  MusicalKey _currentQuestionKey = MusicalKey.D_Major;

  PracticeMode _practiceMode = PracticeMode.staffToFinger;
  RangeValues _rangePercent = const RangeValues(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _nextNote();
  }

  Future<void> _nextNote() async {
    await _player.stop();
    if (_selectedKeys.isEmpty) return;

    List<MusicalKey> availableKeys = _selectedKeys.toList();
    _currentQuestionKey = availableKeys[_rng.nextInt(availableKeys.length)];

    Set<String> validBaseNames = keyNotesMap[_currentQuestionKey] ?? {};
    List<ViolinNote> validNotes = allNotes.where((note) {
      if (_currentQuestionKey == MusicalKey.F_Sharp_Major &&
          note.baseName == 'F')
        return true;
      if (_currentQuestionKey == MusicalKey.C_Sharp_Major &&
          (note.baseName == 'F' || note.baseName == 'C'))
        return true;
      if (_currentQuestionKey == MusicalKey.Cb_Major &&
          (note.baseName == 'B' || note.baseName == 'E'))
        return true;

      return validBaseNames.contains(note.baseName);
    }).toList();

    if (validNotes.isEmpty) return;

    int totalCount = validNotes.length;
    int startIndex = (_rangePercent.start * (totalCount - 1)).round();
    int endIndex = (_rangePercent.end * (totalCount - 1)).round();
    if (endIndex < startIndex) endIndex = startIndex;

    int randomIndex = startIndex + _rng.nextInt(endIndex - startIndex + 1);
    final note = validNotes[randomIndex];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
      _isAnswerVisible = false;
    });

    double adjustedFrequency = note.frequency * (_referencePitch / 440.0);
    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: adjustedFrequency,
      durationMs: 1500,
      sampleRate: 44100,
    );

    try {
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _currentNote == note) {
      setState(() => _isPlaying = false);
    }
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  String _getModeName(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.staffToFinger:
        return "看譜找指位";
      case PracticeMode.fingerToStaff:
        return "看指位猜音";
      case PracticeMode.earTraining:
        return "聽音辨音高";
    }
  }

  // --- 設定面板 ---
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            int total = allNotes.length;
            int sIdx = (_rangePercent.start * (total - 1)).round();
            int eIdx = (_rangePercent.end * (total - 1)).round();

            ViolinNote sNote = allNotes[sIdx];
            ViolinNote eNote = allNotes[eIdx];

            String startStr =
                "${sNote.getDisplayName(_selectedKeys.first).replaceAll('\n', ' ')}";
            String endStr =
                "${eNote.getDisplayName(_selectedKeys.first).replaceAll('\n', ' ')}";

            return Container(
              padding: const EdgeInsets.all(20),
              height: 750,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "設定 (Settings)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "練習模式:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: PracticeMode.values.map((mode) {
                      return ChoiceChip(
                        label: Text(_getModeName(mode)),
                        selected: _practiceMode == mode,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => _practiceMode = mode);
                            setState(() => _nextNote());
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 調性選擇區塊 Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "選擇調性:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Text("多選模式: "),
                          Switch(
                            value: _isMultiSelectMode,
                            onChanged: (val) {
                              setModalState(() => _isMultiSelectMode = val);
                              setState(() => _isMultiSelectMode = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 如果開啟多選，顯示全選/重置按鈕
                  if (_isMultiSelectMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            // 自動開啟多選 (防呆)
                            _isMultiSelectMode = true;
                            if (_selectedKeys.length ==
                                MusicalKey.values.length) {
                              _selectedKeys = {MusicalKey.C_Major};
                            } else {
                              _selectedKeys = Set.from(MusicalKey.values);
                            }
                          });
                          setState(() => _nextNote());
                        },
                        child: const Text("全選/重置"),
                      ),
                    ),

                  const SizedBox(height: 5),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          const TableRow(
                            children: [
                              Center(
                                child: Text(
                                  "降記號 (b)",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              Center(
                                child: Text(
                                  "自然",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              Center(
                                child: Text(
                                  "升記號 (#)",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const TableRow(
                            children: [
                              SizedBox(height: 10),
                              SizedBox(height: 10),
                              SizedBox(height: 10),
                            ],
                          ),

                          TableRow(
                            children: [
                              Container(),
                              _buildKeyCheckbox(
                                MusicalKey.C_Major,
                                setModalState,
                              ),
                              Container(),
                            ],
                          ),

                          _buildKeyRow(
                            MusicalKey.F_Major,
                            MusicalKey.G_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Bb_Major,
                            MusicalKey.D_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Eb_Major,
                            MusicalKey.A_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Ab_Major,
                            MusicalKey.E_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Db_Major,
                            MusicalKey.B_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Gb_Major,
                            MusicalKey.F_Sharp_Major,
                            setModalState,
                          ),
                          _buildKeyRow(
                            MusicalKey.Cb_Major,
                            MusicalKey.C_Sharp_Major,
                            setModalState,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    "基準音:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 440.0, label: Text("440")),
                      ButtonSegment(value: 442.0, label: Text("442")),
                    ],
                    selected: {_referencePitch},
                    onSelectionChanged: (newVal) {
                      setModalState(() => _referencePitch = newVal.first);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "音域範圍:",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "$startStr ~ $endStr",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _rangePercent,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (RangeValues values) {
                      setModalState(() => _rangePercent = values);
                      setState(() {});
                    },
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("完成"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  TableRow _buildKeyRow(
    MusicalKey flatKey,
    MusicalKey sharpKey,
    StateSetter setModalState,
  ) {
    return TableRow(
      children: [
        _buildKeyCheckbox(flatKey, setModalState),
        Container(),
        _buildKeyCheckbox(sharpKey, setModalState),
      ],
    );
  }

  Widget _buildKeyCheckbox(MusicalKey key, StateSetter setModalState) {
    bool isSelected = _selectedKeys.contains(key);
    return InkWell(
      onTap: () {
        setModalState(() {
          if (_isMultiSelectMode) {
            // 多選模式：切換狀態
            if (isSelected) {
              if (_selectedKeys.length > 1) _selectedKeys.remove(key);
            } else {
              _selectedKeys.add(key);
            }
          } else {
            // 單選模式：直接取代，並保持選取狀態
            _selectedKeys = {key};
          }
        });
        setState(() => _nextNote());
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Column(
          children: [
            Text(
              key.label.split(' ')[0],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              key.accidentalLabel,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showStaff = false;
    bool showFingerboardAnswer = false;

    switch (_practiceMode) {
      case PracticeMode.staffToFinger:
        showStaff = true;
        showFingerboardAnswer = _isAnswerVisible;
        break;
      case PracticeMode.fingerToStaff:
        showStaff = _isAnswerVisible;
        showFingerboardAnswer = true;
        break;
      case PracticeMode.earTraining:
        showStaff = _isAnswerVisible;
        showFingerboardAnswer = _isAnswerVisible;
        break;
    }

    String currentKeyLabel =
        "${_currentQuestionKey.label} (${_currentQuestionKey.accidentalLabel})";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_getModeName(_practiceMode)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.blue[50],
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Text(
              "目前調性: $currentKeyLabel",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),

          Expanded(
            flex: 35,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: StaffPainter(
                      noteIndex: showStaff ? _currentNote?.staffIndex : null,
                      keySignature: _currentQuestionKey,
                    ),
                  ),
                  if (!showStaff)
                    const Icon(
                      Icons.visibility_off,
                      size: 50,
                      color: Colors.grey,
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          Expanded(
            flex: 65,
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFF222222),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: ViolinFingerboardPainter(
                            targetNote: showFingerboardAnswer
                                ? _currentNote
                                : null,
                            currentKey: _currentQuestionKey,
                          ),
                        ),
                        if (_practiceMode == PracticeMode.staffToFinger &&
                            !_isAnswerVisible)
                          const Text(
                            "?",
                            style: TextStyle(
                              fontSize: 80,
                              color: Colors.white24,
                            ),
                          ),
                        if (_practiceMode == PracticeMode.earTraining &&
                            !_isAnswerVisible)
                          const Icon(
                            Icons.visibility_off,
                            size: 60,
                            color: Colors.white24,
                          ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: const Border(
                        left: BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isAnswerVisible) ...[
                          Text(
                            _currentNote
                                    ?.getDisplayName(_currentQuestionKey)
                                    .split('\n')[0] ??
                                "",
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            _currentNote?.solfege ?? "",
                            style: const TextStyle(
                              fontSize: 26,
                              color: Colors.black54,
                            ),
                          ),
                        ] else
                          const Text(
                            "?",
                            style: TextStyle(fontSize: 60, color: Colors.grey),
                          ),

                        const Spacer(),

                        ElevatedButton(
                          onPressed: () async {
                            if (_currentNote != null) {
                              double adjFreq =
                                  _currentNote!.frequency *
                                  (_referencePitch / 440.0);
                              final wavBytes = ToneGenerator.generateSineWave(
                                frequency: adjFreq,
                                durationMs: 1000,
                                sampleRate: 44100,
                              );
                              await _player.stop();
                              await _player.play(BytesSource(wavBytes));
                            }
                          },
                          child: const Icon(Icons.volume_up),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_isAnswerVisible) {
                                _nextNote();
                              } else {
                                _revealAnswer();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isAnswerVisible
                                  ? Colors.blue
                                  : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isAnswerVisible ? "Next" : "Answer",
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 繪圖 1: 五線譜
// ---------------------------------------------------------
class StaffPainter extends CustomPainter {
  final int? noteIndex;
  final MusicalKey keySignature;

  StaffPainter({this.noteIndex, required this.keySignature});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    final Paint notePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final double spaceHeight = 14.0;

    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
    }

    int accCount = keySignature.accidentals;
    bool isSharp = accCount > 0;
    int count = accCount.abs();

    List<int> sharpIndices = [8, 5, 9, 6, 10, 7, 11];
    List<int> flatIndices = [4, 7, 3, 6, 2, 5, 1];

    List<int> indicesToDraw = isSharp ? sharpIndices : flatIndices;
    String symbol = isSharp ? "#" : "b";

    for (int i = 0; i < count; i++) {
      if (i >= indicesToDraw.length) break;
      int idx = indicesToDraw[i];
      double y = centerY + 2 * spaceHeight * 2 - (idx * spaceHeight);
      _drawAccidental(canvas, Offset(40.0 + i * 18, y), spaceHeight, symbol);
    }

    if (noteIndex != null) {
      double baseLineY = centerY + 2 * spaceHeight * 2;
      double noteY = baseLineY - (noteIndex! * spaceHeight);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(centerX, noteY), width: 22, height: 16),
        notePaint,
      );

      if (noteIndex! < -1) {
        for (int i = -2; i >= noteIndex!; i -= 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(centerX - 18, lineY),
            Offset(centerX + 18, lineY),
            linePaint,
          );
        }
      }
      if (noteIndex! > 9) {
        for (int i = 10; i <= noteIndex!; i += 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(centerX - 18, lineY),
            Offset(centerX + 18, lineY),
            linePaint,
          );
        }
      }
    }
  }

  void _drawAccidental(Canvas canvas, Offset pos, double scale, String text) {
    TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.black,
        fontSize: scale * 2.2,
        fontWeight: FontWeight.bold,
      ),
      text: text,
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(pos.dx, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// 繪圖 2: 物理指板
// ---------------------------------------------------------
class ViolinFingerboardPainter extends CustomPainter {
  final ViolinNote? targetNote;
  final MusicalKey currentKey;

  ViolinFingerboardPainter({this.targetNote, required this.currentKey});

  final double openStringLength = 325.0;
  final List<double> openFreqs = [196.00, 293.66, 440.00, 659.25];
  final List<String> stringNames = ["G", "D", "A", "E"];

  double _calculatePosition(int semitonesFromOpen) {
    if (semitonesFromOpen <= 0) return -12;
    return openStringLength * (1 - 1 / pow(2, semitonesFromOpen / 12.0));
  }

  ({ViolinNote? note, bool isInKey, int semitones}) _analyzeFrequency(
    double freq,
    int stringIdx,
  ) {
    double openFreq = openFreqs[stringIdx];
    if (freq < openFreq * 0.98)
      return (note: null, isInKey: false, semitones: -1);

    double ratio = freq / openFreq;
    double semitonesFloat = (log(ratio) / log(2) * 12);
    int semitones = semitonesFloat.round();
    if (semitones > 8) return (note: null, isInKey: false, semitones: -1);

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

  int _calcFingerNum(int semitones) {
    if (semitones == 0) return 0;
    if (semitones <= 2) return 1;
    if (semitones <= 4) return 2;
    if (semitones <= 6) return 3;
    return 4;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint boardPaint = Paint()..color = const Color(0xFF111111);
    final Paint stringPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.5;
    final Paint highlightStringPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    final Paint hintPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    final Paint targetPaint = Paint()
      ..color = const Color(0xFFFF3333)
      ..style = PaintingStyle.fill;
    final Paint nutPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0;

    Path boardPath = Path();
    double topWidth = size.width * 0.65;
    double bottomWidth = size.width * 0.85;
    double startX = (size.width - topWidth) / 2;
    double endX = (size.width - bottomWidth) / 2;
    boardPath.moveTo(startX, 0);
    boardPath.lineTo(startX + topWidth, 0);
    boardPath.lineTo(endX + bottomWidth, size.height);
    boardPath.lineTo(endX, size.height);
    boardPath.close();
    canvas.drawPath(boardPath, boardPaint);

    double nutY = 20.0;
    canvas.drawLine(
      Offset(startX, nutY),
      Offset(startX + topWidth, nutY),
      nutPaint,
    );

    double stringSpacing = topWidth / 4;
    double firstStringX = startX + (topWidth - stringSpacing * 3) / 2;
    double pixelPerMm = (size.height - nutY) / 130.0;

    for (int stringIdx = 0; stringIdx < 4; stringIdx++) {
      double x = firstStringX + stringIdx * stringSpacing;

      bool isTargetString = false;
      int targetSemitones = -1;
      if (targetNote != null) {
        var result = _analyzeFrequency(targetNote!.frequency, stringIdx);
        if (result.note == targetNote) {
          isTargetString = true;
          targetSemitones = result.semitones;
        }
      }

      canvas.drawLine(
        Offset(x, nutY),
        Offset(x, size.height),
        isTargetString ? highlightStringPaint : stringPaint,
      );

      TextPainter(
          text: TextSpan(
            text: stringNames[stringIdx],
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(x - 5, 0));

      for (int s = 0; s <= 8; s++) {
        double posFreq = openFreqs[stringIdx] * pow(2, s / 12.0);
        var result = _analyzeFrequency(posFreq, stringIdx);

        double mm = _calculatePosition(s);
        double y = nutY + (mm * pixelPerMm);

        if (result.isInKey) {
          if (s == 0) {
            canvas.drawCircle(
              Offset(x, y),
              7,
              Paint()
                ..color = Colors.grey.withOpacity(0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          } else {
            canvas.drawCircle(Offset(x, y), 7, hintPaint);
          }
        }

        if (isTargetString && s == targetSemitones) {
          if (s == 0) {
            canvas.drawCircle(
              Offset(x, y),
              9,
              Paint()
                ..color = Colors.blueAccent
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5,
            );
          } else {
            canvas.drawCircle(Offset(x, y), 9, targetPaint);
            int fingerNum = _calcFingerNum(s);
            TextPainter(
                text: TextSpan(
                  text: "$fingerNum",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                textDirection: TextDirection.ltr,
              )
              ..layout()
              ..paint(canvas, Offset(x - 4, y - 8));
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ToneGenerator {
  static Uint8List generateSineWave({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    int numSamples = (durationMs * sampleRate) ~/ 1000;
    int dataSize = numSamples * 2;
    final buffer = BytesBuilder();
    buffer.add("RIFF".codeUnits);
    buffer.add(_int32(36 + dataSize));
    buffer.add("WAVE".codeUnits);
    buffer.add("fmt ".codeUnits);
    buffer.add(_int32(16));
    buffer.add(_int16(1));
    buffer.add(_int16(1));
    buffer.add(_int32(sampleRate));
    buffer.add(_int32(sampleRate * 2));
    buffer.add(_int16(2));
    buffer.add(_int16(16));
    buffer.add("data".codeUnits);
    buffer.add(_int32(dataSize));
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double sample = 16000 * sin(2 * pi * frequency * t);
      buffer.add(_int16(sample.toInt()));
    }
    return buffer.toBytes();
  }

  static List<int> _int32(int value) => [
    value & 0xff,
    (value >> 8) & 0xff,
    (value >> 16) & 0xff,
    (value >> 24) & 0xff,
  ];
  static List<int> _int16(int value) => [value & 0xff, (value >> 8) & 0xff];
}
