--!strict
-- Suoni del gioco (Creator Store, quasi tutti di Pro Sound Effects: licenza Roblox, si possono
-- usare in qualsiasi esperienza). Ogni voce: id, volume, velocita' (tono) e quanto lontano si
-- sente. Per cambiare un suono basta l'id qui: il codice usa solo i nomi (Sfx.play("Fuoco")).
-- Una voce con piu' id ne sceglie uno a caso ogni volta.

export type Sound = { ids: { string }, volume: number, speed: number?, range: number? }

local function s(ids: { number }, volume: number, speed: number?, range: number?): Sound
	local list = {}
	for _, id in ids do
		table.insert(list, "rbxassetid://" .. id)
	end
	return { ids = list, volume = volume, speed = speed, range = range }
end

local SoundConfig = {}

SoundConfig.SOUNDS = {
	-- colpi dei draghi: partenza dalla bocca
	SoffioFuoco = s({ 9114446852, 9114444008 }, 0.7, 1, 140), -- Fire Whoosh 15 / 3
	SoffioGelo = s({ 9114446852 }, 0.45, 1.6, 120), -- lo stesso soffio, piu' acuto e freddo
	SoffioGas = s({ 9114446852 }, 0.55, 0.55, 110), -- piu' lento: sembra un sibilo di gas
	SoffioVento = s({ 9120722193 }, 0.45, 1.5, 120), -- Whoosh Giant Swish (roccia, ossa, stelle)
	SoffioOmbra = s({ 9120722193 }, 0.5, 0.8, 120),
	-- impatti
	Esplosione = s({ 9114360785, 9114360994 }, 0.9, 1, 220), -- Explosion Impacts (brevi e sordi)
	ScoppioFuoco = s({ 9114444008 }, 0.6, 0.75, 160),
	Ghiaccio = s({ 9114855870, 9114856215 }, 0.7, 1.05, 160), -- Ice Block Shatter
	Fulmine = s({ 9116277954, 9116276946 }, 0.85, 1, 260), -- Lightning Flashes Quick Electrical
	Roccia = s({ 9125869107, 9125869141 }, 0.8, 0.9, 180), -- Rock Cracks Impact Debris
	Ossa = s({ 9113542694 }, 0.8, 1, 150), -- Bone Cracks
	Stelle = s({ 9116276946 }, 0.5, 1.6, 180), -- lampo elettrico acuto: scintille cosmiche
	Vetro = s({ 9114031948 }, 0.6, 1.1, 140), -- Debris Glass (cristalli che si rompono)
	-- cristalli della mappa (piano, si sentono solo da vicino)
	CristalloScarica = s({ 9116277954 }, 0.18, 1.3, 60),
	CristalloGelo = s({ 9114858583 }, 0.12, 1.2, 45), -- Ice Crackle
	-- draghi
	Ruggito = s({ 9113980319 }, 0.6, 1.25, 200), -- Creature Mix Roar (piu' acuto: drago giovane)
	-- piccozza lanciata
	Lancio = s({ 9120724662 }, 0.4, 1.8, 90),
}

return SoundConfig
