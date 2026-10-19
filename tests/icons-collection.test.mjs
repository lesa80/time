import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {PNG} from 'pngjs';
import {iconModels} from '../scripts/icon-layout.mjs';
import {composePreview} from '../scripts/lib/raster.mjs';
import {handAngles, parseTime, localTime, displayText} from '../time.mjs';
const root=new URL('../',import.meta.url);
const registry=JSON.parse(fs.readFileSync(new URL('themes.json',root)));
const specFor=id=>JSON.parse(fs.readFileSync(new URL(`assets/icons-collection/${id}/theme.json`,root)));
const pixel=(p,x,y)=>[...p.data.slice((Math.floor(y)*p.width+Math.floor(x))*4,(Math.floor(y)*p.width+Math.floor(x))*4+4)];

test('Legendary models has all models and color variants, with matching full watch and dial resources',()=>{
 assert.deepEqual(registry.themes.filter(t=>t.brand==='icons').map(t=>t.id),iconModels.map(t=>t.id));
 for(const model of iconModels){
  const spec=specFor(model.id),layers=spec.layers;
  const bezel=PNG.sync.read(fs.readFileSync(new URL(layers[0].image,root)));
  assert(layers[0].image.endsWith('/bezel.png'));
  assert.deepEqual([bezel.width,bezel.height],spec.resolution);
  assert.equal(pixel(bezel,0,0)[3],0);
  const [x,y,w,h]=spec.dialBounds;
  assert.equal(pixel(bezel,x+w/2,y+h/2)[3],0,'Fixed face must not leak behind live layers');
  assert(layers.every(l=>fs.existsSync(new URL(l.image,root))));
  assert.equal(spec.dialShape,model.shape);
  assert(spec.dialBounds[0]>=0&&spec.dialBounds[1]>=0);
  assert(spec.dialBounds[0]+w<=spec.resolution[0]);
  assert(spec.dialBounds[1]+h<=spec.resolution[1]);
 }
});

test('Tank has two hands, Moonwatch running seconds is at 9, Royal Oak date is live',()=>{
 const tank=specFor('cartier-tank');assert.deepEqual(tank.layers.filter(l=>l.type==='Hand Res').map(l=>path.basename(l.image)),['hour.png','minute.png']);
 const omega=specFor('omega-speedmaster');const hour=omega.layers.find(l=>l.image.endsWith('/hour.png')),seconds=omega.layers.find(l=>l.image.endsWith('/second.png'));
 assert(seconds.handResPosition[0]<hour.handResPosition[0]-100);assert(Math.abs(seconds.handResPosition[1]-hour.handResPosition[1])<10);
 const chrono=omega.layers.filter(l=>path.basename(l.image).startsWith('chrono-'));
 assert.equal(chrono.length,3);assert(chrono.every(l=>l.type==='Hand Res'));
 assert.deepEqual(chrono.find(l=>l.image.endsWith('/chrono-second.png')).handResPosition,hour.handResPosition);
 assert(chrono.find(l=>l.image.endsWith('/chrono-minute.png')).handResPosition[0]>hour.handResPosition[0]+100);
 assert(chrono.find(l=>l.image.endsWith('/chrono-hour.png')).handResPosition[1]>hour.handResPosition[1]+100);
 assert(!omega.layers.some(l=>l.image.endsWith('/chronograph.png')),'Frozen chronograph artwork must not remain under live hands');
 const royal=specFor('ap-royal-oak');assert(royal.layers.some(l=>l.type==='Text Res'&&l.field==='date'));
 const casio=specFor('casio-gshock');assert.equal(casio.displayMode,'digital');assert(!casio.layers.some(l=>l.type==='Hand Res'));
 assert.deepEqual(casio.layers.filter(l=>l.type==='Text Res').map(l=>l.field).sort(),['day','format','hours','indicators','minutes','month','seconds','separator','weekday']);
 assert.deepEqual(casio.mechanicalControls.map(c=>c.action),['gshock-a','gshock-b','gshock-c','gshock-d']);
 assert.equal(casio.mechanicalControls.find(c=>c.action==='gshock-b').longAction,'gshock-flash');
 for(const c of casio.mechanicalControls){const [x,y,w,h]=c.bounds;assert(x>=0&&y>=0&&w>0&&h>0&&x+w<=casio.resolution[0]&&y+h<=casio.resolution[1]);}
});

test('LCD and date formatting follow local leap-day and midnight rollover',()=>{
 const before=localTime(new Date(2028,1,29,23,59,59));const after=localTime(new Date(2028,2,1,0,0,0));
 assert.deepEqual(['hours','minutes','seconds','month','day','weekday'].map(f=>displayText(f,before)),['23','59','59','02','29','TU']);
 assert.deepEqual(['hours','minutes','seconds','month','day','weekday','date'].map(f=>displayText(f,after)),['00','00','00','03','01','WE',' 1']);
});

test('Moonwatch subdial axes match the master hub rings and sit below the central hands',()=>{
 const spec=specFor('omega-speedmaster');
 const registration=JSON.parse(fs.readFileSync(new URL('assets/icons-collection/omega-speedmaster/registration.json',root)));
 const master=PNG.sync.read(fs.readFileSync(new URL('assets/icons-collection/omega-speedmaster/source/master.png',root)));
 for(const [name,cx,cy] of [['second',371,706],['chrono-minute',651,706],['chrono-hour',512,842]]){
  // Independently locate the visible metal ring, rather than repeating the configured axis.
  let x0=Infinity,y0=Infinity,x1=-Infinity,y1=-Infinity;
  for(let y=cy-12;y<=cy+12;y++)for(let x=cx-12;x<=cx+12;x++){
   const i=(y*master.width+x)*4;
   if((master.data[i]+master.data[i+1]+master.data[i+2])/3<85)continue;
   x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
  }
  assert(Number.isFinite(x0),'Hub ring must be visible in the master');
  const axis=spec.layers.find(l=>l.image.endsWith(`/${name}.png`)).handResPosition.map((v,i)=>v+registration.bodyCrop[i]);
  assert(Math.hypot(axis[0]-(x0+x1+1)/2,axis[1]-(y0+y1+1)/2)<.75,`${name} axis must match the raster hub`);
 }
 const layers=spec.layers.map(l=>({name:path.basename(l.image,'.png'),spec:l,size:l.size,png:fs.readFileSync(new URL(l.image,root))}));
 const subsidiary=new Set(['second','seconds-cap','chrono-minute','chrono-hour']);
 const primary=layers.filter(l=>['hour','minute','chrono-second'].includes(l.name));
 assert(!layers.some(l=>l.name==='seconds-cap'),'Small second hub must not float above the central hands');
 for(const [hours,minutes,second,chrono] of [[12,45,0,270],[9,0,90,90],[6,15,180,180]]){
  const angles={...handAngles({hours,minutes,seconds:0},12),second,'chrono-second':chrono};
  const render=ls=>PNG.sync.read(composePreview(ls,spec.resolution,angles,spec.resolution[0]));
  const full=render(layers),withoutSubdials=render(layers.filter(l=>!subsidiary.has(l.name))),mask=render(primary);
  let covered=0;
  for(let i=0;i<mask.data.length;i+=4){
   if(mask.data[i+3]<254)continue;
   covered++;
   for(let c=0;c<4;c++)assert(Math.abs(full.data[i+c]-withoutSubdials.data[i+c])<=2,'Subdial hands or hubs must not cover opaque central hands');
  }
  assert(covered>100,'Check must exercise the central hand surfaces');
 }
});

test('Casio and Royal Oak dynamic readings alter their raster output while the case stays identical',()=>{
 for(const id of ['casio-gshock','ap-royal-oak']){
  const spec=specFor(id),layers=spec.layers.map(l=>({name:path.basename(l.image,'.png'),spec:l,size:l.size,png:fs.readFileSync(new URL(l.image,root))}));
  const time=parseTime('10:10:30'),angles=handAngles(time,id==='casio-gshock'?24:12);
  const reading={...time,day:1,month:1,weekday:1};
  const first=PNG.sync.read(composePreview(layers,spec.resolution,angles,320,reading));
  const second=PNG.sync.read(composePreview(layers,spec.resolution,angles,320,{...reading,hours:23,minutes:59,seconds:58,day:29,month:2,weekday:3}));
  let changed=0;
  const scale=320/spec.resolution[0],textBoxes=spec.layers.filter(l=>l.type==='Text Res').map(l=>[l.position[0]*scale-2,l.position[1]*scale-2,l.size[0]*scale+4,l.size[1]*scale+4]);
  for(let y=0;y<first.height;y++)for(let x=0;x<first.width;x++){
   const offset=(y*first.width+x)*4;
   if(first.data.subarray(offset,offset+4).equals(second.data.subarray(offset,offset+4)))continue;
   changed++;assert(textBoxes.some(([bx,by,w,h])=>x>=bx&&x<=bx+w&&y>=by&&y<=by+h),'Dynamic readout must never repaint the case');
  }
  assert(changed>10,`${id} readout must actually change`);
 }
});
