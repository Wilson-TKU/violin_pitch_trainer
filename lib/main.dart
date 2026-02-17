import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(home: ViolinApp()));
}

// ---------------------------------------------------------
// 1. 資料結構與頻率定義
// ---------------------------------------------------------

enum ViolinString { G, D, A, E }

class ViolinNote {
  final String noteName;
  final String solfege;
  final double frequency; // Base 440Hz
  final int staffIndex;

  // 小提琴指法資訊 (第一把位)
  final ViolinString violinString;
  final int finger; // 0=空弦, 1=食指, 2=中指, 3=無名指, 4=小指

  const ViolinNote({
    required this.noteName,
    required this.solfege,
    required this.frequency,
    required this.staffIndex,
    required this.violinString,
    required this.finger,
  });

  String get displayName => "$noteName ($solfege)";
}

// 題庫 (第一把位)
const List<ViolinNote> scale = [
  // --- G 弦 ---
  ViolinNote(
    noteName: 'G3',
    solfege: 'Sol',
    frequency: 196.00,
    staffIndex: -5,
    violinString: ViolinString.G,
    finger: 0,
  ),
  ViolinNote(
    noteName: 'A3',
    solfege: 'La',
    frequency: 220.00,
    staffIndex: -4,
    violinString: ViolinString.G,
    finger: 1,
  ),
  ViolinNote(
    noteName: 'B3',
    solfege: 'Si',
    frequency: 246.94,
    staffIndex: -3,
    violinString: ViolinString.G,
    finger: 2,
  ),
  ViolinNote(
    noteName: 'C4',
    solfege: 'Do',
    frequency: 261.63,
    staffIndex: -2,
    violinString: ViolinString.G,
    finger: 3,
  ),
  // --- D 弦 ---
  ViolinNote(
    noteName: 'D4',
    solfege: 'Re',
    frequency: 293.66,
    staffIndex: -1,
    violinString: ViolinString.D,
    finger: 0,
  ),
  ViolinNote(
    noteName: 'E4',
    solfege: 'Mi',
    frequency: 329.63,
    staffIndex: 0,
    violinString: ViolinString.D,
    finger: 1,
  ),
  ViolinNote(
    noteName: 'F4',
    solfege: 'Fa',
    frequency: 349.23,
    staffIndex: 1,
    violinString: ViolinString.D,
    finger: 2,
  ),
  ViolinNote(
    noteName: 'G4',
    solfege: 'Sol',
    frequency: 392.00,
    staffIndex: 2,
    violinString: ViolinString.D,
    finger: 3,
  ),
  // --- A 弦 ---
  ViolinNote(
    noteName: 'A4',
    solfege: 'La',
    frequency: 440.00,
    staffIndex: 3,
    violinString: ViolinString.A,
    finger: 0,
  ),
  ViolinNote(
    noteName: 'B4',
    solfege: 'Si',
    frequency: 493.88,
    staffIndex: 4,
    violinString: ViolinString.A,
    finger: 1,
  ),
  ViolinNote(
    noteName: 'C5',
    solfege: 'Do',
    frequency: 523.25,
    staffIndex: 5,
    violinString: ViolinString.A,
    finger: 2,
  ),
  ViolinNote(
    noteName: 'D5',
    solfege: 'Re',
    frequency: 587.33,
    staffIndex: 6,
    violinString: ViolinString.A,
    finger: 3,
  ),
  // --- E 弦 ---
  ViolinNote(
    noteName: 'E5',
    solfege: 'Mi',
    frequency: 659.25,
    staffIndex: 7,
    violinString: ViolinString.E,
    finger: 0,
  ),
  ViolinNote(
    noteName: 'F5',
    solfege: 'Fa',
    frequency: 698.46,
    staffIndex: 8,
    violinString: ViolinString.E,
    finger: 1,
  ),
  ViolinNote(
    noteName: 'G5',
    solfege: 'Sol',
    frequency: 783.99,
    staffIndex: 9,
    violinString: ViolinString.E,
    finger: 2,
  ),
  ViolinNote(
    noteName: 'A5',
    solfege: 'La',
    frequency: 880.00,
    staffIndex: 10,
    violinString: ViolinString.E,
    finger: 3,
  ),
];

// 定義三種練習模式
enum PracticeMode {
  staffToFinger, // 譜 -> 指板
  fingerToStaff, // 指板 -> 譜
  earTraining, // 聽 -> 全部
}

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

  // 設定變數
  double _referencePitch = 440.0;
  RangeValues _rangeValues = RangeValues(0, scale.length - 1.0);
  PracticeMode _practiceMode = PracticeMode.staffToFinger; // 預設模式

  @override
  void initState() {
    super.initState();
    _nextNote();
  }

  Future<void> _nextNote() async {
    await _player.stop(); // 瞬間切斷舊聲音，符合「急速反應」需求

    int start = _rangeValues.start.round();
    int end = _rangeValues.end.round();
    if (end < start) end = start;
    int randomIndex = start + _rng.nextInt(end - start + 1);
    final note = scale[randomIndex];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
      _isAnswerVisible = false;
    });

    // 播放聲音 (背景提示)
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

  // 輔助函式：取得模式名稱
  String _getModeName(PracticeMode mode) {
    switch (mode) {
      case PracticeMode.staffToFinger:
        return "譜 → 指板";
      case PracticeMode.fingerToStaff:
        return "指板 → 譜";
      case PracticeMode.earTraining:
        return "聽力盲測";
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 550, // 加高一點
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "設定 (Settings)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  const Text("練習模式 (Mode):", style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  // 使用 Wrap 防止按鈕太擠
                  Wrap(
                    spacing: 10.0,
                    children: PracticeMode.values.map((mode) {
                      return ChoiceChip(
                        label: Text(_getModeName(mode)),
                        selected: _practiceMode == mode,
                        onSelected: (bool selected) {
                          if (selected) {
                            setModalState(() => _practiceMode = mode);
                            setState(() => _nextNote()); // 切換模式直接換題
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Text("基準音:", style: TextStyle(fontSize: 18)),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 440.0, label: Text("440")),
                      ButtonSegment(value: 442.0, label: Text("442")),
                    ],
                    selected: {_referencePitch},
                    onSelectionChanged: (Set<double> newSelection) {
                      setModalState(() => _referencePitch = newSelection.first);
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 20),
                  const Text("音域範圍:", style: TextStyle(fontSize: 18)),
                  Text(
                    "${scale[_rangeValues.start.round()].displayName} ~ ${scale[_rangeValues.end.round()].displayName}",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  RangeSlider(
                    values: _rangeValues,
                    min: 0,
                    max: scale.length - 1.0,
                    divisions: scale.length - 1,
                    onChanged: (RangeValues values) {
                      setModalState(() => _rangeValues = values);
                      setState(() {});
                    },
                  ),
                  const Spacer(),
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

  @override
  Widget build(BuildContext context) {
    // ----------------------------------------------------
    // 邏輯控制中心：決定誰該顯示
    // ----------------------------------------------------
    bool showStaff = false;
    bool showFingerboard = false;
    bool showNoteName = _isAnswerVisible; // 答案文字永遠是最後才出來

    switch (_practiceMode) {
      case PracticeMode.staffToFinger:
        // 題目: 譜 / 答案: 指板
        showStaff = true;
        showFingerboard = _isAnswerVisible;
        break;
      case PracticeMode.fingerToStaff:
        // 題目: 指板 / 答案: 譜
        showStaff = _isAnswerVisible;
        showFingerboard = true;
        break;
      case PracticeMode.earTraining:
        // 題目: 空 / 答案: 全部
        showStaff = _isAnswerVisible;
        showFingerboard = _isAnswerVisible;
        break;
    }
    // ----------------------------------------------------

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
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // 1. 答案文字區 (Do, Re, Mi)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              width: 300,
              height: 80, // 固定高度避免跳動
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: showNoteName ? Colors.green[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                showNoteName ? (_currentNote?.displayName ?? "") : "?",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: showNoteName ? Colors.black : Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. 五線譜區
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(300, 160),
                  painter: StaffPainter(
                    noteIndex: showStaff ? _currentNote?.staffIndex : null,
                  ),
                ),
                if (!showStaff)
                  // 顯示一個禁止符號代表被遮住
                  const Icon(
                    Icons.visibility_off,
                    size: 40,
                    color: Colors.grey,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. 指板區 (你的虛擬小提琴)
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(300, 160),
                  // 如果不顯示指板，傳入 null 給 painter，它會畫空指板或什麼都不畫
                  painter: ViolinFingerboardPainter(
                    note: showFingerboard ? _currentNote : null,
                    showBoard: true, // 永遠畫出指板框線，但手指位置根據邏輯顯示
                  ),
                ),
                if (!showFingerboard)
                  const Center(
                    child: Text(
                      "?",
                      style: TextStyle(fontSize: 50, color: Colors.grey),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 30),

            // 4. 按鈕區
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay, size: 30),
                  onPressed: () async {
                    if (_currentNote != null) {
                      double adjFreq =
                          _currentNote!.frequency * (_referencePitch / 440.0);
                      final wavBytes = ToneGenerator.generateSineWave(
                        frequency: adjFreq,
                        durationMs: 1000,
                        sampleRate: 44100,
                      );
                      await _player.stop();
                      await _player.play(BytesSource(wavBytes));
                    }
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _isAnswerVisible ? _nextNote : _revealAnswer,
                  icon: Icon(
                    _isAnswerVisible ? Icons.arrow_forward : Icons.visibility,
                  ),
                  label: Text(
                    _isAnswerVisible ? "下一題" : "看答案",
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    backgroundColor: _isAnswerVisible
                        ? Colors.blue
                        : Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. 繪圖引擎 - 五線譜
// ---------------------------------------------------------
class StaffPainter extends CustomPainter {
  final int? noteIndex;
  StaffPainter({this.noteIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;
    final Paint notePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    const double spaceHeight = 12.0;
    final double centerY = size.height / 2;

    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (noteIndex != null) {
      double baseLineY = centerY + 2 * spaceHeight * 2;
      double noteY = baseLineY - (noteIndex! * spaceHeight);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, noteY),
          width: 20,
          height: 14,
        ),
        notePaint,
      );

      if (noteIndex! < -1) {
        for (int i = -2; i >= noteIndex!; i -= 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(size.width / 2 - 18, lineY),
            Offset(size.width / 2 + 18, lineY),
            linePaint,
          );
        }
      }
      if (noteIndex! > 9) {
        for (int i = 10; i <= noteIndex!; i += 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(size.width / 2 - 18, lineY),
            Offset(size.width / 2 + 18, lineY),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// 4. 繪圖引擎 - 小提琴指板 (更新版)
// ---------------------------------------------------------
class ViolinFingerboardPainter extends CustomPainter {
  final ViolinNote? note;
  final bool showBoard; // 是否顯示指板背景

  ViolinFingerboardPainter({this.note, this.showBoard = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (!showBoard) return;

    final Paint stringPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 2.0;
    final Paint stringHighlightPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0;
    final Paint fingerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final Paint nutPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6.0;

    double stringSpacing = size.width / 5;
    double startX = stringSpacing;
    double topY = 20.0;
    double stringLength = size.height - 20;

    // 1. 畫弦枕 (上方的粗黑線)
    canvas.drawLine(
      Offset(startX - 10, topY),
      Offset(startX + stringSpacing * 3 + 10, topY),
      nutPaint,
    );

    // 弦的標籤
    List<String> labels = ["G", "D", "A", "E"];

    // 2. 畫四條弦
    for (int i = 0; i < 4; i++) {
      double x = startX + i * stringSpacing;
      // 如果 note 存在且是這條弦，就加粗顯示
      bool isTargetString = (note != null) && (note!.violinString.index == i);

      canvas.drawLine(
        Offset(x, topY),
        Offset(x, topY + stringLength),
        isTargetString ? stringHighlightPaint : stringPaint,
      );

      TextSpan span = TextSpan(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        text: labels[i],
      );
      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 0));
    }

    // 3. 畫手指位置
    if (note != null) {
      double x = startX + note!.violinString.index * stringSpacing;
      double fingerY = topY;

      if (note!.finger == 0) {
        // 空弦: 藍色空心圓
        canvas.drawCircle(
          Offset(x, topY - 10),
          6,
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // 按指: 紅色實心圓
        // 模擬第一把位音程距離
        List<double> fingerOffsets = [0, 35, 65, 95, 125];
        fingerY += fingerOffsets[note!.finger];

        canvas.drawCircle(Offset(x, fingerY), 8, fingerPaint);

        // 寫出指法數字 (1, 2, 3...)
        TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 10),
          text: "${note!.finger}",
        );
        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, fingerY - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------
// 5. 音訊合成器 (保持不變)
// ---------------------------------------------------------
class ToneGenerator {
  static Uint8List generateSineWave({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    int numSamples = (durationMs * sampleRate) ~/ 1000;
    int byteRate = sampleRate * 2;
    int dataSize = numSamples * 2;
    int fileSize = 36 + dataSize;
    final buffer = BytesBuilder();
    buffer.add("RIFF".codeUnits);
    buffer.add(_int32(fileSize));
    buffer.add("WAVE".codeUnits);
    buffer.add("fmt ".codeUnits);
    buffer.add(_int32(16));
    buffer.add(_int16(1));
    buffer.add(_int16(1));
    buffer.add(_int32(sampleRate));
    buffer.add(_int32(byteRate));
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
