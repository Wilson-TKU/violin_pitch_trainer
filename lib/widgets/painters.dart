import 'dart:math'; // [修正] 補上這行，才能使用 pow
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/violin_logic.dart';

// --- 迷你調號繪圖器 ---
class KeySignaturePainter extends CustomPainter {
  final int accidentals;
  KeySignaturePainter({required this.accidentals});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double spaceHeight = 3.0;
    final Paint linePaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1.0;

    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (accidentals == 0) return;

    bool isSharp = accidentals > 0;
    int count = accidentals.abs();
    String symbol = isSharp ? "#" : "b";

    List<int> sharpIndices = [8, 5, 9, 6, 3, 7, 4];
    List<int> flatIndices = [4, 7, 3, 6, 2, 5, 1];
    List<int> indices = isSharp ? sharpIndices : flatIndices;

    double startX = size.width / 2 - (count * 6.0) / 2;

    for (int i = 0; i < count; i++) {
      if (i >= indices.length) break;
      int idx = indices[i];
      double y = centerY + 2 * spaceHeight * 2 - (idx * spaceHeight);

      TextSpan span = TextSpan(
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
        text: symbol,
      );
      TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(startX + i * 7.0, y - tp.height / 1.7));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 五線譜繪圖器 ---
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

    List<int> sharpIndices = [8, 5, 9, 6, 3, 7, 4];
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

// --- 指板繪圖器 ---
class ViolinFingerboardPainter extends CustomPainter {
  final ViolinNote? targetNote;
  final MusicalKey currentKey;
  final ViolinPosition currentPosition;

  ViolinFingerboardPainter({
    this.targetNote,
    required this.currentKey,
    this.currentPosition = ViolinPosition.first,
  });

  final List<String> stringNames = ["G", "D", "A", "E"];

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

    // 背景指板
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

    // 調整比例：顯示 160mm 長度，適應第三把位
    double visibleLengthMm = 160.0;
    double pixelPerMm = (size.height - nutY) / visibleLengthMm;

    // 從 Logic 取得要掃描的半音範圍
    var range = ViolinLogic.getScanRange(currentPosition);

    for (int stringIdx = 0; stringIdx < 4; stringIdx++) {
      double x = firstStringX + stringIdx * stringSpacing;

      bool isTargetString = false;
      int targetSemitones = -1;

      // 判斷目標音
      if (targetNote != null) {
        var result = ViolinLogic.analyzeFrequency(
          targetNote!.frequency,
          stringIdx,
          currentKey,
        );
        if (result.note == targetNote) {
          isTargetString = true;
          targetSemitones = result.semitones;
        }
      }

      // 畫弦
      canvas.drawLine(
        Offset(x, nutY),
        Offset(x, size.height),
        isTargetString ? highlightStringPaint : stringPaint,
      );

      // 畫弦名
      TextPainter(
          text: TextSpan(
            text: stringNames[stringIdx],
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(x - 5, 0));

      // 根據把位範圍進行掃描
      for (int s = range.start; s <= range.end; s++) {
        double posFreq = ViolinLogic.openFreqs[stringIdx] * pow(2, s / 12.0);
        var result = ViolinLogic.analyzeFrequency(
          posFreq,
          stringIdx,
          currentKey,
        );

        double mm = ViolinLogic.calculatePositionMm(s);
        double y = nutY + (mm * pixelPerMm);

        // 安全檢查，避免畫出邊界
        if (y > size.height - 5) continue;

        // 畫背景圖鑑
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

        // 畫目標高亮
        if (isTargetString && s == targetSemitones) {
          int fingerNum = ViolinLogic.calcFingerNum(s, currentPosition);

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
