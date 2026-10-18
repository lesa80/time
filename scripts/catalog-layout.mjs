// Registration in the 700 × 700 source crop (photo rectangle 100,350,700,700).
// These paths are extraction masks only: all visible artwork comes from raster pixels.
const polygon = points => `<polygon points="${points.map(p => p.join(',')).join(' ')}"/>`;
const circle = (x,y,r) => `<circle cx="${x}" cy="${y}" r="${r}"/>`;
const ring = (x,y,r,w) => `<circle cx="${x}" cy="${y}" r="${r-w/2}" fill="none" stroke="white" stroke-width="${w}"/>`;
const bar = (cx,cy,tx,ty,w,tail=0,tw=w) => {
 const dx=tx-cx,dy=ty-cy,len=Math.hypot(dx,dy),nx=-dy/len,ny=dx/len;
 return polygon([[tx+nx*w/2,ty+ny*w/2],[tx-nx*w/2,ty-ny*w/2],[cx-dx/len*tail-nx*tw/2,cy-dy/len*tail-ny*tw/2],[cx-dx/len*tail+nx*tw/2,cy-dy/len*tail+ny*tw/2]]);
};
const hand=(shape,angle,extra={})=>({shape,angle,...extra});
const poly=(points,angle,extra={})=>hand(polygon(points),angle,extra);
const baton=(tip,w,angle,tail=48,tw=w,c=[350,350])=>hand(bar(...c,...tip,w,tail,tw)+circle(...c,9),angle);
const needle=(tip,angle,tail=55,colorWidth=2,c=[350,350])=>hand(bar(...c,...tip,colorWidth,tail)+circle(...c,6),angle);
const genericBigZero=(secondTip,secondAngle,overrides={})=>({
 hour:poly([[215,253],[222,249],[397,369],[385,390],[211,268]],304),
 minute:poly([[311,384],[303,372],[525,208],[535,209],[535,216],[318,390]],52),
 second:needle(secondTip,secondAngle,58,2.8),...overrides
});
export const catalogLayouts={
 'zolotoy-klyuchik':{title:'Золотой Ключик 0328',center:[350,347],radius:220,capRadius:9,hourCycle:12,referenceTime:'10:10:27',hands:{
  hour:poly([[244,262],[390,368],[379,382],[236,278]],304),
  minute:poly([[312,373],[307,364],[504,253],[514,260]],60),
  second:needle([414,541],162,62,2.1,[350,347])}},
 'sovremennik':{title:'Современник 0352',radius:300,capRadius:8,hourCycle:12,referenceTime:'10:10:38',hands:{
  hour:poly([[224,256],[229,252],[412,359],[378,406]],307),
  minute:poly([[293,356],[547,223],[551,230],[324,404]],58),
  second:poly([[127,528],[168,464],[180,480],[400,302],[408,311],[189,489],[200,504]],232)}},
 'russkiy-kod-0302':{title:'Русский код 0302',radius:295,capRadius:8,hourCycle:12,direction:-1,referenceTime:'01:50:32',hands:{
  hour:poly([[208,254],[214,254],[401,363],[393,380],[205,266]],304),
  minute:poly([[306,368],[310,378],[539,191],[540,183],[533,179]],49),
  second:hand(bar(350,350,296,570,1.8,98)+ring(295,570,35,6)+circle(375,253,9),194)}},
 'russkiy-kod-0344':{title:'Русский код · Меридиан 0344',radius:299,capRadius:9,hourCycle:12,direction:-1,referenceTime:'01:50:22',hands:{
  hour:poly([[202,251],[209,246],[403,364],[393,382],[199,260]],303),
  minute:poly([[307,376],[304,365],[568,211],[577,215],[576,222],[313,383]],59),
  second:hand(bar(354,350,560,552,3,107)+ring(524,515,34,5.5)+circle(277,276,9),134)}},
 'raketa-x-lebedev':{title:'BIG ZERO Лебедев 0333',radius:290,capRadius:11,hourCycle:12,referenceTime:'10:10:37',hands:genericBigZero([172,563],222,{hour:poly([[217,250],[225,248],[396,369],[381,390],[211,264]],305),minute:poly([[312,381],[305,372],[525,209],[532,211],[534,217],[318,388]],52),second:needle([172,563],222,55,1.8)})},
 'baykonur-0325':{title:'Байконур 0325',center:[348,344],radius:259,capRadius:10,hourCycle:24,referenceTime:'20:10:39',hands:{
  hour:poly([[204,251],[234,264],[255,257],[329,305],[311,338],[236,291],[228,272],[203,255]],304),
  minute:poly([[363,313],[476,213],[493,207],[487,225],[378,326]],47),
  second:needle([187,463],234,36,2.5,[348,344])}},
 'big-zero-yankovskaya':{title:'BIG ZERO Янковская 0330',center:[350,347],radius:291,capRadius:0,hourCycle:12,referenceTime:'10:10:30',hands:{
  hour:poly([[218,250],[230,244],[399,370],[389,384],[216,263]],305),
  minute:poly([[309,373],[304,363],[550,232],[557,236],[557,245],[315,382]],61),
  second:poly([[350,330],[358,366],[386,346],[368,375],[402,383],[368,390],[385,417],[357,398],[350,433],[343,399],[315,417],[332,390],[299,383],[333,376],[314,348],[343,366]],180)}},
 'big-zero-azur-blue':{title:'BIG ZERO Лазурь 0308',center:[348,351],radius:297,capRadius:9,hourCycle:12,referenceTime:'10:10:29',hands:{
  hour:poly([[210,258],[217,253],[400,369],[388,388],[210,274]],304),
  minute:poly([[314,392],[305,377],[535,215],[546,228]],55),
  second:needle([363,619],177,63,2.8,[348,351])}},
 'amfibiya-0321':{title:'Амфибия 0321',center:[348,353],radius:249,capRadius:9,hourCycle:12,referenceTime:'10:10:36',hands:{
  hour:poly([[216,266],[267,265],[335,320],[317,348],[238,321]],304),
  minute:poly([[372,335],[411,298],[420,283],[501,212],[515,215],[528,204],[531,209],[519,223],[515,236],[433,309],[419,309],[382,348]],49),
  second:poly([[212,547],[229,511],[237,519],[379,333],[383,328],[393,332],[384,345],[243,525],[252,531]],216)}},
 'kopernik-0293':{title:'Коперник 0307',center:[351,356],radius:291,capRadius:10,hourCycle:12,referenceTime:'09:25:09',hands:{
  hour:hand(ring(237,321,99.5,5)+circle(167,308,21)+bar(351,356,338,350,4,0),284),
  minute:hand(ring(408,463,136,5)+circle(459,562,22),153),
  second:needle([583,187],54,271,1.8,[351,356])}},
 'podvodnik-0317':{title:'Подводник 0317',center:[350,350],radius:255,capRadius:9,hourCycle:24,referenceTime:'20:10:40',hands:{
  hour:poly([[224,222],[318,288],[326,296],[311,304]],316),
  minute:poly([[358,337],[491,169],[535,124],[519,162],[373,350]],43),
  second:poly([[130,477],[128,474],[421,282],[459,280],[455,291],[350,360]],239),
  // The open steel mounting wheel belongs to the hour hand and turns with it.
 },hourExtras:ring(350,350,54,13)+bar(350,350,316,311,9,48)},
 'polyarnye-0300':{title:'Полярные 0300',center:[350,350],radius:257,capRadius:9,hourCycle:24,referenceTime:'20:10:24',hands:{
  hour:poly([[169,243],[218,270],[251,275],[334,327],[322,342],[247,306],[226,278],[169,247]],303),
  minute:poly([[361,341],[374,335],[378,327],[536,245],[542,245],[548,235],[559,238],[570,224],[570,229],[561,244],[557,255],[546,257],[390,342],[380,342],[369,351]],62),
  second:poly([[491,548],[487,546],[474,523],[466,511],[464,502],[345,354],[303,290],[303,284],[309,282],[315,288],[353,346]],145)}},
 'letchik':{title:'Лётчик 0301',center:[350,350],radius:275,capRadius:9,hourCycle:12,referenceTime:'10:10:33',hands:{
  hour:poly([[185,237],[219,264],[267,273],[324,315],[334,333],[326,340],[260,313],[235,277],[186,241]],304),
  minute:poly([[362,341],[374,336],[382,326],[524,244],[538,238],[549,226],[568,218],[560,229],[552,240],[550,253],[397,340],[383,342],[373,351]],61),
  second:poly([[273,602],[274,592],[284,546],[290,538],[292,544],[359,338],[367,273],[376,267],[379,281],[352,357],[287,571],[278,596]],197)}},
 'big-zero-blue':{title:'BIG ZERO Синий 0294',radius:293,capRadius:9,hourCycle:12,referenceTime:'10:10:33',hands:genericBigZero([263,590],200,{hour:poly([[213,256],[222,252],[398,371],[386,390],[211,269]],304),minute:poly([[317,390],[308,380],[522,209],[529,208],[533,215],[324,395]],52),second:needle([263,590],200,59,3.8)})},
 'big-zero-black-0341':{title:'BIG ZERO Чёрный 0341',radius:292,capRadius:9,hourCycle:12,referenceTime:'10:10:33',hands:genericBigZero([267,596],199,{hour:poly([[215,256],[223,252],[395,371],[385,386],[212,267]],305),minute:poly([[311,380],[313,389],[546,244],[550,236],[545,231],[537,234]],60),second:needle([267,596],199,56,2)})},
 'big-zero-0283':{title:'BIG ZERO 0283',radius:291,capRadius:10,hourCycle:12,referenceTime:'10:10:37',hands:genericBigZero([182,555],220)},
 'raketa-avgvst-0316':{title:'Ракета × Avgvst 0316 · серебро',center:[352,349],rectangle:[155,155,393,393],capRadius:9,hourCycle:12,referenceTime:'10:07:00',hands:{
  hour:poly([[245,277],[250,275],[356,342],[347,351],[244,284]],305),
  minute:poly([[350,354],[345,347],[471,228],[476,228],[476,233],[356,354]],46)}},
 'raketa-avgvst':{title:'Ракета × Avgvst 0315 · золото',center:[350,349],rectangle:[153,155,393,393],capRadius:9,hourCycle:12,referenceTime:'10:07:00',hands:{
  hour:poly([[244,277],[249,275],[355,342],[347,351],[244,284]],305),
  minute:poly([[350,354],[345,347],[471,228],[476,228],[476,233],[356,354]],46)}},
 'raketa-avgvst-0320':{title:'Ракета × Avgvst 0320 · чёрный',center:[350,350],rectangle:[154,155,393,393],capRadius:9,hourCycle:12,referenceTime:'10:07:00',hands:{
  hour:poly([[243,280],[247,276],[355,343],[350,351],[245,287]],305),
  minute:poly([[350,354],[345,347],[477,239],[483,239],[484,244],[357,355]],51)}}
};
for(const item of Object.values(catalogLayouts)){
 item.center??=[350,350];item.direction??=1;
 if(item.hourExtras)item.hands.hour.shape+=item.hourExtras;
}
catalogLayouts['raketa-su']={title:'Ракета Су 0331',center:[350,350],radius:250,capRadius:12,hourCycle:12,direction:1,referenceTime:'10:10:39',cropOrigin:[162,390],bodySource:'assets/catalog/su-front/source/restored.png',hands:{
 hour:poly([[208,252],[240,276],[278,280],[323,320],[329,331],[320,341],[264,314],[244,285],[207,256]],304),
 minute:poly([[363,342],[376,336],[382,326],[500,260],[518,254],[527,245],[544,236],[539,245],[526,257],[524,265],[398,337],[382,342],[374,351]],61),
 second:poly([[172,489],[174,480],[213,452],[220,450],[341,353],[378,313],[393,303],[404,301],[405,306],[383,326],[354,355],[221,463],[214,465]],231)} };
// Narrow mounting necks are part of each moving hand, even where the broad
// blade ends before the common axis. Keep their original photographic pixels.
for(const[id,links]of Object.entries({
 'raketa-su':{hour:[[318,330],9],minute:[[380,331],9]},
 'letchik':{hour:[[319,327],10],minute:[[380,331],10]},
 'polyarnye-0300':{hour:[[324,335],8],minute:[[381,335],9]},
 'baykonur-0325':{hour:[[316,321],7],minute:[[376,317],7]},
 'amfibiya-0321':{hour:[[320,334],8],minute:[[380,337],9]}
}))for(const[name,[tip,width]]of Object.entries(links)){const c=catalogLayouts[id];c.hands[name].shape+=bar(...c.center,...tip,width,4);}
catalogLayouts['polyarnye-0300'].hands.second=hand(bar(350,350,491,548,2.7,75)+polygon([[303,290],[304,284],[310,283],[317,291],[350,350],[344,352]])+polygon([[469,518],[465,505],[466,501],[473,508],[478,520]]),145);
catalogLayouts.letchik.hands.second=hand(bar(350,350,273,602,3.6,81)+polygon([[285,541],[294,533],[300,541],[284,575]])+polygon([[360,297],[364,278],[373,268],[379,274],[377,285],[356,338]]),197);
catalogLayouts['russkiy-kod-0302'].hands.second=hand(bar(350,350,304,536,1.8,98)+ring(295,570,35,6)+circle(375,253,9),194);
catalogLayouts['russkiy-kod-0344'].hands.second=hand(bar(354,350,500,491,3,107)+bar(548,539,560,552,2.5,0)+ring(524,515,34,5.5)+circle(277,276,9),134);
catalogLayouts['podvodnik-0317'].hands.hour.shape=`<path d="M 227 223 L 322 295 L 310 306 Z" fill="none" stroke="white" stroke-width="9"/>`+ring(350,350,54,13)+bar(350,350,316,311,9,48);
catalogLayouts['podvodnik-0317'].hands.minute.shape=`<path d="M 358 337 L 493 168 L 532 128 L 518 161 L 374 350 Z" fill="none" stroke="white" stroke-width="9"/>`;

catalogLayouts['podvodnik-0317'].radius=315;
