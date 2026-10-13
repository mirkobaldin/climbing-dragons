--!strict
-- Le 66 mesh VFX di Codex (ReplicatedStorage.VFXLib.Mesh, VFX_01..VFX_66) negli attacchi:
--   MeshFX.charge(el, bocca, dir)       carica alla bocca del drago
--   MeshFX.rider(el, proiettile, tempo) la forma del colpo che segue il proiettile
--   MeshFX.impact(el, punto, dir)       impatto / taglio sul bersaglio
--   MeshFX.special(el, punto, raggio)   attacco speciale (tasto Z) attorno al giocatore
--   MeshFX.monster(nemico, piedi, dir, scala)   artigli e pugno dello yeti, crepe del golem
--   MeshFX.flyer(modello, gesto)        morso, soffio e ruggito dei draghi volanti
-- Assi (gia' convertiti da Blender): le mesh "avanti Y" di Blender guardano verso -Z (come
-- LookVector), quelle "lungo Z" verso +Y, quelle "lungo X" verso +X. Se una mesh manca nel
-- place le funzioni restituiscono false e restano gli effetti di prima.

local VFXKit = require(script.Parent.VFXKit)
local DragonConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DragonConfig"))

local MeshFX = {}

-- da asse della mesh a LookVector
local FWD_Z = CFrame.identity
local FWD_Y = CFrame.Angles(-math.pi / 2, 0, 0)
local FWD_X = CFrame.Angles(0, math.pi / 2, 0)

type Set = {
	charge: string,
	shot: string,
	shotAxis: CFrame,
	shotSpin: Vector3, -- asse locale su cui gira in volo
	shotSize: number,
	ground: string, -- a terra sotto l'impatto (piatta, Y = normale)
	face: string?, -- taglio o morso davanti al bersaglio (piatto in XY, guarda chi colpisce)
	rise: string?, -- cresce da terra all'impatto
	special: string, -- grande, attorno al giocatore
	special2: string?,
}

local SETS: { [string]: Set } = {
	Roccia = {
		charge = "VFX_37_RocciaCuoreFratturato",
		shot = "VFX_40_RocciaAriete", shotAxis = FWD_Y, shotSpin = Vector3.yAxis, shotSize = 3.6,
		ground = "VFX_39_RocciaFagliaRadiale", rise = "VFX_38_RocciaArtiglioTellurico",
		special = "VFX_39_RocciaFagliaRadiale", special2 = "VFX_38_RocciaArtiglioTellurico",
	},
	Gelo = {
		charge = "VFX_42_GeloSigilloEsagonale",
		shot = "VFX_41_GeloLanciaAurora", shotAxis = FWD_Y, shotSpin = Vector3.yAxis, shotSize = 4.2,
		ground = "VFX_42_GeloSigilloEsagonale", face = "VFX_44_GeloAlaTagliente", rise = "VFX_43_GeloLotoGlaciale",
		special = "VFX_42_GeloSigilloEsagonale", special2 = "VFX_43_GeloLotoGlaciale",
	},
	Cosmico = {
		charge = "VFX_45_CosmicoAstrolabio",
		shot = "VFX_47_CosmicoCometaAstrale", shotAxis = FWD_Z, shotSpin = Vector3.zAxis, shotSize = 4.6,
		ground = "VFX_46_CosmicoDiscoAccrescimento", rise = "VFX_48_CosmicoStellaDimensionale",
		special = "VFX_48_CosmicoStellaDimensionale", special2 = "VFX_45_CosmicoAstrolabio",
	},
	Tempesta = {
		charge = "VFX_50_TempestaCicloneSpirale",
		shot = "VFX_52_TempestaOcchioUragano", shotAxis = FWD_Z, shotSpin = Vector3.zAxis, shotSize = 3.6,
		ground = "VFX_51_TempestaRasoioEolico", face = "VFX_49_TempestaAliBurrasca",
		special = "VFX_50_TempestaCicloneSpirale", special2 = "VFX_51_TempestaRasoioEolico",
	},
	Eclissi = {
		charge = "VFX_53_EclissiSoleNero",
		shot = "VFX_56_EclissiSerpenteSolare", shotAxis = FWD_Z, shotSpin = Vector3.zAxis, shotSize = 5,
		ground = "VFX_55_EclissiNovaOscura", face = "VFX_54_EclissiLamaApocalisse",
		special = "VFX_55_EclissiNovaOscura", special2 = "VFX_53_EclissiSoleNero",
	},
	Fulmine = {
		charge = "VFX_59_FulmineSferaTesla",
		shot = "VFX_57_FulmineLanciaRamificata", shotAxis = FWD_X, shotSpin = Vector3.xAxis, shotSize = 5,
		ground = "VFX_60_FulmineReteParalizzante", rise = "VFX_58_FulmineArtiglioTuono",
		special = "VFX_60_FulmineReteParalizzante", special2 = "VFX_59_FulmineSferaTesla",
	},
	Ossa = {
		charge = "VFX_63_OssaSpiraleVertebre",
		shot = "VFX_25_OssaSpina", shotAxis = FWD_Z, shotSpin = Vector3.zAxis, shotSize = 4.2,
		ground = "VFX_26_OssaMorso", face = "VFX_61_OssaFauciDraconiche", rise = "VFX_62_OssaArtiglioScheletrico",
		special = "VFX_63_OssaSpiraleVertebre", special2 = "VFX_61_OssaFauciDraconiche",
	},
	Gas = {
		charge = "VFX_64_GasLotoMiasma",
		shot = "VFX_65_GasBollaVorticosa", shotAxis = FWD_Z, shotSpin = Vector3.yAxis, shotSize = 3.8,
		ground = "VFX_64_GasLotoMiasma", rise = "VFX_27_GasNube",
		special = "VFX_66_GasSoffioSerpentino", special2 = "VFX_64_GasLotoMiasma",
	},
}

-- colori per le mesh bianche del primo kit (le elementali hanno la palette)
local TINT: { [string]: Color3 } = {
	Ossa = Color3.fromRGB(235, 228, 205),
	Gas = Color3.fromRGB(240, 80, 220),
}

-- Tutte le mesh passano da qui: piu' grandi, un po' piu' lunghe e con l'alone del colore
-- dell'elemento (prima erano piccole e scure: di notte l'Eclissi quasi non si vedeva)
local boost, glowNow = 1, nil :: Color3?
local function play(name: string, cf: CFrame, o: VFXKit.PlayOptions): MeshPart?
	if o.from then
		o.from *= boost
	end
	if o.to then
		o.to *= boost
	end
	if not o.follow then
		o.time = (o.time or 0.5) * 1.25
	end
	o.glow = o.glow or glowNow
	if o.light and glowNow and not o.color then
		o.color = glowNow
	end
	return VFXKit.play(name, cf, o)
end
local function use(element: string?, k: number)
	boost = k
	local e = element and DragonConfig.element(element)
	glowNow = if e then e.glow else nil
end

local function look(at: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 0.01 then
		return CFrame.new(at)
	end
	if math.abs(dir.Unit.Y) > 0.98 then
		return CFrame.lookAt(at, at + dir, Vector3.xAxis)
	end
	return CFrame.lookAt(at, at + dir)
end

-- CFrame a terra sotto "at" (Y lungo la normale), o piatta nel punto se non c'e' niente sotto.
-- Conta anche le parti (pavimento dell'arena, ponti), non i personaggi, i draghi e i nemici.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(at: Vector3, depth: number?): (CFrame, boolean)
	local skip: { Instance } = {}
	for _, name in { "Pets", "Nemici", "Volanti" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	for _, pl in game:GetService("Players"):GetPlayers() do
		if pl.Character then
			table.insert(skip, pl.Character)
		end
	end
	groundParams.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -((depth or 8) + 2), 0), groundParams)
	if not hit then
		return CFrame.new(at), false
	end
	local n = hit.Normal
	local side = if math.abs(n.Y) > 0.99 then Vector3.xAxis else n:Cross(Vector3.yAxis).Unit
	return CFrame.fromMatrix(hit.Position + n * 0.15, side, n), true
end

local function spinY(): CFrame
	return CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

function MeshFX.has(element: string?): boolean
	return element ~= nil and SETS[element] ~= nil
end

------------------------------------------------------------------------------------------
-- Draghi del giocatore (colpi, addestramento, palle dei draghi volanti)

function MeshFX.charge(element: string?, at: Vector3, dir: Vector3): boolean
	use(element, 1.5)
	local s = element and SETS[element]
	if not s then
		return false
	end
	local cf = look(at, dir)
	-- le piatte (sigillo, loto) guardano il bersaglio, le altre girano su se stesse
	if s.charge == "VFX_42_GeloSigilloEsagonale" or s.charge == "VFX_64_GasLotoMiasma" then
		cf *= CFrame.Angles(math.pi / 2, 0, 0)
	end
	return play(s.charge, cf, { from = 1.2, to = 4.2, time = 0.42, spin = 0.6, hold = 0.35, ease = "back", color = TINT[element :: string], light = 12 }) ~= nil
end

-- la forma del colpo che segue il proiettile p per "time" secondi; true se c'e'
function MeshFX.rider(element: string?, p: BasePart, time: number): boolean
	use(element, 1.35)
	local s = element and SETS[element]
	if not s then
		return false
	end
	local axis = s.shotAxis
	local size = s.shotSize
	return play(s.shot, p.CFrame * axis, {
		from = size * 0.6,
		to = size,
		time = time + 0.05,
		spin = time * 2.5,
		axis = s.shotSpin,
		fadeIn = 0.04,
		hold = 0.9,
		color = TINT[element :: string],
		follow = function(): CFrame?
			return if p.Parent then p.CFrame * axis else nil
		end,
	}) ~= nil
end

function MeshFX.impact(element: string?, at: Vector3, dir: Vector3, scale: number?): boolean
	use(element, 1.6)
	local s = element and SETS[element]
	if not s then
		return false
	end
	local k = scale or 1
	local tint = TINT[element :: string]
	local g, onGround = groundAt(at, 7)
	local flat = if onGround then g else look(at, dir) * CFrame.Angles(math.pi / 2, 0, 0)
	play(s.ground, flat * CFrame.new(0, 0.2, 0) * spinY(), { from = 3 * k, to = 12 * k, time = 0.75, spin = 0.2, hold = 0.45, color = tint })
	if s.face then
		-- taglio o morso davanti al bersaglio, rivolto verso chi lo colpisce
		local fcf = look(at - dir.Unit * 1.5, -dir) * CFrame.Angles(0, 0, (math.random() - 0.5) * 1.2)
		local squash = if s.face == "VFX_61_OssaFauciDraconiche" then Vector3.new(1, 0.45, 1) else nil
		play(s.face, fcf, { from = 3 * k, to = 8 * k, time = 0.4, hold = 0.4, ease = "back", squash = squash, color = tint, light = 16 })
	end
	if s.rise then
		local rcf = (if onGround then g else CFrame.new(at - Vector3.new(0, 1, 0))) * spinY()
		play(s.rise, rcf, { from = 1 * k, to = 6.5 * k, time = 0.85, hold = 0.55, ease = "back", color = tint })
	end
	return true
end

------------------------------------------------------------------------------------------
-- Attacco speciale: forme grandi attorno al giocatore, grandi quanto l'area del danno

function MeshFX.special(element: string?, at: Vector3, radius: number): boolean
	use(element, 1)
	local s = element and SETS[element]
	if not s then
		return false
	end
	local tint = TINT[element :: string]
	local g = groundAt(at, 10)
	local d = radius * 2
	if s.special == "VFX_50_TempestaCicloneSpirale" or s.special == "VFX_63_OssaSpiraleVertebre" or s.special == "VFX_66_GasSoffioSerpentino" then
		-- colonna che sale e gira attorno al giocatore
		local col = if s.special == "VFX_66_GasSoffioSerpentino" then g * CFrame.Angles(math.pi / 2, 0, 0) else g
		play(s.special, col, { from = radius * 0.3, to = radius * 1.1, time = 1.1, spin = if s.special == "VFX_66_GasSoffioSerpentino" then 0 else 1.2, axis = Vector3.yAxis, hold = 0.55, color = tint })
	else
		play(s.special, g * CFrame.new(0, 0.3, 0) * spinY(), { from = d * 0.2, to = d, time = 0.9, spin = 0.35, hold = 0.5, color = tint, light = 30 })
	end
	if s.special2 then
		local name = s.special2
		local up = g * CFrame.new(0, 3, 0)
		if name == "VFX_53_EclissiSoleNero" or name == "VFX_61_OssaFauciDraconiche" then
			-- disco o fauci in piedi sopra il giocatore, rivolti verso la camera
			local cam = workspace.CurrentCamera.CFrame.Position
			local p = (g * CFrame.new(0, radius * 0.45, 0)).Position
			play(name, look(p, cam - p), { from = 2, to = radius * 0.8, time = 0.8, hold = 0.45, ease = "back", squash = if name == "VFX_61_OssaFauciDraconiche" then Vector3.new(1, 0.4, 1) else nil, color = tint, light = 24 })
		elseif name == "VFX_45_CosmicoAstrolabio" or name == "VFX_59_FulmineSferaTesla" then
			play(name, up * CFrame.new(0, radius * 0.25, 0), { from = 2, to = radius * 0.6, time = 0.9, spin = 1.5, axis = Vector3.new(1, 1, 0).Unit, hold = 0.4, ease = "back", color = tint, light = 24 })
		else
			play(name, g * spinY(), { from = radius * 0.2, to = radius * 0.75, time = 1, spin = 0.25, hold = 0.55, ease = "back", color = tint })
		end
	end
	return true
end

------------------------------------------------------------------------------------------
-- Mostri: yeti (artigli + pugno), golem di ghiaccio (crepe + stalagmiti); i boss in grande

local ICE = Color3.fromRGB(190, 235, 255)

function MeshFX.monster(kind: string, feet: Vector3, dir: Vector3, scale: number): boolean
	use(nil, 1.25)
	glowNow = Color3.fromRGB(150, 220, 255)
	local g = groundAt(feet + Vector3.new(0, 2, 0), 8)
	local flatDir = Vector3.new(dir.X, 0, dir.Z)
	flatDir = if flatDir.Magnitude > 0.01 then flatDir.Unit else Vector3.zAxis
	local front = feet + flatDir * 3 * scale
	if kind == "Yeti" then
		-- strisciata d'artiglio in piedi davanti, verso chi guarda il colpo
		local claw = look(front + Vector3.new(0, 3 * scale, 0), flatDir) * CFrame.Angles(0, 0, -0.5)
		local ok = play("VFX_29_YetiArtigli", claw, { from = 2 * scale, to = 7 * scale, time = 0.35, hold = 0.35, ease = "back", color = ICE, light = 14 }) ~= nil
		play("VFX_30_YetiPugno", g * spinY(), { from = 2 * scale, to = 8 * scale, time = 0.6, spin = 0.15, hold = 0.4, color = ICE })
		return ok
	end
	-- golem: crepe a terra e una fila di stalagmiti che esce verso il bersaglio
	local ok = play("VFX_31_GolemFrattura", g * CFrame.new(0, 0.15, 0) * spinY(), { from = 4 * scale, to = 12 * scale, time = 0.9, hold = 0.6, color = ICE, material = Enum.Material.Neon }) ~= nil
	local gf = groundAt(front + Vector3.new(0, 2, 0), 8)
	-- la fila di punte sta lungo X: la si gira lungo la direzione del colpo
	local yaw = math.atan2(-flatDir.X, -flatDir.Z) + math.pi / 2
	play("VFX_32_GolemStalagmiti", gf * CFrame.Angles(0, yaw, 0), { from = 1 * scale, to = 8 * scale, time = 0.9, hold = 0.6, ease = "back", color = ICE, transparency = 0.25, light = 14 })
	return ok
end

------------------------------------------------------------------------------------------
-- Draghi volanti (selvatico e Guardiano): morso, soffio, ruggito a terra

function MeshFX.flyer(model: Model, act: string, mouth: Vector3)
	local element = model:GetAttribute("Element") :: string?
	use(element, 1)
	local guardian = model:GetAttribute("Guardian") == true
	local s = element and SETS[element]
	local _, size = model:GetBoundingBox()
	local big = math.max(size.X, size.Y, size.Z)
	local fwd = model:GetPivot().LookVector
	local tint = (element and TINT[element]) or Color3.fromRGB(255, 220, 190)
	if act == "Bite" then
		task.delay(0.3, function()
			if not model.Parent then
				return
			end
			use(element, 1)
			local cf = look(mouth + fwd * big * 0.05, fwd)
			local name = if s and s.face == "VFX_61_OssaFauciDraconiche" then s.face else "VFX_35_MostroMorso"
			play(name, cf, { from = big * 0.12, to = big * 0.3, time = 0.35, hold = 0.35, ease = "back", squash = Vector3.new(1, 0.35, 1), color = tint, light = 20 })
			if not model:GetAttribute("Grounded") then
				-- picchiata: la coda spazza sotto
				local g = groundAt(mouth - Vector3.new(0, 4, 0), 40)
				play("VFX_36_MostroCoda", g * spinY(), { from = big * 0.2, to = big * 0.6, time = 0.5, spin = 0.4, hold = 0.4, color = tint })
			end
		end)
	elseif act == "Breath" then
		-- cono di soffio dalla bocca (Guardiano) o il getto dell'elemento
		local name = if guardian then "VFX_33_GuardianoRespiro" elseif element == "Gas" then "VFX_66_GasSoffioSerpentino" elseif element == "Eclissi" then "VFX_56_EclissiSerpenteSolare" else "VFX_33_GuardianoRespiro"
		local headCF = function(): CFrame?
			if not model.Parent then
				return nil
			end
			return look(mouth, model:GetPivot().LookVector - Vector3.new(0, 0.35, 0))
		end
		play(name, headCF() :: CFrame, { from = big * 0.1, to = big * 0.55, time = 1.4, spin = 0.5, axis = Vector3.zAxis, hold = 0.7, color = tint, follow = headCF })
		if s then
			MeshFX.charge(element, mouth, fwd)
		end
	elseif act == "Roar" and model:GetAttribute("Grounded") then
		local g = groundAt(model:GetPivot().Position, size.Y)
		play("VFX_34_GuardianoOnda", g * CFrame.new(0, 0.3, 0) * spinY(), { from = big * 0.3, to = big * 2, time = 0.9, spin = 0.2, hold = 0.4, color = tint, light = 40 })
	end
end

return MeshFX
