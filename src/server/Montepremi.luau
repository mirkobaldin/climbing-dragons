--!strict
-- Montepremi stile Squid Game: una grande sfera di vetro dorata appesa sopra il campo base, con
-- dentro le monete (piu' e' alto il premio, piu' monete) e il numero sopra, visibile da lontano.
-- Cresce a ogni giocatore caduto e un poco ogni minuto (EconomyConfig.JACKPOT); il primo che
-- arriva in vetta lo vince tutto (Upgrades.onSummit) e riparte. I client lo leggono dagli
-- attributi del Workspace: Montepremi (numero), MontepremiTesto e MontepremiT (ultimo evento,
-- per il "+50" che compare in alto, client/Montepremi).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EconomyConfig = require(ReplicatedStorage.Shared.EconomyConfig)
local Economy = require(script.Parent.Economy)

local J = EconomyConfig.JACKPOT
local GOLD = Color3.fromRGB(255, 196, 60)
local PINK = Color3.fromRGB(255, 40, 130)

local Montepremi = {}

local sphere: BasePart? = nil
local coinsFolder: Folder? = nil
local lastDeath: { [Player]: number } = {}

-- 12450 -> "12,450"
local function fmt(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function value(): number
	return (workspace:GetAttribute("Montepremi") or J.START) :: number
end

local function event(text: string)
	workspace:SetAttribute("MontepremiTesto", text)
	workspace:SetAttribute("MontepremiT", workspace:GetServerTimeNow())
end

-- monete dentro la sfera: una ogni 60 del premio (da 10 a 120), cadono dentro dall'alto
local function fillCoins()
	local s, folder = sphere, coinsFolder
	if not s or not folder then
		return
	end
	local want = math.clamp(math.floor(value() / 60), 10, 120)
	local have = #folder:GetChildren()
	local r = s.Size.X / 2
	for k = have + 1, want do
		local coin = Instance.new("Part")
		coin.Name = "Moneta"
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.7, 4.6, 4.6)
		coin.Material = Enum.Material.Metal
		coin.Color = GOLD
		coin.Reflectance = 0.25
		coin.Anchored, coin.CanCollide, coin.CanQuery, coin.CanTouch = true, false, false, false
		-- mucchio sul fondo della sfera: piu' monete, mucchio piu' alto
		local layer = (k - 1) // 16
		local a = math.random() * math.pi * 2
		local rr = math.random() * (r * 0.7 - layer * 0.6)
		local floorY = -r * 0.84 + layer * 1.3
		local spot = s.Position + Vector3.new(math.cos(a) * rr, floorY, math.sin(a) * rr)
		local tilt = CFrame.Angles(math.random() * 0.6, math.random() * 6, math.pi / 2 + (math.random() - 0.5) * 0.6)
		coin.CFrame = CFrame.new(spot + Vector3.new(0, r * 1.6, 0)) * tilt
		coin.Parent = folder
		TweenService:Create(coin, TweenInfo.new(0.9 + math.random() * 0.4, Enum.EasingStyle.Bounce), { CFrame = CFrame.new(spot) * tilt }):Play()
	end
	if have > want then
		for _, c in folder:GetChildren() do
			c:Destroy()
		end
		if want > 0 then
			task.defer(fillCoins)
		end
	end
end

local function add(amount: number, text: string?)
	local v = math.min(J.MAX, value() + amount)
	workspace:SetAttribute("Montepremi", v)
	if text then
		event(text)
	end
	fillCoins()
end

-- sfera e cartello sopra il campo base (MapMarkers.HubSpawn): fuori dal percorso, in alto
local function build()
	local markers = workspace:FindFirstChild("MapMarkers")
	local spawn = markers and markers:FindFirstChild("HubSpawn") :: BasePart?
	if not spawn then
		warn("[Montepremi] manca MapMarkers.HubSpawn: niente sfera")
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Montepremi"
	local base = spawn.Position + Vector3.new(70, 0, -40)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(base + Vector3.new(0, 300, 0), Vector3.new(0, -600, 0), params)
	local groundY = if hit then hit.Position.Y else base.Y
	-- alta sopra i tetti del villaggio, grande: si vede da tutta la pianura
	local center = Vector3.new(base.X, groundY + 120, base.Z)
	local R = 46
	local glass = Instance.new("Part")
	glass.Name = "Sfera"
	glass.Shape = Enum.PartType.Ball
	glass.Size = Vector3.one * R
	glass.Material = Enum.Material.Glass
	glass.Color = Color3.fromRGB(255, 225, 150)
	glass.Transparency = 0.55
	glass.Reflectance = 0.15
	glass.Anchored, glass.CanCollide, glass.CanQuery, glass.CanTouch = true, false, false, false
	glass.CastShadow = false
	glass.Position = center
	glass.Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 40
	glow.Brightness = 2
	glow.Parent = glass
	-- catena fino in cielo e anello in cima
	local ring = Instance.new("Part")
	ring.Name = "Anello"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1.6, 9, 9)
	ring.Material = Enum.Material.Metal
	ring.Color = Color3.fromRGB(70, 70, 76)
	ring.Anchored, ring.CanCollide, ring.CanQuery = true, false, false
	ring.CFrame = CFrame.new(center + Vector3.new(0, R / 2 + 2, 0))
	ring.Parent = folder
	local chain = Instance.new("Part")
	chain.Name = "Catena"
	chain.Size = Vector3.new(1.2, 120, 1.2)
	chain.Material = Enum.Material.DiamondPlate
	chain.Color = Color3.fromRGB(60, 60, 66)
	chain.Anchored, chain.CanCollide, chain.CanQuery = true, false, false
	chain.Position = center + Vector3.new(0, R / 2 + 64, 0)
	chain.Parent = folder
	-- numero grande sopra la sfera (si vede da lontano: grandezza in studs)
	local board = Instance.new("BillboardGui")
	board.Name = "Cartello"
	board.Size = UDim2.fromScale(90, 28)
	board.StudsOffsetWorldSpace = Vector3.new(0, R / 2 + 16, 0)
	board.MaxDistance = 3000
	board.LightInfluence = 0
	board.Adornee = glass
	board.Parent = glass
	local title = Instance.new("TextLabel")
	title.Name = "Titolo"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.32)
	title.Font = Enum.Font.Arcade
	title.TextScaled = true
	title.TextColor3 = PINK
	title.TextStrokeTransparency = 0
	title.Text = "PRIZE POOL"
	title.Parent = board
	local num = Instance.new("TextLabel")
	num.Name = "Numero"
	num.BackgroundTransparency = 1
	num.Position = UDim2.fromScale(0, 0.32)
	num.Size = UDim2.fromScale(1, 0.68)
	num.Font = Enum.Font.Arcade
	num.TextScaled = true
	num.TextColor3 = GOLD
	num.TextStrokeTransparency = 0
	num.Parent = board
	local coins = Instance.new("Folder")
	coins.Name = "Monete"
	coins.Parent = folder
	folder.Parent = workspace
	sphere, coinsFolder = glass, coins
	local function show()
		num.Text = fmt(value())
	end
	workspace:GetAttributeChangedSignal("Montepremi"):Connect(show)
	show()
end

-- chi arriva in vetta vince tutto (Upgrades.onSummit)
function Montepremi.win(player: Player)
	local prize = value()
	Economy.addCoins(player, prize)
	event(string.format("%s reached the summit and won %s!", player.DisplayName, fmt(prize)))
	workspace:SetAttribute("Montepremi", J.START)
	fillCoins()
end

function Montepremi.setup()
	workspace:SetAttribute("Montepremi", J.START)
	task.spawn(build)
	task.defer(fillCoins)
	local function watch(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			local now = os.clock()
			if now - (lastDeath[player] or -math.huge) < J.DEATH_GAP then
				return
			end
			lastDeath[player] = now
			add(J.PER_DEATH, string.format("+%d  %s fell", J.PER_DEATH, player.DisplayName))
		end)
	end
	local function joined(player: Player)
		player.CharacterAdded:Connect(function(c)
			watch(player, c)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, p in Players:GetPlayers() do
		joined(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastDeath[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			add(J.PER_MINUTE)
		end
	end)
end

return Montepremi
