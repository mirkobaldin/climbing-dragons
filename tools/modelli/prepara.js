// Dopo esporta_modelli.py: per ogni modello aggiunge a index.json le scatole di collisione
// (centro, assi e misure dagli 8 vertici) e scrive textures.json con le texture da caricare
// (una volta per materiale). Uso: node prepara.js <cartella del repo> <cartella dei json>
const fs = require("fs")
const path = require("path")
const [repo, out] = process.argv.slice(2)
const DIRS = {
	Tent: "Tent", Campfire: "Campfire", StoneCabin: "StoneCabin", ModernChalet: "ModernChalet", MegaChalet: "MegaChalet",
	AlpineParaglider: "Gliders/AlpineParaglider", AncientStormWyvern: "Gliders/AncientStormWyvern", DragonWings: "Gliders/DragonWings",
}
// modelli della sessione cloud (cloud/<Nome>): si aggiungono quelli che hanno gia' index.json
const CLOUD = process.env.CLOUD_MODELS ? process.env.CLOUD_MODELS.split(",") : []
for (const m of CLOUD) DIRS[m] = "cloud/" + m
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
const len = (v) => Math.hypot(v[0], v[1], v[2])
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

function box(points) {
	const c = [0, 0, 0]
	for (const p of points) for (let k = 0; k < 3; k++) c[k] += p[k] / points.length
	// dal primo vertice: i tre spigoli sono i vicini a due a due perpendicolari
	const p0 = points[0]
	const edges = points.slice(1).map((p) => sub(p, p0)).filter((e) => len(e) > 1e-4).sort((a, b) => len(a) - len(b))
	const axes = []
	for (const e of edges) {
		if (axes.every((a) => Math.abs(dot(a, e)) / (len(a) * len(e)) < 0.05)) axes.push(e)
		if (axes.length === 3) break
	}
	while (axes.length < 3) axes.push([0, 0.001, 0])
	return { c, axes: axes.map((a) => { const l = len(a); return [a[0] / l, a[1] / l, a[2] / l] }), size: axes.map(len) }
}

const textures = {}
for (const [model, dir] of Object.entries(DIRS)) {
	const file = path.join(out, model, "index.json")
	const ix = JSON.parse(fs.readFileSync(file, "utf8"))
	ix.boxes = []
	for (const col of ix.collision) {
		const d = JSON.parse(fs.readFileSync(path.join(out, model, col.file + ".json"), "utf8"))
		const pts = []
		for (let i = 0; i < d.p.length; i += 3) pts.push([d.p[i], d.p[i + 1], d.p[i + 2]])
		ix.boxes.push({ name: col.name, ...box(pts) })
	}
	fs.writeFileSync(file, JSON.stringify(ix, null, 1))
	const used = new Set(ix.parts.map((p) => p.material))
	for (const mat of ix.materials || []) {
		if (!used.has(mat.name)) continue
		for (const kind of ["BaseColor", "Normal", "Roughness"]) {
			const key = mat.name + "|" + kind
			if (textures[key]) continue
			// prima il percorso scritto in Materials.json (cloud: texture cotte in Textures/, quelle
			// ripetute in ../_Texture/, BaseColor anche .jpg), poi per nome
			if (mat[kind]) {
				const full = path.join(repo, dir, mat[kind])
				if (fs.existsSync(full)) textures[key] = path.relative(repo, full).split(path.sep).join("/")
			}
			for (const ext of [".png", ".jpg"]) {
				const name = mat.name + "_" + kind + ext
				for (const sub of ["Textures", path.basename(dir) + ".fbm"]) {
					const full = path.join(repo, dir, sub, name)
					if (!textures[key] && fs.existsSync(full)) textures[key] = path.relative(repo, full).split(path.sep).join("/")
				}
			}
		}
	}
	console.log(model, ix.parts.length, "parti", ix.boxes.length, "scatole")
}
fs.writeFileSync(path.join(out, "textures.json"), JSON.stringify(textures, null, 1))
console.log("texture", Object.keys(textures).length)
