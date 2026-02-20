import 'dart:math';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/violin_logic.dart';

// =====================================================================
// [重要配置] 定義音樂符號字型優先順序
// =====================================================================
const List<String> musicFontFallbacks = [
  'Bravura',
  'Apple Symbols',
  'Segoe UI Symbol',
  'Noto Music',
  'Symbola',
];

// --- 迷你調號繪圖器 (維持不變) ---
class KeySignaturePainter extends CustomPainter {
  final int accidentals;
  KeySignaturePainter({required this.accidentals});

  // 統一座標系：5 為中間線
  double _getY(int idx, double centerY, double spaceHeight) {
    return centerY - (idx - 5) * spaceHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double spaceHeight = 3.0;
    final Paint linePaint = Paint()
      ..color = Colors.black45
      ..strokeWidth = 1.0;

    // 畫五線譜
    for (int i = -2; i <= 2; i++) {
      double y = centerY + (i * spaceHeight * 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    if (accidentals == 0) return;

    bool isSharp = accidentals > 0;
    int count = accidentals.abs();
    String symbol = isSharp ? "\u266F" : "\u266D";

    List<int> sharpIndices = [9, 6, 10, 7, 4, 8, 5];
    List<int> flatIndices = [5, 8, 4, 7, 3, 6, 2];
    List<int> indices = isSharp ? sharpIndices : flatIndices;

    double startX = size.width / 2 - (count * 6.0) / 2;

    for (int i = 0; i < count; i++) {
      if (i >= indices.length) break;
      int idx = indices[i];
      double y = _getY(idx, centerY, spaceHeight);

      TextSpan span = TextSpan(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'serif',
          height: 1.0,
        ),
        text: symbol,
      );
      TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // 視覺置中微調
      double yOffset = isSharp ? tp.height * 0.5 : tp.height * 0.65;
      tp.paint(canvas, Offset(startX + i * 7.0, y - yOffset));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 五線譜繪圖器 (間距與排版全面優化) ---
class StaffPainter extends CustomPainter {
  final int? noteIndex;
  final MusicalKey keySignature;
  final bool isTargetOpenString;

  StaffPainter({
    this.noteIndex,
    required this.keySignature,
    this.isTargetOpenString = false,
  });

  // 絕對統一座標系
  double _getY(int idx, double centerY, double spaceHeight) {
    return centerY - (idx - 5) * spaceHeight;
  }

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

    final double spaceHeight = 10.0;

    // [排版間距設定]
    const double staffLeftPadding = 20.0; // 五線譜起始左邊距
    const double clefLeftPadding = 25.0; // 高音譜號左邊距
    const double clefToKeySpacing = 1.0; // 高音譜號與調號之間的距離
    const double keyToNoteSpacing = 70.0; // 調號結束與音符之間的最小安全距離

    // 1. 畫五條線
    for (int i = -2; i <= 2; i++) {
      double y = centerY + (i * spaceHeight * 2);
      canvas.drawLine(
        Offset(staffLeftPadding, y),
        Offset(size.width - 20, y),
        linePaint,
      );
    }

    // ============================================================
    // 2. 畫高音譜記號 (G-Clef)
    // ============================================================
    const double clefFontSize = 88.0;
    TextPainter clefPainter = TextPainter(
      text: const TextSpan(
        text: '\u{1D11E}',
        style: TextStyle(
          fontSize: clefFontSize,
          color: Colors.black,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    clefPainter.layout();

    // 對齊 G 線
    double gLineY = _getY(3, centerY, spaceHeight);
    // 使用新的左邊距
    clefPainter.paint(
      canvas,
      Offset(clefLeftPadding, gLineY - clefPainter.height * 0.65),
    );

    // ============================================================
    // 3. 畫調號 (升降記號) 並計算總寬度
    // ============================================================
    // 計算調號起始位置：高音譜號左邊距 + 高音譜號寬度 + 間距
    double currentKeyX = clefLeftPadding + clefPainter.width + clefToKeySpacing;
    // 用來記錄調號結束的最右邊位置
    double keySignatureEndX = currentKeyX;

    int accCount = keySignature.accidentals;
    if (accCount != 0) {
      bool isSharp = accCount > 0;
      int count = accCount.abs();

      List<int> sharpIndices = [9, 6, 10, 7, 4, 8, 5];
      List<int> flatIndices = [5, 8, 4, 7, 3, 6, 2];

      List<int> indicesToDraw = isSharp ? sharpIndices : flatIndices;
      String symbol = isSharp ? "\u266F" : "\u266D";
      // 升降記號之間的水平間距
      double accSpacing = 16.0;

      for (int i = 0; i < count; i++) {
        if (i >= indicesToDraw.length) break;
        int idx = indicesToDraw[i];
        double targetY = _getY(idx, centerY, spaceHeight);

        // 在當前 X 位置繪製
        _drawAccidental(
          canvas,
          Offset(currentKeyX, targetY),
          spaceHeight,
          symbol,
          isSharp,
        );

        // 更新 X 位置給下一個符號
        currentKeyX += accSpacing;
      }
      // 記錄最後一個符號結束的大約位置 (稍微扣回一點因為最後一個迴圈多加了一次間距)
      keySignatureEndX = currentKeyX - accSpacing + 10.0; // +10 是符號本身的大約寬度緩衝
    }

    // ============================================================
    // 4. 畫目標音符 (動態計算位置)
    // ============================================================
    if (noteIndex != null) {
      // [核心邏輯] 計算音符的 X 座標
      // 1. 計算音符的「最小安全 X 座標」：調號結束位置 + 安全間距
      double minNoteX = keySignatureEndX + keyToNoteSpacing;

      // 2. 最終音符位置：取「畫布中心」與「最小安全座標」的最大值
      //    這樣保證音符至少在中間，但如果調號太長，音符會自動往右移。
      double noteX = max(centerX, minNoteX);

      double noteY = _getY(noteIndex!, centerY, spaceHeight);

      // --- 符頭 (Note Head) ---
      double noteWidth = spaceHeight * 2.4;
      double noteHeight = spaceHeight * 1.6;

      canvas.save();
      // 使用動態計算的 noteX
      canvas.translate(noteX, noteY);
      canvas.rotate(-0.25);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: noteWidth,
          height: noteHeight,
        ),
        notePaint,
      );
      canvas.restore();

      // --- 空弦外圈 ---
      if (isTargetOpenString) {
        canvas.drawCircle(
          Offset(noteX, noteY), // 使用 noteX
          spaceHeight * 1.6,
          Paint()
            ..color = Colors.blueAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // --- 符桿 (Stem) ---
      bool stemDown = noteIndex! >= 5;
      double stemLength = spaceHeight * 7.0;
      double stemXOffset = (noteWidth / 2) - 0.7;

      Paint stemPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5;

      if (stemDown) {
        canvas.drawLine(
          Offset(noteX - stemXOffset, noteY + noteHeight * 0.1), // 使用 noteX
          Offset(noteX - stemXOffset, noteY + stemLength),
          stemPaint,
        );
      } else {
        canvas.drawLine(
          Offset(noteX + stemXOffset, noteY - noteHeight * 0.1), // 使用 noteX
          Offset(noteX + stemXOffset, noteY - stemLength),
          stemPaint,
        );
      }

      // --- 加線 (Ledger Lines) ---
      // 加線也要以 noteX 為中心繪製
      if (noteIndex! < 1) {
        for (int i = 0; i >= noteIndex!; i -= 2) {
          double lineY = _getY(i, centerY, spaceHeight);
          canvas.drawLine(
            Offset(noteX - 18, lineY),
            Offset(noteX + 18, lineY),
            linePaint,
          );
        }
      }
      if (noteIndex! > 9) {
        for (int i = 11; i <= noteIndex!; i += 2) {
          double lineY = _getY(i, centerY, spaceHeight);
          canvas.drawLine(
            Offset(noteX - 18, lineY),
            Offset(noteX + 18, lineY),
            linePaint,
          );
        }
      }
    }
  }

  // 繪製升降記號 (維持不變)
  void _drawAccidental(
    Canvas canvas,
    Offset centerPos,
    double spaceHeight,
    String text,
    bool isSharp,
  ) {
    TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.black,
        fontSize: spaceHeight * 4.0,
        fontFamily: 'serif',
        fontWeight: FontWeight.w600,
      ),
      text: text,
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    double yOffset = isSharp ? tp.height * 0.52 : tp.height * 0.63;
    tp.paint(canvas, Offset(centerPos.dx, centerPos.dy - yOffset));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 指板繪圖器 (維持不變) ---
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

      if (isTargetString && targetSemitones == 0) {
        canvas.drawCircle(Offset(x, 8), 12, targetPaint);
      }

      TextPainter(
          text: TextSpan(
            text: stringNames[stringIdx],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
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
          if (s != 0) {
            canvas.drawCircle(Offset(x, y), 7, hintPaint);
          }
        }

        if (isTargetString && s == targetSemitones) {
          int fingerNum = ViolinLogic.calcFingerNum(s, currentPosition);

          if (s != 0) {
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
