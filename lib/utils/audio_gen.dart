import 'dart:math';
import 'dart:typed_data';

class ToneGenerator {
  static Uint8List generateSineWave({
    required double frequency,
    required int durationMs,
    required int sampleRate,
  }) {
    int numSamples = (durationMs * sampleRate) ~/ 1000;
    int dataSize = numSamples * 2;
    final buffer = BytesBuilder();
    buffer.add("RIFF".codeUnits);
    buffer.add(_int32(36 + dataSize));
    buffer.add("WAVE".codeUnits);
    buffer.add("fmt ".codeUnits);
    buffer.add(_int32(16));
    buffer.add(_int16(1));
    buffer.add(_int16(1));
    buffer.add(_int32(sampleRate));
    buffer.add(_int32(sampleRate * 2));
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
