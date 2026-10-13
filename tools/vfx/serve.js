const http=require('http'),fs=require('fs'),path=require('path');
const root=process.argv[2];
http.createServer((q,r)=>{const f=path.join(root,decodeURIComponent(q.url.split('?')[0]));
if(fs.existsSync(f)&&fs.statSync(f).isFile()){r.writeHead(200);fs.createReadStream(f).pipe(r);}else{r.writeHead(404);r.end();}}).listen(8765,'127.0.0.1',()=>console.log('ok'));
