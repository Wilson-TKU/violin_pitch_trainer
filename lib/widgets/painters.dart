import 'dart:math';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/violin_logic.dart';

// --- 迷你調號繪圖器 (維持穩定版邏輯) ---
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
        style: const TextStyle(
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

// --- 五線譜繪圖器 (加入符桿與美化，保留穩定座標系) ---
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

    // 固定的五線譜間距，確保升降記號座標完美對齊
    final double spaceHeight = 10.0;

    // 1. 畫五條線
    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), linePaint);
    }

    // 2. 畫升降記號 (完美還原正確的座標矩陣)
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

    // 3. 畫目標音符與符桿
    if (noteIndex != null) {
      double baseLineY = centerY + 2 * spaceHeight * 2; // 最下面那條線 (E4)
      double noteY = baseLineY - (noteIndex! * spaceHeight);

      double noteWidth = spaceHeight * 2.4; // 音符寬度
      double noteHeight = spaceHeight * 1.6; // 音符高度

      // --- [NEW] 畫符桿 (Stem) ---
      // staffIndex 4 是 B4 (五線譜正中間那條線)。大於等於它符桿朝下。
      bool stemDown = noteIndex! >= 4;
      double stemLength = spaceHeight * 6.5;
      double stemXOffset = (noteWidth / 2) - 0.5; // 符桿要貼齊符頭邊緣

      Paint stemPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      if (stemDown) {
        // 符桿朝下 (畫在音符左邊)
        canvas.drawLine(
          Offset(centerX - stemXOffset, noteY),
          Offset(centerX - stemXOffset, noteY + stemLength),
          stemPaint,
        );
      } else {
        // 符桿朝上 (畫在音符右邊)
        canvas.drawLine(
          Offset(centerX + stemXOffset, noteY),
          Offset(centerX + stemXOffset, noteY - stemLength),
          stemPaint,
        );
      }

      // --- [NEW] 畫更真實的符頭 (Tilted Oval) ---
      canvas.save();
      canvas.translate(centerX, noteY);
      canvas.rotate(-0.25); // 稍微傾斜，看起來更像手寫/印刷樂譜
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: noteWidth,
          height: noteHeight,
        ),
        notePaint,
      );
      canvas.restore();

      // --- 畫加線 (Ledger Lines) ---
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

// --- 指板繪圖器 (維持穩定版邏輯，不動它) ---
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

    double visibleLengthMm = 200.0;
    double pixelPerMm = (size.height - nutY) / visibleLengthMm;

    var range = ViolinLogic.getScanRange(currentPosition);

    for (int stringIdx = 0; stringIdx < 4; stringIdx++) {
      double x = firstStringX + stringIdx * stringSpacing;

      bool isTargetString = false;
      int targetSemitones = -1;

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

      for (int s = range.start; s <= range.end; s++) {
        double posFreq = ViolinLogic.openFreqs[stringIdx] * pow(2, s / 12.0);
        var result = ViolinLogic.analyzeFrequency(
          posFreq,
          stringIdx,
          currentKey,
        );

        double mm = ViolinLogic.calculatePositionMm(s);
        double y = nutY + (mm * pixelPerMm);

        if (y > size.height - 5) continue;

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
