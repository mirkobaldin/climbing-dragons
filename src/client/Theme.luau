--!strict
-- Stile comune dell'interfaccia: colori, angoli arrotondati, bordi, testi, pulsanti e
-- "immagini" 3D (ViewportFrame) di draghi, uova, minerali e attrezzi, senza caricare immagini.
-- Pulsanti grandi abbastanza per il dito (min 44 px) perche' si gioca anche da telefono.

local Theme = {}

Theme.BG = Color3.fromRGB(16, 18, 24)
Theme.PANEL = Color3.fromRGB(28, 31, 39)
Theme.CARD = Color3.fromRGB(38, 42, 52)
Theme.TEXT = Color3.fromRGB(240, 240, 242)
Theme.MUTED = Color3.fromRGB(165, 170, 182)
Theme.ACCENT = Color3.fromRGB(255, 196, 80)
Theme.GOOD = Color3.fromRGB(110, 205, 120)
Theme.BAD = Color3.fromRGB(235, 95, 85)
Theme.BLUE = Color3.fromRGB(90, 170, 255)
Theme.COIN = Color3.fromRGB(255, 205, 60)

Theme.ORE_COLORS = {
	Carbone = Color3.fromRGB(45, 45, 50),
	Ferro = Color3.fromRGB(170, 170, 176),
	Oro = Color3.fromRGB(255, 180, 20),
	Cristallo = Color3.fromRGB(0, 225, 255),
	Rubino = Color3.fromRGB(230, 25, 40),
	Cosmico = Color3.fromRGB(230, 40, 200),
}

function Theme.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 255, 255)
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.85
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function Theme.padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
end

function Theme.frame(parent: Instance, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color or Theme.PANEL
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- Sfumatura verticale leggera: le schede smettono di sembrare rettangoli piatti
function Theme.gradient(parent: Instance, top: Color3?, bottom: Color3?, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or Color3.fromRGB(255, 255, 255), bottom or Color3.fromRGB(190, 190, 200))
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Theme.label(parent: Instance, text: string, size: number, color: Color3?, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or Theme.TEXT
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.RichText = true
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Parent = parent
	return l
end

function Theme.button(parent: Instance, text: string, color: Color3?, size: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.new(0, 110, 0, 40)
	b.BackgroundColor3 = color or Theme.ACCENT
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Theme.BG
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.corner(b, 10)
	return b
end

function Theme.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
end

function Theme.scroll(parent: Instance): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = Theme.MUTED
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.Size = UDim2.fromScale(1, 1)
	s.Parent = parent
	return s
end

-- Scatola che contiene tutte le parti di un oggetto (Model o Tool)
local function bounds(root: Instance): (Vector3, number)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	local any = false
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			any = true
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = d.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
						minV = minV:Min(p)
						maxV = maxV:Max(p)
					end
				end
			end
		end
	end
	if not any then
		return Vector3.zero, 2
	end
	return (minV + maxV) / 2, (maxV - minV).Magnitude / 2
end

-- "Immagine" 3D di un oggetto: lo clona in un ViewportFrame e ci punta una camera
function Theme.viewport(parent: Instance, object: Instance?, size: UDim2, spin: boolean?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Size = size
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-1, -1.5, -0.8)
	vf.Parent = parent
	if not object then
		return vf
	end
	local clone = object:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	clone.Parent = vf
	local center, radius = bounds(clone)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	local dist = radius / math.tan(math.rad(17.5)) * 1.05
	local dir = Vector3.new(0.9, 0.55, -1).Unit
	camera.CFrame = CFrame.lookAt(center + dir * dist, center)
	camera.Parent = vf
	vf.CurrentCamera = camera
	if spin then
		task.spawn(function()
			local a = 0
			while vf.Parent do
				a += 0.03
				local d = Vector3.new(math.cos(a), 0.55, math.sin(a)).Unit
				camera.CFrame = CFrame.lookAt(center + d * dist, center)
				task.wait(1 / 30)
			end
		end)
	end
	return vf
end

-- Piccolo modello di minerale (tre sassi del colore giusto) per le icone
function Theme.oreModel(ore: string): Model
	local m = Instance.new("Model")
	local color = Theme.ORE_COLORS[ore] or Color3.fromRGB(150, 150, 150)
	for k, o in { Vector3.new(0, 0, 0), Vector3.new(0.9, -0.2, 0.3), Vector3.new(-0.7, -0.25, 0.5) } do
		local p = Instance.new("Part")
		p.Size = Vector3.new(1.4, 1.1, 1.2) * (1 - (k - 1) * 0.2)
		p.CFrame = CFrame.new(o) * CFrame.Angles(k * 0.7, k * 1.3, k * 0.4)
		p.Color = color
		p.Material = if ore == "Cristallo" or ore == "Rubino" or ore == "Cosmico" then Enum.Material.Glass else Enum.Material.Slate
		p.Parent = m
	end
	return m
end

-- Icone semplici costruite con Part per gli oggetti del negozio
function Theme.itemModel(id: string, color: Color3): Model
	local m = Instance.new("Model")
	local function part(size: Vector3, cf: CFrame, c: Color3, shape: Enum.PartType?, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Parent = m
	end
	if id == "Medkit" then
		part(Vector3.new(2.4, 1.6, 1), CFrame.new(), color)
		part(Vector3.new(0.4, 1.1, 1.05), CFrame.new(), Color3.new(1, 1, 1))
		part(Vector3.new(1.1, 0.4, 1.05), CFrame.new(), Color3.new(1, 1, 1))
	elseif id == "Thermos" then
		part(Vector3.new(2.4, 1, 1), CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, Enum.Material.Metal)
		part(Vector3.new(0.5, 0.7, 0.7), CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 40, 44), Enum.PartType.Cylinder)
	elseif id == "Torcia" then
		part(Vector3.new(0.35, 2.6, 0.35), CFrame.new(0, -0.3, 0), Color3.fromRGB(110, 76, 46), nil, Enum.Material.Wood)
		part(Vector3.new(0.7, 0.8, 0.7), CFrame.new(0, 1.2, 0), Color3.fromRGB(60, 44, 30), nil, Enum.Material.Fabric)
		part(Vector3.new(0.6, 0.9, 0.6), CFrame.new(0, 1.9, 0), Color3.fromRGB(255, 150, 50), Enum.PartType.Ball, Enum.Material.Neon)
	elseif id == "Pitons" then
		for k = -1, 1 do
			part(Vector3.new(0.25, 2, 0.25), CFrame.new(k * 0.6, 0, 0) * CFrame.Angles(0, 0, k * 0.2), color, nil, Enum.Material.Metal)
			part(Vector3.new(0.7, 0.2, 0.7), CFrame.new(k * 0.6 + k * 0.2, 1, 0), color, Enum.PartType.Cylinder, Enum.Material.Metal)
		end
	else
		part(Vector3.new(2, 2, 2), CFrame.new(), color, Enum.PartType.Ball)
	end
	return m
end

return Theme
