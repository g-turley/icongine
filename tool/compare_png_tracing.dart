import 'dart:io';

import 'package:icongine/icongine.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;

import '../test/support/png_tracing_fixtures.dart';

/// Writes real 16x16 PNGs and OTF/TTF comparison fonts to build/png_tracing.
/// Run with --serve to inspect the generated fonts at http://127.0.0.1:5174.
Future<void> main(List<String> args) async {
  final output = Directory('build/png_tracing')..createSync(recursive: true);
  final symbols = <IconSymbol>[];
  final rows = StringBuffer();
  for (final fixture in pngTracingFixtures.entries) {
    for (final antialias in [true, false]) {
      final name = '${fixture.key}_${antialias ? 'aa' : 'binary'}';
      final file = File(path.join(output.path, '$name.png'));
      file.writeAsBytesSync(
        image.encodePng(samplePngFixture(fixture.value, antialias: antialias)),
      );
      final code = 0xe001 + symbols.length;
      symbols.add(
        IconSymbol(
          file: IconFile(
            absolutePath: file.absolute.path,
            relativePath: '$name.png',
          ),
          name: name,
        ),
      );
      rows.writeln('''
<tr><th scope="row">${fixture.key}<small>${antialias ? 'Antialiased' : 'Binary alpha'}</small></th>
<td><div class="frame"><img src="$name.png" alt="16 by 16 ${fixture.key} input"></div></td>
<td><div class="frame"><span class="glyph legacy">&#$code;</span></div></td>
<td><div class="frame improved"><span class="glyph smooth">&#$code;</span></div></td></tr>
''');
    }
  }

  for (final format in FontFormat.values) {
    for (final mode in [PngTracingMode.legacy, PngTracingMode.smooth]) {
      final fontPath = path.join(output.path, '${mode.name}.${format.name}');
      final result = const SvgFontCompiler().compile(
        config: GenerationConfig(
          packageName: 'comparison',
          inputDir: output.path,
          outClassFile: path.join(output.path, 'icons.dart'),
          outFontFile: fontPath,
          className: 'Comparison',
          fontFormat: format,
          pngTracing: mode,
        ),
        symbols: symbols,
      );
      File(fontPath).writeAsBytesSync(result.fontBytes);
    }
  }
  File(
    path.join(output.path, 'index.html'),
  ).writeAsStringSync(_html(rows.toString()));
  stdout.writeln(
    'Wrote ${symbols.length} PNG fixtures and four comparison fonts to ${output.path}.',
  );
  if (!args.contains('--serve')) return;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 5174);
  stdout.writeln('PNG tracing comparison: http://127.0.0.1:5174');
  await for (final request in server) {
    final name = request.uri.path == '/'
        ? 'index.html'
        : request.uri.path.substring(1);
    final file = File(path.join(output.path, name));
    if (!path.isWithin(output.absolute.path, file.absolute.path) ||
        !file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      final mime = switch (path.extension(name)) {
        '.html' => 'text/html; charset=utf-8',
        '.png' => 'image/png',
        '.otf' => 'font/otf',
        '.ttf' => 'font/ttf',
        _ => 'application/octet-stream',
      };
      request.response.headers.set(HttpHeaders.contentTypeHeader, mime);
      request.response.add(file.readAsBytesSync());
    }
    await request.response.close();
  }
}

String _html(String rows) =>
    '''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>icongine · PNG tracing</title>
<style>
@font-face{font-family:legacy-otf;src:url(legacy.otf)}
@font-face{font-family:smooth-otf;src:url(smooth.otf)}
@font-face{font-family:legacy-ttf;src:url(legacy.ttf)}
@font-face{font-family:smooth-ttf;src:url(smooth.ttf)}
*{box-sizing:border-box}body{margin:0;padding:40px 24px;background:#f3f6f5;color:#132a26;font:16px system-ui,sans-serif}
main{max-width:1000px;margin:auto}header{display:flex;align-items:center;justify-content:space-between;gap:24px}
h1{font-size:32px;letter-spacing:-1px;margin:8px 0}p{color:#4d625c;line-height:1.5}
.eyebrow{font-size:12px;text-transform:uppercase;letter-spacing:2px;font-weight:700;color:#006a60}
label{font-size:14px}select{margin-left:8px;padding:12px;border:1px solid #8daba1;border-radius:8px;background:white;font:inherit}
.scroll{overflow:auto;margin-top:32px}table{border-collapse:collapse;width:100%;min-width:560px;background:white;border:1px solid #d6e1dc}
th,td{padding:12px;text-align:center;border-bottom:1px solid #d6e1dc}thead th{font-size:14px;color:#4d625c;background:#eaf0ed}
tbody th{text-align:left;width:160px;text-transform:capitalize}small{display:block;color:#62766f;font-size:12px;font-weight:400;text-transform:none;margin-top:8px}
.frame{width:clamp(96px,18vw,200px);height:clamp(96px,18vw,200px);display:grid;place-items:center;border-radius:8px;background:#f5f7f6;margin:auto}
.improved{background:#e7f5ee}.glyph{font-size:clamp(96px,18vw,200px);line-height:1;font-synthesis:none}.legacy{font-family:legacy-otf}.smooth{font-family:smooth-otf}
img{width:clamp(92px,17.3vw,192px);height:clamp(92px,17.3vw,192px);image-rendering:pixelated}#status{font-size:13px;min-height:24px}
@media(max-width:700px){body{padding:24px 16px}header{align-items:start;flex-direction:column}h1{font-size:28px}}
</style><main><header><div><div class="eyebrow">icongine / tracing comparison</div>
<h1>Small PNG. Smooth outline.</h1><p>Real 16×16 inputs, enlarged alongside their generated font glyphs.</p></div>
<label>Font format<select id="format"><option value="otf">OTF</option><option value="ttf">TTF</option></select></label></header>
<div id="status" role="status">Loading generated fonts…</div><div class="scroll"><table>
<thead><tr><th>Source</th><th>16×16 PNG</th><th>Existing tracing</th><th>Smooth tracing</th></tr></thead>
<tbody>$rows</tbody></table></div><p>Binary alpha has no antialiasing information. Smooth mode protects confident alpha samples and falls back to interpolated contours when a curve would damage topology. Smooth tracing is now the default.</p></main>
<script>
const select=document.getElementById('format');
async function update(){
  const format=select.value, status=document.getElementById('status');
  document.querySelectorAll('.legacy').forEach(el=>el.style.fontFamily='legacy-'+format);
  document.querySelectorAll('.smooth').forEach(el=>el.style.fontFamily='smooth-'+format);
  try{await Promise.all(['legacy','smooth'].map(mode=>document.fonts.load('200px '+mode+'-'+format)));
    status.textContent='Displaying generated '+format.toUpperCase()+' fonts.';
  }catch(error){status.textContent='Font loading failed. Check the development server.';}
}
select.addEventListener('change',update);update();
</script></html>''';
