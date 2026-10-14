// Tavole locali: vera suddivisione in nove parti, testo separato dai PNG.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
const root=path.dirname(fileURLToPath(import.meta.url));
const jobs=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8').replace(/^\uFEFF/,''));
const versions=path.join(process.env.LOCALAPPDATA,'Roblox/Versions');
const font=fs.readdirSync(versions).map(v=>path.join(versions,v,'content/fonts/Montserrat-Black.ttf')).find(f=>fs.existsSync(f));
if(!font)throw Error('Font locale Montserrat-Black mancante: equivalente Roblox di GothamBlack.');
const html=`<!doctype html><html lang="it"><meta charset="utf-8"><title>Climbing & Dragons — UI v2</title>
<style>@font-face{font-family:GameBlack;src:url('${pathToFileURL(font).href}')}*{box-sizing:border-box}body{margin:0;background:#0c1420;color:#f2e7cf;font:16px Arial}header{padding:24px;position:sticky;top:0;background:#0c1420;z-index:2}h1{margin:0 0 12px}button,select{padding:9px 18px;background:#24374a;color:white;border:1px solid #a68b57;border-radius:5px;margin-right:8px;cursor:pointer}canvas{display:block}#interactive{display:flex;gap:16px;flex-wrap:wrap;padding:24px}#interactive canvas{cursor:pointer}p{max-width:1000px;line-height:1.5}#board{max-width:100%;height:auto}</style>
<header><h1>Climbing & Dragons · UI v2</h1><p>24 asset richiesti + 2 livelli separati per colorare le rune del piedistallo. Anteprima locale; le scritte sono sovrapposte e non fanno parte dei PNG. Passa sui pulsanti e tieni premuto per confrontare gli stati.</p>
<button onclick="document.querySelector('#board').style.maxWidth='none'">Pixel reali</button><button onclick="document.querySelector('#board').style.maxWidth='100%'">Adatta alla finestra</button><a href="index.md" style="color:#f1d59d">Specifiche per il collegamento</a></header><div id="interactive"></div><canvas id="board"></canvas>
<script>window.V2_JOBS=${JSON.stringify(jobs)};</script><script src="preview.js"></script></html>`;
fs.writeFileSync(path.join(root,'preview.html'),html);
const profile=path.join(root,'.preview-cache');fs.mkdirSync(profile,{recursive:true});
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--remote-debugging-port=0',`--user-data-dir=${profile}`,'--allow-file-access-from-files','--no-first-run','--disable-background-networking','--disable-extensions','about:blank'],{windowsHide:true,stdio:['ignore','ignore','pipe']});
let ws;
try{
 const endpoint=await new Promise((resolve,reject)=>{let log='';const timer=setTimeout(()=>reject(Error('Avvio Chrome scaduto')),20000);chrome.stderr.on('data',b=>{log+=b;const m=log.match(/DevTools listening on (ws:\/\/[^\s]+)/);if(m){clearTimeout(timer);resolve(m[1]);}});chrome.on('error',reject);});
 ws=new WebSocket(endpoint);await new Promise((res,rej)=>{ws.onopen=res;ws.onerror=rej;});
 let counter=0;const pending=new Map();ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id&&pending.has(m.id)){const {resolve,reject}=pending.get(m.id);pending.delete(m.id);m.error?reject(Error(m.error.message)):resolve(m.result);}};
 const call=(method,params={},sessionId)=>new Promise((resolve,reject)=>{const id=++counter;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}));});
 const {targetId}=await call('Target.createTarget',{url:pathToFileURL(path.join(root,'preview.html')).href});
 const {sessionId}=await call('Target.attachToTarget',{targetId,flatten:true});
 let ready=false;for(let i=0;i<80;i++){
   const r=await call('Runtime.evaluate',{expression:'({ready:window.previewReady,error:window.previewError})',returnByValue:true},sessionId);
   if(r.result.value?.error)throw Error(r.result.value.error);
   if(r.result.value?.ready){ready=true;break;}await new Promise(r=>setTimeout(r,250));
 }
 if(!ready)throw Error('Anteprima non completata.');
 fs.mkdirSync(path.join(root,'review'),{recursive:true});
 for(const [key,dest] of [['board','anteprima.png'],['mobile','review/telefono-50.png'],['overview','review/panoramica.png'],['cards','review/cornici.png']]){
   const r=await call('Runtime.evaluate',{expression:`window.previewCanvases.${key}.toDataURL('image/png')`,returnByValue:true},sessionId);
   if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));
   fs.writeFileSync(path.join(root,dest),Buffer.from(r.result.value.split(',')[1],'base64'));
 }
 const stats=await call('Runtime.evaluate',{expression:'window.previewStats',returnByValue:true},sessionId);
 fs.writeFileSync(path.join(root,'review/preview-checks.json'),JSON.stringify(stats.result.value,null,2)+'\n');
 console.log(JSON.stringify(stats.result.value));
}finally{if(ws)ws.close();chrome.kill();}
