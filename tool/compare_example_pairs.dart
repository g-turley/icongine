import 'dart:io';
import 'dart:math' as math;

import 'package:icongine/icongine.dart';
import 'package:icongine/src/pipeline/contour/contour_flattener.dart';
import 'package:path/path.dart' as path;

void main() {
  final repoRoot = Directory.current;
  final svgDirectory = Directory(
    path.join(repoRoot.path, 'example', 'assets', 'icons', 'svg'),
  );
  final pngDirectory = Directory(
    path.join(repoRoot.path, 'example', 'assets', 'icons', 'png'),
  );
  final outputDirectory = Directory(
    path.join(repoRoot.path, 'example', 'build', 'compare'),
  )..createSync(recursive: true);

  final svgFiles = {
    for (final file in svgDirectory.listSync().whereType<File>())
      path.basenameWithoutExtension(file.path): file,
  };
  final pngFiles = {
    for (final file in pngDirectory.listSync().whereType<File>())
      path.basenameWithoutExtension(file.path): file,
  };
  final sharedNames = svgFiles.keys.toSet().intersection(pngFiles.keys.toSet())
    ..toList().sort();

  final rows = <_ComparisonRow>[];
  for (final iconName in sharedNames.toList()..sort()) {
    final svgFile = svgFiles[iconName]!;
    final pngFile = pngFiles[iconName]!;
    rows.add(
      _ComparisonRow(
        iconName: iconName,
        svg: _compilePreview(svgFile),
        png: _compilePreview(pngFile),
      ),
    );
  }

  final reportFile = File(
    path.join(outputDirectory.path, 'png_svg_glyph_comparison.html'),
  );
  reportFile.writeAsStringSync(_buildHtml(rows));
  stdout.writeln('Wrote ${reportFile.path}');
}

_CompiledPreview _compilePreview(File sourceFile) {
  final compiler = const SvgFontCompiler();
  final result = compiler.compile(
    config: GenerationConfig(
      packageName: 'example',
      inputDir: sourceFile.parent.path,
      outFontFile: path.join(sourceFile.parent.path, 'placeholder.otf'),
      outClassFile: path.join(sourceFile.parent.path, 'placeholder.dart'),
      normalize: false,
    ),
    symbols: [
      IconSymbol(
        file: IconFile(
          absolutePath: sourceFile.absolute.path,
          relativePath: path.basename(sourceFile.path),
        ),
        name: path.basenameWithoutExtension(sourceFile.path),
      ),
    ],
  );

  final glyph = result.glyphs.single;
  final contourPath = glyph.compiledContourPath!;
  final bounds = _measureBounds(contourPath);
  final svgMarkup = _renderContourSvg(
    contourPath: contourPath,
    width: 220,
    height: 220,
    strokeColor: '#111827',
    fillColor: '#111827',
  );

  return _CompiledPreview(
    sourcePath: sourceFile.path,
    sourceName: path.basename(sourceFile.path),
    contourCount: contourPath.contours.length,
    segmentCount: contourPath.contours.fold<int>(
      0,
      (count, contour) => count + contour.segments.length,
    ),
    bounds: bounds,
    svgMarkup: svgMarkup,
    contourPath: contourPath,
  );
}

String _buildHtml(List<_ComparisonRow> rows) {
  final cards = rows
      .map((row) {
        final overlayMarkup = _renderOverlaySvg(
          svgContourPath: row.svg,
          pngContourPath: row.png,
          width: 220,
          height: 220,
        );
        return '''
<article class="card">
  <header>
    <h2>${row.iconName}</h2>
    <p>${row.svg.segmentCount} svg segments vs ${row.png.segmentCount} png segments</p>
  </header>
  <section class="grid">
    <div class="panel">
      <h3>SVG glyph</h3>
      ${row.svg.svgMarkup}
      <p>${row.svg.sourceName}</p>
      <p>${_boundsLabel(row.svg.bounds)}</p>
    </div>
    <div class="panel">
      <h3>PNG glyph</h3>
      ${row.png.svgMarkup}
      <p>${row.png.sourceName}</p>
      <p>${_boundsLabel(row.png.bounds)}</p>
    </div>
    <div class="panel">
      <h3>Overlay</h3>
      $overlayMarkup
      <p><span class="legend svg"></span> SVG <span class="legend png"></span> PNG</p>
    </div>
  </section>
</article>
''';
      })
      .join('\n');

  return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PNG vs SVG Glyph Comparison</title>
  <style>
    :root {
      --bg: #f4f1e8;
      --surface: #fffdf7;
      --ink: #1d1d1f;
      --muted: #6b6b6b;
      --border: #d8d0c0;
      --svg: #111827;
      --png: #dc2626;
    }
    body {
      margin: 0;
      font-family: Georgia, "Iowan Old Style", serif;
      background:
        radial-gradient(circle at top left, #fff7d6 0, transparent 24rem),
        linear-gradient(180deg, #f6f2e8 0%, #efe7d6 100%);
      color: var(--ink);
    }
    main {
      max-width: 1200px;
      margin: 0 auto;
      padding: 32px 20px 48px;
    }
    h1 {
      margin: 0 0 8px;
      font-size: 2.2rem;
    }
    .intro {
      margin: 0 0 28px;
      color: var(--muted);
      max-width: 70ch;
    }
    .card {
      background: rgba(255, 253, 247, 0.9);
      border: 1px solid var(--border);
      border-radius: 18px;
      padding: 18px;
      margin-bottom: 18px;
      box-shadow: 0 12px 30px rgba(70, 58, 30, 0.08);
    }
    .card header h2 {
      margin: 0;
      font-size: 1.4rem;
    }
    .card header p {
      margin: 6px 0 0;
      color: var(--muted);
    }
    .grid {
      margin-top: 16px;
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 14px;
    }
    .panel {
      background: white;
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 12px;
    }
    .panel h3 {
      margin: 0 0 10px;
      font-size: 1rem;
    }
    .glyph {
      width: 100%;
      height: auto;
      background:
        linear-gradient(90deg, rgba(216,208,192,0.4) 1px, transparent 1px) 0 0 / 24px 24px,
        linear-gradient(rgba(216,208,192,0.4) 1px, transparent 1px) 0 0 / 24px 24px,
        #fcfbf7;
      border-radius: 10px;
    }
    .panel p {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 0.92rem;
    }
    .legend {
      display: inline-block;
      width: 10px;
      height: 10px;
      border-radius: 999px;
      margin-left: 10px;
      margin-right: 4px;
      vertical-align: middle;
    }
    .legend.svg { background: var(--svg); margin-left: 0; }
    .legend.png { background: var(--png); }
  </style>
</head>
<body>
  <main>
    <h1>PNG vs SVG Glyph Comparison</h1>
    <p class="intro">
      Each row compares the final compiled glyph outlines for icons that exist in both
      <code>example/assets/icons/svg</code> and <code>example/assets/icons/png</code>.
      The overlay panel draws the SVG glyph in black and the PNG-derived glyph in red.
    </p>
    $cards
  </main>
</body>
</html>
''';
}

String _boundsLabel(_Bounds bounds) {
  return 'bounds ${bounds.minX.toStringAsFixed(1)}, ${bounds.minY.toStringAsFixed(1)} '
      'to ${bounds.maxX.toStringAsFixed(1)}, ${bounds.maxY.toStringAsFixed(1)}';
}

String _renderContourSvg({
  required SvgContourPath contourPath,
  required double width,
  required double height,
  required String strokeColor,
  required String fillColor,
}) {
  final bounds = _measureBounds(contourPath);
  final padding = 18.0;
  final contentWidth = math.max(1.0, bounds.maxX - bounds.minX);
  final contentHeight = math.max(1.0, bounds.maxY - bounds.minY);
  final scale = math.min(
    (width - padding * 2) / contentWidth,
    (height - padding * 2) / contentHeight,
  );
  final offsetX = (width - contentWidth * scale) / 2 - bounds.minX * scale;
  final offsetY = (height - contentHeight * scale) / 2 - bounds.minY * scale;
  final renderedPolylines = contourPath.contours.map((contour) {
    final points = flattenContourToPolyline(contour, curveSteps: 24)
        .map(
          (point) =>
              '${(point.x * scale + offsetX).toStringAsFixed(2)},'
              '${(height - (point.y * scale + offsetY)).toStringAsFixed(2)}',
        )
        .join(' ');
    return '<polygon points="$points" />';
  }).join();

  return '''
<svg class="glyph" viewBox="0 0 ${width.toStringAsFixed(0)} ${height.toStringAsFixed(0)}" xmlns="http://www.w3.org/2000/svg">
  <g fill="$fillColor" stroke="$strokeColor" stroke-width="1.5">
    $renderedPolylines
  </g>
</svg>
''';
}

String _renderOverlaySvg({
  required _CompiledPreview svgContourPath,
  required _CompiledPreview pngContourPath,
  required double width,
  required double height,
}) {
  final mergedBounds = _Bounds(
    minX: math.min(svgContourPath.bounds.minX, pngContourPath.bounds.minX),
    minY: math.min(svgContourPath.bounds.minY, pngContourPath.bounds.minY),
    maxX: math.max(svgContourPath.bounds.maxX, pngContourPath.bounds.maxX),
    maxY: math.max(svgContourPath.bounds.maxY, pngContourPath.bounds.maxY),
  );
  final padding = 18.0;
  final contentWidth = math.max(1.0, mergedBounds.maxX - mergedBounds.minX);
  final contentHeight = math.max(1.0, mergedBounds.maxY - mergedBounds.minY);
  final scale = math.min(
    (width - padding * 2) / contentWidth,
    (height - padding * 2) / contentHeight,
  );
  final offsetX =
      (width - contentWidth * scale) / 2 - mergedBounds.minX * scale;
  final offsetY =
      (height - contentHeight * scale) / 2 - mergedBounds.minY * scale;

  String polygonsFor(SvgContourPath contourPath, String color, double opacity) {
    return contourPath.contours.map((contour) {
      final points = flattenContourToPolyline(contour, curveSteps: 24)
          .map(
            (point) =>
                '${(point.x * scale + offsetX).toStringAsFixed(2)},'
                '${(height - (point.y * scale + offsetY)).toStringAsFixed(2)}',
          )
          .join(' ');
      return '<polygon points="$points" fill="$color" fill-opacity="$opacity" '
          'stroke="$color" stroke-width="2" />';
    }).join();
  }

  return '''
<svg class="glyph" viewBox="0 0 ${width.toStringAsFixed(0)} ${height.toStringAsFixed(0)}" xmlns="http://www.w3.org/2000/svg">
  ${polygonsFor(svgContourPath.contourPath, '#111827', 0.16)}
  ${polygonsFor(pngContourPath.contourPath, '#dc2626', 0.16)}
</svg>
''';
}

_Bounds _measureBounds(SvgContourPath contourPath) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final contour in contourPath.contours) {
    for (final point in flattenContourToPolyline(contour, curveSteps: 24)) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
  }

  if (!minX.isFinite) {
    return const _Bounds(minX: 0, minY: 0, maxX: 1, maxY: 1);
  }
  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

class _ComparisonRow {
  const _ComparisonRow({
    required this.iconName,
    required this.svg,
    required this.png,
  });

  final String iconName;
  final _CompiledPreview svg;
  final _CompiledPreview png;
}

class _CompiledPreview {
  const _CompiledPreview({
    required this.sourcePath,
    required this.sourceName,
    required this.contourCount,
    required this.segmentCount,
    required this.bounds,
    required this.svgMarkup,
    required this.contourPath,
  });

  final String sourcePath;
  final String sourceName;
  final int contourCount;
  final int segmentCount;
  final _Bounds bounds;
  final String svgMarkup;
  final SvgContourPath contourPath;
}

class _Bounds {
  const _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}
