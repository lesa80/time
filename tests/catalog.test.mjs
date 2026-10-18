import fs from 'node:fs';import assert from 'node:assert/strict';import test from 'node:test';import {PNG} from 'pngjs';import {handAngles,parseTime} from '../time.mjs';
const catalog=JSON.parse(fs.readFileSync(new URL('../themes.json',import.meta.url)));
const official=JSON.parse(fs.readFileSync(new URL('../reference/catalog/index.json',import.meta.url)));
const specFor=t=>JSON.parse(fs.readFileSync(new URL(`../${t.sourceSpec}`,import.meta.url)));
test('every current official catalog variant is represented, including sold-out models',()=>{
 assert.equal(catalog.themes.length,official.items.length+4);
 const urls=new Set(catalog.themes.map(t=>t.referenceURL));for(const item of official.items)assert(urls.has(item.productURL),item.code);
 assert.equal(new Set(catalog.themes.map(t=>t.id)).size,catalog.themes.length);
 assert(!catalog.themes.some(t=>t.id==='polar'),'legacy photo theme removed');
 assert.deepEqual(catalog.themes.filter(t=>t.brand!=='raketa').map(t=>t.id),['minimalism','minimalism-24','minimalism-dark','minimalism-24-dark']);
 assert.equal(catalog.themes.filter(t=>t.brand==='raketa').length,official.items.length);
});
test('Russian Code runs backwards for all three hands; 24h models retain their own cycle',()=>{
 for(const id of ['russkiy-kod-0302','russkiy-kod-0344']){const t=catalog.themes.find(t=>t.id===id);assert.equal(t.direction,-1);const a=handAngles(parseTime('01:10:20'),t.hourCycle,t.direction);assert(a.hour<0&&a.minute<0&&a.second<0);assert.equal(a.second,-120);}
 for(const id of ['baykonur-0325','podvodnik-0317','polyarnye-0300'])assert.equal(catalog.themes.find(t=>t.id===id).hourCycle,24);
 assert.throws(()=>handAngles(parseTime('00:00:00'),12,0),RangeError);
});
test('Avgvst keeps square glass, two hands and no invented seconds',()=>{
 for(const t of catalog.themes.filter(t=>t.id.startsWith('raketa-avgvst'))){const s=specFor(t);assert.equal(s.dialShape,'rectangle');assert.equal(s.layers.filter(l=>l.type==='Hand Res').length,2);assert(!s.layers.some(l=>l.image.endsWith('/second.png')));const dial=PNG.sync.read(fs.readFileSync(new URL(`../${s.layers.find(l=>l.image.endsWith('/dial.png')).image}`,import.meta.url)));assert(dial.data[(20*dial.width+20)*4+3]>240,'rectangle corners must not be cut to a circle');}
});
test('catalog themes ship 2048px dials, transparent cases and a common hand axis',()=>{
 for(const t of catalog.themes.filter(t=>t.specification.startsWith('catalog/'))){const s=specFor(t);const bezel=s.layers.find(l=>l.image.endsWith('/bezel.png'));const body=PNG.sync.read(fs.readFileSync(new URL(`../${bezel.image}`,import.meta.url)));const hands=s.layers.filter(l=>l.type==='Hand Res');assert(hands.length>=2);const pivot=hands[0].handResPosition;for(const l of hands){assert.deepEqual(l.handResPosition,pivot,t.id);assert(l.rotatePoint.every(Number.isFinite));}
 assert.equal(body.data[(Math.floor(pivot[1])*body.width+Math.floor(pivot[0]))*4+3],0,`${t.id}: fixed source hands must not leak through case`);
 const dial=PNG.sync.read(fs.readFileSync(new URL(`../${s.layers.find(l=>l.image.endsWith('/dial.png')).image}`,import.meta.url)));assert.deepEqual([dial.width,dial.height],[2048,2048]);
 }
});
