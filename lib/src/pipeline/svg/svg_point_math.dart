import 'dart:math' as math;

import 'contour.dart';

/// Normalized direction vector from [from] to [to].
///
/// Returns `SvgPoint(1, 0)` for coincident points.
SvgPoint direction(SvgPoint from, SvgPoint to) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length < 1e-10) return const SvgPoint(1, 0);
  return SvgPoint(dx / length, dy / length);
}

/// Euclidean distance between two points.
double distance(SvgPoint a, SvgPoint b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}

/// Whether two points are equal within a 1e-6 tolerance.
bool pointsAreEqual(SvgPoint a, SvgPoint b) {
  return (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() < 1e-6;
}
