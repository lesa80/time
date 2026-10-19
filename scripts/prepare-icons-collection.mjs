import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {PNG} from 'pngjs';
import {Resvg} from '@resvg/resvg-js';
import {iconModels} from './icon-layout.mjs';
import {resample, composePreview} from './lib/raster.mjs';
import {handAngles, parseTime} from '../time.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const chars='0123456789 SUMOTWEHFRA';
const svg=(w,h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
const gradients='<defs><linearGradient id="steel"><stop stop-color="#f9faf9"/><stop offset=".4" stop-color="#9ca2a5"/><stop offset=".58" stop-color="#fff"/><stop offset="1" stop-color="#787d82"/></linearGradient><linearGradient id="blue"><stop stop-color="#061932"/><stop offset=".5" stop-color="#2965ae"/><stop offset="1" stop-color="#071a35"/></linearGradient></defs>';
function raster(folder,name,w,h,body,scale=4){const source=svg(w,h,body);fs.writeFileSync(path.join(folder,`${name}.svg`),source+'\n');const png=new Resvg(source,{fitTo:{mode:'width',value:w*scale},font:{loadSystemFonts:true}}).render().asPng();fs.writeFileSync(path.join(folder,`${name}.png`),png);return png;}
function bounds(p){let x0=p.width,y0=p.height,x1=0,y1=0;for(let y=0;y<p.height;y++)for(let x=0;x<p.width;x++)if(p.data[(y*p.width+x)*4+3]>16){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}return [Math.max(0,x0-3),Math.max(0,y0-3),Math.min(p.width-1,x1+3)-Math.max(0,x0-3)+1,Math.min(p.height-1,y1+3)-Math.max(0,y0-3)+1];}
function crop(p,[x,y,w,h]){const q=new PNG({width:w,height:h});for(let row=0;row<h;row++)p.data.copy(q.data,row*w*4,((y+row)*p.width+x)*4,((y+row)*p.width+x+w)*4);return q;}
function hole(p,cx,cy,rx,ry){for(let y=Math.max(0,Math.floor(cy-ry-1));y<Math.min(p.height,cy+ry+1);y++)for(let x=Math.max(0,Math.floor(cx-rx-1));x<Math.min(p.width,cx+rx+1);x++){const coverage=Math.max(0,Math.min(1,(1-Math.hypot((x+.5-cx)/rx,(y+.5-cy)/ry))*Math.min(rx,ry)+.5));p.data[(y*p.width+x)*4+3]=Math.round(p.data[(y*p.width+x)*4+3]*(1-coverage));}}
function atlas(folder,name,{color='#202a21',segment=false,dots=false,font='Helvetica,Arial,sans-serif',characters=chars}={}){
 const bits=[63,6,91,79,102,109,125,7,127,111];
 const paths=['M12 5H48L53 10L47 16H13L7 10Z','M49 17L55 11L55 49L49 55L44 49V23Z','M49 61L55 55V94L49 100L44 94V67Z','M12 96H47L53 102L47 108H12L6 102Z','M5 61L11 67V94L5 100L0 94V55Z','M5 17L11 23V49L5 55L0 49V11Z','M12 51H47L53 57L47 63H12L6 57Z'];
 const body=[...characters].map((c,i)=>{
  if(segment&&/\d/.test(c))return `<g transform="translate(${i*64+4},0)" fill="${color}">${paths.map((d,k)=>`<path d="${d}" opacity="${bits[Number(c)]&(1<<k)?1:.035}"/>`).join('')}</g>`;
  if(dots){
   const endpoints=[[17,10,47,10],[52,19,52,47],[52,65,52,93],[17,103,47,103],[12,65,12,93],[12,19,12,47],[17,57,47,57]];
   if(c===':')return `<g transform="translate(${i*64},0)" fill="#ff6169"><ellipse cx="32" cy="38" rx="4.4" ry="1.8"/><ellipse cx="32" cy="78" rx="4.4" ry="1.8"/></g>`;
   if(!/\d/.test(c))return '';
   const points=endpoints.flatMap(([x0,y0,x1,y1],k)=>bits[Number(c)]&(1<<k)?Array.from({length:9},(_,j)=>[x0+(x1-x0)*j/8,y0+(y1-y0)*j/8]):[]);
   return `<g transform="translate(${i*64},0)">${points.map(([x,y])=>`<ellipse cx="${x}" cy="${y}" rx="2.7" ry="2.2" fill="#b31424"/><ellipse cx="${x}" cy="${y}" rx="1.9" ry="1.6" fill="#ff2c3c"/><ellipse cx="${x-.2}" cy="${y-.2}" rx=".8" ry=".7" fill="#ffb6ad"/>`).join('')}</g>`;
  }
  return `<text x="${i*64+32}" y="87" text-anchor="middle" font-family="${font}" font-size="87" font-weight="500" fill="${color}">${c}</text>`;
 }).join('');
 raster(folder,name,64*characters.length,112,body,dots?4:2);
}
const entries=[];
const only=process.argv.find(arg=>arg.startsWith('--only='))?.slice(7);
if(only&&!iconModels.some(model=>model.id===only))throw new Error(`Unknown model: ${only}`);
for(const model of iconModels.filter(model=>!only||model.id===only)){
 const base=`assets/icons-collection/${model.id}`,folder=path.join(root,base);
 const materialGradients=model.gold?gradients.replace('#f9faf9','#fff0b3').replace('#9ca2a5','#9c6e20').replace('stop-color="#fff"','stop-color="#ffea98"').replace('#787d82','#7b4d12'):gradients;
 const master=PNG.sync.read(fs.readFileSync(path.join(folder,'source/master.png')));
 for(let i=0;i<master.data.length;i+=4){const a=master.data[i+3];if(a<=4)master.data.fill(0,i,i+4);else if(a>=240)master.data[i+3]=255;}
 for(const y of model.holes??[])hole(master,512,y,model.digital?21:8,model.digital?7:8);
 if(model.id==='casio-gshock'){
  // Open buckle interior, leaving the center metal tongue intact.
  for(let y=56;y<110;y++)for(let x=405;x<619;x++)if(x<493||x>532)master.data[(y*master.width+x)*4+3]=0;
 }
 const box=model.bodyBounds??bounds(master),[bx,by,bw,bh]=box,[dx,dy,dw,dh]=model.dial;
 const bezel=crop(master,box);
 for(let y=0;y<bh;y++)for(let x=0;x<bw;x++){
  const sx=x+bx+.5,sy=y+by+.5;
  const a=model.shape==='circle'?Math.max(0,Math.min(1,dw/2+.5-Math.hypot(sx-model.center[0],sy-model.center[1]))):Math.max(0,Math.min(1,Math.min(sx-dx,sy-dy,dx+dw-sx,dy+dh-sy)+.5));
  const i=(y*bw+x)*4+3;bezel.data[i]=Math.round(bezel.data[i]*(1-a));
 }
 fs.writeFileSync(path.join(folder,'bezel.png'),PNG.sync.write(bezel));
 const dial=resample(master,model.dial,2048,Math.round(2048*dh/dw));
 if(model.shape==='circle')for(let y=0;y<dial.height;y++)for(let x=0;x<dial.width;x++)dial.data[(y*dial.width+x)*4+3]=Math.round(255*Math.max(0,Math.min(1,1024+.5-Math.hypot(x+.5-1024,y+.5-1024))));
 fs.writeFileSync(path.join(folder,'dial.png'),PNG.sync.write(dial));
 const dialBounds=[dx-bx,dy-by,dw,dh],center=model.center.map((v,i)=>v-box[i]);
 const layers=[{type:'Single Res',image:`${base}/bezel.png`,position:[0,0],size:[bw,bh]},{type:'Single Res',image:`${base}/dial.png`,position:dialBounds.slice(0,2),size:[dw,dh]}];
 function staticLayer(name,position,size,body){raster(folder,name,...size,materialGradients+body);layers.push({type:'Single Res',image:`${base}/${name}.png`,position:position.map((v,i)=>v-box[i]),size});}
 function hand(name,length,width,{lume=false,blue=false,mercedes=false,pivot=model.center,tail=18,cap=false}={}){
  const w=Math.ceil(Math.max(width*2+4,mercedes?42:22)),h=Math.ceil(length+tail+4),cx=w/2;
  let shape=`<path d="M${cx} 1L${cx+width/2} ${Math.min(length*.2,30)}V${h-3}H${cx-width/2}V${Math.min(length*.2,30)}Z" fill="url(#${blue?'blue':'steel'})" stroke="${blue?'#06162d':'#53595c'}" stroke-width="1"/>`;
  if(lume)shape+=`<path d="M${cx} 10L${cx+width*.26} 27V${length*.85}H${cx-width*.26}V27Z" fill="${model.style==='speedmaster'?'#d6e3b6':'#edf0e0'}"/>`;
  if(mercedes){const cy=length*.33;shape+=`<circle cx="${cx}" cy="${cy}" r="18" fill="url(#steel)" stroke="#74797b"/><circle cx="${cx}" cy="${cy}" r="14" fill="#edf0e0"/><path d="M${cx} ${cy}V${cy-15}M${cx} ${cy}L${cx-13} ${cy+8}M${cx} ${cy}L${cx+13} ${cy+8}" stroke="#777f80" stroke-width="3"/>`;}
  if(name==='second'&&model.style==='mercedes')shape+=`<circle cx="${cx}" cy="${length*.18}" r="7" fill="#edf0e0" stroke="#b3b9bd" stroke-width="2"/>`;
  if(cap)shape+=`<circle cx="${cx}" cy="${length}" r="2.5" fill="#d9dedb"/>`;
  raster(folder,name,w,h,materialGradients+shape);
  layers.push({type:'Hand Res',image:`${base}/${name}.png`,handResPosition:pivot.map((v,i)=>v-box[i]),rotatePoint:[cx,length],size:[w,h]});
 }
 function text(name,field,position,size,atlasName,characters=chars){layers.push({type:'Text Res',image:`${base}/${atlasName}.png`,position:position.map((v,i)=>v-box[i]),size,field,characters});}
 function chronoHand(name,pivot,length,tail=0){
  const w=16,h=length+Math.max(tail,8)+2,cx=w/2;
  raster(folder,name,w,h,`<path d="M${cx} 1V${length+tail}" fill="none" stroke="#e8ebdd" stroke-width="3"/><circle cx="${cx}" cy="${length}" r="${tail?4:6}" fill="#cdd2d0" stroke="#777"/>`);
  layers.push({type:'Hand Res',image:`${base}/${name}.png`,handResPosition:pivot.map((v,i)=>v-box[i]),rotatePoint:[cx,length],size:[w,h]});
 }
 if(model.interactionProfile==='pulsar'){
  const ledChars=chars+':';atlas(folder,'led-digits',{dots:true,characters:ledChars});
  // Original 25-chip P1: upper four digits for hours/minutes, independent
  // lower pair for seconds. Holding the button changes which row is lit.
  for(const [field,pos,size,visibility] of [['hours12',[392,583],[104,100],'led-time'],['colon',[500,583],[22,100],'led-time'],['minutes',[528,583],[104,100],'led-time'],['seconds',[460,723],[104,100],'led-seconds']]){
   text(field,field,pos,size,'led-digits',ledChars);layers.at(-1).visibility=visibility;
  }
 }else if(model.digital){
  const lcdChars=chars+'LPCIG-:';
  atlas(folder,'lcd-digits',{segment:true,characters:lcdChars});atlas(folder,'lcd-letters',{font:'Menlo,monospace',characters:lcdChars});
  staticLayer('lcd-marks',[378,626],[270,170],'<g fill="#273127"><rect x="107" y="94" width="4" height="5"/><rect x="107" y="118" width="4" height="5"/></g>');
  const lcd=(field,position,size,atlasName='lcd-digits')=>text(field,field,position,size,atlasName,lcdChars);
  lcd('format',[385,626],[35,13],'lcd-letters');lcd('indicators',[430,626],[202,13],'lcd-letters');
  lcd('weekday',[417,645],[54,29],'lcd-letters');
  lcd('month',[515,645],[46,27]);lcd('day',[582,645],[46,27]);lcd('separator',[565,646],[15,22],'lcd-letters');
  lcd('hours',[391,699],[88,73]);lcd('minutes',[494,699],[88,73]);lcd('seconds',[591,726],[48,44]);
 }else{
  if(model.style==='speedmaster'){
   chronoHand('chrono-minute',model.chronographMinuteCenter,69);
   chronoHand('chrono-hour',model.chronographHourCenter,62);
  }
  if(model.date){atlas(folder,'date-atlas',{color:model.dateInk??'#e8ece8'});text('date','date',model.date.slice(0,2),model.date.slice(2),'date-atlas');}
  const radius=dw/2;
  // All subsidiary hands and their hubs sit below the central hand stack.
  if(model.secondsCenter)hand('second',67,2,{pivot:model.secondsCenter,tail:10,cap:true});
  const dress=model.style==='sword';
  hand('hour',model.style==='sword'?73:radius*.58,model.style==='sword'?7:model.style==='mercedes'?15:12,{lume:!dress,blue:model.style==='sword',mercedes:model.style==='mercedes',tail:dress?8:20});
  hand('minute',model.style==='sword'?99:radius*.86,model.style==='sword'?5:model.style==='mercedes'?11:9,{lume:!dress,blue:model.style==='sword',tail:dress?7:24});
  if(!dress&&!model.secondsCenter)hand('second',radius*.91,2.2,{tail:36});
  if(model.style==='speedmaster')chronoHand('chrono-second',model.center,292,38);
  staticLayer('cap',model.center.map(v=>v-6),[12,12],`<circle cx="6" cy="6" r="5.5" fill="${model.style==='sword'?'url(#blue)':'url(#steel)'}" stroke="#7a7e81"/>`);
 }
 const mechanicalControls=model.mechanicalControls?.map(control=>({...control,bounds:control.bounds.map((v,i)=>i<2?v-box[i]:v)}));
 const spec={name:model.title,target:'macOS / Retina',hourCycle:model.hourCycle,displayMode:model.digital?'digital':'analog',interactionProfile:model.interactionProfile,resolution:[bw,bh],dialBounds,dialShape:model.shape,rasterResolution:[dial.width,dial.height],mechanicalControls,layers};
 fs.writeFileSync(path.join(folder,'theme.json'),JSON.stringify(spec,null,2)+'\n');
 fs.writeFileSync(path.join(folder,'registration.json'),JSON.stringify({master:[master.width,master.height],bodyCrop:box,dialBox:model.dial,center:model.center,secondsCenter:model.secondsCenter,chronographMinuteCenter:model.chronographMinuteCenter,chronographHourCenter:model.chronographHourCenter,source:model.url,reference:model.reference,chronograph:model.style==='speedmaster'?'Interactive: central 60-second, right 30-minute, bottom 12-hour; running seconds at 9':undefined},null,2)+'\n');
 const time=parseTime('10:10:30'),angles=handAngles(time,model.hourCycle);const assets=layers.map(l=>({name:path.basename(l.image,'.png'),spec:l,png:fs.readFileSync(path.join(root,l.image)),size:l.size}));
 fs.writeFileSync(path.join(folder,'preview-full.png'),composePreview(assets,spec.resolution,angles,500,time));
 const face=assets.filter(l=>l.name!=='bezel').map(l=>({...l,spec:{...l.spec,...(l.spec.position?{position:l.spec.position.map((v,i)=>v-dialBounds[i])}:{}),...(l.spec.handResPosition?{handResPosition:l.spec.handResPosition.map((v,i)=>v-dialBounds[i])}:{})}}));
 fs.writeFileSync(path.join(folder,'preview.png'),composePreview(face,[dw,dh],angles,600,time));
 entries.push({id:model.id,title:model.title,brand:'icons',hourCycle:model.hourCycle,dialShape:model.shape,displayMode:spec.displayMode,specification:`icons-collection/${model.id}/theme.json`,sourceSpec:`${base}/theme.json`,referenceTime:'10:10:30',referenceAngles:angles,referenceURL:model.url});
 console.log(`Prepared ${model.id}: ${spec.resolution}, ${spec.displayMode}`);
}
const registry=JSON.parse(fs.readFileSync(path.join(root,'themes.json')));
const previous=registry.themes.filter(t=>t.brand!=='icons');
const merged=new Map(registry.themes.filter(t=>t.brand==='icons').map(t=>[t.id,t]));
for(const entry of entries)merged.set(entry.id,entry);
registry.themes=[...previous.filter(t=>!t.brand),...iconModels.map(model=>merged.get(model.id)).filter(Boolean),...previous.filter(t=>t.brand)];
fs.writeFileSync(path.join(root,'themes.json'),JSON.stringify(registry,null,2)+'\n');
