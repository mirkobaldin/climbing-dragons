--!strict
-- Miniere: con il Piccone in mano, click vicino a un giacimento (tag "OreNode") per estrarre.
-- Ogni colpo stacca un pezzo; quando il giacimento e' esaurito sparisce e ricresce dopo
-- ORE_RESPAWN_SECONDS. I minerali raccolti finiscono nella cartella "Ores" del giocatore
-- (e il totale nella classifica in alto a destra). Rubino e Cosmico richiedono il Piccone
-- rinforzato (vedi shared/Gear).
-- Tutto lato server: il client non puo' barare su distanza o velocita'.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)
local Gear = require(ReplicatedStorage.Shared.Gear)
local Progression = require(script.Parent.Progression)

local Mining = {}

local lastHit: { [Player]: number } = {}

local function addOre(player: Player, oreType: string, amount: number)
	Progression.oreValue(player, oreType).Value += amount
	Progression.updateTotal(player)
end

local function nodeParts(node: Instance): { BasePart }
	local parts = {}
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	return parts
end

local function burst(position: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Size = NumberSequence.new(0.5, 0.1)
	e.Rate = 0
	e.Parent = p
	e:Emit(18)
	task.delay(1.5, function()
		p:Destroy()
	end)
end

-- Nasconde/mostra il giacimento (esaurito / ricresciuto)
local function setVisible(node: Instance, visible: boolean)
	for _, p in nodeParts(node) do
		local original = p:GetAttribute("OriginalTransparency")
		if original == nil then
			p:SetAttribute("OriginalTransparency", p.Transparency)
			original = p.Transparency
		end
		p.Transparency = if visible then original :: number else 1
		p.CanCollide = visible
		p.CanQuery = visible
		for _, light in p:GetChildren() do
			if light:IsA("Light") then
				light.Enabled = visible
			end
		end
	end
end

local function nearestNode(root: BasePart): Instance?
	local best, bestScore = nil, math.huge
	for _, node in CollectionService:GetTagged("OreNode") do
		if (node:GetAttribute("Amount") or 0) <= 0 then
			continue
		end
		local pos = if node:IsA("Model") then node:GetPivot().Position elseif node:IsA("BasePart") then node.Position else nil
		if pos then
			local offset = pos - root.Position
			local dist = offset.Magnitude
			if dist <= ClimbConfig.MINE_RANGE then
				-- preferisce quello davanti al personaggio
				local facing = if dist > 0.1 then root.CFrame.LookVector:Dot(offset.Unit) else 1
				local score = dist - facing * 6
				if score < bestScore then
					best, bestScore = node, score
				end
			end
		end
	end
	return best
end

-- Messaggio a schermo per un solo giocatore (lo mostra l'HUD del client)
local function warnPlayer(player: Player, text: string)
	player:SetAttribute("Notice", text)
	player:SetAttribute("NoticeTime", os.clock())
end

local function mine(player: Player, tool: Tool)
	local now = os.clock()
	if now - (lastHit[player] or 0) < ClimbConfig.MINE_COOLDOWN then
		return
	end
	lastHit[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or tool.Parent ~= character then
		return
	end

	-- animazione di colpo (la fa lo script Animate del personaggio)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	task.delay(0.5, function()
		anim:Destroy()
	end)

	local node = nearestNode(root)
	if not node then
		return
	end
	local oreType = node:GetAttribute("OreType") or "Pietra"
	if Gear.HARD_ORES[oreType] and not Gear.has(player, "PiccoRinforzato") then
		warnPlayer(player, "Too hard! You need the Reinforced Pickaxe (Workbench)")
		return
	end
	local amount = (node:GetAttribute("Amount") or 1) - 1
	node:SetAttribute("Amount", amount)
	local parts = nodeParts(node)
	local color = if #parts > 0 then parts[1].Color else Color3.new(1, 1, 1)
	burst(if node:IsA("Model") then node:GetPivot().Position else root.Position, color)
	addOre(player, oreType :: string, 1)
	player:SetAttribute("OresMined", (player:GetAttribute("OresMined") or 0) + 1) -- per il tutorial

	if amount <= 0 then
		setVisible(node, false)
		task.delay(ClimbConfig.ORE_RESPAWN_SECONDS, function()
			node:SetAttribute("Amount", node:GetAttribute("MaxAmount") or 5)
			setVisible(node, true)
		end)
	end
end

local function bindTool(player: Player, tool: Instance)
	if tool:IsA("Tool") and tool.Name == ClimbConfig.PICKAXE_NAME and not tool:GetAttribute("MiningBound") then
		tool:SetAttribute("MiningBound", true)
		tool.Activated:Connect(function()
			mine(player, tool)
		end)
	end
end

function Mining.setup()
	for _, node in CollectionService:GetTagged("OreNode") do
		if node:GetAttribute("MaxAmount") == nil then
			node:SetAttribute("MaxAmount", node:GetAttribute("Amount") or 5)
		end
	end

	local function onPlayer(player: Player)
		local stats = player:FindFirstChild("leaderstats") or Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
		if not stats:FindFirstChild("Ores") then
			local total = Instance.new("IntValue")
			total.Name = "Ores"
			total.Parent = stats
		end
		local function onCharacter(character: Model)
			character.ChildAdded:Connect(function(child)
				bindTool(player, child)
			end)
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return Mining
