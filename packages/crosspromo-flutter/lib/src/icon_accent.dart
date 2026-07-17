import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Dominant brand color extracted from a promoted app's icon, normalized so
/// every derived color stays rich, legible, and pleasant in both themes.
class IconAccent {
  const IconAccent({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  /// Hue in degrees (0-360), matching [HSVColor].
  final double hue;
  final double saturation;
  final double brightness;

  /// Samples the icon and picks the strongest saturated hue family, ignoring
  /// transparent, near-white, near-black, and gray pixels.
  static Future<IconAccent?> extract(ui.Image image) async {
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (data == null) return null;
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final pixelCount = bytes.length ~/ 4;
    if (pixelCount == 0) return null;
    final step = math.max(1, pixelCount ~/ 4096);

    const bucketCount = 12;
    final weights = List<double>.filled(bucketCount, 0);
    final counts = List<int>.filled(bucketCount, 0);
    final reds = List<double>.filled(bucketCount, 0);
    final greens = List<double>.filled(bucketCount, 0);
    final blues = List<double>.filled(bucketCount, 0);
    var sampled = 0;

    for (var pixel = 0; pixel < pixelCount; pixel += step) {
      final offset = pixel * 4;
      sampled++;
      if (bytes[offset + 3] < 160) continue;
      final red = bytes[offset] / 255;
      final green = bytes[offset + 1] / 255;
      final blue = bytes[offset + 2] / 255;
      final value = math.max(red, math.max(green, blue));
      final chroma = value - math.min(red, math.min(green, blue));
      final saturation = value == 0 ? 0.0 : chroma / value;
      if (value < 0.16 || saturation < 0.16) continue;
      if (value > 0.95 && saturation < 0.2) continue;
      var hue = 0.0;
      if (chroma > 0) {
        if (value == red) {
          hue = ((green - blue) / chroma) % 6;
        } else if (value == green) {
          hue = (blue - red) / chroma + 2;
        } else {
          hue = (red - green) / chroma + 4;
        }
        hue /= 6;
        if (hue < 0) hue += 1;
      }
      final bucket = math.min(bucketCount - 1, (hue * bucketCount).floor());
      final weight = saturation * saturation * value;
      weights[bucket] += weight;
      counts[bucket] += 1;
      reds[bucket] += red * weight;
      greens[bucket] += green * weight;
      blues[bucket] += blue * weight;
    }

    var best = 0;
    for (var bucket = 1; bucket < bucketCount; bucket++) {
      if (weights[bucket] > weights[best]) best = bucket;
    }
    final threshold = math.max(12, (sampled * 0.02).round());
    if (counts[best] < threshold || weights[best] <= 0) return null;

    final color = Color.fromARGB(
      255,
      (reds[best] / weights[best] * 255).round().clamp(0, 255),
      (greens[best] / weights[best] * 255).round().clamp(0, 255),
      (blues[best] / weights[best] * 255).round().clamp(0, 255),
    );
    final hsv = HSVColor.fromColor(color);
    return IconAccent(
      hue: hsv.hue,
      saturation: hsv.saturation.clamp(0.55, 0.85).toDouble(),
      brightness: hsv.value,
    );
  }

  /// Saturated fill for the call-to-action capsule.
  Color ctaColor({required bool darkTheme}) {
    if (darkTheme) {
      return HSVColor.fromAHSV(
        1,
        hue,
        math.min(saturation, 0.75),
        brightness.clamp(0.62, 0.84).toDouble(),
      ).toColor();
    }
    return HSVColor.fromAHSV(
      1,
      hue,
      saturation,
      brightness.clamp(0.5, 0.72).toDouble(),
    ).toColor();
  }

  /// Text color on top of [ctaColor] — dark ink on bright accents (yellows,
  /// limes), white elsewhere, so the button never loses contrast.
  Color onCtaColor({required bool darkTheme}) {
    if (ctaColor(darkTheme: darkTheme).computeLuminance() > 0.4) {
      return const Color(0xFF12161C);
    }
    return const Color(0xFFFFFFFF);
  }

  /// Whisper of brand color meant to be alpha-blended over the card surface.
  Color washColor({required bool darkTheme}) => HSVColor.fromAHSV(
          1, hue, math.min(saturation, 0.8), darkTheme ? 0.72 : 0.56)
      .toColor()
      .withAlpha(darkTheme ? 33 : 15);

  Color hairlineColor({required bool darkTheme}) => HSVColor.fromAHSV(
          1, hue, math.min(saturation, 0.8), darkTheme ? 0.78 : 0.5)
      .toColor()
      .withAlpha(darkTheme ? 97 : 66);

  Color glowColor({required bool darkTheme}) =>
      HSVColor.fromAHSV(1, hue, saturation, darkTheme ? 0.72 : 0.6)
          .toColor()
          .withAlpha(darkTheme ? 128 : 82);

  Color chipBackgroundColor({required bool darkTheme}) => HSVColor.fromAHSV(
          1, hue, math.min(saturation, 0.8), darkTheme ? 0.75 : 0.55)
      .toColor()
      .withAlpha(darkTheme ? 61 : 36);

  Color chipTextColor({required bool darkTheme}) => HSVColor.fromAHSV(
          1, hue, math.min(saturation, 0.8), darkTheme ? 0.88 : 0.42)
      .toColor();
}
