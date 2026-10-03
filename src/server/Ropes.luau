--!strict
-- Chiodi e corde. Il client chiede di piantare un chiodo; il server controlla distanza e
-- scorte, crea il chiodo nel mondo e una corda (RopeConstraint) tra il chiodo e il giocatore.
-- La corda si allunga mentre sali (il client la "fila" e ce lo comunica) e ti ferma se cadi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClimbConfig = require(ReplicatedStorage.Shared.ClimbConfig)

local Ropes = {}

local ROPE_NAME = "BelayRope"
local pitonsByPlayer: { [Player]: { BasePart } } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function releaseRope(player: Player)
	local root = rootOf(player)
	local rope = root and root:FindFirstChild(ROPE_NAME)
	if rope then
		rope:Destroy()
	end
end

local function makePiton(position: Vector3, normal: Vector3): (BasePart, Attachment)
	local piton = Instance.new("Part")
	piton.Name = "Piton"
	piton.Size = Vector3.new(0.35, 0.35, 1.2)
	piton.CFrame = CFrame.lookAt(position + normal * 0.3, position - normal)
	piton.Anchored = true
	piton.CanCollide = false
	piton.Material = Enum.Material.Metal
	piton.Color = Color3.fromRGB(90, 92, 98)
	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.15, 0.8, 0.8)
	ring.CFrame = piton.CFrame * CFrame.new(0, 0, 0.55)
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Metal
	ring.Color = Color3.fromRGB(200, 170, 60)
	ring.Parent = piton
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 0, 0.55)
	attachment.Parent = piton
	return piton, attachment
end

local function placePiton(player: Player, position: any, normal: any)
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" or normal.Magnitude < 0.5 then
		return
	end
	local root = rootOf(player)
	local count = player:GetAttribute("Pitons") or 0
	if not root or count <= 0 or (position - root.Position).Magnitude > ClimbConfig.PLACE_RANGE then
		return
	end
	-- Il punto deve essere davvero su una superficie
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local check = workspace:Raycast(position + normal.Unit * 1.5, -normal.Unit * 3, params)
	if not check then
		return
	end

	local folder = workspace:FindFirstChild("Pitons") or Instance.new("Folder")
	folder.Name = "Pitons"
	folder.Parent = workspace
	local piton, attachment = makePiton(check.Position, check.Normal)
	piton.Parent = folder
	player:SetAttribute("Pitons", count - 1)
	player:SetAttribute("PitonsPlaced", (player:GetAttribute("PitonsPlaced") or 0) + 1) -- per il tutorial

	local list = pitonsByPlayer[player] or {}
	pitonsByPlayer[player] = list
	table.insert(list, piton)
	if #list > ClimbConfig.PITONS_IN_WORLD then
		table.remove(list, 1):Destroy()
	end

	-- Corda nuova dal chiodo al giocatore
	releaseRope(player)
	local rootAttachment = root:FindFirstChild("RopeAttachment") :: Attachment?
	if not rootAttachment then
		local a = Instance.new("Attachment")
		a.Name = "RopeAttachment"
		a.Parent = root
		rootAttachment = a
	end
	local rope = Instance.new("RopeConstraint")
	rope.Name = ROPE_NAME
	rope.Attachment0 = attachment
	rope.Attachment1 = rootAttachment
	rope.Length = (attachment.WorldPosition - root.Position).Magnitude + ClimbConfig.ROPE_SLACK
	rope.Visible = true
	rope.Thickness = 0.12
	rope.Color = BrickColor.new("Bright orange")
	rope.Restitution = 0.05
	rope.Parent = root
end

local function updateRope(player: Player, length: any)
	if typeof(length) ~= "number" or length ~= length then
		return
	end
	local root = rootOf(player)
	local rope = root and root:FindFirstChild(ROPE_NAME) :: RopeConstraint?
	if rope then
		rope.Length = math.clamp(length, 0.5, ClimbConfig.ROPE_MAX)
	end
end

function Ropes.setup(remotes: { [string]: RemoteEvent })
	remotes.PlacePiton.OnServerEvent:Connect(placePiton)
	remotes.UpdateRope.OnServerEvent:Connect(updateRope)
	remotes.ReleaseRope.OnServerEvent:Connect(releaseRope)

	local function onPlayer(player: Player)
		player:SetAttribute("Pitons", ClimbConfig.PITONS_START)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, piton in pitonsByPlayer[player] or {} do
			piton:Destroy()
		end
		pitonsByPlayer[player] = nil
	end)
end

-- Usato dai campi base per rifornire i chiodi
function Ropes.refill(player: Player)
	player:SetAttribute("Pitons", ClimbConfig.PITONS_MAX)
end

return Ropes
