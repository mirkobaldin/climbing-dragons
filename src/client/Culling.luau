--!strict
-- Spegne in locale luci e particelle della mappa lontane dalla camera e le riaccende quando ti
-- avvicini. Nella mappa ce ne sono piu' di 600 luci e 400 emitter (borghi, zone a tema,
-- foresta, villaggio, ghiacciaio): accese tutte insieme pesano su ogni client anche se sono
-- a chilometri. Tocca solo le cartelle statiche della mappa (non personaggi, draghi, minerali:
-- quelli li accendono e spengono altri script).

local Culling = {}

local FOLDERS = { "Borghi", "ZoneATema", "Forest", "Village", "Glacier", "Landmarks", "Isole", "Ores" }
local LIGHT_FAR = 320 -- oltre questa distanza le luci si spengono
local FX_FAR = 380 -- e le particelle
local EVERY = 1.2 -- secondi tra un controllo e l'altro

type Entry = { inst: Instance, part: BasePart, far: number }

local entries: { [Instance]: Entry } = {}
local culled: { [Instance]: boolean } = {} -- spente da qui (solo queste si riaccendono)

local function holderOf(inst: Instance): BasePart?
	local p = inst.Parent
	if p and p:IsA("Attachment") then
		p = p.Parent
	end
	return if p and p:IsA("BasePart") then p else nil
end

local function add(inst: Instance)
	local far = if inst:IsA("Light") then LIGHT_FAR elseif inst:IsA("ParticleEmitter") or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then FX_FAR else nil
	if not far then
		return
	end
	local part = holderOf(inst)
	if part then
		entries[inst] = { inst = inst, part = part, far = far }
	end
end

local function watch(folder: Instance)
	for _, d in folder:GetDescendants() do
		add(d)
	end
	folder.DescendantAdded:Connect(add)
	folder.DescendantRemoving:Connect(function(d)
		entries[d] = nil
		culled[d] = nil
	end)
end

function Culling.start()
	for _, name in FOLDERS do
		local f = workspace:FindFirstChild(name)
		if f then
			watch(f)
		end
	end
	-- con lo streaming le cartelle possono arrivare dopo
	workspace.ChildAdded:Connect(function(c)
		if table.find(FOLDERS, c.Name) then
			watch(c)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			local camera = workspace.CurrentCamera
			if camera then
				local here = camera.CFrame.Position
				for inst, e in entries do
					if not inst.Parent then
						entries[inst] = nil
						culled[inst] = nil
						continue
					end
					local far = (e.part.Position - here).Magnitude > e.far
					local obj = inst :: any
					if far and obj.Enabled then
						obj.Enabled = false
						culled[inst] = true
					elseif not far and culled[inst] and e.part.Transparency < 1 then -- (giacimento esaurito: resta spento)
						obj.Enabled = true
						culled[inst] = nil
					end
				end
			end
		end
	end)
end

return Culling
