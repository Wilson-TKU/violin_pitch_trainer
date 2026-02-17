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
class ViolinNote {
  final String noteName;
  final String solfege;
  final double frequency; // 這是以 440Hz 為基準的頻率
  final int staffIndex;

  const ViolinNote({
    required this.noteName,
    required this.solfege,
    required this.frequency,
    required this.staffIndex,
  });

  String get displayName => "$noteName ($solfege)";
}

// 題庫：以 A4=440Hz 為基準
const List<ViolinNote> scale = [
  // --- G 弦 ---
  ViolinNote(noteName: 'G3', solfege: 'Sol', frequency: 196.00, staffIndex: -5),
  ViolinNote(noteName: 'A3', solfege: 'La', frequency: 220.00, staffIndex: -4),
  ViolinNote(noteName: 'B3', solfege: 'Si', frequency: 246.94, staffIndex: -3),
  ViolinNote(noteName: 'C4', solfege: 'Do', frequency: 261.63, staffIndex: -2),
  // --- D 弦 ---
  ViolinNote(noteName: 'D4', solfege: 'Re', frequency: 293.66, staffIndex: -1),
  ViolinNote(noteName: 'E4', solfege: 'Mi', frequency: 329.63, staffIndex: 0),
  ViolinNote(noteName: 'F4', solfege: 'Fa', frequency: 349.23, staffIndex: 1),
  ViolinNote(noteName: 'G4', solfege: 'Sol', frequency: 392.00, staffIndex: 2),
  // --- A 弦 ---
  ViolinNote(noteName: 'A4', solfege: 'La', frequency: 440.00, staffIndex: 3),
  ViolinNote(noteName: 'B4', solfege: 'Si', frequency: 493.88, staffIndex: 4),
  ViolinNote(noteName: 'C5', solfege: 'Do', frequency: 523.25, staffIndex: 5),
  ViolinNote(noteName: 'D5', solfege: 'Re', frequency: 587.33, staffIndex: 6),
  // --- E 弦 ---
  ViolinNote(noteName: 'E5', solfege: 'Mi', frequency: 659.25, staffIndex: 7),
  ViolinNote(noteName: 'F5', solfege: 'Fa', frequency: 698.46, staffIndex: 8),
  ViolinNote(noteName: 'G5', solfege: 'Sol', frequency: 783.99, staffIndex: 9),
  ViolinNote(noteName: 'A5', solfege: 'La', frequency: 880.00, staffIndex: 10),
];

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

  // --- 新增設定變數 ---
  double _referencePitch = 440.0; // 基準音 (440 或 442)
  RangeValues _rangeValues = const RangeValues(
    0,
    15,
  ); // 預設全選 (0 到 scale.length-1)

  @override
  void initState() {
    super.initState();
    // 初始化範圍為整個題庫
    _rangeValues = RangeValues(0, scale.length - 1.0);
    _nextNote();
  }

  // 抽出下一個題目的邏輯
  Future<void> _nextNote() async {
    if (_isPlaying) return;

    // 1. 根據設定的範圍，計算出合法的 index 列表
    int start = _rangeValues.start.round();
    int end = _rangeValues.end.round();

    // 防呆：如果範圍太小
    if (end < start) end = start;

    // 2. 在範圍內隨機選一個
    int randomIndex = start + _rng.nextInt(end - start + 1);
    final note = scale[randomIndex];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
      _isAnswerVisible = false;
    });

    // 3. 計算頻率 (440 vs 442)
    // 公式： 新頻率 = 原頻率 * (設定基準 / 440)
    double adjustedFrequency = note.frequency * (_referencePitch / 440.0);

    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: adjustedFrequency,
      durationMs: 1000,
      sampleRate: 44100,
    );

    try {
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isPlaying = false);
  }

  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  // 顯示設定視窗
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 讓 BottomSheet 內部的 Slider 可以即時更新 UI
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "設定 (Settings)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // 1. 基準音設定
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
                            setModalState(() {
                              _referencePitch = newSelection.first;
                            });
                            // 同步更新外面的 State
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 2. 音域範圍設定
                  const Text("考試範圍 (Range):", style: TextStyle(fontSize: 18)),
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
                    labels: RangeLabels(
                      scale[_rangeValues.start.round()].noteName,
                      scale[_rangeValues.end.round()].noteName,
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        _rangeValues = values;
                      });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("小提琴音感 (${_referencePitch.toInt()} Hz)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 題目區
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isAnswerVisible ? Colors.green[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  _isAnswerVisible
                      ? (_currentNote?.displayName ?? "Ready")
                      : "?",
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: _isAnswerVisible ? Colors.black : Colors.grey,
                  ),
                ),
                if (!_isAnswerVisible && _currentNote != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "聽聲音 & 看位置，猜猜是哪個音？",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 五線譜區
          Center(
            child: CustomPaint(
              size: const Size(300, 200),
              painter: StaffPainter(noteIndex: _currentNote?.staffIndex),
            ),
          ),

          const SizedBox(height: 60),

          // 按鈕區
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.replay, size: 30),
                onPressed: _isPlaying
                    ? null
                    : () async {
                        if (_currentNote != null) {
                          setState(() => _isPlaying = true);
                          // Replay 也要套用新的頻率公式
                          double adjustedFrequency =
                              _currentNote!.frequency *
                              (_referencePitch / 440.0);

                          final wavBytes = ToneGenerator.generateSineWave(
                            frequency: adjustedFrequency,
                            durationMs: 1000,
                            sampleRate: 44100,
                          );
                          await _player.play(BytesSource(wavBytes));
                          setState(() => _isPlaying = false);
                        }
                      },
                tooltip: "再聽一次",
              ),
              ElevatedButton.icon(
                onPressed: _isPlaying
                    ? null
                    : (_isAnswerVisible ? _nextNote : _revealAnswer),
                icon: Icon(
                  _isAnswerVisible ? Icons.arrow_forward : Icons.visibility,
                ),
                label: Text(
                  _isAnswerVisible ? "下一題 (Next)" : "看答案 (Reveal)",
                  style: const TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. 繪圖引擎 (StaffPainter)
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

    const double spaceHeight = 15.0;
    final double centerY = size.height / 2;

    // 畫五線譜 (由下往上：E4, G4, B4, D5, F5)
    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (noteIndex != null) {
      double baseLineY = centerY + 2 * spaceHeight * 2; // E4 (第一線)
      double noteY = baseLineY - (noteIndex! * spaceHeight);

      // 畫音符豆豆
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, noteY),
          width: 22,
          height: 16,
        ),
        notePaint,
      );

      // 加線邏輯
      // 下加線 (Lower Leger Lines): index < -1 (低於 D4)
      if (noteIndex! < -1) {
        // 從 -2 (C4) 開始往下畫，每次跳 2 格 (一線)
        for (int i = -2; i >= noteIndex!; i -= 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(size.width / 2 - 20, lineY),
            Offset(size.width / 2 + 20, lineY),
            linePaint,
          );
        }
      }
      // 上加線 (Upper Leger Lines): index > 9 (高於 G5)
      // 第五線 F5 是 index 8, 上加一間 G5 是 9, 上加一線 A5 是 10
      if (noteIndex! > 9) {
        for (int i = 10; i <= noteIndex!; i += 2) {
          double lineY = baseLineY - (i * spaceHeight);
          canvas.drawLine(
            Offset(size.width / 2 - 20, lineY),
            Offset(size.width / 2 + 20, lineY),
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
// 4. 音訊合成器 (ToneGenerator)
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
