// Serve due cartelle in locale per il caricamento da Studio: /repo/... e /json/...
const http = require("http"), fs = require("fs"), path = require("path")
const [repo, json] = process.argv.slice(2)
http.createServer((q, r) => {
	const url = decodeURIComponent(q.url.split("?")[0])
	const root = url.startsWith("/repo/") ? repo : url.startsWith("/json/") ? json : null
	const f = root && path.join(root, url.slice(6))
	if (f && fs.existsSync(f) && fs.statSync(f).isFile()) {
		r.writeHead(200)
		fs.createReadStream(f).pipe(r)
	} else {
		r.writeHead(404)
		r.end()
	}
}).listen(8766, "127.0.0.1", () => console.log("ok"))
