import fs from 'node:fs';
const assets=JSON.parse(fs.readFileSync('artifacts/ui-20261010/manifest.json','utf8').replace(/^\uFEFF/,''));
const s=`--!strict
-- Inserire qui gli ID dopo il caricamento dei PNG; gli ID vuoti mantengono il ripiego.
local UiAssets = {}
UiAssets.ids = {
${assets.map(a=>`\t${a.name} = "",`).join('\n')}
}
UiAssets.slices = {
${assets.filter(a=>a.slice).map(a=>`\t${a.name} = Rect.new(${a.slice[0]}, ${a.slice[1]}, ${a.w-a.slice[2]}, ${a.h-a.slice[3]}),`).join('\n')}
}
function UiAssets.get(name: string): string?
 local id = (UiAssets.ids :: {[string]: string})[name]
 return if id and id ~= "" then id else nil
end
return UiAssets
`;
if(fs.existsSync('src/shared/UiAssets.luau'))throw Error('Non sovrascrivere gli ID esistenti');
fs.writeFileSync('src/shared/UiAssets.luau',s);
