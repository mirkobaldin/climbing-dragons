-- Riconoscimento degli scheletri veri (DragonSkeleton.analyze): stampa cosa trova e controlla
-- i casi che MapGen.AnimDraghi sbagliava (collo che finiva in un corno).
local fallimenti = 0
local function check(cond: boolean, msg: string)
	if not cond then
		fallimenti += 1
		print("  ERRORE: " .. msg)
	end
end
local function list(t: { number }): string
	local s = {}
	for _, v in t do table.insert(s, tostring(v)) end
	return table.concat(s, " ")
end
-- atteso (indici delle ossa nel file scheletri.txt, controllati a mano sulle posizioni)
local ATTESO = {
	Drago_Gas = { head = 10, jaw = false, chest = 4 },
	Drago_FulmineNero = { head = 12, jaw = false, chest = 6 },
	Drago_Roccia = { head = 10, jaw = false, chest = 6 },
	Drago_Gelo = { head = 10, jaw = false, chest = 4 },
	Drago_Roccia_Adulto = { head = 10, jaw = 12, chest = 4 },
	Drago_Eclissi_Adulto = { head = 10, jaw = 13, chest = 6 },
}
for _, d in SCHELETRI do
	local sk, err = DragonSkeleton.analyze(d.ossa)
	print(d.nome)
	if not sk then
		check(false, "analisi fallita: " .. tostring(err))
		continue
	end
	local horns = {}
	for _, h in sk.horns do table.insert(horns, "[" .. list(h) .. "]") end
	local snout = {}
	for _, h in sk.snout do table.insert(snout, "[" .. list(h) .. "]") end
	print(string.format("  bacino %d  colonna [%s]  petto %d  collo [%s]  testa %d  mascella [%s]  muso %s  corna %s  coda [%s]",
		sk.hips, list(sk.spine), sk.chest, list(sk.neck), sk.head, list(sk.jaw), table.concat(snout, ""), table.concat(horns, ""), list(sk.tail)))
	for _, l in sk.legs do
		print(string.format("  zampa %s %s: [%s] dita %s", if l.front then "davanti" else "dietro", if l.side > 0 then "dx" else "sx", list(l.chain), tostring(l.toe)))
	end
	for _, w in sk.wings do
		print(string.format("  ala %s: braccio [%s], %d dita", if w.side > 0 then "dx" else "sx", list(w.arm), #w.fingers))
	end
	print(string.format("  avanti %s  altezza %.2f  lunghezza %.2f  avvisi: %s", tostring(sk.fwd), sk.height, sk.length, table.concat(sk.warnings, "; ")))
	local a = ATTESO[d.nome]
	if a then
		check(sk.head == a.head, "testa " .. sk.head .. " invece di " .. a.head)
		check(sk.chest == a.chest, "petto " .. sk.chest .. " invece di " .. a.chest)
		if a.jaw then
			check(sk.jaw[1] == a.jaw, "mascella [" .. list(sk.jaw) .. "] invece di " .. a.jaw)
		else
			check(#sk.jaw == 0, "mascella inventata [" .. list(sk.jaw) .. "]")
		end
	end
	local nf, nb, sides = 0, 0, 0
	for _, l in sk.legs do
		if l.front then nf += 1 else nb += 1 end
		sides += l.side
		-- il piede e' a terra
		check(d.ossa[l.chain[#l.chain]].pos.Y < sk.ground + 0.08 * sk.height, "piede non a terra: osso " .. l.chain[#l.chain])
	end
	check(nf == 2 and nb == 2 and sides == 0, "zampe sbagliate")
	check(#sk.wings == 2 and sk.wings[1].side ~= sk.wings[2].side, "ali sbagliate")
	check(#sk.tail >= 6, "coda corta")
	check(sk.fwd.Z < -0.9, "avanti non e' -Z")
	-- nessun corno dentro il collo
	for _, h in sk.horns do
		for _, b in h do
			for _, c in sk.neck do
				check(b ~= c, "corno " .. b .. " nel collo")
			end
		end
	end
end
print(if fallimenti == 0 then "TUTTO OK" else ("FALLIMENTI: " .. fallimenti))
