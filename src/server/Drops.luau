--!strict
-- Materiali lasciati dai nemici (i modelli di Mirko in ServerStorage.Modelli.Drop): il modello
-- appare dove il nemico muore, galleggia e gira con una luce; chi lo tocca lo raccoglie
-- (cartella "Materiali" del giocatore, salvata da Progression). Spariscono dopo 60 s.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Drops = {}

-- cosa lascia ogni nemico: { materiale, probabilita' }
Drops.TABLE = {
	Yeti = { { "Pelliccia_Yeti", 1 }, { "Cristallo_Ghiaccio", 0.35 } },
	GolemGhiaccio = { { "Nucleo_Glaciale", 0.6 }, { "Cristallo_Ghiaccio", 1 } },
} :: { [string]: { { any } } }
-- i capi lasciano sempre anche il materiale raro
Drops.BOSS = {
	Yeti = { "Pelliccia_Yeti", "Cristallo_Ghiaccio", "Cristallo_Ghiaccio" },
	GolemGhiaccio = { "Nucleo_Glaciale", "Nucleo_Glaciale", "Cristallo_Ghiaccio" },
} :: { [string]: { string } }

-- nomi da mostrare
Drops.NAMES = {
	Pelliccia_Yeti = "Yeti Fur",
	Cristallo_Ghiaccio = "Ice Crystal",
	Nucleo_Glaciale = "Glacial Core",
} :: { [string]: string }

local folderWorld: Folder? = nil

function Drops.materials(player: Player): Folder
	local f = player:FindFirstChild("Materiali")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Materiali"
		f.Parent = player
	end
	return f :: Folder
end

function Drops.add(player: Player, name: string, amount: number)
	local f = Drops.materials(player)
	local v = f:FindFirstChild(name) :: IntValue?
	if not v then
		local nv = Instance.new("IntValue")
		nv.Name = name
		nv.Parent = f
		v = nv
	end
	(v :: IntValue).Value += amount
end

local function spawnOne(name: string, at: Vector3)
	local store = ServerStorage:FindFirstChild("Modelli")
	local tpl = store and store:FindFirstChild(name, true)
	if not tpl or not tpl:IsA("Model") then
		return
	end
	local m = tpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local _, s0 = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * 2.2 / math.max(s0.X, s0.Y, s0.Z, 0.05))
	local base = at + Vector3.new(math.random() * 6 - 3, 2.5, math.random() * 6 - 3)
	m:PivotTo(CFrame.new(base))
	-- area di raccolta, luce e scintille
	local pick = Instance.new("Part")
	pick.Name = "Raccogli"
	pick.Shape = Enum.PartType.Ball
	pick.Size = Vector3.one * 6
	pick.Transparency = 1
	pick.Anchored, pick.CanCollide, pick.CanQuery = true, false, false
	pick.CFrame = CFrame.new(base)
	pick.Parent = m
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(170, 220, 255)
	l.Range = 10
	l.Brightness = 2
	l.Parent = pick
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 6
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(1, 2)
	e.Size = NumberSequence.new(0.4, 0)
	e.LightEmission = 1
	e.Parent = pick
	m:SetAttribute("Material", name)
	m.Name = "Drop_" .. name
	CollectionService:AddTag(m, "Drop")
	m.Parent = folderWorld
	-- galleggia e gira (sul server: pochi oggetti)
	task.spawn(function()
		local t0 = os.clock()
		while m.Parent and os.clock() - t0 < 60 do
			local t = os.clock() - t0
			m:PivotTo(CFrame.new(base + Vector3.new(0, math.sin(t * 2) * 0.5, 0)) * CFrame.Angles(0, t * 1.5, 0))
			task.wait(0.05)
		end
		if m.Parent then
			m:Destroy()
		end
	end)
	pick.CanTouch = true
	local taken = false
	pick.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if taken or not player then
			return
		end
		taken = true
		Drops.add(player, name, 1)
		player:SetAttribute("Notice", "+1 " .. (Drops.NAMES[name] or name))
		player:SetAttribute("NoticeTime", os.clock())
		TweenService:Create(l, TweenInfo.new(0.2), { Brightness = 0 }):Play()
		m:Destroy()
	end)
end

-- il nemico "kind" e' morto in "at"
function Drops.drop(kind: string, at: Vector3, boss: boolean)
	if boss and Drops.BOSS[kind] then
		for _, name in Drops.BOSS[kind] do
			spawnOne(name, at)
		end
		return
	end
	for _, entry in Drops.TABLE[kind] or {} do
		if math.random() < entry[2] then
			spawnOne(entry[1], at)
		end
	end
end

function Drops.setup()
	local f = Instance.new("Folder")
	f.Name = "Drop"
	f.Parent = workspace
	folderWorld = f
end

return Drops
