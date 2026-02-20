import 'dart:math';
import 'package:flutter/material.dart';
import '../models/note.dart';
import '../utils/violin_logic.dart';

// =====================================================================
// [重要配置] 定義音樂符號字型優先順序
// 這能確保在不同平台上，系統會優先選用專業的音樂符號字型進行渲染，
// 而不是使用醜醜的系統預設文字字型。
// =====================================================================
const List<String> musicFontFallbacks = [
  'Bravura', // 專業樂譜軟體標準字型 (如果使用者有安裝)
  'Apple Symbols', // macOS/iOS 內建高品質符號
  'Segoe UI Symbol', // Windows 內建符號
  'Noto Music', // Android/Linux 常見音樂字型
  'Symbola', // 通用符號字型
];

// --- 迷你調號繪圖器 (維持原本邏輯，但套用新字型以求統一) ---
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
    // 使用標準音樂 Unicode 符號
    String symbol = isSharp ? "\u266F" : "\u266D";

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
          fontSize: 14, // 稍微調整大小
          fontWeight: FontWeight.normal, // 專業樂譜符號不需粗體
          height: 1.0,
          fontFamilyFallback: musicFontFallbacks, // [套用新字型]
        ),
        text: symbol,
      );
      TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      // 精準垂直置中
      tp.paint(canvas, Offset(startX + i * 7.0, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 五線譜繪圖器 (高音譜號與升降記號精準化) ---
class StaffPainter extends CustomPainter {
  final int? noteIndex;
  final MusicalKey keySignature;
  final bool isTargetOpenString;

  StaffPainter({
    this.noteIndex,
    required this.keySignature,
    this.isTargetOpenString = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.3; // 稍微加粗一點點線條，更有質感
    final Paint notePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final double spaceHeight = 10.0;
    const double staffLeftPadding = 20.0;

    // 1. 畫五條線
    for (int i = 0; i < 5; i++) {
      double y = centerY + (2 - i) * spaceHeight * 2;
      canvas.drawLine(
        Offset(staffLeftPadding, y),
        Offset(size.width - 20, y),
        linePaint,
      );
    }

    // ============================================================
    // 2. 畫高音譜記號 (G-Clef) - 精準定位版
    // ============================================================
    // 大小相對於五線譜間距設定，約跨越 8 個間距
    final double clefFontSize = spaceHeight * 8.2;
    const double clefLeftOffset = 20.0;

    TextPainter clefPainter = TextPainter(
      text: TextSpan(
        text: '\u{1D11E}', // G-Clef Unicode
        style: TextStyle(
          fontSize: clefFontSize,
          color: Colors.black,
          height: 1.0,
          fontFamilyFallback: musicFontFallbacks, // [套用新字型]
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    clefPainter.layout();

    // G線的 Y 座標 (從下數上來第二條線)
    double gLineY = centerY + spaceHeight;

    // [精準定位邏輯]
    // 1. 先將圖形垂直中心對齊 G 線 (gLineY - clefPainter.height / 2)
    // 2. 大多數音樂字型的基線設計偏高，需要一個微小的向下修正偏移量。
    //    經過測試，約 0.25 個 spaceHeight 的偏移量能讓螺旋中心完美對齊 G 線。
    double clefCorrectionOffset = spaceHeight * 0.25;
    double clefY = gLineY - (clefPainter.height / 2) + clefCorrectionOffset;

    clefPainter.paint(canvas, Offset(clefLeftOffset, clefY));

    // ============================================================
    // 3. 畫調號 (升降記號) - 標準化大小與位置
    // ============================================================
    double keySignatureStartX = clefLeftOffset + clefPainter.width + 5.0;
    int accCount = keySignature.accidentals;
    if (accCount != 0) {
      bool isSharp = accCount > 0;
      int count = accCount.abs();

      List<int> sharpIndices = [8, 5, 9, 6, 3, 7, 4];
      List<int> flatIndices = [4, 7, 3, 6, 2, 5, 1];

      List<int> indicesToDraw = isSharp ? sharpIndices : flatIndices;
      String symbol = isSharp ? "\u266F" : "\u266D";

      // 標準間距：符號寬度 + 一點空隙
      double accSpacing = spaceHeight * 1.4;

      for (int i = 0; i < count; i++) {
        if (i >= indicesToDraw.length) break;
        int idx = indicesToDraw[i];
        // 計算目標線或間的中心 Y 座標
        double targetY = centerY + 2 * spaceHeight * 2 - (idx * spaceHeight);
        _drawAccidental(
          canvas,
          Offset(keySignatureStartX + i * accSpacing, targetY),
          spaceHeight,
          symbol,
        );
      }
    }

    // 4. 畫目標音符 (維持不變)
    if (noteIndex != null) {
      double baseLineY = centerY + 2 * spaceHeight * 2;
      double noteY = baseLineY - (noteIndex! * spaceHeight);

      // --- 符頭 ---
      double noteWidth = spaceHeight * 2.4;
      double noteHeight = spaceHeight * 1.6;

      canvas.save();
      canvas.translate(centerX, noteY);
      canvas.rotate(-0.28); // 稍微調整傾斜角度，更貼近參考圖
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
          Offset(centerX, noteY),
          spaceHeight * 1.6,
          Paint()
            ..color = Colors.blueAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // --- 符桿 ---
      bool stemDown = noteIndex! >= 4;
      double stemLength = spaceHeight * 7.0;
      // 微調符桿與符頭的接觸點
      double stemXOffset = (noteWidth / 2) - 0.8;

      Paint stemPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round; // 圓角端點更好看

      if (stemDown) {
        canvas.drawLine(
          Offset(centerX - stemXOffset, noteY + noteHeight * 0.1), // 稍微插入符頭一點
          Offset(centerX - stemXOffset, noteY + stemLength),
          stemPaint,
        );
      } else {
        canvas.drawLine(
          Offset(centerX + stemXOffset, noteY - noteHeight * 0.1),
          Offset(centerX + stemXOffset, noteY - stemLength),
          stemPaint,
        );
      }

      // --- 加線 ---
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

  // 輔助函式：繪製精準對齊的升降記號
  void _drawAccidental(
    Canvas canvas,
    Offset targetCenterPos,
    double spaceHeight,
    String text,
  ) {
    TextSpan span = TextSpan(
      style: TextStyle(
        color: Colors.black,
        // 大小標準化：約為五線譜間距的 3.3 倍
        fontSize: spaceHeight * 3.3,
        fontWeight: FontWeight.normal, // 不用粗體
        height: 1.0,
        fontFamilyFallback: musicFontFallbacks, // [套用新字型]
      ),
      text: text,
    );
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();

    // [精準定位邏輯]
    // 將文字方塊的中心點，對齊目標座標的中心點
    double drawX = targetCenterPos.dx;
    double drawY = targetCenterPos.dy - (tp.height / 2);

    // 微調：音樂字型的視覺中心有時不再物理中心，做極小的修正
    // 降記號稍微往上一點點視覺上比較平衡
    if (text == "\u266D") {
      drawY -= spaceHeight * 0.05;
    }

    tp.paint(canvas, Offset(drawX, drawY));
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

      // 如果目標是這條弦的空弦，畫紅色實心底圖
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
