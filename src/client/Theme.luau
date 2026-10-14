--!strict
-- Stile comune dell'interfaccia: colori, angoli arrotondati, bordi, testi, pulsanti e
-- "immagini" 3D (ViewportFrame) di draghi, uova, minerali e attrezzi, senza caricare immagini.
-- Pulsanti grandi abbastanza per il dito (min 44 px) perche' si gioca anche da telefono.

local Theme = {}
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UiView = require(Shared:WaitForChild("UiView"))
local UiAssets = require(Shared:WaitForChild("UiAssets"))

-- Token cromatici unici: anche il ripiego senza PNG mantiene lo stile colorato.
Theme.BG = Color3.fromRGB(30, 58, 122)
Theme.PANEL = Color3.fromRGB(43, 76, 155)
Theme.CARD = Color3.fromRGB(24, 48, 106)
Theme.OUTLINE = Color3.fromRGB(11, 22, 51)
Theme.TEXT = Color3.fromRGB(255, 255, 255)
Theme.MUTED = Color3.fromRGB(205, 224, 248)
Theme.ACCENT = Color3.fromRGB(255, 210, 63)
Theme.GOOD = Color3.fromRGB(91, 217, 74)
Theme.BAD = Color3.fromRGB(255, 77, 94)
Theme.BLUE = Color3.fromRGB(63, 184, 255)
Theme.TEAL = Color3.fromRGB(34, 211, 197)
Theme.ORANGE = Color3.fromRGB(255, 138, 42)
Theme.PURPLE = Color3.fromRGB(155, 91, 255)
Theme.PINK = Color3.fromRGB(255, 111, 181)
Theme.DISABLED = Color3.fromRGB(185, 200, 221)
Theme.COIN = Theme.ACCENT
Theme.GRADE = { C = Theme.DISABLED, B = Theme.BLUE, A = Theme.GOOD, S = Theme.ACCENT }
Theme.RARITY = {
	Comune = { Theme.DISABLED, Color3.fromRGB(100, 130, 170) },
	Raro = { Theme.BLUE, Theme.PANEL },
	Epico = { Theme.PURPLE, Color3.fromRGB(103, 57, 187) },
	Leggendario = { Theme.ACCENT, Theme.ORANGE },
}
Theme.ELEMENT = {
	Roccia = Theme.ORANGE, Gelo = Theme.BLUE, Cosmico = Theme.PURPLE,
	Tempesta = Theme.TEAL, Eclissi = Theme.PINK, Fulmine = Theme.PURPLE,
	Ossa = Theme.MUTED, Gas = Theme.GOOD,
}
Theme.MENU = { Store = Theme.ACCENT, Backpack = Theme.ORANGE, Dragons = Theme.PURPLE,
	Crafting = Theme.TEAL, Upgrades = Theme.GOOD, Teleport = Theme.BLUE }

function Theme.fitText(o: TextLabel | TextButton, size: number, wrapped: boolean?)
	o.TextSize = math.max(12, size)
	o.TextScaled = true
	o.TextTruncate = Enum.TextTruncate.AtEnd
	o.TextWrapped = wrapped == true and not o:IsA("TextButton")
	o.TextStrokeColor3 = Theme.OUTLINE
	o.TextStrokeTransparency = 0
	local limit = o:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = math.max(12, size)
	limit.Parent = o
	local pad = o:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 2)
	pad.Parent = o
	local caption = o:FindFirstChild("AssetCaption")
	if caption and caption:IsA("TextLabel") then Theme.fitText(caption, size, wrapped) end
end

function Theme.action(button: TextButton, kind: string, disabled: boolean?)
	local k = if disabled then "off" else kind
	local colors = { buy = Theme.GOOD, sell = Theme.BAD, main = Theme.ACCENT, alt = Theme.BLUE, off = Theme.DISABLED }
	button.BackgroundColor3 = colors[k] or Theme.BLUE
	button:SetAttribute("ButtonKind", k)
	button:SetAttribute("UiDisabled", disabled == true)
	local tint = button:FindFirstChild("Tinta")
	if tint then tint:Destroy() end
	button.ClipsDescendants = true
	local stroke = button:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color, stroke.Thickness, stroke.Transparency = Theme.OUTLINE, 2, 0
	stroke.Parent = button
	local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	UiView.skin(button, "btn_" .. k .. "_v3_normal")
	Theme.fitText(button, 22, false)
end

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
	f.ClipsDescendants = true
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
	l.TextWrapped = false
	l.RichText = true
	l.TextStrokeTransparency = 0.6
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Parent = parent
	Theme.fitText(l, size)
	return l
end

function Theme.button(parent: Instance, text: string, color: Color3?, size: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size or UDim2.new(0, 140, 0, 52)
	b.BackgroundColor3 = color or Theme.ACCENT
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = Theme.TEXT
	b.AutoButtonColor = true
	b.Parent = parent
	Theme.corner(b, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(44, 44)
	minimum.Parent = b
	b.TextStrokeTransparency = 0.6
	Theme.fitText(b, 22)
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
	-- piu' luce: i draghi scuri (Eclissi, Fulmine) nelle schede sembravano macchie nere
	vf.Ambient = Color3.fromRGB(205, 205, 215)
	vf.LightColor = Color3.fromRGB(255, 252, 245)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.9)
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
	-- inquadratura stretta: il modello riempie il riquadro (prima stava piccolo in mezzo)
	local dist = radius / math.tan(math.rad(17.5)) * 0.82
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
	elseif id == "Rampino" then
		-- il modello vero del rampino (lo mette il server in ReplicatedStorage), se c'e'
		local gun = game:GetService("ReplicatedStorage"):FindFirstChild("RampinoScena")
		if gun then
			for _, c in gun:GetChildren() do
				c:Clone().Parent = m
			end
		else
			part(Vector3.new(0.4, 1.6, 0.4), CFrame.new(0, -0.4, 0), Color3.fromRGB(40, 40, 44), nil, Enum.Material.Metal)
			for k = 0, 2 do
				part(Vector3.new(0.2, 0.9, 0.2), CFrame.Angles(0, k * 2.1, 0) * CFrame.new(0, 0.7, 0.3) * CFrame.Angles(0.8, 0, 0), Color3.fromRGB(170, 174, 180), nil, Enum.Material.Metal)
			end
			part(Vector3.new(0.5, 1.2, 1.2), CFrame.new(0.5, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.PartType.Cylinder, Enum.Material.Fabric)
		end
	elseif id == "Ramponi" then
		-- telaio d'acciaio sotto lo scarpone, con le punte
		local steel = Color3.fromRGB(175, 180, 188)
		part(Vector3.new(1.3, 0.9, 2.6), CFrame.new(0, 0.55, 0), Color3.fromRGB(60, 50, 44), nil, Enum.Material.Leather)
		part(Vector3.new(1.4, 0.15, 2.8), CFrame.new(0, 0, 0), steel, nil, Enum.Material.Metal)
		for _, z in { -1.2, -0.6, 0, 0.6, 1.2 } do
			for _, x in { -0.6, 0.6 } do
				part(Vector3.new(0.15, 0.6, 0.15), CFrame.new(x, -0.35, z), steel, nil, Enum.Material.Metal)
			end
		end
		part(Vector3.new(0.15, 0.15, 0.7), CFrame.new(-0.3, -0.05, -1.65) * CFrame.Angles(0.5, 0, 0), steel, nil, Enum.Material.Metal)
		part(Vector3.new(0.15, 0.15, 0.7), CFrame.new(0.3, -0.05, -1.65) * CFrame.Angles(0.5, 0, 0), steel, nil, Enum.Material.Metal)
	elseif id == "Tuta" then
		-- giacca imbottita arancione con cappuccio
		part(Vector3.new(2, 2.2, 1.1), CFrame.new(), color, nil, Enum.Material.Fabric)
		part(Vector3.new(0.8, 2, 0.9), CFrame.new(-1.35, -0.1, 0) * CFrame.Angles(0, 0, -0.2), color, nil, Enum.Material.Fabric)
		part(Vector3.new(0.8, 2, 0.9), CFrame.new(1.35, -0.1, 0) * CFrame.Angles(0, 0, 0.2), color, nil, Enum.Material.Fabric)
		part(Vector3.new(1.3, 0.9, 1), CFrame.new(0, 1.45, 0.1), Color3.fromRGB(50, 50, 56), Enum.PartType.Ball, Enum.Material.Fabric)
		part(Vector3.new(0.12, 2.1, 1.15), CFrame.new(0, 0, 0), Color3.fromRGB(40, 40, 44), nil, Enum.Material.Metal)
		for _, y in { -0.5, 0.3 } do
			part(Vector3.new(2.05, 0.18, 1.15), CFrame.new(0, y, 0), Color3.fromRGB(200, 90, 40), nil, Enum.Material.Fabric)
		end
	elseif id == "PiccoRinforzato" then
		-- piccone col manico di legno e la testa dorata
		part(Vector3.new(0.3, 3, 0.3), CFrame.new(0, -0.3, 0), Color3.fromRGB(110, 76, 46), nil, Enum.Material.Wood)
		part(Vector3.new(2.8, 0.45, 0.4), CFrame.new(0, 1.2, 0), color, nil, Enum.Material.Metal)
		part(Vector3.new(0.6, 0.35, 0.35), CFrame.new(-1.55, 1.05, 0) * CFrame.Angles(0, 0, 0.5), color, nil, Enum.Material.Metal)
		part(Vector3.new(0.6, 0.35, 0.35), CFrame.new(1.55, 1.05, 0) * CFrame.Angles(0, 0, -0.5), color, nil, Enum.Material.Metal)
	elseif id == "Bende" then
		part(Vector3.new(1.2, 1.6, 1.6), CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 236, 226), Enum.PartType.Cylinder, Enum.Material.Fabric)
		part(Vector3.new(1.25, 0.5, 0.5), CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(200, 196, 186), Enum.PartType.Cylinder, Enum.Material.Fabric)
		part(Vector3.new(0.12, 0.6, 1.4), CFrame.new(0, -0.6, 0.6) * CFrame.Angles(0.4, 0, 0), Color3.fromRGB(240, 236, 226), nil, Enum.Material.Fabric)
		part(Vector3.new(0.5, 0.15, 0.5), CFrame.new(0, 0.82, 0), Color3.fromRGB(220, 50, 50))
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

-- Icone degli oggetti del negozio e degli attrezzi: le immagini del set dell'interfaccia (stesso
-- stile delle altre) invece dei modellini fatti di Part. Le "act_" sono bianche: si colorano.
Theme.ITEM_ICONS = {
	Pitons = "item_Pitons", Chiodi = "item_Chiodi", Medkit = "item_Medkit",
	Bende = "item_Bende", Thermos = "item_Thermos", Tuta = "item_Tuta",
	Torcia = "item_Torcia", Parapendio = "item_Parapendio", Ramponi = "item_Ramponi",
	Rampino = "item_Rampino", PiccoRinforzato = "item_PiccoRinforzato", Sella = "item_Sella",
	MysteryEgg = "item_MysteryEgg", RareEgg = "item_RareEgg",
	Piccozza = "item_Piccozza", Piccone = "item_Piccone",
} :: { [string]: string }

function Theme.itemIcon(image: ImageLabel, id: string, fallback: Instance?)
	local asset = Theme.ITEM_ICONS[id] or ""
	if id == "Sella" or id == "Parapendio" or id == "Chiodi" then fallback = nil end
	Theme.assetPreview(image, asset, fallback)
	image.ImageColor3 = if string.sub(asset, 1, 4) == "act_" then Color3.fromRGB(255, 205, 110) else Color3.new(1, 1, 1)
end

-- L'immagine sostituisce l'anteprima 3D solo dopo l'inserimento del suo ID.
function Theme.assetPreview(image: ImageLabel, asset: string, object: Instance?)
	for _, child in image:GetChildren() do
		if child:IsA("ViewportFrame") or child.Name == "IconFallback" then child:Destroy() end
	end
	UiView.asset(image, asset)
	if UiAssets.get(asset) then return end
	image.Visible = true
	if object then
		Theme.viewport(image, object, UDim2.fromScale(1, 1), false)
	else
		-- ID ancora vuoto: nome breve pertinente, mai un'icona di un altro oggetto.
		local Names = require(Shared.Names)
		local id = asset:gsub("^item_", "")
		local titles = { TravelHub = "Base camp", TravelHome = "Home", TravelArena = "Arena", TravelGym = "Gym", TravelIsland = "Island", TravelCamp = "Camp", Piccozza = "Ice axe", Piccone = "Pickaxe", MysteryEgg = "Mystery egg", RareEgg = "Rare egg", Pitons = "Pitons", Medkit = "Medkit", Thermos = "Thermos" }
		for _, recipe in require(Shared.Gear).RECIPES do titles[recipe.id] = recipe.name end
		for _, upgrade in require(Shared.UpgradeConfig).UPGRADES do titles["Upgrade" .. upgrade.id] = upgrade.name end
		local hint = Theme.label(image, titles[id] or Names.t(id), 12, Theme.TEXT, true)
		hint.Name = "IconFallback"
		hint.Size = UDim2.fromScale(1, 1)
		hint.TextWrapped = true
		hint.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function Theme.paint(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, o in all do
		if o:FindFirstAncestor("Templates") then continue end
		if o:IsA("TextLabel") or o:IsA("TextButton") then
			Theme.fitText(o, math.max(12, o.TextSize), o.TextWrapped)
		end
		if o:IsA("GuiObject") then
			local asset = o:GetAttribute("UiAsset")
			if type(asset) == "string" and asset:match("^panel_") then
				o.BackgroundColor3 = Theme.PANEL
				o.BackgroundTransparency = 0
				o.ClipsDescendants = true
				local gradient = o:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
				gradient.Color = ColorSequence.new(Theme.TEXT, Theme.PANEL:Lerp(Theme.TEXT, 0.65))
				gradient.Rotation = 90
				gradient.Parent = o
			end
			if o:IsA("TextButton") and o.Name ~= "Close" and not o:GetAttribute("SemanticBound") then
				o:SetAttribute("SemanticBound", true)
				local function update()
					if o:GetAttribute("UiNative") then return end
					local text = o.Text:lower()
					local kind = if text:match("^sell") or text == "sure?" then "sell"
						elseif text:match("^buy") or text:match("^craft") or text:match("^hatch") or text == "follow" then "buy"
						elseif text:match("^upgrade") or text:match("^unlock") or text:match("^rebirth") or text == "ride" or text == "evolve" then "main"
						else "alt"
					if o.Parent and o.Parent.Name == "Tabs" then return end
					Theme.action(o, kind, text == "not ready yet" or text == "owned" or text == "max")
				end
				o:GetPropertyChangedSignal("Text"):Connect(update)
				update()
			end
		end
	end
end

UiView.setStyler(Theme.paint, Theme)

return Theme
