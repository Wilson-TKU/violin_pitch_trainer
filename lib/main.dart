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
// 1. 資料結構更新：加入唱名邏輯
class ViolinNote {
  final String noteName; // 音名 (e.g. G3)
  final String solfege; // 唱名 (e.g. Sol)
  final double frequency; // 頻率
  final int staffIndex; // 五線譜位置

  // 建構子稍微改一下，自動組合成顯示字串
  const ViolinNote({
    required this.noteName,
    required this.solfege,
    required this.frequency,
    required this.staffIndex,
  });

  // Getter: 方便UI直接拿 "G3 (Sol)" 這種格式
  String get displayName => "$noteName ($solfege)";
}

// 2. 題庫更新：小提琴常用音域 (包含空弦與手指按音)
const List<ViolinNote> scale = [
  // --- G 弦 (G3 ~ C4) ---
  ViolinNote(
    noteName: 'G3',
    solfege: 'Sol',
    frequency: 196.00,
    staffIndex: -5,
  ), // G弦空弦 (最低音)
  ViolinNote(
    noteName: 'A3',
    solfege: 'La',
    frequency: 220.00,
    staffIndex: -4,
  ), // G弦一指
  ViolinNote(
    noteName: 'B3',
    solfege: 'Si',
    frequency: 246.94,
    staffIndex: -3,
  ), // G弦二指
  ViolinNote(
    noteName: 'C4',
    solfege: 'Do',
    frequency: 261.63,
    staffIndex: -2,
  ), // 中央C (G弦三指)
  // --- D 弦 (D4 ~ G4) ---
  ViolinNote(
    noteName: 'D4',
    solfege: 'Re',
    frequency: 293.66,
    staffIndex: -1,
  ), // D弦空弦
  ViolinNote(
    noteName: 'E4',
    solfege: 'Mi',
    frequency: 329.63,
    staffIndex: 0,
  ), // 第一線
  ViolinNote(
    noteName: 'F4',
    solfege: 'Fa',
    frequency: 349.23,
    staffIndex: 1,
  ), // D弦二指(低)
  ViolinNote(
    noteName: 'G4',
    solfege: 'Sol',
    frequency: 392.00,
    staffIndex: 2,
  ), // D弦三指
  // --- A 弦 (A4 ~ D5) ---
  ViolinNote(
    noteName: 'A4',
    solfege: 'La',
    frequency: 440.00,
    staffIndex: 3,
  ), // A弦空弦 (標準音)
  ViolinNote(
    noteName: 'B4',
    solfege: 'Si',
    frequency: 493.88,
    staffIndex: 4,
  ), // 第三線
  ViolinNote(
    noteName: 'C5',
    solfege: 'Do',
    frequency: 523.25,
    staffIndex: 5,
  ), // A弦二指(低)
  ViolinNote(
    noteName: 'D5',
    solfege: 'Re',
    frequency: 587.33,
    staffIndex: 6,
  ), // A弦三指
  // --- E 弦 (E5 ~ A5) ---
  ViolinNote(
    noteName: 'E5',
    solfege: 'Mi',
    frequency: 659.25,
    staffIndex: 7,
  ), // E弦空弦
  ViolinNote(
    noteName: 'F5',
    solfege: 'Fa',
    frequency: 698.46,
    staffIndex: 8,
  ), // 第五線
  ViolinNote(
    noteName: 'G5',
    solfege: 'Sol',
    frequency: 783.99,
    staffIndex: 9,
  ), // 上加一間
  ViolinNote(
    noteName: 'A5',
    solfege: 'La',
    frequency: 880.00,
    staffIndex: 10,
  ), // E弦三指
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

  // 新增：控制答案顯示的布林值 (Flag)
  bool _isAnswerVisible = false;

  @override
  void initState() {
    super.initState();
    _nextNote();
  }

  Future<void> _nextNote() async {
    if (_isPlaying) return;

    final note = scale[_rng.nextInt(scale.length)];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
      _isAnswerVisible = false; // 每次出新題目時，先把答案蓋起來
    });

    // 合成並播放聲音
    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: note.frequency,
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

  // 新增：揭曉答案的邏輯
  void _revealAnswer() {
    setState(() {
      _isAnswerVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("小提琴音感考試模式")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. 題目區 (唱名)
          // 這裡運用三元運算子 (Ternary Operator) 來決定顯示什麼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isAnswerVisible ? Colors.green[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  // 如果 _isAnswerVisible 是 true 就顯示名字，否則顯示問號
                  _isAnswerVisible
                      ? (_currentNote?.displayName ?? "Ready")
                      : "?",
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: _isAnswerVisible ? Colors.black : Colors.grey,
                  ),
                ),
                // 如果答案還沒揭曉，顯示提示文字
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

          // 2. 五線譜繪圖區 (視覺提示)
          // 目前我們先保留「顯示位置」，因為你說要連結「視覺與聽覺」
          Center(
            child: CustomPaint(
              size: const Size(300, 200),
              painter: StaffPainter(noteIndex: _currentNote?.staffIndex),
            ),
          ),

          const SizedBox(height: 60),

          // 3. 操作按鈕區
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 按鈕 A: 重聽一次 (Replay)
              // 這是給考試用的實用功能
              IconButton(
                icon: const Icon(Icons.replay, size: 30),
                onPressed: _isPlaying
                    ? null
                    : () async {
                        if (_currentNote != null) {
                          setState(() => _isPlaying = true);
                          final wavBytes = ToneGenerator.generateSineWave(
                            frequency: _currentNote!.frequency,
                            durationMs: 1000,
                            sampleRate: 44100,
                          );
                          await _player.play(BytesSource(wavBytes));
                          setState(() => _isPlaying = false);
                        }
                      },
                tooltip: "再聽一次",
              ),

              // 按鈕 B: 揭曉答案 / 下一題
              // 這裡做了一個 UX 優化：
              // 如果答案還沒開 -> 按鈕顯示「看答案」
              // 如果答案已開 -> 按鈕顯示「下一題」
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
                  foregroundColor: Colors.white, // 文字顏色
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
// 3. 繪圖引擎 (Graphics / Framebuffer Logic)
// ---------------------------------------------------------
class StaffPainter extends CustomPainter {
  final int? noteIndex; // 0 = E4 Line

  StaffPainter({this.noteIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    final Paint notePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // 定義間距
    const double spaceHeight = 15.0;

    // 計算五條線的 Y 軸位置 (置中)
    // 我們希望 E4 (第一線) 在某個基準點
    // 五線譜由下而上：E4, G4, B4, D5, F5
    final double centerY = size.height / 2;

    // 畫五條線
    for (int i = 0; i < 5; i++) {
      // i=0 是最下線 (E4)
      // 在 Canvas 座標中，Y 越大越下面。
      // 為了讓 i=0 在最下面，我們設 base 為 centerY + 2格，然後往上減
      double y = centerY + (2 - i) * spaceHeight * 2;
      // *2 是因為線與線之間隔了一個「間」

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 畫音符
    if (noteIndex != null) {
      // 基準線 E4 (i=0) 的 Y 座標
      double baseLineY = centerY + 2 * spaceHeight * 2;

      // 每個 index 代表半個間距 (spaceHeight)
      double noteY = baseLineY - (noteIndex! * spaceHeight);

      // 畫豆豆
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, noteY),
          width: 22,
          height: 16,
        ),
        notePaint,
      );

      // 簡單的加線邏輯 (Leger Lines) - 針對 G3, A3, C4
      // 如果音符在第一線以下 (index < 0) 且是偶數位置(代表在線上的音)
      if (noteIndex! < -1) {
        for (int i = -2; i >= noteIndex!; i -= 2) {
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
// 4. 音訊合成器 (DSP / Wave Generation)
// ---------------------------------------------------------
class ToneGenerator {
  // 產生標準的 WAV Header + PCM Data
  static Uint8List generateSineWave({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    int numSamples = (durationMs * sampleRate) ~/ 1000;
    int byteRate = sampleRate * 2; // 16-bit mono = 2 bytes per sample
    int dataSize = numSamples * 2;
    int fileSize = 36 + dataSize;

    final buffer = BytesBuilder();

    // --- RIFF Header ---
    buffer.add("RIFF".codeUnits);
    buffer.add(_int32(fileSize));
    buffer.add("WAVE".codeUnits);

    // --- fmt Chunk ---
    buffer.add("fmt ".codeUnits);
    buffer.add(_int32(16)); // PCM chunk size
    buffer.add(_int16(1)); // AudioFormat 1 = PCM
    buffer.add(_int16(1)); // Channels 1 = Mono
    buffer.add(_int32(sampleRate));
    buffer.add(_int32(byteRate));
    buffer.add(_int16(2)); // BlockAlign
    buffer.add(_int16(16)); // BitsPerSample

    // --- data Chunk ---
    buffer.add("data".codeUnits);
    buffer.add(_int32(dataSize));

    // --- PCM Payload (Sinewave) ---
    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      // 振幅設為 0.5 避免爆音 (MAX 32767)
      double sample = 16000 * sin(2 * pi * frequency * t);
      buffer.add(_int16(sample.toInt()));
    }

    return buffer.toBytes();
  }

  static List<int> _int32(int value) {
    return [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];
  }

  static List<int> _int16(int value) {
    return [value & 0xff, (value >> 8) & 0xff];
  }
}
