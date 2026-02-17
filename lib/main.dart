import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MaterialApp(home: ViolinApp()));
}

// ---------------------------------------------------------
// 1. 資料結構與頻率定義 (BSP Data Model)
// ---------------------------------------------------------

// 定義小提琴的四條弦
enum ViolinString { G, D, A, E }

class ViolinNote {
  final String noteName;
  final String solfege;
  final double frequency; // Base 440Hz
  final int staffIndex;

  // 新增：小提琴指法資訊 (第一把位)
  final ViolinString violinString; // 哪一條弦
  final int finger; // 第幾指 (0=空弦, 1=食指, 2=中指, 3=無名指, 4=小指)

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

// 題庫：更新為包含指法資訊 (以第一把位 First Position 為主)
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
  ), // F Natural (低二指)
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
  ), // C Natural (低二指)
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
  ), // F Natural (低一指)
  ViolinNote(
    noteName: 'G5',
    solfege: 'Sol',
    frequency: 783.99,
    staffIndex: 9,
    violinString: ViolinString.E,
    finger: 2,
  ), // G Natural (低二指)
  ViolinNote(
    noteName: 'A5',
    solfege: 'La',
    frequency: 880.00,
    staffIndex: 10,
    violinString: ViolinString.E,
    finger: 3,
  ),
];

// 定義練習模式
enum PracticeMode {
  sightReading, // 視譜反應 (看譜 -> 猜音/指法)
  earTraining, // 聽音辨位 (聽音 -> 猜譜/指法)
}

// ---------------------------------------------------------
// 2. 核心邏輯 UI (App Logic)
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
  PracticeMode _practiceMode = PracticeMode.sightReading; // 預設視譜模式

  @override
  void initState() {
    super.initState();
    _nextNote();
  }

  Future<void> _nextNote() async {
    // 關鍵修改：如果是視譜模式，按下一題要瞬間切掉上一個聲音
    await _player.stop();

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

    // 播放聲音
    double adjustedFrequency = note.frequency * (_referencePitch / 440.0);
    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: adjustedFrequency,
      durationMs: 1500, // 稍微加長一點，方便聽音模式
      sampleRate: 44100,
    );

    try {
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    // 聲音播放完畢的 callback 就不強制設為 false 了，
    // 因為我們現在允許中途切斷，狀態管理交給按鈕邏輯
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _currentNote == note) {
      // 確保不是已經切到下一題了
      setState(() => _isPlaying = false);
    }
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  // 設定視窗
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "設定 (Settings)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  const Text("練習模式 (Mode):", style: TextStyle(fontSize: 18)),
                  SegmentedButton<PracticeMode>(
                    segments: const [
                      ButtonSegment(
                        value: PracticeMode.sightReading,
                        label: Text("視譜 (看->聽)"),
                        icon: Icon(Icons.visibility),
                      ),
                      ButtonSegment(
                        value: PracticeMode.earTraining,
                        label: Text("聽寫 (聽->看)"),
                        icon: Icon(Icons.hearing),
                      ),
                    ],
                    selected: {_practiceMode},
                    onSelectionChanged: (Set<PracticeMode> newSelection) {
                      setModalState(() {
                        _practiceMode = newSelection.first;
                      });
                      setState(() {
                        _nextNote(); // 切換模式時直接換一題
                      });
                    },
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    "基準音 (Reference Pitch):",
                    style: TextStyle(fontSize: 18),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<double>(
                          segments: const [
                            ButtonSegment(value: 440.0, label: Text("440 Hz")),
                            ButtonSegment(value: 442.0, label: Text("442 Hz")),
                          ],
                          selected: {_referencePitch},
                          onSelectionChanged: (Set<double> newSelection) {
                            setModalState(
                              () => _referencePitch = newSelection.first,
                            );
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("音域範圍 (Range):", style: TextStyle(fontSize: 18)),
                  Text(
                    "${scale[_rangeValues.start.round()].displayName}  ~  ${scale[_rangeValues.end.round()].displayName}",
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
    // 邏輯判斷：是否要顯示五線譜
    // 1. 如果是「視譜模式」，永遠顯示
    // 2. 如果是「聽音模式」，只有在 Answer Visible 時才顯示
    bool showStaff =
        _practiceMode == PracticeMode.sightReading || _isAnswerVisible;

    // 邏輯判斷：是否要顯示答案文字
    // 只有在按下 Reveal 後才顯示，無論哪種模式
    bool showText = _isAnswerVisible;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _practiceMode == PracticeMode.sightReading ? "視譜極速反應" : "聽音盲測",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        // 防止螢幕太小溢出
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // 1. 答案顯示區
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: showText ? Colors.green[100] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                showText
                    ? (_currentNote?.displayName ?? "")
                    : (_practiceMode == PracticeMode.sightReading
                          ? "..."
                          : "?"),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: showText ? Colors.black : Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 2. 五線譜區 (根據模式隱藏或顯示)
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
                  const Icon(
                    Icons.visibility_off,
                    size: 50,
                    color: Colors.grey,
                  ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. 小提琴指板示意圖 (新功能!)
            // 只有在揭曉答案，或是視譜模式下才顯示
            if (showStaff) ...[
              const Text(
                "指板位置 (Fingerboard)",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              CustomPaint(
                size: const Size(300, 150), // 寬度 300, 高度 150
                painter: ViolinFingerboardPainter(note: _currentNote),
              ),
            ] else ...[
              const SizedBox(height: 160 + 30), // 佔位符，保持介面高度不跳動
            ],

            const SizedBox(height: 30),

            // 4. 按鈕區
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay, size: 30),
                  onPressed: () async {
                    // 重播邏輯
                    if (_currentNote != null) {
                      double adjFreq =
                          _currentNote!.frequency * (_referencePitch / 440.0);
                      final wavBytes = ToneGenerator.generateSineWave(
                        frequency: adjFreq,
                        durationMs: 1000,
                        sampleRate: 44100,
                      );
                      await _player.stop(); // 先停再播
                      await _player.play(BytesSource(wavBytes));
                    }
                  },
                  tooltip: "再聽一次",
                ),

                // 智慧按鈕
                ElevatedButton.icon(
                  onPressed: _isAnswerVisible ? _nextNote : _revealAnswer,
                  icon: Icon(
                    _isAnswerVisible ? Icons.arrow_forward : Icons.visibility,
                  ),
                  label: Text(
                    _isAnswerVisible ? "下一題 (Next)" : "看答案 (Reveal)",
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
// 3. 繪圖引擎 - 五線譜 (StaffPainter)
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
    const double spaceHeight = 12.0; // 稍微縮小一點適應螢幕
    final double centerY = size.height / 2;

    // 畫五線
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

      // 加線
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
// 4. 繪圖引擎 - 小提琴指板 (ViolinFingerboardPainter)
// ---------------------------------------------------------
class ViolinFingerboardPainter extends CustomPainter {
  final ViolinNote? note;
  ViolinFingerboardPainter({this.note});

  @override
  void paint(Canvas canvas, Size size) {
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

    // 參數定義
    double stringSpacing = size.width / 5; // 四條弦平分寬度
    double startX = stringSpacing;
    double topY = 20.0; // 弦枕位置
    double stringLength = size.height - 20;

    // 1. 畫弦枕 (Nut)
    canvas.drawLine(
      Offset(startX - 10, topY),
      Offset(startX + stringSpacing * 3 + 10, topY),
      nutPaint,
    );

    // 2. 畫四條弦 (G, D, A, E)
    List<String> labels = ["G", "D", "A", "E"];
    for (int i = 0; i < 4; i++) {
      double x = startX + i * stringSpacing;

      // 如果是當前選到的弦，畫粗一點
      bool isTargetString = note != null && note!.violinString.index == i;

      canvas.drawLine(
        Offset(x, topY),
        Offset(x, topY + stringLength),
        isTargetString ? stringHighlightPaint : stringPaint,
      );

      // 畫弦的名稱 (G, D, A, E)
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
      tp.paint(canvas, Offset(x - tp.width / 2, 0)); // 標籤在最上面
    }

    // 3. 畫按手指的位置
    if (note != null) {
      double x = startX + note!.violinString.index * stringSpacing;

      // 計算手指的 Y 軸位置 (模擬指板間距，越往下一指距離越寬)
      // 簡單模擬：每指大概間距 30
      double fingerY = topY;
      if (note!.finger == 0) {
        // 空弦：畫一個空心圓在弦枕上方
        canvas.drawCircle(
          Offset(x, topY - 10),
          6,
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        // 1, 2, 3, 4 指
        // 這裡做簡單的距離模擬
        List<double> fingerOffsets = [0, 35, 65, 95, 125];
        fingerY += fingerOffsets[note!.finger];

        // 畫紅色實心圓代表按壓點
        canvas.drawCircle(Offset(x, fingerY), 8, fingerPaint);

        // 標示指法數字
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
// 5. 音訊合成器 (ToneGenerator) - 保持不變
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
