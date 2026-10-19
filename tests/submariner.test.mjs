import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {PNG} from 'pngjs';
import {iconModels} from '../scripts/icon-layout.mjs';
import {submarinerVariants} from '../scripts/submariner-variants.mjs';
const root=new URL('../',import.meta.url);
const read=id=>PNG.sync.read(fs.readFileSync(new URL(`assets/icons-collection/${id}/source/master.png`,root)));
function mean(p,x,y,w,h){let n=0,r=0,g=0,b=0;for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++){const i=(yy*p.width+xx)*4;if(p.data[i+3]<240)continue;n++;r+=p.data[i];g+=p.data[i+1];b+=p.data[i+2];}assert(n>0);return[r/n,g/n,b/n];}
test('Submariner covers the seven current catalog configurations with live dates on Date models',()=>{
 const family=iconModels.filter(m=>m.id.startsWith('rolex-submariner'));
 assert.deepEqual(family.map(m=>m.reference).sort(),['124060','126610LN','126610LV','126613LB','126613LN','126618LB','126618LN']);
 for(const m of submarinerVariants){
  const spec=JSON.parse(fs.readFileSync(new URL(`assets/icons-collection/${m.id}/theme.json`,root)));
  assert.equal(spec.layers.filter(l=>l.type==='Text Res'&&l.field==='date').length,1,m.reference);
  const p=read(m.id),[x,y,w,h]=m.date,plate=mean(p,x,y,w,h);
  assert(plate.every(v=>v>220),'Date glyphs must sit inside an empty white calendar window');
  const dial=mean(p,440,620,140,60);
  if(m.dialColor==='blue')assert(dial[2]>dial[0]*1.4&&dial[2]>dial[1]*1.1,'Blue models must retain the blue dial');
  else assert(Math.max(...dial)-Math.min(...dial)<18&&Math.max(...dial)<95,'Steel/green and black models must keep black dials');
  const outer=mean(p,360,125,30,30),middle=mean(p,480,125,30,30);
  if(m.material==='rolesor'){assert(middle[0]>middle[2]+30,'Rolesor central links must be gold');assert(Math.max(...outer)-Math.min(...outer)<20,'Rolesor outer links must stay steel');}
  if(m.material==='yellow-gold')assert(outer[0]>outer[2]+30&&middle[0]>middle[2]+30,'Entire yellow-gold bracelet must be gold');
 }
 assert(!family.find(m=>m.reference==='124060').date,'Original no-date model must remain available');
});
