--!strict
-- Attrezzi dati a ogni giocatore (in StarterPack, cosi' li riceve a ogni spawn):
--   Piccozza  Click vicino a una parete: aggrappati | F: pianta un chiodo | R: sgancia la corda
--   Piccone   Click vicino a un giacimento: estrai il minerale
-- Se in ServerStorage (o Workspace) ci sono i tuoi modelli li usa, altrimenti li costruisce:
--   Piccozza: "Piccozza", "IceAxe" o "Ice Axes" (il Tool del kit "Ice Climbing": con due
--             piccozze, la seconda "FakeHandle" va nella mano sinistra)
--   Piccone:  "Piccone" o "Simple Pickaxe"
-- Gli script dentro i modelli vengono sempre rimossi (quelli del Toolbox a volte sono virus).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)

local Tools = {}

local AXE_TIP = "Click near a wall: grab / let go | Space: jump off | F: piton | R: unclip the rope"
local PICK_TIP = "Click near an ore vein: mine it"
local OFFHAND = { FakeHandle = true, LeftHandle = true, OffHandle = true }

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Attrezzo a blocchi: manico di legno + testa di metallo (becca/lama)
local function builtTool(name: string, tip: string, headLength: number, pickAngle: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -1.1, 0)

	local handle = part("Handle", Vector3.new(0.35, 3.4, 0.35), Color3.fromRGB(60, 44, 32), Enum.Material.Wood)
	handle.Parent = tool
	local head = part("Head", Vector3.new(0.3, 0.45, headLength), Color3.fromRGB(160, 164, 170), Enum.Material.Metal)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.7, 0.25)
	head.Parent = tool
	local pick = part("Pick", Vector3.new(0.2, 0.9, 0.3), Color3.fromRGB(140, 144, 150), Enum.Material.Metal)
	pick.CFrame = head.CFrame * CFrame.new(0, -0.35, -headLength / 2) * CFrame.Angles(pickAngle, 0, 0)
	pick.Parent = tool
	weld(handle, head)
	weld(handle, pick)
	return tool
end

local function findModel(names: { string }): Instance?
	for _, container in { ServerStorage, workspace } do
		for _, name in names do
			local found = container:FindFirstChild(name, true)
			if found and (found:IsA("Tool") or found:IsA("Model")) then
				return found
			end
		end
	end
	return nil
end

-- Parti gia' unite tra loro da giunti (Motor6D, Weld, WeldConstraint) a partire da "root"
local function connected(tool: Instance, root: BasePart): { [BasePart]: boolean }
	local links: { [BasePart]: { BasePart } } = {}
	for _, d in tool:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			local a, b = (d :: any).Part0, (d :: any).Part1
			if a and b then
				links[a] = links[a] or {}
				links[b] = links[b] or {}
				table.insert(links[a], b)
				table.insert(links[b], a)
			end
		end
	end
	local seen = { [root] = true }
	local queue = { root }
	while #queue > 0 do
		local p = table.remove(queue) :: BasePart
		for _, q in links[p] or {} do
			if not seen[q] then
				seen[q] = true
				table.insert(queue, q)
			end
		end
	end
	return seen
end

-- Model qualsiasi -> Tool: un manico invisibile allineato alla parte piu' lunga (l'asta),
-- con la testa (dove sta il grosso del modello) verso l'alto, impugnato vicino al fondo
local function toolFromLooseModel(source: Instance): Tool?
	local tool = Instance.new("Tool")
	local copy = source:Clone()
	local parts: { BasePart } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	local stick = parts[1]
	local longest = 0
	for _, p in parts do
		local m = math.max(p.Size.X, p.Size.Y, p.Size.Z)
		if m > longest then
			stick, longest = p, m
		end
	end
	local s = stick.Size
	local axis = if s.X >= s.Y and s.X >= s.Z
		then stick.CFrame.RightVector
		elseif s.Y >= s.Z then stick.CFrame.UpVector
		else stick.CFrame.LookVector
	-- la testa sta dal lato dove c'e' piu' "roba"
	local center = Vector3.zero
	for _, p in parts do
		center += p.Position
	end
	center /= #parts
	if (center - stick.Position):Dot(axis) < 0 then
		axis = -axis
	end
	local side = if math.abs(axis.Y) < 0.9 then Vector3.yAxis:Cross(axis).Unit else Vector3.xAxis
	local handle = part("Handle", Vector3.new(0.3, longest, 0.3), Color3.new(), Enum.Material.SmoothPlastic)
	handle.Transparency = 1
	handle.CFrame = CFrame.fromMatrix(stick.Position, side, axis)
	handle.Parent = tool
	for _, p in parts do
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		weld(handle, p)
	end
	copy.Parent = tool
	tool.Grip = CFrame.new(0, -longest * 0.3, 0)
	return tool
end

-- Tool o Model del Toolbox -> Tool pulito e funzionante
local function toolFromModel(source: Instance, name: string, tip: string): Tool?
	local tool: Tool?
	if source:IsA("Tool") then
		local t = source:Clone()
		local handle = t:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			-- salda le parti rimaste libere, tranne la piccozza della mano sinistra
			local offhand: BasePart? = nil
			for n in OFFHAND do
				local p = t:FindFirstChild(n)
				if p and p:IsA("BasePart") then
					offhand = p
				end
			end
			local linked = connected(t, handle)
			local linkedOff = if offhand then connected(t, offhand) else {}
			for _, d in t:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = false
					d.CanCollide = false
					d.Massless = true
					if not linked[d] and not linkedOff[d] then
						weld(handle, d)
					end
				end
			end
			tool = t
		else
			t:Destroy()
			tool = toolFromLooseModel(source)
		end
	else
		tool = toolFromLooseModel(source)
	end
	if not tool then
		return nil
	end
	for _, d in tool:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			d:Destroy()
		end
	end
	-- WeldConstraint -> Weld con la posizione fissata adesso: una WeldConstraint si ricorda la
	-- distanza del momento in cui si attiva, e la seconda piccozza (libera per un attimo quando
	-- impugni il Tool, finche' non viene agganciata alla mano sinistra) cadeva e restava indietro
	for _, w in tool:GetDescendants() do
		if w:IsA("WeldConstraint") and w.Part0 and w.Part1 then
			local fixed = Instance.new("Weld")
			fixed.Name = "Fissa"
			fixed.Part0 = w.Part0
			fixed.Part1 = w.Part1
			fixed.C0 = (w.Part0 :: BasePart).CFrame:ToObjectSpace((w.Part1 :: BasePart).CFrame)
			fixed.Parent = w.Parent
			w:Destroy()
		end
	end
	tool.Name = name
	tool.ToolTip = tip
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	return tool
end

-- La seconda piccozza (mano sinistra): sempre visibile quando impugni la Piccozza.
-- Il client avvisa con il remote "ClimbState" quando si attacca o si stacca.
local function offhandParts(character: Model?): { BasePart }
	local list = {}
	local tool = character and character:FindFirstChild(ClimbConfig.TOOL_NAME)
	if not tool then
		return list
	end
	for n in OFFHAND do
		local p = tool:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			table.insert(list, p)
			for _, d in p:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

function Tools.setOffhandVisible(character: Model?, visible: boolean)
	for _, p in offhandParts(character) do
		if p:GetAttribute("Trasparenza") == nil then
			p:SetAttribute("Trasparenza", p.Transparency)
		end
		p.Transparency = if visible then (p:GetAttribute("Trasparenza") :: number) else 1
	end
end

-- Piccozza doppia: quando la impugni, la seconda (FakeHandle) va nella mano sinistra
local function bindOffhand(character: Model)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") or child.Name ~= ClimbConfig.TOOL_NAME then
			return
		end
		local offhand: BasePart? = nil
		for n in OFFHAND do
			local p = child:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				offhand = p
			end
		end
		local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
		if not offhand or not hand or not hand:IsA("BasePart") then
			return
		end
		local grip = hand:FindFirstChild("LeftGripAttachment")
		local w = Instance.new("Weld")
		w.Name = "OffhandWeld"
		w.Part0 = hand
		w.Part1 = offhand
		w.C0 = if grip and grip:IsA("Attachment") then grip.CFrame else CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		w.C1 = child.Grip
		w.Parent = offhand
		-- tutte e due le piccozze sempre in mano (anche camminando)
		Tools.setOffhandVisible(character, true)
		local conn: RBXScriptConnection
		conn = child.AncestryChanged:Connect(function()
			if child.Parent ~= character then
				w:Destroy()
				conn:Disconnect()
			end
		end)
	end)
end

-- Rampino: impugnatura con tre uncini d'acciaio e un rotolo di corda
local function grapplingHook(): Tool
	local tool = Instance.new("Tool")
	tool.Name = ClimbConfig.GRAPPLE_NAME
	tool.ToolTip = "Click a distant wall: the rope pulls you up"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.6, 0)
	local handle = part("Handle", Vector3.new(0.4, 1.6, 0.4), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	handle.Parent = tool
	local shaft = part("Shaft", Vector3.new(0.25, 1.2, 0.25), Color3.fromRGB(150, 154, 160), Enum.Material.Metal)
	shaft.CFrame = handle.CFrame * CFrame.new(0, 1.3, 0)
	shaft.Parent = tool
	weld(handle, shaft)
	for k = 0, 2 do
		local claw = part("Claw", Vector3.new(0.2, 0.9, 0.2), Color3.fromRGB(170, 174, 180), Enum.Material.Metal)
		claw.CFrame = shaft.CFrame * CFrame.Angles(0, k * 2 * math.pi / 3, 0) * CFrame.new(0, 0.5, 0.3) * CFrame.Angles(0.8, 0, 0)
		claw.Parent = tool
		weld(handle, claw)
	end
	local coil = part("Coil", Vector3.new(0.5, 1.2, 1.2), Color3.fromRGB(196, 150, 80), Enum.Material.Fabric)
	coil.Shape = Enum.PartType.Cylinder
	coil.CFrame = handle.CFrame * CFrame.new(0.5, -0.3, 0)
	coil.Parent = tool
	weld(handle, coil)
	return tool
end

-- Rampino a pistola (il tuo modello "Rampino" in ServerStorage, una mesh sola): lungo GUN_LENGTH
-- studs, la canna (lato -X del modello, dove c'e' la punta gialla) in avanti e l'impugnatura in
-- mano. "Bocca" e' l'attacco in punta alla canna: da li' parte l'uncino (client/Grapple).
local GUN_LENGTH = 2.2
-- impugnatura: dove sta la mano sulla mesh (frazioni della grandezza, centro = 0) e come si gira
-- la pistola perche' la canna guardi avanti. Trovati provando in Play.
local GUN_GRIP_AT = Vector3.new(0.12, -0.18, 0)
local GUN_GRIP_ROT = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
local GUN_MUZZLE_AT = Vector3.new(-0.5, 0.2, 0)

-- Copia pulita e in scala del modello (anche per la cinematica del rampino, sul client)
function Tools.gunModel(): Model?
	local source = findModel({ "Rampino", "Grappling Hook", "GrapplingHook" })
	if not source or source:IsA("Tool") then
		return nil
	end
	local copy = source:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			d:Destroy()
		end
	end
	local model: Model
	if copy:IsA("Model") then
		model = copy
	else
		model = Instance.new("Model")
		copy.Parent = model
	end
	local main: BasePart? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (not main or d.Size.Magnitude > (main :: BasePart).Size.Magnitude) then
			main = d
		end
	end
	if not main then
		return nil
	end
	model.PrimaryPart = main
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * GUN_LENGTH / math.max(size.X, size.Y, size.Z, 0.01))
	local m = main :: BasePart
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Bocca"
	muzzle.Position = m.Size * GUN_MUZZLE_AT
	muzzle.Parent = m
	model:SetAttribute("Grip", CFrame.new(m.Size * GUN_GRIP_AT) * GUN_GRIP_ROT)
	return model
end

local function gunTool(): Tool?
	local model = Tools.gunModel()
	if not model or not model.PrimaryPart then
		return nil
	end
	local tool = Instance.new("Tool")
	local main = model.PrimaryPart :: BasePart
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			if d ~= main then
				weld(main, d)
			end
		end
	end
	for _, d in model:GetChildren() do
		d.Parent = tool
	end
	main.Name = "Handle"
	tool.Grip = CFrame.new(main.Size * GUN_GRIP_AT) * GUN_GRIP_ROT
	tool.Name = ClimbConfig.GRAPPLE_NAME
	tool.ToolTip = "Click a distant wall: the rope pulls you up"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	return tool
end

-- Torcia: manico di legno con la testa avvolta che brucia. Fa luce (ombre vere) e, portata
-- in mano, scalda un po' (tag "HeatSource" sulla fiamma, vedi il freddo in Progression).
local function torch(): Tool
	local tool = Instance.new("Tool")
	tool.Name = ClimbConfig.TORCH_NAME
	tool.ToolTip = "Lights up caves and the night"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.8, 0)
	local handle = part("Handle", Vector3.new(0.35, 2.4, 0.35), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
	handle.Parent = tool
	local head = part("Testa", Vector3.new(0.6, 0.7, 0.6), Color3.fromRGB(60, 44, 30), Enum.Material.Fabric)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.45, 0)
	head.Parent = tool
	weld(handle, head)
	local fire = Instance.new("Fire")
	fire.Size = 2.4
	fire.Heat = 6
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 26
	light.Brightness = 2.2
	light.Shadows = true
	light.Parent = head
	game:GetService("CollectionService"):AddTag(head, "HeatSource")
	return tool
end

-- Attrezzi costruiti al Banco da lavoro (vedi shared/Gear): "Rampino" (o un tuo modello
-- "Rampino"/"Grappling Hook" in ServerStorage); "Torcia" si costruisce ovunque
function Tools.make(id: string): Tool?
	if id == "Torcia" then
		local source = findModel({ "Torcia", "Torch" })
		local tool = if source then toolFromModel(source, ClimbConfig.TORCH_NAME, "Lights up caves and the night") else nil
		return tool or torch()
	end
	if id == "Rampino" then
		local gun = gunTool()
		if gun then
			return gun
		end
		local source = findModel({ "Rampino", "Grappling Hook", "GrapplingHook" })
		local tool = if source then toolFromModel(source, ClimbConfig.GRAPPLE_NAME, "Click a distant wall: the rope pulls you up") else nil
		return tool or grapplingHook()
	end
	return nil
end

local function install(tool: Tool)
	local existing = StarterPack:FindFirstChild(tool.Name)
	if existing then
		existing:Destroy()
	end
	tool.Parent = StarterPack
end

function Tools.setup()
	local axeSource = findModel({ ClimbConfig.TOOL_NAME, "Piccozza", "IceAxe", "Ice Axes" })
	local axe = if axeSource then toolFromModel(axeSource, ClimbConfig.TOOL_NAME, AXE_TIP) else nil
	if axeSource and not axe then
		warn("[Tools] Il modello della piccozza non ha parti: uso quella predefinita")
	end
	install(axe or builtTool(ClimbConfig.TOOL_NAME, AXE_TIP, 2.2, 0.5))

	local pickSource = findModel({ ClimbConfig.PICKAXE_NAME, "Piccone", "Simple Pickaxe" })
	local pick = if pickSource then toolFromModel(pickSource, ClimbConfig.PICKAXE_NAME, PICK_TIP) else nil
	install(pick or builtTool(ClimbConfig.PICKAXE_NAME, PICK_TIP, 3, 0))

	-- la pistola del rampino per la cinematica (il client non vede ServerStorage)
	local gun = Tools.gunModel()
	if gun then
		gun.Name = "RampinoScena"
		for _, d in gun:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		gun.Parent = ReplicatedStorage
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(bindOffhand)
		if player.Character then
			bindOffhand(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return Tools
