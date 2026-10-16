--!strict
-- Il personaggio del giocatore in 3D dentro un riquadro (profilo e zaino del menu): copia vera
-- dell'avatar (vestiti, accessori, attrezzo in mano escluso), luce dall'alto a sinistra, gira
-- piano da solo finche' non lo tocchi; col mouse o col dito lo giri trascinando, FRONT lo
-- rimette di fronte. Il trascinamento parte solo sul personaggio: non muove la telecamera del
-- gioco ne' le liste accanto.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local UiKit = require(script.Parent.UiKit)
local player = Players.LocalPlayer

local AvatarView = {}

export type View = {
	frame: ViewportFrame,
	front: TextButton,
	rebuild: () -> (),
}

-- parent: dove mettere il riquadro (prende tutta la sua grandezza); visible: se va disegnato ora
function AvatarView.new(parent: GuiObject, visible: () -> boolean): View
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Avatar3D"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(150, 146, 165)
	vf.LightColor = Color3.fromRGB(255, 240, 215)
	-- luce dall'alto a sinistra (come le cornici della UI)
	vf.LightDirection = Vector3.new(0.6, -1, -0.5)
	vf.ZIndex = 5
	vf.Active = true
	vf.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vf
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vf
	vf.CurrentCamera = camera

	local front = Instance.new("TextButton")
	front.Name = "Fronte"
	-- in basso a destra: in alto copriva la testa del personaggio
	front.AnchorPoint = Vector2.new(1, 1)
	front.Position = UDim2.new(1, -4, 1, -4)
	front.Size = UDim2.fromOffset(60, 26)
	front.ZIndex = 7
	front.Parent = parent
	UiKit.button(front, "secondary")
	front.Text = "FRONT"
	front.TextSize = 13

	local model: Model? = nil
	local modelOf: Instance? = nil
	local center, dist = Vector3.zero, 10
	local function rebuild()
		-- si rifa' solo se il personaggio e' cambiato (respawn)
		if model and modelOf == player.Character and model.Parent then
			return
		end
		modelOf = player.Character
		if model then
			model:Destroy()
			model = nil
		end
		local character = player.Character
		if not character then
			return
		end
		character.Archivable = true
		local ok, clone = pcall(function()
			return character:Clone()
		end)
		if not ok or not clone then
			return
		end
		local m = clone :: Model
		for _, d in m:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") or d:IsA("ForceField") or d:IsA("Sound")
				or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Constraint") or d:IsA("LinearVelocity") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		m:PivotTo(CFrame.new(0, 0, 0))
		m.Parent = world
		local cf, size = m:GetBoundingBox()
		center = cf.Position
		dist = math.max(size.Y, size.X * 0.8) / (2 * math.tan(math.rad(15))) * 1.08
		model = m
	end

	local angle = 0
	local target: number? = nil
	local touched = false
	local dragging: InputObject? = nil
	local lastX = 0
	vf.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			lastX = input.Position.X
			touched = true
			target = nil
		end
	end)
	UIS.InputChanged:Connect(function(input)
		local d = dragging
		if not d then
			return
		end
		if input == d or (d.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
			angle += (input.Position.X - lastX) * 0.012
			lastX = input.Position.X
		end
	end)
	UIS.InputEnded:Connect(function(input)
		local d = dragging
		if d and (input == d or input.UserInputType == d.UserInputType) then
			dragging = nil
		end
	end)
	front.Activated:Connect(function()
		touched = true
		-- l'angolo piu' vicino che guarda avanti (senza fare il giro lungo)
		target = math.round(angle / (2 * math.pi)) * 2 * math.pi
	end)
	RunService.RenderStepped:Connect(function(dt)
		if not model or not vf.Parent or not visible() then
			return
		end
		if target then
			angle += (target - angle) * math.min(1, dt * 8)
			if math.abs(target - angle) < 0.002 then
				angle = target
				target = nil
			end
		elseif not touched then
			angle += dt * 0.6
		end
		local m = model :: Model
		m:PivotTo(CFrame.Angles(0, angle, 0))
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0.6, -dist), center + Vector3.new(0, 0.3, 0))
	end)
	player.CharacterAdded:Connect(function()
		task.delay(1, rebuild)
	end)
	return { frame = vf, front = front, rebuild = rebuild }
end

return AvatarView
