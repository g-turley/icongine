// Rasterize independent SVG references and PNG inputs with Sharp/librsvg.
// Usage: node tool/png_study/prepare.cjs [output-directory]
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');

const output = path.resolve(process.argv[2] || 'build/png_study');
const sizes = [16, 24, 32, 48, 64, 96, 128, 256, 512];
fs.mkdirSync(path.join(output, 'inputs'), {recursive: true});
const existing = name => fs.readFileSync(`example/assets/icons/svg/${name}.svg`, 'utf8');
const wrap = body => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">${body}</svg>`;
const petals = Array.from({length:12}, (_,i) => {
  const angle=i*Math.PI/6, r=146, cx=256+Math.cos(angle)*r, cy=256+Math.sin(angle)*r;
  return `<ellipse cx="${cx}" cy="${cy}" rx="71" ry="26" transform="rotate(${i*30} ${cx} ${cy})" fill="none" stroke="black" stroke-width="10"/>`;
}).join('');
const holes = Array.from({length:25}, (_,i) => {
  const x=92+(i%5)*66, y=92+Math.floor(i/5)*66;
  return `M${x} ${y}h34v34h-34Z`;
}).join('');
const fixtures = [
  {id:'circle', label:'Circle', kind:'simple', svg:wrap('<circle cx="256" cy="256" r="208"/>')},
  {id:'ring', label:'Ring / hole', kind:'simple', svg:wrap('<path fill-rule="evenodd" d="M464 256a208 208 0 1 0-416 0 208 208 0 1 0 416 0M392 256a136 136 0 1 0-272 0 136 136 0 1 0 272 0"/>')},
  {id:'arrow', label:'Sharp corners', kind:'simple', svg:wrap('<path d="M64 208H272V104L456 256 272 408V304H64Z"/>')},
  {id:'accessibility', label:'Thin strokes', kind:'detail', svg:existing('accessibility-outline')},
  {id:'basket', label:'Basket outline', kind:'detail', svg:existing('basket-outline')},
  {id:'earth', label:'Organic detail', kind:'detail', svg:existing('earth-outline')},
  {id:'rosette', label:'Radial pattern', kind:'detail', svg:wrap(petals+'<circle cx="256" cy="256" r="50" fill="none" stroke="black" stroke-width="10"/>')},
  {id:'lattice', label:'25 cutouts', kind:'detail', svg:wrap(`<path fill-rule="evenodd" d="M64 64H448V448H64Z${holes}"/>`)},
];

(async () => {
  const cases=[];
  for (const fixture of fixtures) {
    fs.writeFileSync(path.join(output,'inputs',`${fixture.id}.svg`),fixture.svg);
    // Same 92% em-square fit as the library; the independent renderer supplies
    // the reference geometry, never the compiler's own contour preview.
    const nested=fixture.svg.replace(/^[\s\S]*?<svg/,'<svg').replace(/<svg\b[^>]*>/,root=>root.replace(/\s(?:width|height)="[^"]*"/g,'').replace(/>$/,' width="512" height="512">'));
    const ref=wrap(`<g transform="translate(20.48 20.48) scale(0.92)">${nested}</g>`);
    await sharp(Buffer.from(ref),{density:288}).resize(2048,2048).png().toFile(path.join(output,`${fixture.id}_reference.png`));
    for (const size of sizes) {
      const name=`${fixture.id}_${size}`;
      // Render at 4x then downsample for consistent antialiased alpha at every size.
      await sharp(Buffer.from(fixture.svg),{density:72*size*4/512}).resize(size,size).png().toFile(path.join(output,'inputs',`${name}.png`));
      cases.push({id:fixture.id,label:fixture.label,kind:fixture.kind,size,name,source:`inputs/${name}.png`});
    }
    cases.push({id:fixture.id,label:fixture.label,kind:fixture.kind,size:null,name:`${fixture.id}_svg`,source:`inputs/${fixture.id}.svg`});
  }
  fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify({sizes,renderer:sharp.versions,fixtures:fixtures.map(({svg,...rest})=>rest),cases},null,2)+'\n');
  console.log(`Prepared ${cases.length} independent PNG/SVG inputs in ${output}.`);
})();
