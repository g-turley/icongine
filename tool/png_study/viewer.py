"""Generate a local development viewer for the study's real font files."""
import json


def build_viewer(manifest, measurements):
    rows = ''.join(f'''<tr data-id="{f['id']}"><th scope="row">{f['label']}</th>
      <td><img class="vector" src="inputs/{f['id']}.svg" alt="{f['label']} SVG source"></td>
      <td><span class="glyph vector-glyph" aria-label="{f['label']} SVG font glyph"></span></td>
      <td><img class="raster" alt="{f['label']} PNG source"></td>
      <td class="result"><span class="glyph raster-glyph" aria-label="{f['label']} PNG font glyph"></span><small class="raster-note"></small></td></tr>'''
      for f in manifest['fixtures'])
    options = ''.join(f'<option value="{s}" {"selected" if s==64 else ""}>{s} × {s}</option>' for s in manifest['sizes'])
    faces = ''.join(f'@font-face{{font-family:{m}-{f};src:url({m}.{f})}}' for m in ['legacy','smooth'] for f in ['otf','ttf'])
    template = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>icongine · PNG resolution study</title>
<style>__FACES__
*{box-sizing:border-box}body{margin:0;padding:32px 24px;background:#f7faf8;color:#142c27;font:16px system-ui,sans-serif}
main{max-width:1200px;margin:auto}h1{font-size:36px;letter-spacing:-1px;margin:8px 0}p{color:#526b63;max-width:850px;line-height:1.5}
.tag{color:#16705c;font-size:12px;letter-spacing:2px;font-weight:700}.controls{display:flex;gap:24px;flex-wrap:wrap;margin:24px 0}
label{font-size:14px;display:grid;gap:8px}select{font:inherit;padding:12px;border:1px solid #91aaa0;border-radius:8px;background:white;min-width:140px}
.scroll{overflow:auto}table{width:100%;min-width:600px;border-collapse:collapse;background:white}th,td{text-align:center;padding:12px;border-bottom:1px solid #d5e2db}
thead th{font-size:13px;color:#526b63;background:#eef4f0}tbody th{text-align:left;font-size:14px;width:160px}
img,.glyph{width:clamp(84px,14vw,160px);height:clamp(84px,14vw,160px);object-fit:contain;display:inline-block;vertical-align:middle}
.raster{image-rendering:pixelated}.glyph{font-size:clamp(84px,14vw,160px);line-height:1}.result{background:#e4f1e9}
#status{font-size:13px;min-height:24px;color:#526b63}details{margin-top:32px}summary{padding:12px;cursor:pointer;font-weight:600;min-height:44px}
.raster-note{display:block;font-size:12px;color:#526b63}
.figure{width:100%;height:auto;margin-top:16px;display:block}a{color:#16705c}
@media(max-width:600px){body{padding:24px 16px}h1{font-size:28px}.controls{gap:16px}}
</style><main><div class="tag">ICONGINE / MEASURED PNG TRACING</div>
<h1>Find the source size your design needs.</h1>
<p>64px is a practical starting point. Try 16–32px for simple icons, 128px for details, and 256–512px or SVG for fine gaps. The glyphs below come from the actual generated fonts.</p>
<div class="controls"><label>PNG source size<select id="size">__OPTIONS__</select></label>
<label>Tracing<select id="mode"><option value="smooth">Smooth · default</option><option value="legacy">Legacy</option></select></label>
<label>Font format<select id="format"><option value="otf">OTF</option><option value="ttf">TTF</option></select></label></div>
<div id="status" role="status">Loading generated fonts…</div>
<div class="scroll"><table><thead><tr><th>Design</th><th>SVG source</th><th>SVG → font</th><th>PNG source</th><th>PNG → font</th></tr></thead><tbody>__ROWS__</tbody></table></div>
<p>Very fine artwork may disappear in a tiny source. Smooth tracing cannot recover information that was never sampled. OTF/TTF share a design; their rasterization can differ slightly.</p>
<details><summary>README source-to-font figure</summary><img class="figure" src="source-to-font.png" alt="README figure comparing source SVG and PNG artwork with actual OTF and TTF renders"></details>
<details><summary>README resolution sweep</summary><img class="figure" src="png-resolution.png" alt="README figure comparing six designs at five PNG source sizes"></details>
</main><script>
const cases=__CASES__, byName=Object.fromEntries(cases.map((c,i)=>[c.name,0xe001+i]));
const emptyGlyphs=new Set(__EMPTY__);
const size=document.getElementById('size'),mode=document.getElementById('mode'),format=document.getElementById('format');
let revision=0;
async function update(){
 const current=++revision, family=mode.value+'-'+format.value;
 document.querySelectorAll('tbody tr').forEach(row=>{
   const id=row.dataset.id, rasterName=id+'_'+size.value;
   row.querySelector('.raster').src='inputs/'+rasterName+'.png';
   row.querySelector('.vector-glyph').textContent=String.fromCodePoint(byName[id+'_svg']);
   row.querySelector('.raster-glyph').textContent=String.fromCodePoint(byName[rasterName]);
   row.querySelector('.raster-note').textContent=emptyGlyphs.has(mode.value+':'+format.value+':'+rasterName)?'No visible glyph at this size':'';
   row.querySelectorAll('.glyph').forEach(el=>el.style.fontFamily=family);
 });
 const status=document.getElementById('status');status.textContent='Loading generated fonts…';
 try{await document.fonts.load('160px '+family);if(current===revision)status.textContent=size.value+'px PNG · '+mode.value+' tracing · actual '+format.value.toUpperCase()+' font.';}
 catch(error){if(current===revision)status.textContent='Font loading failed. Check the local study server.';}
}
[size,mode,format].forEach(el=>el.addEventListener('change',update));update();
</script></html>'''
    empty = [f"{r['mode']}:{r['format']}:{r['name']}" for r in measurements if r['contours']==0]
    return template.replace('__FACES__',faces).replace('__OPTIONS__',options).replace('__ROWS__',rows).replace('__CASES__',json.dumps(manifest['cases'])).replace('__EMPTY__',json.dumps(empty))
