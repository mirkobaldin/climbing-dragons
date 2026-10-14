// Verifica della consegna e protezione degli asset precedenti; nessuna scrittura nel gioco.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url)),repo=path.resolve(root,'../..');
const read=p=>fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'');
const json=n=>JSON.parse(read(path.join(root,n)));
const manifest=json('manifest.json'),validation=json('validation.json'),preview=json('review/preview-checks.json');
const checks=[];
function check(label,passed){checks.push({label,passed});if(!passed)throw Error(label);}
check('26 PNG previsti: 24 richiesti e 2 livelli opzionali',manifest.length===26&&new Set(manifest.map(j=>j.name)).size===26);
for(const j of manifest){
 const p=fs.readFileSync(path.join(root,j.name+'.png'));
 check(j.name+': PNG RGBA a misura',p.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))&&p.readUInt32BE(16)===j.width&&p.readUInt32BE(20)===j.height&&p[25]===6);
 check(j.name+': verifica pixel',validation.some(r=>r.name===j.name&&r.passed));
}
check('189 combinazioni di stato, misura e sfondo; nessuna scritta tagliata',preview.buttonDraws===189&&preview.clippedLabels.length===0);
const baseline=json('old-assets-baseline.json');
for(const f of baseline){const p=path.isAbsolute(f.Path)?f.Path:path.resolve(repo,f.Path);const hash=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();check('Originale intatto: '+path.basename(p),hash===f.Hash);}
const before=execFileSync('git',['show','main:src/shared/UiAssets.luau'],{cwd:repo,encoding:'utf8'}),after=read(path.join(repo,'src/shared/UiAssets.luau'));
function entries(s,section){const body=s.split(`UiAssets.${section} = {`)[1].split('\n}')[0];return new Map([...body.matchAll(/^\s*(\w+)\s*=\s*(.+),\s*$/gm)].map(m=>[m[1],m[2]]));}
for(const section of ['ids','slices']){
 const a=entries(before,section),b=entries(after,section);
 for(const [k,v]of a)check(`Chiave precedente intatta: ${section}.${k}`,b.get(k)===v);
 for(const [k,v]of b)if(!a.has(k)){check('Solo nuove chiavi v2: '+k,manifest.some(j=>j.name===k));if(section==='ids')check('ID non inventato: '+k,v==='""');}
}
const newIds=entries(after,'ids');for(const j of manifest)check('Chiave registrata: '+j.name,newIds.has(j.name));
const report={passed:true,assetCount:manifest.length,oldFilesVerified:baseline.length,checks:checks.length,minimumWhiteContrast:Math.min(...validation.filter(r=>/^(btn_|tab_)/.test(r.name)).map(r=>r.whiteContrastMin)),robloxUploadComplete:false,studioTested:false};
fs.writeFileSync(path.join(root,'review/delivery-checks.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
