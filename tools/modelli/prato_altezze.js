// Altezze del prato dell'Isola dei Draghi per il Terrain sotto le colline (mapgen/IsolaDraghi,
// pratoTerreno). Legge il JSON di Isola_Prato scritto da esporta_modelli.py (metri, assi Roblox) e
// per ogni punto di una griglia da 8 stud tiene l'altezza piu' alta dei triangoli rivolti in su.
// Uso: node prato_altezze.js <cartella json>/IsolaDraghi  -> prato_altezze.json nella stessa cartella
// Poi in Studio il contenuto va nella StringValue "PratoAltezze" di ServerStorage.CaseCodex.IsolaDraghi.
const fs = require("fs")
const path = require("path")
const dir = process.argv[2]
const d = JSON.parse(fs.readFileSync(path.join(dir, "Isola_Prato.json"), "utf8"))
const ix = JSON.parse(fs.readFileSync(path.join(dir, "index.json"), "utf8"))
const part = ix.parts.find((p) => p.name === "Isola_Prato")
const P = d.p, T = d.t
const STEP = 8 / (5 / 1.7) // 8 stud in metri (scala del gioco 5/1,7)
const minX = Math.floor(part.min[0]) - 1, minZ = Math.floor(part.min[2]) - 1
const nx = Math.ceil((part.max[0] + 1 - minX) / STEP) + 1, nz = Math.ceil((part.max[2] + 1 - minZ) / STEP) + 1
const H = new Float32Array(nx * nz).fill(-1e9)
const v = (i) => [P[3 * i], P[3 * i + 1], P[3 * i + 2]]
for (let k = 0; k < T.length; k += 9) {
	const a = v(T[k]), b = v(T[k + 3]), c = v(T[k + 6])
	const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2], wx = c[0] - a[0], wy = c[1] - a[1], wz = c[2] - a[2]
	const ny = uz * wx - ux * wz
	const len = Math.hypot(uy * wz - uz * wy, ny, ux * wy - uy * wx)
	if (len < 1e-9 || Math.abs(ny) / len < 0.25) continue // pareti: niente
	const det = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
	if (Math.abs(det) < 1e-12) continue
	const x0 = Math.min(a[0], b[0], c[0]), x1 = Math.max(a[0], b[0], c[0])
	const z0 = Math.min(a[2], b[2], c[2]), z1 = Math.max(a[2], b[2], c[2])
	for (let i = Math.ceil((x0 - minX) / STEP); i <= Math.floor((x1 - minX) / STEP); i++) {
		for (let j = Math.ceil((z0 - minZ) / STEP); j <= Math.floor((z1 - minZ) / STEP); j++) {
			const x = minX + i * STEP, z = minZ + j * STEP
			const l1 = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / det
			const l2 = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / det
			const l3 = 1 - l1 - l2
			if (l1 < -1e-6 || l2 < -1e-6 || l3 < -1e-6) continue
			const y = l1 * a[1] + l2 * b[1] + l3 * c[1]
			if (y > H[i * nz + j]) H[i * nz + j] = y
		}
	}
}
const h = Array.from(H, (y) => (y > -1e8 ? Math.round(y * 10) : "")).join(",")
fs.writeFileSync(path.join(dir, "prato_altezze.json"), JSON.stringify({ minX, minZ, step: STEP, nx, nz, h }))
console.log("griglia", nx, "x", nz, "celle con prato", H.filter((y) => y > -1e8).length)
