"""Render the README placement comparison from actual generated OTFs.

Run `dart run tool/normalization/compile.dart`, then this script.
Requires Pillow (also used by tool/png_study).
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/normalization')
INK, MUTED, GREEN = '#142c27', '#526b63', '#16705c'
canvas = Image.new('RGB', (1440, 1232), '#f7faf8')
draw = ImageDraw.Draw(canvas)


def font(size, bold=False):
    candidates = ([r'C:/Windows/Fonts/segoeuib.ttf',
                   '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
                  if bold else [r'C:/Windows/Fonts/segoeui.ttf',
                                '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'])
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default(size=size)


draw.text((48, 32), 'ADVANCED ALIGNMENT OPTION', font=font(19, True), fill=GREEN)
draw.text((48, 70), 'Normalization changes placement', font=font(44, True), fill=INK)
draw.text((48, 134), 'Leave it off to preserve the positions designed into your icons.',
          font=font(25), fill=MUTED)
columns = [438, 780, 1122]
for x, heading, note in zip(columns,
        ['Source SVG', 'normalize: false', 'normalize: true'],
        ['24 × 24 canvas', 'Default · keep placement', 'Optional · recenter artwork']):
    draw.text((x + 112, 208), heading, anchor='mt', font=font(27, True), fill=INK)
    draw.text((x + 112, 250), note, anchor='mt', font=font(20), fill=MUTED)

fixtures = json.loads((ROOT / 'fixtures.json').read_text())
labels = [
    ('Already centered', ['Both settings give', 'the same placement.']),
    ('Accidental offset', ['Turning it on can help', 'recenter a messy export.']),
    ('Intentional corner dot', ['Leave it off when the', 'corner position matters.']),
]
for index, (item, (title, lines)) in enumerate(zip(fixtures, labels)):
    y = 308 + index * 264
    draw.text((48, y + 60), title, font=font(27, True), fill=INK)
    for line_index, line in enumerate(lines):
        draw.text((48, y + 108 + line_index * 30), line, font=font(23), fill=MUTED)
    for col, x in enumerate(columns):
        draw.rectangle((x, y, x + 224, y + 224), fill='#eaf1ed', outline='#b5c9bf', width=2)
        for d in range(8, 218, 14):
            draw.line((x + 112, y + d, x + 112, y + d + 6), fill='#b5c9bf', width=1)
            draw.line((x + d, y + 112, x + d + 6, y + 112), fill='#b5c9bf', width=1)
        mask = Image.new('L', (1024, 1024))
        if col == 0:
            scale = 1024 / 24
            cx, cy, radius = item['x'] * scale, item['y'] * scale, item['r'] * scale
            ImageDraw.Draw(mask).ellipse((cx-radius, cy-radius, cx+radius, cy+radius), fill=255)
        else:
            actual_font = ImageFont.truetype(str(ROOT / f'{str(col == 2).lower()}.otf'), 1024)
            ImageDraw.Draw(mask).text((0, 1024), chr(0xe001 + index),
                                      font=actual_font, fill=255, anchor='ls')
        mask = mask.resize((224, 224), Image.Resampling.LANCZOS)
        canvas.paste(Image.new('RGB', mask.size, INK), (x, y), mask)

draw.text((48, 1130), 'Actual OTF renders at the same font size. Dashed lines mark each cell’s center.',
          font=font(23), fill=MUTED)
draw.text((48, 1168), 'Font output includes the usual safety margin. Normalization does not improve tracing quality.',
          font=font(23), fill=MUTED)
destination = Path('doc/images/normalization.png')
destination.parent.mkdir(parents=True, exist_ok=True)
canvas.save(destination)
print(destination)
