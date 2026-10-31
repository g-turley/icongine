"""Build committed README figures and a study from measured font renders."""
import json
import statistics
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from viewer import build_viewer


INK = '#142c27'
MUTED = '#526b63'
GREEN = '#e4f1e9'
BG = '#f7faf8'
ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/png_study')
DEST = Path('doc/images')
DEST.mkdir(parents=True, exist_ok=True)
DATA = json.loads((ROOT / 'measurements.json').read_text())
MANIFEST = json.loads((ROOT / 'manifest.json').read_text())


def font(size, bold=False):
    # Cross-platform system UI fonts; figure geometry stays fixed.
    candidates = (['C:/Windows/Fonts/segoeuib.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
                  if bold else ['C:/Windows/Fonts/segoeui.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'])
    for name in candidates:
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default(size=size)


def mask(name, size, mode='smooth', fmt='otf'):
    return Image.open(ROOT / 'renders' / f'{name}_{mode}_{fmt}.png').convert('L').resize((size, size), Image.Resampling.LANCZOS)


def reference(name, size):
    return Image.open(ROOT / f'{name}_reference.png').getchannel('A').resize((size, size), Image.Resampling.LANCZOS)


def paste_mask(canvas, alpha, x, y, color=INK):
    canvas.paste(Image.new('RGB', alpha.size, color), (x, y), alpha)


def title(canvas, heading, subtitle, tag):
    draw = ImageDraw.Draw(canvas)
    draw.text((48, 28), tag.upper(), fill='#16705c', font=font(19, True))
    draw.text((48, 65), heading, fill=INK, font=font(42, True))
    draw.text((48, 126), subtitle, fill=MUTED, font=font(23))


def gallery():
    ids = ['ring', 'arrow', 'accessibility', 'basket', 'earth', 'rosette', 'lattice']
    labels = {f['id']: f['label'] for f in MANIFEST['fixtures']}
    sizes = {name: 64 for name in ids}
    sizes['rosette'] = 256  # The sweep shows narrow petal gaps need more information.
    width, row_height, top = 1600, 208, 250
    canvas = Image.new('RGB', (width, top + len(ids)*row_height + 92), BG)
    title(canvas, 'From source art to a real icon font',
          'Independent SVG / PNG previews beside glyphs rendered from the generated font files.', 'icongine · source to output')
    draw = ImageDraw.Draw(canvas)
    columns = [260, 520, 780, 1040, 1300]
    headings = ['SVG source', 'SVG → OTF', 'PNG source', 'PNG → OTF', 'PNG → TTF']
    for x, label in zip(columns, headings):
        draw.text((x+12, 205), label, fill=MUTED, font=font(23, True))
    for row, name in enumerate(ids):
        y = top + row*row_height
        draw.line((48, y, width-48, y), fill='#d5e2db', width=1)
        draw.text((48, y+57), labels[name], fill=INK, font=font(24, True))
        draw.text((48, y+97), f'{sizes[name]} × {sizes[name]} PNG', fill=MUTED, font=font(20))
        for x in columns[3:]:
            draw.rounded_rectangle((x, y+16, x+214, y+194), radius=12, fill=GREEN)
        paste_mask(canvas, reference(name, 176), columns[0]+18, y+17)
        paste_mask(canvas, mask(f'{name}_svg', 176), columns[1]+18, y+17)
        png = Image.open(ROOT / 'inputs' / f'{name}_{sizes[name]}.png').getchannel('A')
        # Match the library's 92% fit while exposing the source's actual pixels.
        source = Image.new('L', (176, 176))
        source.paste(png.resize((162, 162), Image.Resampling.NEAREST), (7, 7))
        paste_mask(canvas, source, columns[2]+18, y+17)
        paste_mask(canvas, mask(f'{name}_{sizes[name]}', 176), columns[3]+18, y+17)
        paste_mask(canvas, mask(f'{name}_{sizes[name]}', 176, fmt='ttf'), columns[4]+18, y+17)
    draw.text((48, canvas.height-62), 'Monochrome alpha silhouettes. OTF and TTF share the design; rasterization can differ slightly.', fill=MUTED, font=font(22))
    canvas.save(DEST / 'source-to-font.png', optimize=True)


def scale_grid():
    ids = ['circle', 'accessibility', 'basket', 'earth', 'rosette', 'lattice']
    sizes = [16, 32, 64, 128, 512]
    labels = {f['id']: f['label'] for f in MANIFEST['fixtures']}
    canvas = Image.new('RGB', (1600, 250 + len(ids)*192 + 88), BG)
    title(canvas, 'How much source resolution is enough?',
          'Same designs, same output size. Every sample below is a rendered OTF glyph, not an SVG contour preview.', 'icongine · PNG scale sweep')
    draw = ImageDraw.Draw(canvas)
    columns = [280, 532, 784, 1036, 1288]
    for x, size in zip(columns, sizes):
        draw.text((x+18, 203), f'{size} × {size} PNG', fill=MUTED, font=font(24, True))
    for row, name in enumerate(ids):
        y = 250 + row*192
        draw.line((48, y, 1552, y), fill='#d5e2db', width=1)
        draw.text((48, y+67), labels[name], fill=INK, font=font(24, True))
        for x, size in zip(columns, sizes):
            if size == 64:
                draw.rounded_rectangle((x, y+12, x+204, y+180), radius=12, fill=GREEN)
            rendered = mask(f'{name}_{size}', 160)
            if rendered.getbbox() is None:
                draw.text((x+30, y+70), 'Detail lost', fill=MUTED, font=font(22))
            else:
                paste_mask(canvas, rendered, x+22, y+13)
    draw.text((48, canvas.height-61), '64px is a practical starting point. Fine gaps and dense linework may still need 128–512px or SVG.', fill=MUTED, font=font(22))
    canvas.save(DEST / 'png-resolution.png', optimize=True)


def evidence():
    summaries = []
    for size in MANIFEST['sizes']:
        subset = [r for r in DATA if r['mode']=='smooth' and r['format']=='otf' and r['size']==size]
        simple = [r['iou'] for r in subset if r['kind']=='simple']
        detail = [r for r in subset if r['kind']=='detail']
        summaries.append(dict(size=size, simple_iou=statistics.median(simple),
                              detail_iou=statistics.median(r['iou'] for r in detail),
                              detail_topology_matches=sum(r['topology']==r['reference_topology'] for r in detail),
                              detail_count=len(detail), median_segments=statistics.median(r['segments'] for r in subset)))
    table = '\n'.join(f"| {r['size']} | {r['simple_iou']:.1%} | {r['detail_iou']:.1%} | {r['detail_topology_matches']}/{r['detail_count']} | {r['median_segments']:.0f} |" for r in summaries)
    report = f'''# PNG tracing scale study

Smooth tracing makes 64px a practical starting point for ordinary icons, with
128px preferable for detailed shapes. Very fine gaps still need 256–512px or SVG.
These are fixture-based recommendations, not a minimum size or a universal guarantee.

![PNG source resolution versus rendered OTF glyph](images/png-resolution.png)

## Measured results

Eight designs cover circles, rings, sharp corners, thin strokes, a basket,
organic continents, a fine radial pattern, and 25 cutouts. Each design was
independently rasterized at nine source resolutions, then compiled to both OTF
and TTF using both legacy and smooth tracing. Three designs are classed as
simple; five are detailed. All figures show actual FreeType font renders.

| PNG side (px) | Simple median IoU | Detailed median IoU | Detailed topology matches | Median outline segments |
| --- | --- | --- | --- | --- |
{table}

IoU is the intersection divided by the union of filled pixels against the
independent SVG reference, measured at 256px with a 50% alpha threshold. Fonts
are rendered at 1024px and downsampled to 256px. Reference SVGs are rendered at
2048px and downsampled, with the same 92% em-square fit. Sources retain the same
geometry and padding at every resolution; small PNGs are not enlarged before
tracing. Topology checks count connected foreground islands and holes; a high
area score can still conceal a closed gap. Exact counts are measured on the
final font render and can vary with rasterization size and quantization.

The detail median improves by only about two percentage points from 64px to
512px on this fixture set, but the finest pattern is a deliberate exception:
its closely spaced petals need 256px to retain all islands and holes. Prefer
SVG when the source is available. Upscaling an existing tiny PNG adds no detail.

OTF and TTF encode the same design using different outline representations.
Their median filled-pixel agreement here is {statistics.median(r['format_iou'] for r in DATA if r['mode']=='smooth'):.2%};
small antialiasing and quantization differences are expected. The README shows
both formats side by side rather than claiming byte-identical pixels.

## Library behavior

Smooth tracing is the default in pubspec, CLI, and programmatic use. Its alpha
saddle rule keeps nearby thick shapes separate while joining isolated diagonal
stroke samples. Curve acceptance protects confident interior/exterior samples
(alpha ≤25% or ≥75%); soft edge samples may move within the fit tolerance.
Binary inputs retain exact pixel-center coverage. Topology, bounds, winding,
and sampled crossings are checked before a fit is accepted.

Sources up to 64px use 0.15px simplification and 0.18px control deviation.
Larger sources scale those tolerances gradually, capped at 0.30px and 0.36px.
Overly complex or unsafe fits retain interpolated line contours. Pixel mode
keeps exact thresholded boundaries; legacy mode reproduces older PNG output.

## Reproduce

Install Node.js, Dart, and Python, then run from the repository root:

```sh
npm install --prefix tool/png_study
python -m pip install -r tool/png_study/requirements.txt
node tool/png_study/prepare.cjs
dart run tool/png_study/compile.dart
python tool/png_study/render.py
python tool/png_study/publish.py
```

To inspect live font rendering with size and format controls, serve the output
with `python -m http.server 5175 --bind 127.0.0.1 --directory build/png_study`
and open `http://127.0.0.1:5175`.

The study writes inputs, fonts, individual renders, and measurements to
`build/png_study/`. The final command refreshes the README images and this
report. Sharp/librsvg supplies independent SVG rasterization; Pillow/FreeType
renders the actual fonts; NumPy measures their masks. No Python or Node runtime
is needed by the library itself. Reruns on another renderer version or platform
may differ slightly.

Existing accessibility, basket, and earth SVGs are from the repository's MIT
Ionicons fixtures. The other geometric patterns are generated by the study.
'''
    Path('doc/png-tracing-study.md').write_text(report, encoding='utf-8')


gallery()
scale_grid()
evidence()
(ROOT / 'index.html').write_text(build_viewer(MANIFEST, DATA), encoding='utf-8')
for name in ['source-to-font.png', 'png-resolution.png']:
    (ROOT / name).write_bytes((DEST / name).read_bytes())
print('Wrote README figures and doc/png-tracing-study.md.')
