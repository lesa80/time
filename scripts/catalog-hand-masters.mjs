import fs from 'node:fs';import {PNG} from 'pngjs';import {resample,resampleWarped} from './lib/raster.mjs';
const clamp=(v)=>Math.max(0,Math.min(1,v));
const geometry={
 'polyarnye-0300':{hour:{length:210,width:44},minute:{length:253,width:21}},
 'letchik':{hour:{length:200,width:45},minute:{length:255,width:21}},
 'raketa-su':{hour:{length:173,width:35},minute:{length:223,width:18}},
 'amfibiya-0321':{hour:{length:157,width:64},minute:{length:235,width:25}},
 'podvodnik-0317':{hour:{length:180,width:112,wheel:true},minute:{length:287,width:44}}
};
function bounds(p,threshold=128){let x0=p.width,y0=p.height,x1=-1,y1=-1;for(let y=0;y<p.height;y++)for(let x=0;x<p.width;x++)if(p.data[(y*p.width+x)*4+3]>threshold){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}return[x0,y0,x1,y1];}
function trim(p){const b=bounds(p,3),x=Math.max(0,b[0]-4),y=Math.max(0,b[1]-4),w=Math.min(p.width-x,b[2]-x+5),h=Math.min(p.height-y,b[3]-y+5),out=new PNG({width:w,height:h});for(let row=0;row<h;row++)p.data.copy(out.data,row*w*4,((row+y)*p.width+x)*4,((row+y)*p.width+x+w)*4);return{png:out,size:[w/2,h/2],rotatePoint:[350-x/2,350-y/2]};}
function clean(p){for(let i=0;i<p.data.length;i+=4)if(p.data[i+3]<=12)p.data.fill(0,i,i+4);return p;}
function eye(p,b){const x=(b[0]+b[2])/2,ix=Math.round(x),groups=[];let group=[];for(let y=Math.round(b[1]+(b[3]-b[1])*.7);y<b[3];y++){if(p.data[(y*p.width+ix)*4+3]<32){group.push(y);}else if(group.length){groups.push(group);group=[];}}if(group.length)groups.push(group);const selected=groups.filter(g=>g.length>8).at(-1);if(!selected)throw Error('Cannot locate mounting eye');return[x,(selected[0]+selected.at(-1))/2];}
function place(dest,src,dx,dy){dx=Math.round(dx);dy=Math.round(dy);for(let y=0;y<src.height;y++)for(let x=0;x<src.width;x++){const xx=dx+x,yy=dy+y;if(xx<0||yy<0||xx>=dest.width||yy>=dest.height)continue;const i=(y*src.width+x)*4,j=(yy*dest.width+xx)*4,a=src.data[i+3]/255,b=dest.data[j+3]/255,z=a+b*(1-a);if(!z)continue;for(let c=0;c<3;c++)dest.data[j+c]=Math.round((src.data[i+c]*a+dest.data[j+c]*b*(1-a))/z);dest.data[j+3]=Math.round(z*255);}}
function ringMaster(p,name){
 const b=bounds(p),cx=(b[0]+b[2])/2,r=(b[2]-b[0]+1)/2;let cy=0,n=0;
 for(let y=b[1];y<=b[3];y++){let lo=p.width,hi=-1;for(let x=b[0];x<=b[2];x++)if(p.data[(y*p.width+x)*4+3]>128){lo=Math.min(lo,x);hi=Math.max(hi,x);}if(hi-lo>r*1.96){cy+=y;n++;}}
 cy/=n;if(!n)throw Error('No ring center');
 const radius=name==='hour'?99.5:136,offset=name==='hour'?119:121,width=3.4;
 const out=resample(p,[cx-350*r/radius,cy-(350-offset)*r/radius,700*r/radius,700*r/radius],1400,1400);
 const sampleX=Math.round(cx+r-4),sampleY=Math.round(cy),si=(sampleY*p.width+sampleX)*4;
 for(let y=0;y<1400;y++)for(let x=0;x<1400;x++){const d=Math.hypot(x+.5-700,y+.5-(350-offset)*2),coverage=clamp(radius*2+.5-d)*clamp(d-(radius-width)*2+.5),i=(y*1400+x)*4;if(out.data[i+3]<128&&coverage>0)out.data.set(p.data.subarray(si,si+3),i);out.data[i+3]=Math.round(coverage*255);}
 // Erode the bright-white mask to exclude the thin polished metal rim.
 let mx=0,my=0,count=0;for(let y=20;y<p.height-20;y+=2)for(let x=20;x<p.width-20;x+=2){let bright=true;for(const dy of[-18,0,18])for(const dx of[-18,0,18]){const i=((y+dy)*p.width+x+dx)*4;if(p.data[i+3]<220||Math.min(...p.data.subarray(i,i+3))<165)bright=false;}if(bright){mx+=x;my+=y;count++;}}
 if(count<50)throw Error('Missing luminous ring marker');mx/=count;my/=count;const markerSourceRadius=Math.sqrt(count*4/Math.PI)+27,markerRadius=name==='hour'?21:22,markerDistance=name==='hour'?190:233;
 const marker=resample(p,[mx-markerSourceRadius,my-markerSourceRadius,markerSourceRadius*2,markerSourceRadius*2],markerRadius*4,markerRadius*4);
 for(let y=0;y<marker.height;y++)for(let x=0;x<marker.width;x++)marker.data[(y*marker.width+x)*4+3]=Math.round(clamp(marker.width/2+.5-Math.hypot(x+.5-marker.width/2,y+.5-marker.height/2))*255);
 place(out,marker,700-marker.width/2,(350-markerDistance)*2-marker.height/2);
 const length=Math.abs(offset-radius),stem=resample(p,[sampleX-2,sampleY-2,4,4],8,Math.max(2,Math.round((length+4)*2)));for(let i=3;i<stem.data.length;i+=4)stem.data[i]=255;
 place(out,stem,696,name==='hour'?(350-length-1)*2:700);
 return trim(clean(out));
}
export function generatedHand(id,name,root){
 const file=`${root}/assets/catalog/${id}/source/${name}.png`;if(!fs.existsSync(file))return null;
 const p=clean(PNG.sync.read(fs.readFileSync(file)));
 if(id==='kopernik-0293')return ringMaster(p,name);
 if(id==='amfibiya-0321'&&name==='second'){
  const b=bounds(p),cx=(b[0]+b[2])/2,ix=Math.round(cx);let hole=[];
  for(let y=Math.round(b[1]+(b[3]-b[1])*.35);y<b[1]+(b[3]-b[1])*.65;y++)if(p.data[(y*p.width+ix)*4+3]<32)hole.push(y);
  if(!hole.length)throw Error('No second-hand mounting eye');
  const py=(hole[0]+hole.at(-1))/2;
  return trim(clean(resampleWarped(p,{size:[1400,1400],pivot:[700,700],masterPivot:[cx,py],
   sourceYKnots:[[200,b[1]],[700,py],[820,b[3]]],
   targetXScaleKnots:[[0,40/(b[2]-b[0]+1)],[285,40/(b[2]-b[0]+1)],[310,5/26],[670,5/26],[686,24/80],[714,24/80],[730,5/26],[790,5/26],[805,11/60],[1400,11/60]]
  })));
 }
 const g=geometry[id]?.[name];if(!g)return null;
 const b=bounds(p),pivot=g.wheel?[(b[0]+b[2])/2,b[3]-(b[2]-b[0])/2]:eye(p,b);
 const sx=g.width/(b[2]-b[0]+1),sy=g.length/(pivot[1]-b[1]);
 const normalized=resample(p,[pivot[0]-350/sx,pivot[1]-350/sy,700/sx,700/sy],1400,1400);
 return trim(clean(normalized));
}
