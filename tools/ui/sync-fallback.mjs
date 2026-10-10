// I JSON di StarterGui sono la fonte: questo comando aggiorna soltanto il ripiego Luau.
import fs from 'node:fs';
import path from 'node:path';
const enums={Font:'Font',TextXAlignment:'TextXAlignment',TextYAlignment:'TextYAlignment',ScaleType:'ScaleType',AutomaticSize:'AutomaticSize',AutomaticCanvasSize:'AutomaticSize',ScrollingDirection:'ScrollingDirection',SortOrder:'SortOrder',FillDirection:'FillDirection',HorizontalAlignment:'HorizontalAlignment',VerticalAlignment:'VerticalAlignment',ZIndexBehavior:'ZIndexBehavior'};
function value(v,key=''){
 if(enums[key])return `Enum.${enums[key]}.${v}`;
 if(v && typeof v==='object' && !Array.isArray(v)){
  const [t,d]=Object.entries(v)[0];
  if(t==='UDim2')return `UDim2.new(${d.flat().join(', ')})`;
  if(['Vector2','Color3','UDim'].includes(t))return `${t}.new(${d.join(', ')})`;
  if(['String','Bool','Float64'].includes(t))return value(d);
 }
 return JSON.stringify(v);
}
function serialize(n){
 const props=Object.entries(n.properties||{}).filter(([k])=>k!=='Attributes').map(([k,v])=>`[${JSON.stringify(k)}] = ${value(v,k)}`).join(',\n');
 const attrs=Object.entries(n.properties?.Attributes||{}).map(([k,v])=>`[${JSON.stringify(k)}] = ${value(v)}`).join(', ');
 return `{ name = ${JSON.stringify(n.name)}, class = ${JSON.stringify(n.className)}, properties = {${props}}, attributes = {${attrs}}, children = {${(n.children||[]).map(serialize).join(',\n')}} }`;
}
const screens=fs.readdirSync('src/gui',{withFileTypes:true}).filter(d=>d.isDirectory()).map(d=>{
 const dir=path.join('src/gui',d.name), meta=JSON.parse(fs.readFileSync(path.join(dir,'init.meta.json')));
 return {name:d.name,className:meta.className,properties:meta.properties,children:fs.readdirSync(dir).filter(n=>n.endsWith('.model.json')).map(n=>JSON.parse(fs.readFileSync(path.join(dir,n))))};
});
const result=`--!strict
-- Generato da tools/ui/sync-fallback.mjs: modificare i modelli in src/gui.
-- Usato solo se il place non contiene le schermate StarterGui.
local specs: {[string]: any} = {
${screens.map(s=>`[${JSON.stringify(s.name)}] = ${serialize(s)}`).join(',\n')}
}
local function make(spec: any): Instance
 local instance: any = Instance.new(spec.class)
 instance.Name = spec.name
 for key, value in spec.properties do instance[key] = value end
 for key, value in spec.attributes do instance:SetAttribute(key, value) end
 for _, child in spec.children do make(child).Parent = instance end
 return instance
end
return function(name: string): ScreenGui
 assert(specs[name], "Schermata UI sconosciuta: " .. name)
 return make(specs[name]) :: ScreenGui
end
`;
const dest='src/shared/UiFallback.luau';
if(process.argv.includes('--check')){if(fs.readFileSync(dest,'utf8')!==result)throw Error('Ripiego UI da rigenerare');}
else fs.writeFileSync(dest,result);
