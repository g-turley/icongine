import 'package:test/test.dart';
import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/stroke_join_builder.dart';

// stroke_join_builder.dart uncovered lines:
// 92-107:  isCorner=false, tangentLength < 1e-8 (antiparallel dirs) fallback
// 168:     _lineIntersection returns null → _midpoint fallback for outerCorner
// 176:     _lineIntersection returns null → _midpoint fallback for innerCorner
// 186-188: bevel join with cross >= 0 (left turn)
// 209-212: miter exceeded with cross < 0 (right turn)
// 215-217: miter exceeded with cross >= 0 (left turn)

void main() {
  const builder = StrokeJoinBuilder();
  const halfWidth = 10.0;
  const miterLimit = 4.0;

  group('StrokeJoinBuilder - isCorner=false', () {
    test('returns bisector normal when directions are nearly aligned', () {
      // Standard case: smooth curve subdivision point
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(20, 0.01); // nearly same direction

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.miter,
        miterLimit,
        false, // isCorner=false
      );

      expect(result.outerPoints, hasLength(1));
      expect(result.innerPoints, hasLength(1));
    });

    test(
      'returns fallback normal when directions are antiparallel (180 degree turn) and isCorner=false',
      () {
        // Lines 92-107: tangentX+tangentY ≈ 0 when dirIn and dirOut are opposite
        // dirIn = (1,0), dirOut = (-1,0): tangent = (0,0) → fallback
        const prev = SvgPoint(0, 0);
        const current = SvgPoint(10, 0);
        const next = SvgPoint(0, 0); // going back, dirOut = (-1,0)

        final result = builder.computeOffsets(
          prev,
          current,
          next,
          halfWidth,
          SvgStrokeLineJoin.miter,
          miterLimit,
          false, // isCorner=false → enters the non-corner branch
        );

        // The fallback normal is based on dirOut = (-1,0), so normal = (0,-1)
        // outer = current + normal*halfWidth, inner = current - normal*halfWidth
        expect(result.outerPoints, hasLength(1));
        expect(result.innerPoints, hasLength(1));
      },
    );

    test('preferredTangent used when directions are well-aligned', () {
      // Lines 68-83: preferredTangent branch
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(20, 0); // same direction
      const preferredTangent = SvgPoint(1, 0);

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.miter,
        miterLimit,
        false,
        preferredTangent: preferredTangent,
      );

      expect(result.outerPoints, hasLength(1));
      expect(result.innerPoints, hasLength(1));
      // With tangent=(1,0), normal=(0,1): outer.y = current.y + halfWidth
      expect(result.outerPoints.first.y, closeTo(current.y + halfWidth, 1e-6));
    });
  });

  group('StrokeJoinBuilder - near turnback (dot < -0.9)', () {
    // Lines 131-145: isNearTurnback branch
    test('round join emits arcs for near-180-degree corner', () {
      // dirIn=(1,0), dirOut=(-0.95, 0.31): dot ≈ -0.95 < -0.9
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(0.5, 3.1); // nearly antiparallel

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.round,
        miterLimit,
        true,
      );

      // round join at turnback produces arc points (>1)
      expect(result.outerPoints.length, greaterThan(1));
    });

    test('bevel join returns two points for near-180-degree corner', () {
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(0.5, 3.1);

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.bevel,
        miterLimit,
        true,
      );

      expect(result.outerPoints, hasLength(2));
      expect(result.innerPoints, hasLength(2));
    });
  });

  group('StrokeJoinBuilder - bevel join', () {
    test(
      'bevel with cross >= 0 (right turn: going right then down) returns outerCorner and two inner points',
      () {
        // Lines 186-188: bevel with cross >= 0
        // dirIn=(1,0), dirOut=(0,1) → cross = 1*1 - 0*0 = 1 > 0
        const prev = SvgPoint(0, 0);
        const current = SvgPoint(10, 0);
        const next = SvgPoint(10, 10); // right turn in SVG Y-down space

        final result = builder.computeOffsets(
          prev,
          current,
          next,
          halfWidth,
          SvgStrokeLineJoin.bevel,
          miterLimit,
          true,
        );

        expect(result.outerPoints, hasLength(1));
        expect(result.innerPoints, hasLength(2));
      },
    );

    test(
      'bevel with cross < 0 (left turn: going right then up) returns two outer points and innerCorner',
      () {
        // Lines 180-184: bevel with cross < 0
        // dirIn=(1,0), dirOut=(0,-1) → cross = 1*(-1) - 0*0 = -1 < 0
        const prev = SvgPoint(0, 0);
        const current = SvgPoint(10, 0);
        const next = SvgPoint(10, -10); // left turn in SVG Y-down space

        final result = builder.computeOffsets(
          prev,
          current,
          next,
          halfWidth,
          SvgStrokeLineJoin.bevel,
          miterLimit,
          true,
        );

        expect(result.outerPoints, hasLength(2));
        expect(result.innerPoints, hasLength(1));
      },
    );
  });

  group('StrokeJoinBuilder - round join', () {
    test('round with cross < 0 (left turn) returns arc outer points', () {
      // Lines 193-196: round with cross < 0
      // dirIn=(1,0), dirOut=(0,-1) → cross=-1 < 0
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(10, -10); // left turn

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.round,
        miterLimit,
        true,
      );

      expect(result.outerPoints.length, greaterThan(1));
      expect(result.innerPoints, hasLength(1));
    });

    test('round with cross >= 0 (right turn) returns arc inner points', () {
      // Lines 198-202: round with cross >= 0
      // dirIn=(1,0), dirOut=(0,1) → cross=1 >= 0
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(10, 10); // right turn

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.round,
        miterLimit,
        true,
      );

      expect(result.outerPoints, hasLength(1));
      expect(result.innerPoints.length, greaterThan(1));
    });
  });

  group('StrokeJoinBuilder - miter join with exceeded limit', () {
    test('miter uses midpoint fallback when offset lines are parallel', () {
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(20, 0);

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.miter,
        miterLimit,
        true,
      );

      expect(result.outerPoints, hasLength(1));
      expect(result.innerPoints, hasLength(1));
      expect(result.outerPoints.first.y, closeTo(halfWidth, 1e-6));
      expect(result.innerPoints.first.y, closeTo(-halfWidth, 1e-6));
    });

    test(
      'miter exceeded with cross < 0 (left turn) falls back to bevel-like result',
      () {
        // Lines 209-212: miterRatio > miterLimit, cross < 0
        // dirIn=(1,0), dirOut=(0,-1) → cross=-1 < 0
        // Use tiny miterLimit to force exceeded path
        const prev = SvgPoint(0, 0);
        const current = SvgPoint(10, 0);
        const next = SvgPoint(10, -10); // left turn (cross < 0)
        const tinyMiterLimit = 1.01;

        final result = builder.computeOffsets(
          prev,
          current,
          next,
          halfWidth,
          SvgStrokeLineJoin.miter,
          tinyMiterLimit,
          true,
        );

        // When miter exceeded with cross<0: 2 outer, 1 inner (like bevel)
        expect(result.outerPoints, hasLength(2));
        expect(result.innerPoints, hasLength(1));
      },
    );

    test(
      'miter exceeded with cross >= 0 (right turn) falls back to bevel-like result',
      () {
        // Lines 215-217: miterRatio > miterLimit, cross >= 0
        // dirIn=(1,0), dirOut=(0,1) → cross=1 >= 0
        const prev = SvgPoint(0, 0);
        const current = SvgPoint(10, 0);
        const next = SvgPoint(10, 10); // right turn (cross >= 0)
        const tinyMiterLimit = 1.01;

        final result = builder.computeOffsets(
          prev,
          current,
          next,
          halfWidth,
          SvgStrokeLineJoin.miter,
          tinyMiterLimit,
          true,
        );

        // When miter exceeded with cross>=0: 1 outer, 2 inner (like bevel)
        expect(result.outerPoints, hasLength(1));
        expect(result.innerPoints, hasLength(2));
      },
    );

    test('miter within limit returns single corner points', () {
      // Lines 220-223: miter within limit
      const prev = SvgPoint(0, 0);
      const current = SvgPoint(10, 0);
      const next = SvgPoint(20, 1); // very shallow turn

      final result = builder.computeOffsets(
        prev,
        current,
        next,
        halfWidth,
        SvgStrokeLineJoin.miter,
        miterLimit,
        true,
      );

      expect(result.outerPoints, hasLength(1));
      expect(result.innerPoints, hasLength(1));
    });
  });
}
