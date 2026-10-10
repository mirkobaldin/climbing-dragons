--!strict
-- Tutorial guidato alla parete di allenamento davanti al campo (la costruisce MapGen nella
-- cartella workspace.Tutorial). Un obiettivo alla volta, mostrato in alto a sinistra:
-- l'attributo "TutorialStep" del giocatore dice a che punto e' (salvato da Progression).
-- Ogni passo si completa da solo quando il giocatore fa la cosa giusta.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ropes = require(script.Parent.Ropes)

local Tutorial = {}

-- text = obiettivo mostrato; check = fatto?; target = dove puntano le frecce guida
type Step = {
	text: string,
	check: (Player, { [string]: any }) -> boolean,
	target: (Player, { [string]: any }) -> Vector3?,
}

local function near(player: Player, target: Vector3?, radius: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and target ~= nil and (root.Position - (target :: Vector3)).Magnitude < radius
end

local function attributeAtLeast(name: string, base: string): (Player, { [string]: any }) -> boolean
	return function(player, memo)
		local value = player:GetAttribute(name) or 0
		if memo[base] == nil then
			memo[base] = value
		end
		return value > memo[base]
	end
end

local function fixed(key: string): (Player, { [string]: any }) -> Vector3?
	return function(_, memo)
		return memo[key]
	end
end

local function playerAttr(name: string): (Player, { [string]: any }) -> Vector3?
	return function(player)
		local v = player:GetAttribute(name)
		return if typeof(v) == "Vector3" then v else nil
	end
end

-- Uovo di allenamento se non lo porti gia', altrimenti il tuo nido
local function eggTarget(player: Player, memo: { [string]: any }): Vector3?
	if player:GetAttribute("CarryingEgg") then
		local nest = player:GetAttribute("NestPosition")
		return if typeof(nest) == "Vector3" then nest else nil
	end
	return memo.eggSpot
end

local STEPS: { Step } = {
	{
		text = "Go to the practice wall: follow the arrows",
		check = function(player, memo)
			return near(player, memo.wallBase, 30)
		end,
		target = fixed("wallBase"),
	},
	{
		text = "Take the Ice Axe (key 1), click near the rock and climb with W to the top",
		check = function(player, memo)
			return near(player, memo.wallTop, 16)
		end,
		target = fixed("wallTop"),
	},
	{
		text = "Pitons: grab the wall and press F to place a piton (the rope catches you if you fall)",
		check = attributeAtLeast("PitonsPlaced", "pitons0"),
		target = fixed("wallBase"),
	},
	{
		text = "Mining: take the Pickaxe (key 2) and click the ores at the foot of the wall",
		check = attributeAtLeast("OresMined", "ores0"),
		target = fixed("ore"),
	},
	{
		text = "Money: open the store and sell your ores (Sell tab)",
		check = attributeAtLeast("OresSold", "sold0"),
		target = fixed("shop"),
	},
	{
		text = "Home: this is your camp at the foot of the mountain. Buy the Tent (unlocks the nest)",
		arrive = "camp",
		check = function(player)
			return ((player:GetAttribute("HouseLevel") or 0) :: number) >= 1
		end,
		target = playerAttr("PlotPosition"),
	},
	{
		text = "Crafting: open the Workbench next to the store (Crampons, Grappling Hook, Suit...)",
		arrive = "hub",
		check = function(player)
			return player:GetAttribute("BenchOpened") == true
		end,
		target = fixed("bench"),
	},
	{
		text = "Dragon eggs: pick up the egg near the wall and bring it to your tent's nest (T > My camp)",
		check = attributeAtLeast("EggsIncubated", "incubated0"),
		target = eggTarget,
	},
	{
		text = "Wait for it to hatch: press G (Dragons menu), then 'Hatch'",
		check = attributeAtLeast("EggsHatched", "hatched0"),
		target = playerAttr("NestPosition"),
	},
}

local DONE_TEXT = "Ready! Use the 'Mountain' sign at camp or follow the road. Happy climbing!"

-- porta il giocatore al suo accampamento (terreno ai piedi della montagna) o al campo base
local function bring(player: Player, where: string)
	task.delay(1.5, function()
		local p: any = nil
		if where == "camp" then
			p = player:GetAttribute("PlotSpawn") or player:GetAttribute("PlotPosition")
		else
			local markers = workspace:FindFirstChild("MapMarkers")
			local hub = markers and markers:FindFirstChild("HubSpawn")
			p = if hub and hub:IsA("BasePart") then hub.Position else nil
		end
		local character = player.Character
		if typeof(p) == "Vector3" and character then
			character:PivotTo(CFrame.new(p + Vector3.new(0, 2, 0)))
			player:SetAttribute("Notice", if where == "camp" then "Welcome to your camp!" else "Back to the base camp")
			player:SetAttribute("NoticeTime", os.clock())
		end
	end)
end

local function publish(player: Player, step: number)
	local before = player:GetAttribute("TutorialStep")
	if type(before) == "number" and before ~= step then
		if before <= #STEPS and step > #STEPS then
			-- finito (o saltato): al proprio accampamento, cosi' non lo si deve cercare nella mappa
			bring(player, "camp")
		elseif STEPS[step] and (STEPS[step] :: any).arrive then
			bring(player, (STEPS[step] :: any).arrive)
		end
	end
	player:SetAttribute("TutorialStep", step)
	local s = STEPS[step]
	player:SetAttribute("TutorialText", if s then string.format("(%d/%d) %s", step, #STEPS, s.text) else nil)
	player:SetAttribute("TutorialTotal", #STEPS)
	if not s then
		player:SetAttribute("GuideTarget", nil)
	end
end

local runFn: ((Player) -> ())? = nil

-- Ricomincia il tutorial (comando admin)
function Tutorial.reset(player: Player)
	publish(player, 1)
	if runFn then
		task.spawn(runFn :: any, player)
	end
end

function Tutorial.setup()
	local tutorial = workspace:WaitForChild("Tutorial", 10)
	local wallBase = tutorial and tutorial:FindFirstChild("WallBase") :: BasePart?
	local wallTop = tutorial and tutorial:FindFirstChild("WallTop") :: BasePart?
	if not tutorial then
		warn("[Tutorial] workspace.Tutorial non trovato: rigenera la mappa con MapGen")
	end

	-- Salta il tutorial (pulsante nell'interfaccia)
	local skip = Instance.new("RemoteEvent")
	skip.Name = "SkipTutorial"
	skip.Parent = ReplicatedStorage:WaitForChild("Remotes")
	skip.OnServerEvent:Connect(function(player)
		publish(player, #STEPS + 1)
		player:SetAttribute("TutorialText", nil)
	end)

	local function run(player: Player)
		-- aspetta che Progression abbia caricato il salvataggio
		while player.Parent and player:GetAttribute("TutorialStep") == nil do
			task.wait(0.5)
		end
		local function points(): { [string]: any }
			local shop = CollectionService:GetTagged("ShopCounter")[1]
			local bench = CollectionService:GetTagged("Workbench")[1]
			local ore = tutorial and tutorial:FindFirstChild("Ore_Ferro")
			local eggSpot = tutorial and tutorial:FindFirstChild("EggSpot") :: BasePart?
			return {
				wallBase = wallBase and wallBase.Position,
				wallTop = wallTop and wallTop.Position,
				shop = if shop and shop:IsA("BasePart") then shop.Position else nil,
				bench = if bench and bench:IsA("BasePart") then bench.Position else nil,
				ore = if ore and ore:IsA("Model") then ore:GetPivot().Position else nil,
				eggSpot = eggSpot and eggSpot.Position,
			}
		end
		local memo = points()
		local step = player:GetAttribute("TutorialStep") :: number
		publish(player, step)
		while player.Parent and step <= #STEPS do
			task.wait(0.5)
			step = player:GetAttribute("TutorialStep") :: number -- puo' cambiare (salta/admin)
			local s = STEPS[step]
			if s then
				player:SetAttribute("GuideTarget", s.target(player, memo))
			end
			if s and s.check(player, memo) then
				step += 1
				memo = points()
				publish(player, step)
				if step == 3 then
					Ropes.refill(player) -- chiodi pieni per provare
				end
				if step > #STEPS then
					player:SetAttribute("Notice", DONE_TEXT)
					player:SetAttribute("NoticeTime", os.clock())
				end
			end
		end
	end

	runFn = run
	Players.PlayerAdded:Connect(function(player)
		task.spawn(run, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(run, player)
	end
end

Tutorial.STEP_COUNT = #STEPS

return Tutorial
