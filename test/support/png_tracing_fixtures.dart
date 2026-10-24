import 'dart:math' as math;

import 'package:image/image.dart' as image;

/// Analytic silhouettes sampled into real 16x16 PNG fixtures.
final pngTracingFixtures = <String, bool Function(double, double)>{
  'circle': (x, y) => _radius(x, y) <= 5.5,
  'ring': (x, y) => _radius(x, y) <= 5.5 && _radius(x, y) >= 3.5,
  'arrow': (x, y) =>
      (x >= 2 && x <= 8 && y >= 6 && y <= 10) ||
      (x >= 7 && x <= 14 && (y - 8).abs() <= (14 - x) * 0.8),
  'square': (x, y) => x >= 3 && x <= 13 && y >= 3 && y <= 13,
  'diagonal': (x, y) => x >= 2 && x <= 14 && (y - x).abs() <= 0.6,
};

image.Image samplePngFixture(
  bool Function(double, double) contains, {
  bool antialias = true,
  int size = 16,
}) {
  final raster = image.Image(width: size, height: size, numChannels: 4);
  final samples = antialias ? 8 : 1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var covered = 0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          if (contains(
            (x + (sx + 0.5) / samples) * 16 / size,
            (y + (sy + 0.5) / samples) * 16 / size,
          )) {
            covered++;
          }
        }
      }
      raster.setPixelRgba(
        x,
        y,
        0,
        0,
        0,
        (covered * 255 / (samples * samples)).round(),
      );
    }
  }
  return raster;
}

double _radius(double x, double y) =>
    math.sqrt((x - 8) * (x - 8) + (y - 8) * (y - 8));
