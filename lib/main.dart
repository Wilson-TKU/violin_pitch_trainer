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
  final String name; // 音名 (e.g., A4)
  final double frequency; // 頻率 (Hz)
  final int staffIndex; // 五線譜位置：以第一線(E4)為 0，每高半格(線或間) +1

  const ViolinNote(this.name, this.frequency, this.staffIndex);
}

// 定義小提琴四條空弦 + 常見音
// staffIndex: 0=E4(下數第一線), 2=G4, 4=B4, 6=D5, 8=F5(上數第一線)
const List<ViolinNote> scale = [
  ViolinNote('G3 (G弦)', 196.00, -5), // E4往下推5格 (G3在下加二間)
  ViolinNote('D4 (D弦)', 293.66, -1), // E4往下推1格 (下加一間)
  ViolinNote('A4 (A弦)', 440.00, 3), // E4往上推3格 (第二間)
  ViolinNote('E5 (E弦)', 659.25, 7), // E4往上推7格 (第四間)
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

  @override
  void initState() {
    super.initState();
    _nextNote(); // 啟動時先來一個
  }

  Future<void> _nextNote() async {
    if (_isPlaying) return;

    // 1. 隨機選音
    final note = scale[_rng.nextInt(scale.length)];

    setState(() {
      _currentNote = note;
      _isPlaying = true;
    });

    // 2. 即時合成音訊 (Real-time Synthesis)
    // 這裡我們直接生成 1秒鐘 的 Sine Wave WAV 數據
    final Uint8List wavBytes = ToneGenerator.generateSineWave(
      frequency: note.frequency,
      durationMs: 1000,
      sampleRate: 44100,
    );

    // 3. 播放
    try {
      await _player.play(BytesSource(wavBytes));
    } catch (e) {
      debugPrint("Audio Error: $e");
    }

    // 簡單延遲讓動畫感覺自然一點
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Violin Trainer MVP")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 顯示音名
          Text(
            _currentNote?.name ?? "Ready",
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            _currentNote != null ? "${_currentNote!.frequency} Hz" : "",
            style: const TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 60),

          // 五線譜繪圖區
          Center(
            child: CustomPaint(
              size: const Size(300, 200),
              painter: StaffPainter(noteIndex: _currentNote?.staffIndex),
            ),
          ),

          const SizedBox(height: 80),

          // 按鈕
          ElevatedButton.icon(
            onPressed: _isPlaying ? null : _nextNote,
            icon: const Icon(Icons.music_note),
            label: const Text("Next Random Note"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
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
