import 'dart:math';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../models/scale_data.dart'; // 需要引用 allNotes

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

  ViolinFingerboardPainter({this.targetNote, required this.currentKey});

  final double openStringLength = 325.0;
  final List<double> openFreqs = [196.00, 293.66, 440.00, 659.25];
  final List<String> stringNames = ["G", "D", "A", "E"];

  // 之後這部分邏輯會被移到 utils/violin_logic.dart
  double _calculatePosition(int semitonesFromOpen) {
    if (semitonesFromOpen <= 0) return -12;
    return openStringLength * (1 - 1 / pow(2, semitonesFromOpen / 12.0));
  }

  // 之後這部分邏輯會被移到 utils/violin_logic.dart
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
