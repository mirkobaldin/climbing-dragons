// Riproduce il 9-slice previsto, con dimensioni v2 e scala dei bordi documentata.
(async()=>{
const jobs=window.V2_JOBS,images={};
const image=src=>new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(Error('Immagine non leggibile: '+src));im.src=src;});
await Promise.all(jobs.map(async j=>images[j.name]=await image(j.name+'.png')));
const backdrop=await image('../ui-20261010/bg_menu.png');
await document.fonts.load('900 22px GameBlack');await document.fonts.ready;
const make=(w,h)=>Object.assign(document.createElement('canvas'),{width:w,height:h});
const labels={btn_buy_v2:['Buy','Craft','Hatch'],btn_sell_v2:['Sell all','Sell all','Sell all'],btn_main_v2:['Unlock','REBIRTH','Ride'],btn_alt_v2:['Rest','Skip','Reset'],btn_off_v2:['Not ready yet','Not ready yet','Not ready yet'],tab_on_v2:['Buy','Rebirth','Upgrades'],tab_off_v2:['Sell','Bounties','Rebirth']};
const stats={assets:jobs.length,buttonDraws:0,clippedLabels:[],font:'Montserrat Black (mappatura Roblox di GothamBlack)',sizes:[[120,44],[200,56],[320,64]],backgrounds:['bg_menu','dark','light']};
function nine(g,j,x,y,w,h){
 const im=images[j.name];if(!j.slice){g.drawImage(im,x,y,w,h);return;}
 const [l,t,r,b]=j.slice,ew=l+j.width-r,eh=t+j.height-b;
 const scale=Math.max(.05,Math.min(w*.8/ew,h*.8/eh,j.name.startsWith('btn_')?.5:.3));
 const sx=[0,l,r,j.width],sy=[0,t,b,j.height];
 const dx=[x,x+l*scale,x+w-(j.width-r)*scale,x+w],dy=[y,y+t*scale,y+h-(j.height-b)*scale,y+h];
 for(let iy=0;iy<3;iy++)for(let ix=0;ix<3;ix++)g.drawImage(im,sx[ix],sy[iy],sx[ix+1]-sx[ix],sy[iy+1]-sy[iy],dx[ix],dy[iy],dx[ix+1]-dx[ix],dy[iy+1]-dy[iy]);
}
function text(g,label,x,y,w,h,size=22){
 g.save();g.font=`900 ${size}px GameBlack`;g.textAlign='center';g.textBaseline='middle';g.lineJoin='round';g.strokeStyle='#071018';g.lineWidth=3;g.fillStyle='white';
 let actual=size;while(g.measureText(label).width>w-22&&actual>11){actual--;g.font=`900 ${actual}px GameBlack`;}
 if(g.measureText(label).width>w-18)stats.clippedLabels.push({label,w,actual});
 g.strokeText(label,x+w/2,y+h/2+1);g.fillText(label,x+w/2,y+h/2+1);g.restore();
}
function surface(g,type,x,y,w,h){
 g.save();g.beginPath();g.rect(x,y,w,h);g.clip();
 if(type===0){const f=Math.max(w/backdrop.width,h/backdrop.height);g.drawImage(backdrop,x+(w-backdrop.width*f)/2,y+(h-backdrop.height*f)/2,backdrop.width*f,backdrop.height*f);}
 else{g.fillStyle=type===1?'#131c2a':'#e4dfd2';g.fillRect(x,y,w,h);}g.restore();
}
function caption(g,s,x,y,color='#ddc6a0',size=14){g.font=`${size}px Arial`;g.fillStyle=color;g.textAlign='left';g.fillText(s,x,y);}
const board=document.querySelector('#board');board.width=2280;board.height=2230;let g=board.getContext('2d');g.fillStyle='#0b1420';g.fillRect(0,0,board.width,board.height);
caption(g,'CLIMBING & DRAGONS  /  V2 — all states, real nine-slice',24,36,'#f4e6c9',25);
const buttons=jobs.filter(j=>j.state);
for(let bg=0;bg<3;bg++){
 const bx=bg*760;caption(g,['ILLUSTRATED MENU','DARK PANEL','LIGHT BACKGROUND'][bg],bx+24,73,'#ddc6a0',16);
 caption(g,'120 × 44                 200 × 56                         320 × 64',bx+24,98);
 for(let row=0;row<buttons.length;row++){
   const j=buttons[row],yy=112+row*96;
   surface(g,bg,bx+12,yy,736,91);caption(g,j.name,bx+22,yy+18,bg===2?'#384454':'#dce4ed',12);
   const family=j.name.replace(/_(normal|hover|pressed)$/,'');
   for(let s=0;s<3;s++){
     const [w,h]=stats.sizes[s],xx=bx+[24,160,376][s],y=yy+25+(64-h)/2;
     nine(g,j,xx,y,w,h);text(g,labels[family][s],xx,y+(j.state==='pressed'?1:0),w,h,s===0?20:22);stats.buttonDraws++;
   }
 }
}
caption(g,'Font: GothamBlack → Montserrat Black in Roblox. White text + dark outline. Long labels at 120 px shrink; use 200 px for full 22 px text.',24,2160,'#e6d9c2',16);
caption(g,'Normal / hover / pressed. Text is ONLY in this preview. All 24 upload sprites are text-free RGBA.',24,2195,'#afbecf',16);
const mobile=make(board.width/2,board.height/2);mobile.getContext('2d').drawImage(board,0,0,mobile.width,mobile.height);
const overview=make(1060,850),og=overview.getContext('2d');surface(og,0,0,0,1060,850);og.fillStyle='#07111ddd';og.fillRect(0,0,1060,850);
caption(og,'CLIMBING & DRAGONS',40,48,'#f4d497',26);caption(og,'UI v2 · semantic colours / illustrated slate & enamel',40,78,'#c0ccda',16);
['NORMAL','HOVER','PRESSED'].forEach((s,i)=>caption(og,s,240+i*270,119,'#dec9a4',13));
Object.keys(labels).forEach((family,row)=>{
 const y=139+row*96;caption(og,family.replace('_v2',''),30,y+33,'#c4d0dc',15);
 ['normal','hover','pressed'].forEach((state,i)=>{const j=jobs.find(j=>j.name===family+'_'+state);nine(og,j,200+i*280,y,250,64);text(og,labels[family][family==='btn_main_v2'?i:0],200+i*280,y,250,64,22);});
});
const cards=make(1200,1080),cg=cards.getContext('2d');surface(cg,0,0,0,1200,1080);cg.fillStyle='#07111d66';cg.fillRect(0,0,1200,1080);
caption(cg,'REBIRTH / GLASS OVER THE ILLUSTRATED MENU',28,38,'#f7e6bd',21);
const glass=jobs.find(j=>j.name==='card_glass_v2');nine(cg,glass,36,70,500,650);text(cg,'REBIRTH',86,105,400,60,32);
caption(cg,'A new ascent. A stronger companion.',100,198,'#e0e8ee',18);
nine(cg,jobs.find(j=>j.name==='pedestal_v2'),87,295,400,200);
nine(cg,jobs.find(j=>j.name==='btn_main_v2_normal'),126,590,320,64);text(cg,'REBIRTH',126,590,320,64,22);
caption(cg,'ITEM CARDS / TRANSPARENT CENTRE',600,76,'#f7e6bd',18);
const item=jobs.find(j=>j.name==='card_item_v2');['#142d45','#382c17'].forEach((c,i)=>{cg.fillStyle=c;cg.fillRect(594+i*290,116,260,345);nine(cg,item,594+i*290,116,260,345);text(cg,i?'CRAFTING':'STORE',610+i*290,141,228,40,22);});
caption(cg,'PEDESTAL / ORIGINAL TRANSPARENT SPRITE',600,520,'#f7e6bd',18);nine(cg,jobs.find(j=>j.name==='pedestal_v2'),614,548,512,256);
caption(cg,'OPTIONAL LAYERS / ONLY THE RUNES CHANGE COLOUR',28,858,'#f7e6bd',20);
[['Frost','#8fdcff'],['Cosmic','#c589ff'],['Black Lightning','#a7baff']].forEach(([label,color],i)=>{
 const x=44+i*395;caption(cg,label,x,895,'#f3e3c2',16);
 nine(cg,jobs.find(j=>j.name==='pedestal_base_v2'),x,911,320,160);
 const mask=make(512,256),mg=mask.getContext('2d');mg.drawImage(images.pedestal_runes_v2,0,0);mg.globalCompositeOperation='source-in';mg.fillStyle=color;mg.fillRect(0,0,512,256);cg.drawImage(mask,x,911,320,160);
});
window.previewCanvases={board,mobile,overview,cards};window.previewStats=stats;
for(const family of Object.keys(labels)){
 const c=make(250,64);document.querySelector('#interactive').append(c);const ctx=c.getContext('2d');
 const draw=state=>{ctx.clearRect(0,0,c.width,c.height);nine(ctx,jobs.find(j=>j.name===family+'_'+state),0,0,250,64);text(ctx,labels[family][0],0,state==='pressed'?1:0,250,64,22);};
 c.onmouseenter=()=>draw('hover');c.onmouseleave=()=>draw('normal');c.onpointerdown=()=>draw('pressed');c.onpointerup=()=>draw('hover');draw('normal');
}
window.previewReady=true;
})().catch(e=>{window.previewError=String(e.stack||e);document.body.append(String(e));});
