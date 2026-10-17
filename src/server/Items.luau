--!strict
-- Oggetti consumabili (shared/Items): quantita' nella cartella "Oggetti" del giocatore, un Tool
-- per ogni oggetto che hai (va nella barra 1-5, mostra la quantita'), uso col click del Tool in
-- mano o dallo zaino (Shop "use"), butta dallo zaino (Shop "discard", "item:<id>").
-- Salvati da Progression (Items.serialize / Items.load), anche i minuti che restano alle pozioni.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Items)
local UiAssets = require(ReplicatedStorage.Shared.UiAssets)

local Items = {}

local lastUse: { [Player]: number } = {}

local function notice(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

function Items.folder(player: Player): Folder
	local f = player:FindFirstChild("Oggetti")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Oggetti"
		f.Parent = player
	end
	return f :: Folder
end

function Items.count(player: Player, id: string): number
	local v = Items.folder(player):FindFirstChild(id)
	return if v and v:IsA("IntValue") then v.Value else 0
end

local function toolOf(player: Player, name: string): Tool?
	for _, parent in { player:FindFirstChildOfClass("Backpack"), player.Character } :: { Instance? } do
		local t = parent and (parent :: Instance):FindFirstChild(name)
		if t and t:IsA("Tool") then
			return t
		end
	end
	return nil
end

-- boccetta o pacchetto in mano: una scatoletta del colore dell'oggetto (i modelli veri si
-- potranno mettere in ServerStorage.Modelli.Oggetti.<id>)
local function makeTool(player: Player, item: ItemConfig.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.ToolTip = item.text
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Oggetto", item.id)
	tool.TextureId = UiAssets.get(item.icon) or UiAssets.get(item.fallback) or ""
	local models = game:GetService("ServerStorage"):FindFirstChild("Modelli")
	local folder = models and models:FindFirstChild("Oggetti")
	local custom = folder and folder:FindFirstChild(item.id)
	local handle: BasePart
	if custom and custom:IsA("BasePart") then
		handle = custom:Clone()
		for _, d in handle:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- regola del gioco: niente script dentro i modelli clonati
			end
		end
	else
		local p = Instance.new("Part")
		p.Size = if item.boost then Vector3.new(0.5, 0.8, 0.5) else Vector3.new(0.9, 0.6, 0.5)
		p.Shape = if item.boost then Enum.PartType.Cylinder else Enum.PartType.Block
		p.Color = item.color
		p.Material = if item.boost then Enum.Material.Glass else Enum.Material.SmoothPlastic
		p.Transparency = if item.boost then 0.15 else 0
		handle = p
	end
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Activated:Connect(function()
		local owner = Players:GetPlayerFromCharacter(tool.Parent)
		if owner == player then
			Items.use(player, item.id)
		end
	end)
	return tool
end

-- un Tool per ogni oggetto che hai, con la quantita'; via quelli finiti
function Items.sync(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, item in ItemConfig.LIST do
		local n = Items.count(player, item.id)
		local tool = toolOf(player, item.name)
		if n > 0 then
			if not tool and backpack then
				tool = makeTool(player, item)
				;(tool :: Tool).Parent = backpack
			end
			if tool then
				tool:SetAttribute("Quantita", n)
			end
		elseif tool then
			tool:Destroy()
		end
	end
end

function Items.add(player: Player, id: string, n: number)
	if not ItemConfig.get(id) then
		return
	end
	local f = Items.folder(player)
	local v = f:FindFirstChild(id) :: IntValue?
	if not v then
		local nv = Instance.new("IntValue")
		nv.Name = id
		nv.Parent = f
		v = nv
	end
	local iv = v :: IntValue
	iv.Value = math.clamp(iv.Value + n, 0, 999)
	Items.sync(player)
end

-- usa un oggetto: false (e il motivo) se non serve o non ce l'hai
function Items.use(player: Player, id: string): (boolean, string)
	local item = ItemConfig.get(id)
	if not item then
		return false, "Unknown item"
	end
	if Items.count(player, id) <= 0 then
		return false, "You don't have any"
	end
	if os.clock() - (lastUse[player] or 0) < 0.6 then
		return false, ""
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if item.heal then
		if not humanoid or humanoid.Health <= 0 then
			return false, "You can't use it now"
		end
		if humanoid.Health >= humanoid.MaxHealth then
			return false, "You're not hurt"
		end
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + (item.heal :: number))
	elseif item.warmth then
		if ((player:GetAttribute("Warmth") or 100) :: number) >= 99 then
			return false, "You're warm already"
		end
		player:SetAttribute("Warmth", item.warmth)
	elseif item.boost then
		local key = "Boost_" .. (item.boost :: string)
		local now = workspace:GetServerTimeNow()
		local from = math.max(now, (player:GetAttribute(key) or 0) :: number)
		player:SetAttribute(key, from + ItemConfig.BOOST_SECONDS)
	end
	lastUse[player] = os.clock()
	Items.add(player, id, -1)
	local message = if item.boost then string.format("%s active: %d min", ItemConfig.BOOST_NAMES[item.boost :: string] or item.name,
		math.ceil(ItemConfig.boostLeft(player, item.boost :: string) / 60)) else item.name .. " used"
	notice(player, message)
	return true, message
end

-- salvataggio: quantita' e secondi che restano a ogni pozione
function Items.serialize(player: Player): { [string]: any }
	local counts = {}
	for _, v in Items.folder(player):GetChildren() do
		if v:IsA("IntValue") and v.Value > 0 then
			counts[v.Name] = v.Value
		end
	end
	local boosts = {}
	for kind in ItemConfig.BOOST_NAMES do
		local left = ItemConfig.boostLeft(player, kind)
		if left > 1 then
			boosts[kind] = math.floor(left)
		end
	end
	return { counts = counts, boosts = boosts }
end

function Items.load(player: Player, data: any)
	if type(data) == "table" then
		if type(data.counts) == "table" then
			for id, n in data.counts do
				if type(id) == "string" and type(n) == "number" and ItemConfig.get(id) then
					Items.add(player, id, math.floor(n))
				end
			end
		end
		if type(data.boosts) == "table" then
			for kind, left in data.boosts do
				if type(kind) == "string" and ItemConfig.BOOST_NAMES[kind] and type(left) == "number" then
					player:SetAttribute("Boost_" .. kind, workspace:GetServerTimeNow() + math.min(left, 24 * 3600))
				end
			end
		end
	end
	Items.sync(player)
end

function Items.setup()
	local function onPlayer(player: Player)
		Items.folder(player)
		player.CharacterAdded:Connect(function()
			-- lo zaino di Roblox si svuota a ogni rinascita: si rimettono i Tool
			task.delay(0.5, Items.sync, player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUse[player] = nil
	end)
end

return Items
