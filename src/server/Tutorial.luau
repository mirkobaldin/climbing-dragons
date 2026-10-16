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

-- Testi corti (Mirko: "deve capirlo un bambino"): "OBIETTIVO|aiuto", l'aiuto compare solo se
-- serve (client/HUD). {KEY1}, {CLIMB}... diventano il comando del
-- computer o del telefono (UiView.hintText); {UI:Store} fa lampeggiare quel pulsante del menu
local STEPS: { Step } = {
	{
		text = "GO TO THE CLIMBING WALL|Follow the arrows",
		check = function(player, memo)
			return near(player, memo.wallBase, 30)
		end,
		target = fixed("wallBase"),
	},
	{
		text = "CLIMB THE WALL|{KEY1}. {CLIMB}",
		check = function(player, memo)
			return near(player, memo.wallTop, 16)
		end,
		target = fixed("wallTop"),
	},
	-- un passo solo (i passi sono 9 come prima: TutorialStep e' nei salvataggi e chi l'aveva
	-- finito, passo 10, deve restare fuori dal tutorial)
	{
		-- chiodo: si pianta col tasto del chiodo sulla parete (cerchio verde = punto buono), poi
		-- ci si sgancia vicino al chiodo e torna nello zaino (+1). Il client cambia l'obiettivo in
		-- "UNCLIP THE ROPE" quando la corda e' attaccata (client/HUD)
		text = "PLACE A PITON|{KEY1}. Face the rock wall. {PITON}",
		check = function(player, memo)
			-- per la prova servono chiodi: se non ne hai, il tutorial te ne da' due
			if not memo.gave and ((player:GetAttribute("Pitons") or 0) :: number) < 1 then
				memo.gave = true
				player:SetAttribute("Pitons", 2)
				player:SetAttribute("Notice", "+2 pitons for the lesson")
				player:SetAttribute("NoticeTime", os.clock())
			end
			local placed = attributeAtLeast("PitonsPlaced", "pitons0")(player, memo)
			memo.placedOnce = memo.placedOnce or placed
			return memo.placedOnce and attributeAtLeast("PitonsRecovered", "recovered0")(player, memo)
		end,
		target = fixed("wallBase"),
	},
	{
		text = "MINE THE CRYSTAL|{KEY2}. {MINE}",
		check = attributeAtLeast("OresMined", "ores0"),
		target = fixed("ore"),
	},
	{
		text = "SELL YOUR ORES|Open the menu, then Shop, tab Sell {UI:Store}",
		check = attributeAtLeast("OresSold", "sold0"),
		target = fixed("shop"),
	},
	-- l'uovo si prende QUI, prima di andare al campo (Mirko: prima ti portava al campo e poi
	-- toccava tornare indietro a prendere l'uovo e risalire). Si porta al campo sulla schiena.
	{
		text = "PICK UP THE EGG|Follow the arrows to the egg",
		check = function(player, memo)
			return player:GetAttribute("CarryingEgg") ~= nil or attributeAtLeast("EggsIncubated", "incubated0")(player, memo)
		end,
		target = fixed("eggSpot"),
	},
	{
		text = "BUY THE TENT|This is your camp: buy the Tent in the Shop {UI:Store}",
		arrive = "camp",
		check = function(player)
			return ((player:GetAttribute("HouseLevel") or 0) :: number) >= 1
		end,
		target = playerAttr("PlotPosition"),
	},
	-- (il passo "apri il Crafting" non c'e' piu': i passi devono restare 9 per i salvataggi;
	-- il banco da lavoro arriva con la Tenda e lo dice la nota finale)
	{
		text = "PUT THE EGG IN YOUR NEST|Walk to the nest with the egg",
		check = attributeAtLeast("EggsIncubated", "incubated1"),
		target = eggTarget,
	},
	{
		text = "HATCH YOUR EGG|Open the menu, then Dragons, and tap Hatch {UI:Dragons}",
		check = attributeAtLeast("EggsHatched", "hatched0"),
		target = playerAttr("NestPosition"),
	},
}

local DONE_TEXT = "Ready! Craft gear at the Workbench by your tent. Happy climbing!"

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

	-- il client avvisa quando apri un menu (il Crafting conta anche aperto dal menu, non solo
	-- dal banco: prima il tutorial diceva di andare al banco anche se c'era il pulsante)
	local opened = Instance.new("RemoteEvent")
	opened.Name = "MenuOpened"
	opened.Parent = ReplicatedStorage:WaitForChild("Remotes")
	opened.OnServerEvent:Connect(function(player, name)
		if name == "Crafting" then
			player:SetAttribute("CraftingSeen", true)
		end
	end)

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
			local ore = tutorial and tutorial:FindFirstChild("Ore_Ferro")
			local eggSpot = tutorial and tutorial:FindFirstChild("EggSpot") :: BasePart?
			return {
				wallBase = wallBase and wallBase.Position,
				wallTop = wallTop and wallTop.Position,
				shop = if shop and shop:IsA("BasePart") then shop.Position else nil,
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
