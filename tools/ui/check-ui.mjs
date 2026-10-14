// Controlli dichiarativi e geometria calcolata dalle funzioni Luau effettive.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const exe=process.argv[2];assert(exe,'Uso: node tools/ui/check-ui.mjs percorso/luau.exe');
const root='artifacts/ui-v3-20261014';
const source=fs.readFileSync('src/shared/UiView.luau','utf8');
const metrics=source.slice(source.indexOf('function UiView.menuMetrics'),source.indexOf('\nreturn UiView'));
const viewports=[[1920,1080],[1366,768],[844,390],[390,844],[844,354]];
const harness=`local UiView={}\n${metrics}\nfor _, v in ${JSON.stringify(viewports).replaceAll('[','{').replaceAll(']','}')} do
 local scale=if v[1]<600 or v[2]<560 then 1 else math.clamp(math.min(v[1]/1280,v[2]/680),1,1.5)
 local m=UiView.menuMetrics({X=v[1]/scale,Y=v[2]/scale})
 print(string.format('%d,%d,%f,%d,%f,%f,%f,%f,%f,%f,%f',v[1],v[2],scale,m.cols,m.cell,m.navWidth,m.navHeight,m.x,m.y,m.width,m.height))
end`;
const file=path.join(os.tmpdir(),'climbing-ui-v3-layout.luau');fs.writeFileSync(file,harness);
const rows=execFileSync(exe,[file],{encoding:'utf8'}).trim().split(/\r?\n/).map(line=>{
 const [width,height,scale,cols,cell,navWidth,navHeight,x,y,w,h]=line.split(',').map(Number);
 assert(cell*scale>=44&&56*scale>=44,'Area touch troppo piccola');
 assert(y>=8+navHeight+8,'Finestra sopra la barra');
 assert(x>=0&&y>=0&&(x+w)*scale<=width+1&&(y+h)*scale<=height+1,'Finestra fuori schermo');
 return {width,height,scale,cols,cell,navWidth,navHeight,x,y,w,h};
});
const ids=fs.readFileSync('src/shared/UiAssets.luau','utf8');
const jobs=JSON.parse(fs.readFileSync(root+'/manifest.json','utf8'));
assert.equal(jobs.length,50);assert.equal(new Set(jobs.map(j=>j.name)).size,50);
for(const j of jobs){assert(ids.includes(j.name+' = ""'),'ID nuovo mancante: '+j.name);if(j.slice)assert(ids.includes(j.name+' = Rect.new('+j.slice.join(', ')+')'),'Slice errato: '+j.name);}
let labels=0,buttons=0;
function visit(n,p){const children=n.children||[];assert.equal(new Set(children.map(c=>c.name)).size,children.length,'Nomi duplicati: '+p);
 if(['TextButton','TextLabel'].includes(n.className)){
  labels++;assert.equal(n.properties.TextScaled,true,'Testo non adattivo: '+p);
  const limit=children.find(c=>c.className==='UITextSizeConstraint');assert(limit&&limit.properties.MinTextSize>=12&&limit.properties.MaxTextSize>=limit.properties.MinTextSize,'Limiti testo: '+p);
  assert(children.some(c=>c.className==='UIPadding'),'Padding mancante: '+p);
  if(n.className==='TextButton'){buttons++;assert.equal(n.properties.TextWrapped,false,'Pulsante su due righe: '+p);}
 }
 for(const c of children)visit(c,p+'/'+c.name);
}
for(const dir of fs.readdirSync('src/gui'))for(const file of fs.readdirSync('src/gui/'+dir).filter(x=>x.endsWith('.model.json')))visit(JSON.parse(fs.readFileSync('src/gui/'+dir+'/'+file)),dir+'/'+file);
const travel=JSON.parse(fs.readFileSync('src/gui/Teletrasporto/Panel.model.json'));
assert(travel.children.find(c=>c.name==='Destinations').children.some(c=>c.name==='Destination5'),'Dragon Island manca dalla GUI');
const names=[...fs.readFileSync('src/shared/Names.luau','utf8').matchAll(/\w+ = "([^"]+)"/g)].map(m=>m[1]);
const tools=[...fs.readFileSync('src/shared/ClimbConfig.luau','utf8').matchAll(/(?:TOOL|PICKAXE|GRAPPLE|TORCH)_NAME = "([^"]+)"/g)].map(m=>m[1]);
const gear=[...fs.readFileSync('src/shared/Gear.luau','utf8').matchAll(/id = "([^"]+)",\s*name = "([^"]+)",\s*description = "([^"]+)"/g)].map(m=>({id:m[1],name:m[2],description:m[3]}));
const shop=[...fs.readFileSync('src/shared/ShopConfig.luau','utf8').matchAll(/id = "([^"]+)",\s*name = "([^"]+)",\s*description = "([^"]+)",\s*price = (\d+)/g)].map(m=>({id:m[1],name:m[2],description:m[3],price:+m[4]}));
const upgrades=[...fs.readFileSync('src/shared/UpgradeConfig.luau','utf8').matchAll(/id = "([^"]+)",\s*name = "([^"]+)",\s*description = "([^"]+)"/g)].map(m=>({id:m[1],name:m[2],description:m[3]}));
assert(gear.length===9&&tools.length===4&&upgrades.length===7,'Estrazione stringhe reali incompleta');
const data={viewports:rows,names,tools,gear,shop,upgrades,travel:['Base camp','Home','Dragon arena','Muscle Beach','Dragon Island','Base Camp 99'],actions:['Not ready yet','SURE? TAP AGAIN','Sell 999999','Upgrade','Follow']};
fs.writeFileSync(root+'/layout-checks.json',JSON.stringify({labels,buttons,...data},null,2)+'\n');
console.log(`OK: ${labels} testi, ${buttons} pulsanti, 50 asset, 5 destinazioni fisse, 5 risoluzioni. Misure tipografiche: preview-v3.mjs.`);
