// Verifica i modelli e valuta con Luau le funzioni responsive effettive dei controller.
// Non sostituisce Play o il Device Emulator di Studio.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
const exe=process.argv[2];
assert(exe,'Uso: node tools/ui/check-ui.mjs percorso/luau.exe');
const models={};
for(const name of fs.readdirSync('src/gui')){
 const dir=path.join('src/gui',name), meta=JSON.parse(fs.readFileSync(path.join(dir,'init.meta.json')));
 assert.equal(meta.className,'ScreenGui');assert.equal(meta.properties.ResetOnSpawn,false);
 models[name]={name,className:'ScreenGui',properties:meta.properties,children:fs.readdirSync(dir).filter(f=>f.endsWith('.model.json')).map(f=>({...JSON.parse(fs.readFileSync(path.join(dir,f))),name:f.replace('.model.json','')}))};
}
const manifest=JSON.parse(fs.readFileSync('artifacts/ui-20261010/manifest.json','utf8').replace(/^\uFEFF/,''));
const ids=fs.readFileSync('src/shared/UiAssets.luau','utf8');
for(const a of manifest){
 assert(ids.includes(`${a.name} = ""`),`ID iniziale non vuoto o mancante: ${a.name}`);
 if(a.slice)assert(ids.includes(`${a.name} = Rect.new(${a.slice[0]}, ${a.slice[1]}, ${a.w-a.slice[2]}, ${a.h-a.slice[3]})`),`Slice diverso dall'indice: ${a.name}`);
}
function validate(n,p=''){
 const names=new Set();for(const c of n.children||[]){assert(!names.has(c.name),`Nome duplicato: ${p}/${c.name}`);names.add(c.name);validate(c,p+'/'+c.name);}
 for(const prop of ['Position','Size'])if(n.properties?.[prop])assert(n.properties[prop].UDim2.every(d=>d[1]===0),`Offset statico: ${p}.${prop}`);
 if(n.className==='TextButton'||n.className==='ImageButton'){
  const limit=n.children.find(c=>c.className==='UISizeConstraint');assert(limit,`Minimo touch mancante: ${p}`);
  assert(limit.properties.MinSize.Vector2.every(v=>v>=44),`Touch inferiore a 44: ${p}`);
 }
 const asset=n.properties?.Attributes?.UiAsset?.String;
 if(asset)assert(manifest.some(a=>a.name===asset),`Asset inesistente: ${asset}`);
}
Object.values(models).forEach(m=>validate(m,m.name));
const q=s=>'[====['+s+']====]';
let luau=`
local Enum = setmetatable({}, {__index=function(t,k) local v=setmetatable({}, {__index=function(_,n) return n end});rawset(t,k,v);return v end})
local Vector2 = {new=function(x,y) return {X=x,Y=y} end}
local Color3 = {new=function(r,g,b) return {R=r,G=g,B=b} end}
local UDim = {new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2 = {new=function(x,xo,y,yo) return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}} end}
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local Instance = {}
Instance.new=function(class)
 local props={ClassName=class,Size=UDim2.fromScale(1,1),Position=UDim2.fromScale(0,0),AnchorPoint=Vector2.new(0,0)}
 local kids={}
 local obj
 obj=setmetatable({}, {__index=function(_,k)
  if k=="SetAttribute" then return function() end end
  if k=="IsA" then return function(_,c) return c==class or c=='GuiButton' and class=='TextButton' end end
  if k=="GetChildren" then return function() return kids end end
  if k=="FindFirstChild" then return function(_,n) for _,c in kids do if c.Name==n then return c end end end end
  if props[k]~=nil then return props[k] end
  for _,c in kids do if c.Name==k then return c end end end,
 __newindex=function(_,k,v) props[k]=v;if k=="Parent" and v then table.insert(v:GetChildren(),obj) end end})
 return obj
end
local factory=assert(loadstring(${q(fs.readFileSync('src/shared/UiFallback.luau','utf8'))}))
setfenv(factory,setmetatable({Enum=Enum,Vector2=Vector2,Color3=Color3,UDim=UDim,UDim2=UDim2,Instance=Instance},{__index=getfenv()}))
local make=factory()
local function dump(root, prefix)
 for _,c in root:GetChildren() do
  if c.ClassName~="Folder" and not string.find(c.ClassName,"UI",1,true) then
   print("BOX|"..prefix.."/"..c.Name.."|"..c.Position.X.Scale.."|"..c.Position.Y.Scale.."|"..c.Size.X.Scale.."|"..c.Size.Y.Scale)
   dump(c,prefix.."/"..c.Name)
  end
 end
end
for _,v in {{1920,1080},{1366,768},{844,390},{390,844}} do
 local vp=Vector2.new(v[1],v[2]-36)
 print("VIEW|"..v[1].."|"..v[2])
`;
for(const [file,screen,bindings] of [
 ['MainMenu','MainMenu','local column,window=gui.Column,gui.Window;local content=window.Content'],
 ['HUD','ClimbHUD','local me,coins,info,pet,quest,noticePanel,hint=gui.Player,gui.Coins,gui.Weather,gui.Pet,gui.Quest,gui.Notice,gui.Hint'],
 ['Combat','CombatHUD','local spBtn,timer,eventLabel=gui.Speciale,gui.Timer,gui.Event'],
 ['TeleportMenu','Teletrasporto','local panel=gui.Panel'],
]){
 const source=fs.readFileSync(`src/client/${file}.luau`,'utf8');
 const match=source.match(/Ui\.viewportChanged\(function\(vp\)([\s\S]*?)\n[ \t]*end\)/);
 assert(match,`Funzione responsive non trovata: ${file}`);
 luau+=`do\nlocal gui=make("${screen}")\n${bindings}\n${match[1]}\ndump(gui,"${screen}")\nend\n`;
}
const mobile=fs.readFileSync('src/client/MobileControls.luau','utf8');
const refresh=mobile.match(/local function refresh\(\)([\s\S]*?)\n\tend\n\t--/);
assert(refresh,'Controllo touch non trovato');
luau+=`do
 local gui=make("MobileControls")
 local actions=gui.Actions
 local Config={TOOL_NAME="Axe",GRAPPLE_NAME="Hook",PICKAXE_NAME="Pickaxe"}
 local ClientState={climbing=false,dragonMode=false}
 local Climbing={wallInReach=function() return true end}
 local player={Character={FindFirstChildOfClass=function() return {Name="Axe"} end,FindFirstChild=function() return {FindFirstChild=function() return {} end} end}}
 local last=""
 local function refresh() ${refresh[1]} end
 refresh()
 dump(gui,"MobileControls")
end
`;
luau+='end\nprint("OK: funzioni responsive eseguite su quattro viewport")\n';
const temp=path.join(os.tmpdir(),'climbing-ui-layout-check.luau');fs.writeFileSync(temp,luau);
const output=execFileSync(exe,[temp],{encoding:'utf8'});
let view, computed={};
for(const line of output.split(/\r?\n/)){
 const a=line.split('|');if(a[0]==='VIEW'){view=a.slice(1).join('x');computed[view]={};}
 if(a[0]==='BOX')computed[view][a[1]]=a.slice(2).map(Number);
}
const reports=[];
for(const [viewport,boxes] of Object.entries(computed)){
 const [W,H]=viewport.split('x').map(Number);
 const rects={};
 function walk(n,parent,p){
  const dims=boxes[p]||[...(n.properties.Position?.UDim2||[[0,0],[0,0]]).map(v=>v[0]),...(n.properties.Size?.UDim2||[[1,0],[1,0]]).map(v=>v[0])];
  let [x,y,w,h]=dims;w*=parent.w;h*=parent.h;
  const limit=n.children?.find(c=>c.className==='UISizeConstraint')?.properties;
  if(limit){const min=limit.MinSize?.Vector2||[0,0],max=limit.MaxSize?.Vector2||[10000,10000];w=Math.max(min[0],Math.min(max[0],w));h=Math.max(min[1],Math.min(max[1],h));}
  const aspect=n.children?.find(c=>c.className==='UIAspectRatioConstraint')?.properties.AspectRatio;
  if(aspect){h=Math.min(h,w/aspect);w=h*aspect;}
  const anchor=n.properties.AnchorPoint?.Vector2||[0,0];
  const r={x:parent.x+x*parent.w-w*anchor[0],y:parent.y+y*parent.h-h*anchor[1],w,h};rects[p]=r;
  if(n.className==='TextButton')assert(w>=43.99&&h>=43.99,`${viewport}: bersaglio troppo piccolo ${p}`);
  if(n.name==='Templates')return;
  for(const c of n.children||[])if(['Frame','TextLabel','TextButton','ImageLabel','ScrollingFrame'].includes(c.className))walk(c,r,p+'/'+c.name);
 }
 for(const m of Object.values(models))for(const c of m.children)if(c.className!=='Folder')walk(c,{x:0,y:m.properties.IgnoreGuiInset?0:36,w:W,h:m.properties.IgnoreGuiInset?H:H-36},m.name+'/'+c.name);
 for(const name of ['MainMenu/Window','ClimbHUD/Player','ClimbHUD/Quest','ClimbHUD/Weather','Teletrasporto/Panel','DeathScreen/Panel']){
  const r=rects[name];assert(r.x>=-.1&&r.y>=-.1&&r.x+r.w<=W+.1&&r.y+r.h<=H+.1,`${viewport}: fuori schermo ${name}`);
 }
 // Aree conservative di 160x160 px nei due angoli inferiori per i controlli Roblox.
 if(W<=844){
  const reserved=[{x:0,y:H-160,w:160,h:160},{x:W-160,y:H-160,w:160,h:160}];
  const overlap=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
  for(const name of ['MainMenu/Column','CombatHUD/Speciale',...['Run','Climb','Release','Throw'].map(n=>'MobileControls/Actions/'+n)]){
   const r=rects[name];assert(!reserved.some(b=>overlap(r,b)),`${viewport}: ${name} copre joystick/salto`);
  }
 }
 reports.push({viewport,rects});
}
fs.mkdirSync('artifacts/ui-startergui-review',{recursive:true});
fs.writeFileSync('artifacts/ui-startergui-review/layout-check.json',JSON.stringify({note:'Simulazione geometrica locale, non un test Play in Studio',assets:manifest.length,reports},null,2)+'\n');
console.log(`OK: ${manifest.length} asset, ${Object.keys(models).length} ScreenGui, quattro viewport, target touch >=44 px, finestra e pannelli nello schermo.`);
