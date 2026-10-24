"""Measure actual FreeType font renders against independent SVG rasterization.

Usage: python tool/png_study/render.py [study-directory]
Dependencies are development-only: Pillow and NumPy.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def component_count(mask, diagonal=False):
    """Count connected regions with row runs and union-find (8/4 connectivity)."""
    parent = []

    def find(label):
        while parent[label] != label:
            parent[label] = parent[parent[label]]
            label = parent[label]
        return label

    previous = []
    for row in mask:
        changes = np.flatnonzero(np.diff(np.r_[False, row, False]))
        current = []
        j = 0
        for start, end in zip(changes[::2], changes[1::2]):
            label = len(parent)
            parent.append(label)
            reach = int(diagonal)
            while j < len(previous) and previous[j][1] + reach <= start:
                j += 1
            k = j
            while k < len(previous) and previous[k][0] < end + reach:
                parent[find(label)] = find(previous[k][2])
                k += 1
            current.append((int(start), int(end), label))
        previous = current
    return len({find(i) for i in range(len(parent))})


def topology(mask):
    components = component_count(mask, diagonal=True)
    # Transparent padding gives exactly one exterior background component.
    holes = component_count(np.pad(~mask, 1, constant_values=True)) - 1
    return components, holes


def iou(a, b):
    union = np.count_nonzero(a | b)
    return float(np.count_nonzero(a & b) / union) if union else 1.0


def render_font(font, codepoint, size=256):
    image = Image.new("L", (size * 4, size * 4))
    ImageDraw.Draw(image).text((0, size * 4), chr(codepoint), font=font,
                               fill=255, anchor="ls")
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "build/png_study")
    manifest = json.loads((root / "manifest.json").read_text())
    records = json.loads((root / "compiled.json").read_text())
    renders = root / "renders"
    renders.mkdir(exist_ok=True)
    fonts = {(mode, fmt): ImageFont.truetype(str(root / f"{mode}.{fmt}"), 1024)
             for mode in ("legacy", "smooth") for fmt in ("otf", "ttf")}
    references = {}
    for fixture in manifest["fixtures"]:
        alpha = Image.open(root / f"{fixture['id']}_reference.png").getchannel("A")
        references[fixture["id"]] = np.asarray(alpha.resize((256, 256), Image.Resampling.LANCZOS))
    arrays = {}
    for record in records:
        name, mode, fmt = record["name"], record["mode"], record["format"]
        rendered = render_font(fonts[mode, fmt], record["codepoint"])
        rendered.save(renders / f"{name}_{mode}_{fmt}.png")
        pixels = np.asarray(rendered)
        reference = references[record["id"]]
        expected, actual = reference >= 128, pixels >= 128
        arrays[name, mode, fmt] = actual
        record.update(iou=iou(expected, actual),
                      alpha_mae=float(np.abs(reference.astype(float) - pixels).mean() / 255),
                      topology=list(topology(actual)), reference_topology=list(topology(expected)))
    for record in records:
        record["format_iou"] = iou(arrays[record["name"], record["mode"], "otf"],
                                   arrays[record["name"], record["mode"], "ttf"])
    (root / "measurements.json").write_text(json.dumps(records, indent=2) + "\n")
    print("Size | simple IoU | detailed IoU | detail topology matches | segments (median)")
    for size in manifest["sizes"]:
        selected = [r for r in records if r["size"] == size and r["mode"] == "smooth" and r["format"] == "otf"]
        simple = [r for r in selected if r["kind"] == "simple"]
        detail = [r for r in selected if r["kind"] == "detail"]
        print(f"{size:4} | {np.median([r['iou'] for r in simple]):.3%} | "
              f"{np.median([r['iou'] for r in detail]):.3%} | "
              f"{sum(r['topology']==r['reference_topology'] for r in detail)}/{len(detail)} | "
              f"{np.median([r['segments'] for r in selected]):.0f}")
    vectors = [r for r in records if r['size'] is None and r['mode']=='smooth' and r['format']=='otf']
    print("SVG controls:", {r['id']: round(r['iou'], 4) for r in vectors})
    print("OTF/TTF median agreement:", np.median([r['format_iou'] for r in records if r['mode']=='smooth']))


if __name__ == "__main__":
    main()
