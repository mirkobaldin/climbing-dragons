// Prova la logica di UiView con un adattatore minimo delle istanze, senza simulare il rendering.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const q=s=>'[====['+s+']====]';
const harness=`
local function signal()
 local callbacks={}
 return {Connect=function(_,f) table.insert(callbacks,f);return {Disconnect=function() end} end,
 Fire=function(_,...) for _,f in callbacks do f(...) end end}
end
local Enum=setmetatable({}, {__index=function(t,k) local v=setmetatable({}, {__index=function(_,n) return n end});rawset(t,k,v);return v end})
local Vector2={new=function(x,y) return {X=x,Y=y} end}
local Color3={new=function(r,g,b) return {R=r,G=g,B=b} end,fromRGB=function(r,g,b) return {R=r/255,G=g/255,B=b/255} end}
local Rect={new=function(a,b,c,d) return {a,b,c,d} end}
local UDim={new=function(s,o) return {Scale=s,Offset=o} end}
local UDim2={new=function(x,xo,y,yo) return {X={Scale=x,Offset=xo},Y={Scale=y,Offset=yo}} end}
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local Instance={}
local stores={}
Instance.new=function(class)
 local props={ClassName=class,Name=class,BackgroundTransparency=0,Text='',TextColor3=Color3.new(1,1,1),AbsoluteSize=Vector2.new(128,64)}
 local kids,attrs,events={},{},{}
 local methods={}
 local obj
 methods.IsA=function(_,c) return class==c or c=='Instance' or c=='GuiObject' and table.find({'Frame','TextLabel','TextButton','ImageLabel','ScrollingFrame'},class)~=nil end
 methods.GetChildren=function() return table.clone(kids) end
 methods.GetDescendants=function() local out={};local function visit(p) for _,c in p:GetChildren() do table.insert(out,c);visit(c) end end;visit(obj);return out end
 methods.FindFirstChild=function(_,n) for _,c in kids do if c.Name==n then return c end end;return nil end
 methods.WaitForChild=methods.FindFirstChild
 methods.SetAttribute=function(_,k,v) attrs[k]=v end
 methods.GetAttribute=function(_,k) return attrs[k] end
 methods.GetPropertyChangedSignal=function(_,k) if not events[k] then events[k]=signal() end;return events[k] end
 methods.FindFirstAncestor=function(_,n) local p=props.Parent;while p do if p.Name==n then return p end;p=p.Parent end;return nil end
 methods.Destroy=function() obj.Parent=nil end
 methods.Clone=function()
  local copy=Instance.new(class)
  for k,v in props do if k~='Parent' then copy[k]=v end end
  for k,v in attrs do copy:SetAttribute(k,v) end
  for _,c in kids do c:Clone().Parent=copy end
  return copy
 end
 methods.ChildAdded=signal()
 obj=setmetatable({}, {__index=function(_,k)
  if methods[k] then return methods[k] end
  if props[k]~=nil then return props[k] end
  return methods.FindFirstChild(obj,k)
 end,__newindex=function(_,k,v)
  local old=props[k];props[k]=v
  if k=='Parent' then
   if old then local a=stores[old];local i=table.find(a,obj);if i then table.remove(a,i) end end
   if v then table.insert(stores[v],obj);v.ChildAdded:Fire(obj) end
  end
  if events[k] then events[k]:Fire() end
 end})
 stores[obj]=kids
 return obj
end
local env=setmetatable({Enum=Enum,Vector2=Vector2,Color3=Color3,Rect=Rect,UDim=UDim,UDim2=UDim2,Instance=Instance},{__index=getfenv()})
local function run(source,extra)
 local f=assert(loadstring(source));local e=setmetatable(extra or {},{__index=env});setfenv(f,e);return f()
end
local make=run(${q(fs.readFileSync('src/shared/UiFallback.luau','utf8'))})
local assets=run(${q(fs.readFileSync('src/shared/UiAssets.luau','utf8'))})
local pg=Instance.new('PlayerGui');pg.Name='PlayerGui'
local player=Instance.new('Player');pg.Parent=player
local starter=Instance.new('StarterGui')
local services={Players={LocalPlayer=player},StarterGui=starter,TweenService={Create=function(_,target,_,values) return {Play=function() for k,v in values do target[k]=v end end} end}}
local ui=run(${q(fs.readFileSync('src/shared/UiView.luau','utf8'))},{game={GetService=function(_,n) return services[n] end},script={Parent={WaitForChild=function(_,n) return n end}},require=function(n) return if n=='UiAssets' then assets else make end,TweenInfo={new=function() return {} end}})
local main=make('MainMenu');main.Parent=pg
assert(ui.screen('MainMenu')==main,'La schermata esistente deve essere riutilizzata')
local mobile=ui.screen('MobileControls')
assert(mobile.Parent==pg and mobile.Name=='MobileControls','Ripiego mancante')
assert(ui.screen('MobileControls')==mobile,'Ripiego duplicato')
local late=make('MobileControls');late.Parent=pg
assert(late.Parent==nil,'La copia tardiva di StarterGui deve essere rimossa')
for _,name in {'Caricamento','ClimbHUD','CombatHUD','DeathScreen','Teletrasporto'} do
 local gui=ui.screen(name);assert(gui.Parent==pg and gui.ResetOnSpawn==false)
end
assert(assets.get('icon_coin')==nil and assets.get('inesistente')==nil,'ID vuoti e sconosciuti devono dare nil')
assets.ids.panel_card='rbxassetid://1'
ui.apply(main)
assert(ui.node(main,'Templates/ItemCard'):FindFirstChild('AssetSurface')==nil,'Non applicare immagini ai modelli sorgente')
local card=ui.template('ItemCard',main.Window.Content.Store.List)
assert(card.Visible and card:FindFirstChild('AssetSurface'),'La carta clonata deve avere la propria superficie')
local b=card.Buy
assets.ids.btn_primary_normal='rbxassetid://2'
ui.skin(b,'btn_primary_normal')
b.Text='New caption'
assert(b.AssetCaption.Text=='New caption','La didascalia deve seguire il testo del controller')
ui.skin(b,'btn_primary_normal')
local count=0;for _,c in b:GetChildren() do if c.Name=='AssetSurface' then count+=1 end end
assert(count==1,'Superfici duplicate')
assert(ui.asset(card.Icon,'icon_coin')==false and not card.Icon.Visible,'Ripiego icona vuota errato')
assets.ids.icon_coin='rbxassetid://3'
assert(ui.asset(card.Icon,'icon_coin') and card.Icon.Visible,'ID icona non applicato')
assert(main.Window.Visible==false,'Le finestre partono chiuse')
ui.open(main.Window)
assert(main.Window.Visible and main.Window.OpeningScale.Scale==1,'Apertura finestra non completata')
print('OK: riuso StarterGui, ripiego, replica tardiva, 7 schermate, ID vuoti, template, slice, didascalie e apertura')
`;
const file=path.join(os.tmpdir(),'climbing-ui-view-test.luau');fs.writeFileSync(file,harness);
process.stdout.write(execFileSync(process.argv[2],[file],{encoding:'utf8'}));
