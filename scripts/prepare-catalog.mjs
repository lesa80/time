import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import { Resvg } from '@resvg/resvg-js';
import { fileURLToPath } from 'node:url';
import { resample } from './lib/raster.mjs';
import { composePreview } from './lib/raster.mjs';
import { generatedHand } from './catalog-hand-masters.mjs';
import { catalogLayouts } from './catalog-layout.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>PNG.sync.read(fs.readFileSync(path.join(root,p)));
const write=(p,png)=>fs.writeFileSync(path.join(root,p),PNG.sync.write(png));
const clamp=(v,min=0,max=1)=>Math.max(min,Math.min(max,v));
const gray=(p,i)=>p.data[i]*.25+p.data[i+1]*.55+p.data[i+2]*.2;
const svgMask=(shape,side=700)=>PNG.sync.read(new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="${side}" height="${side}" viewBox="0 0 700 700"><g fill="white">${shape}</g></svg>`).render().asPng());
function bounds(p,threshold=3){let x0=p.width,y0=p.height,x1=-1,y1=-1;for(let y=0;y<p.height;y++)for(let x=0;x<p.width;x++)if(p.data[(y*p.width+x)*4+3]>threshold){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}if(x1<0)throw Error('Empty raster');return[x0,y0,x1-x0+1,y1-y0+1];}
function crop(p,[x,y,w,h]){const out=new PNG({width:w,height:h});for(let row=0;row<h;row++)p.data.copy(out.data,row*w*4,((row+y)*p.width+x)*4,((row+y)*p.width+x+w)*4);return out;}
function dilate(mask,radius){const w=mask.width,h=mask.height,hor=new Float32Array(w*h),out=new Float32Array(w*h);for(let y=0;y<h;y++)for(let x=0;x<w;x++){let v=0;for(let k=-radius;k<=radius;k++)if(x+k>=0&&x+k<w)v=Math.max(v,mask.data[(y*w+x+k)*4+3]/255);hor[y*w+x]=v;}for(let y=0;y<h;y++)for(let x=0;x<w;x++){let v=0;for(let k=-radius;k<=radius;k++)if(y+k>=0&&y+k<h)v=Math.max(v,hor[(y+k)*w+x]);out[y*w+x]=v;}return out;}
function sample(p,x,y,c){if(x<0||y<0||x>=p.width-1||y>=p.height-1)return 0;const ix=Math.floor(x),iy=Math.floor(y),fx=x-ix,fy=y-iy;return (p.data[(iy*p.width+ix)*4+c]*(1-fx)+p.data[(iy*p.width+ix+1)*4+c]*fx)*(1-fy)+(p.data[((iy+1)*p.width+ix)*4+c]*(1-fx)+p.data[((iy+1)*p.width+ix+1)*4+c]*fx)*fy;}
function register(original,generated,blocked,config){
 const [cx,cy]=config.center;const points=[];
 for(let y=35;y<665;y+=3)for(let x=35;x<665;x+=3){const i=(y*700+x)*4;if(blocked[y*700+x]>.01)continue;if(config.radius&&Math.hypot(x-cx,y-cy)>config.radius-7)continue;if(config.rectangle&&(x<config.rectangle[0]+5||x>config.rectangle[0]+config.rectangle[2]-5||y<config.rectangle[1]+5||y>config.rectangle[1]+config.rectangle[3]-5))continue;const gradient=Math.abs(gray(original,i+4)-gray(original,i-4))+Math.abs(gray(original,i+700*4)-gray(original,i-700*4));if(gradient>15)points.push([x,y,gray(original,i),Math.min(60,gradient)]);}
 if(points.length<50)return{sx:1,sy:1,dx:0,dy:0,error:0};
 const score=p=>{let sum=0,weight=0;for(const[x,y,value,g]of points){const xx=(x-cx)*p.sx+cx+p.dx,yy=(y-cy)*p.sy+cy+p.dy;const v=sample(generated,xx,yy,0)*.25+sample(generated,xx,yy,1)*.55+sample(generated,xx,yy,2)*.2;sum+=Math.min(90,Math.abs(v-value))*g;weight+=g;}return sum/weight;};
 let best={sx:1,sy:1,dx:0,dy:0};let error=score(best);
 for(const step of [4,2,1,.5])for(let pass=0;pass<2;pass++)for(const key of ['dx','dy','sx','sy']){
  const unit=key==='sx'||key==='sy'?step/250:step;
  for(const delta of [-unit,unit]){const p={...best,[key]:best[key]+delta};if(Math.abs(p.dx)>18||Math.abs(p.dy)>18||Math.abs(p.sx-1)>.065||Math.abs(p.sy-1)>.065)continue;const e=score(p);if(e<error){best=p;error=e;}}
 }
 return {...best,error};
}
function staticDial(original,restored,config){
 const source=read(original),gen0=read(restored),gen=resample(gen0,[0,0,gen0.width,gen0.height],700,700);
 const all=Object.values(config.hands).map(h=>h.shape).join('')+`<circle cx="${config.center[0]}" cy="${config.center[1]}" r="${Math.max(16,config.capRadius+5)}"/>`;
 const mask=svgMask(all),large=dilate(mask,42),small=dilate(mask,30),registration=register(source,gen,large,config);
 // Match local RGB bias at each removed object's edge, retaining the source photo
 // everywhere else. This keeps exact typography, material grain and reflections.
 const bias=[0,0,0],count=[0,0,0];
 for(let y=20;y<680;y+=2)for(let x=20;x<680;x+=2)if(large[y*700+x]>.5&&small[y*700+x]<.1){const i=(y*700+x)*4;const xx=(x-config.center[0])*registration.sx+config.center[0]+registration.dx,yy=(y-config.center[1])*registration.sy+config.center[1]+registration.dy;for(let c=0;c<3;c++){const d=source.data[i+c]-sample(gen,xx,yy,c);if(Math.abs(d)<25){bias[c]+=d;count[c]++;}}}
 for(let c=0;c<3;c++)bias[c]=count[c]?bias[c]/count[c]:0;
 // A short box blur softens only the inpaint-mask perimeter.
 const blend=new Float32Array(700*700);for(let y=0;y<700;y++)for(let x=0;x<700;x++){let sum=0,n=0;for(let yy=Math.max(0,y-5);yy<=Math.min(699,y+5);yy++)for(let xx=Math.max(0,x-5);xx<=Math.min(699,x+5);xx++){sum+=small[yy*700+xx];n++;}blend[y*700+x]=sum/n;}
 const out=new PNG({width:700,height:700});source.data.copy(out.data);
 for(let y=0;y<700;y++)for(let x=0;x<700;x++){const a=blend[y*700+x];if(!a)continue;const i=(y*700+x)*4,xx=(x-config.center[0])*registration.sx+config.center[0]+registration.dx,yy=(y-config.center[1])*registration.sy+config.center[1]+registration.dy;for(let c=0;c<3;c++)out.data[i+c]=Math.round(clamp(sample(gen,xx,yy,c)+bias[c],0,255)*a+source.data[i+c]*(1-a));out.data[i+3]=255;}
 return {png:out,registration,bias};
}
function coverage(config,x,y){if(config.radius)return clamp(config.radius+.5-Math.hypot(x-config.center[0],y-config.center[1]));const[rx,ry,w,h]=config.rectangle;return clamp(Math.min(x-rx,y-ry,rx+w-x,ry+h-y)+.5);}
function handSprite(source,hand,center,id,name){
 const side=1400,mask=svgMask(hand.shape,side),photo=resample(source,[0,0,700,700],side,side);
 for(let i=0;i<photo.data.length;i+=4){
  photo.data[i+3]=mask.data[i+3];
  if(name==='second'&&['polyarnye-0300','podvodnik-0317'].includes(id)&&!(photo.data[i]>100&&photo.data[i]>photo.data[i+1]*1.45&&photo.data[i]>photo.data[i+2]*1.35))photo.data[i+3]=0;
  if(name==='second'&&id==='letchik'&&!(photo.data[i]>140&&photo.data[i+1]>125&&photo.data[i+2]<130))photo.data[i+3]=0;
 }
 const bytes=PNG.sync.write(photo),angle=-hand.angle;
 const png=PNG.sync.read(new Resvg(`<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="1400" viewBox="0 0 700 700"><image x="0" y="0" width="700" height="700" transform="rotate(${angle} ${center[0]} ${center[1]})" href="data:image/png;base64,${bytes.toString('base64')}"/></svg>`).render().asPng());
 let box=bounds(png);box=[Math.max(0,box[0]-3),Math.max(0,box[1]-3),Math.min(side,box[2]+6),Math.min(side,box[3]+6)];if(box[0]+box[2]>side)box[2]=side-box[0];if(box[1]+box[3]>side)box[3]=side-box[1];
 return{png:crop(png,box),size:box.slice(2).map(v=>v/2),rotatePoint:[center[0]-box[0]/2,center[1]-box[1]/2]};
}
export function prepareCatalog({only}={}){
 const registry=JSON.parse(fs.readFileSync(path.join(root,'themes.json'))),official=JSON.parse(fs.readFileSync(path.join(root,'reference/catalog/index.json')));
 const existing=registry.themes.filter(t=>t.id.startsWith('minimalism')||t.id==='avangard');
 const entries=[];
 fs.mkdirSync(path.join(root,'macos/.build/previews/catalog'),{recursive:true});
 for(const item of official.items){if(item.code==='avangard-0292')continue;const id=item.code,config=catalogLayouts[id];if(!config)throw Error(`No geometry for ${id}`);const base=`assets/catalog/${id}`;fs.mkdirSync(path.join(root,base),{recursive:true});const restored=`${base}/source/restored.png`;
 if(only&&id!==only)continue;
 if(!fs.existsSync(path.join(root,restored)))throw Error(`Missing restored dial: ${id}`);
 const source=read(`reference/catalog/${id}/face-source.png`),prepared=staticDial(`reference/catalog/${id}/face-source.png`,restored,config);
 const dialBox=config.radius?[config.center[0]-config.radius,config.center[1]-config.radius,config.radius*2,config.radius*2]:config.rectangle;
 const dial=resample(prepared.png,dialBox,2048,2048);
 for(let y=0;y<2048;y++)for(let x=0;x<2048;x++){const a=coverage(config,dialBox[0]+(x+.5)/2048*dialBox[2],dialBox[1]+(y+.5)/2048*dialBox[3]);dial.data[(y*2048+x)*4+3]=Math.round(a*255);}
 write(`${base}/dial.png`,dial);
 const body=read(config.bodySource??`reference/catalog/${id}/front.png`),bb=bounds(body,8),pad=6;
 const bodyCrop=[Math.max(0,bb[0]-pad),Math.max(0,bb[1]-pad),Math.min(body.width,bb[2]+pad*2),Math.min(body.height,bb[3]+pad*2)];bodyCrop[2]=Math.min(bodyCrop[2],body.width-bodyCrop[0]);bodyCrop[3]=Math.min(bodyCrop[3],body.height-bodyCrop[1]);
 const origin=config.cropOrigin??[100,350],center=config.center.map((v,i)=>v+origin[i]-bodyCrop[i]),dialOrigin=dialBox.slice(0,2).map((v,i)=>v+origin[i]-bodyCrop[i]);
 const bezel=crop(body,bodyCrop);
 for(let y=0;y<bezel.height;y++)for(let x=0;x<bezel.width;x++){const a=coverage(config,x+bodyCrop[0]-origin[0]+.5,y+bodyCrop[1]-origin[1]+.5);const i=(y*bezel.width+x)*4+3;bezel.data[i]=Math.round(bezel.data[i]*(1-a));}
 write(`${base}/bezel.png`,bezel);
 const layers=[{type:'Single Res',image:`${base}/bezel.png`,position:[0,0],size:bodyCrop.slice(2)},{type:'Single Res',image:`${base}/dial.png`,position:dialOrigin,size:dialBox.slice(2)}];
 for(const[name,hand]of Object.entries(config.hands)){const sprite=generatedHand(id,name,root)??handSprite(source,hand,config.center,id,name);write(`${base}/${name}.png`,sprite.png);layers.push({type:'Hand Res',image:`${base}/${name}.png`,valueType:name==='hour'?`Hour ${config.hourCycle} Ratio`:name==='minute'?'Minute Ratio':'Second Ratio',handResPosition:center,rotatePoint:sprite.rotatePoint,size:sprite.size,angle:[0,360]});}
 if(config.capRadius){const r=config.capRadius,cap=resample(source,[config.center[0]-r,config.center[1]-r,r*2,r*2],Math.round(r*8),Math.round(r*8));for(let y=0;y<cap.height;y++)for(let x=0;x<cap.width;x++)cap.data[(y*cap.width+x)*4+3]=Math.round(clamp(cap.width/2+.5-Math.hypot(x+.5-cap.width/2,y+.5-cap.height/2))*255);write(`${base}/cap.png`,cap);layers.push({type:'Single Res',image:`${base}/cap.png`,position:center.map(v=>v-r),size:[r*2,r*2]});}
 const spec={name:config.title,target:'macOS / Retina',hourCycle:config.hourCycle,direction:config.direction,resolution:bodyCrop.slice(2),dialBounds:[...dialOrigin,...dialBox.slice(2)],dialShape:config.rectangle?'rectangle':'circle',rasterResolution:[2048,2048],layers};
 fs.writeFileSync(path.join(root,base,'theme.json'),JSON.stringify(spec,null,2)+'\n');
 const angles=Object.fromEntries(Object.entries(config.hands).map(([name,h])=>[name,h.angle]));
 const entry={id,brand:'raketa',title:config.title,hourCycle:config.hourCycle,direction:config.direction,dialShape:spec.dialShape,specification:`catalog/${id}/theme.json`,sourceSpec:`${base}/theme.json`,referenceTime:config.referenceTime,referenceAngles:angles,referenceURL:item.productURL,section:item.sectionCode};entries.push(entry);
 fs.writeFileSync(path.join(root,base,'registration.json'),JSON.stringify({source:item.previewPicture,bodySource:config.bodySource??`reference/catalog/${id}/front.png`,cropOrigin:origin,bodyCrop,center:config.center,dialBox,hands:config.hands,restoration:{registration:prepared.registration,bias:prepared.bias}},null,2)+'\n');
 const composed=layers.map(l=>({name:path.basename(l.image,'.png'),spec:l,png:fs.readFileSync(path.join(root,l.image)),size:l.size}));
 fs.writeFileSync(path.join(root,`macos/.build/previews/catalog/${id}-full.png`),composePreview(composed,spec.resolution,angles,280));
 const dialLayers=composed.filter(l=>l.name!=='bezel').map(l=>({...l,spec:{...l.spec,...(l.spec.position?{position:l.spec.position.map((v,i)=>v-dialOrigin[i])}:{}),...(l.spec.handResPosition?{handResPosition:l.spec.handResPosition.map((v,i)=>v-dialOrigin[i])}:{})}}));
 fs.writeFileSync(path.join(root,`macos/.build/previews/catalog/${id}-dial.png`),composePreview(dialLayers,dialBox.slice(2),angles,466));
 console.log(`Prepared ${id}: ${config.hourCycle}h, ${config.direction===-1?'counterclockwise':'clockwise'}, ${Object.keys(config.hands).length} hands; registration error ${prepared.registration.error.toFixed(2)}`);
 }
 if(!only){registry.themes=[...existing,...entries];fs.writeFileSync(path.join(root,'themes.json'),JSON.stringify(registry,null,2)+'\n');}
 return entries;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))prepareCatalog({only:process.argv[2]});
