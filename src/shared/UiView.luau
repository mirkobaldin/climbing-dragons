--!strict
-- Collegamento fra modelli modificabili in Studio, immagini e ripiego senza asset.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UiAssets = require(script.Parent:WaitForChild("UiAssets"))
local fallback = require(script.Parent:WaitForChild("UiFallback"))
local UiView = {}
local activeScreens: { [string]: ScreenGui } = {}
local watchedPlayerGui = false

function UiView.node(root: Instance, path: string): any
	local current = root
	for _, name in string.split(path, "/") do
		local nextNode = current:FindFirstChild(name)
		assert(nextNode, "Nodo UI mancante: " .. root.Name .. "/" .. path)
		current = nextNode
	end
	return current
end

-- grandezza dei PNG con i bordi 9-slice (serve a sapere quanto sono spessi i bordi)
local IMAGE_SIZE: { [string]: Vector2 } = {
	panel_main = Vector2.new(512, 512),
	panel_card = Vector2.new(256, 256),
	panel_header = Vector2.new(512, 128),
	panel_toast = Vector2.new(512, 128),
	panel_quest = Vector2.new(512, 192),
	btn_round = Vector2.new(256, 256),
	btn = Vector2.new(384, 128),
	rarity = Vector2.new(256, 256),
}
local function imageSize(name: string): Vector2
	if IMAGE_SIZE[name] then
		return IMAGE_SIZE[name]
	elseif string.find(name, "btn_round", 1, true) then
		return IMAGE_SIZE.btn_round
	elseif string.sub(name, 1, 4) == "btn_" then
		return IMAGE_SIZE.btn
	elseif string.sub(name, 1, 7) == "rarity_" then
		return IMAGE_SIZE.rarity
	end
	return Vector2.new(256, 256)
end

-- scala dei bordi adatta alla grandezza vera: su un pulsante basso i bordi (pensati per 128 px)
-- schiacciavano tutto e il pulsante diventava una riga
local function fitSlice(target: ImageLabel, name: string, slice: Rect)
	local full = imageSize(name)
	local edgeX = slice.Min.X + (full.X - slice.Max.X)
	local edgeY = slice.Min.Y + (full.Y - slice.Max.Y)
	local function resize()
		local s = target.AbsoluteSize
		if s.X < 1 or s.Y < 1 then
			return
		end
		-- cornici dei riquadri sottili (piu' spazio dentro), pulsanti un po' piu' pieni
		local maxScale = if string.sub(name, 1, 4) == "btn_" then 0.5 else 0.3
		target.SliceScale = math.clamp(math.min(s.X * 0.8 / edgeX, s.Y * 0.8 / edgeY), 0.05, maxScale)
	end
	resize()
	if not target:GetAttribute("SliceFitBound") then
		target:SetAttribute("SliceFitBound", true)
		target:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	end
end

function UiView.asset(target: ImageLabel, name: string): boolean
	local id = UiAssets.get(name)
	target.Image = id or ""
	target.Visible = id ~= nil
	local slice = (UiAssets.slices :: { [string]: Rect })[name]
	if slice then
		target.ScaleType = Enum.ScaleType.Slice
		target.SliceCenter = slice
		fitSlice(target, name, slice)
	elseif string.sub(name, 1, 3) == "bg_" then
		target.ScaleType = Enum.ScaleType.Crop
	else
		target.ScaleType = Enum.ScaleType.Fit
	end
	return id ~= nil
end

function UiView.skin(target: GuiObject, name: string)
	target:SetAttribute("UiAsset", name)
	local id = UiAssets.get(name)
	if target:IsA("ImageLabel") then
		UiView.asset(target, name)
		return
	end
	if not id then
		return
	end
	local image = target:FindFirstChild("AssetSurface") :: ImageLabel?
	if not image then
		image = Instance.new("ImageLabel")
		image.Name = "AssetSurface"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.ZIndex = 0
		image.Parent = target
		target.BackgroundTransparency = 1
		for _, child in target:GetChildren() do
			if child:IsA("UIStroke") then
				child.Enabled = false
			end
		end
		if target:IsA("TextButton") or target:IsA("TextLabel") then
			local caption = Instance.new("TextLabel")
			caption.Name = "AssetCaption"
			caption.Size = UDim2.fromScale(1, 1)
			caption.BackgroundTransparency = 1
			caption.ZIndex = 2
			caption.Parent = target
			local function sync()
				caption.Text = target.Text
				caption.Font = target.Font
				caption.TextSize = target.TextSize
				caption.TextScaled = target.TextScaled
				caption.TextWrapped = target.TextWrapped
				caption.RichText = target.RichText
				caption.TextXAlignment = target.TextXAlignment
				caption.TextColor3 = Color3.fromRGB(240, 240, 242)
				caption.TextStrokeTransparency = 0.6
				if name == "btn_close" then
					caption.Text = ""
				elseif string.find(name, "btn_round", 1, true) then
					caption.Position = UDim2.fromScale(0, 0.7)
					caption.Size = UDim2.fromScale(1, 0.28)
					caption.TextSize = 10
				end
			end
			sync()
			target.TextTransparency = 1
			for _, prop in { "Text", "Font", "TextSize", "TextScaled", "TextWrapped" } do
				target:GetPropertyChangedSignal(prop):Connect(sync)
			end
		end
	end
	UiView.asset(image :: ImageLabel, name)
end

function UiView.apply(root: Instance)
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, item in all do
		local key = item:GetAttribute("UiAsset")
		if
			not item:FindFirstAncestor("Templates")
			and item:IsA("GuiObject")
			and type(key) == "string"
			and key ~= ""
		then
			UiView.skin(item, key)
		end
	end
end

function UiView.screen(name: string): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	if not watchedPlayerGui then
		watchedPlayerGui = true
		-- rete di sicurezza: per i primi 2 minuti una sola copia di ogni schermata (la copia
		-- automatica di StarterGui puo' arrivare prima o dopo, con tempi diversi a ogni avvio)
		task.spawn(function()
			for _ = 1, 240 do
				task.wait(0.5)
				for screenName, active in activeScreens do
					if active.Parent then
						for _, other in pg:GetChildren() do
							if other ~= active and other.Name == screenName and other:IsA("ScreenGui") then
								other:Destroy()
							end
						end
					end
				end
			end
		end)
		pg.ChildAdded:Connect(function(child)
			-- ReplicatedFirst puo' anticipare la copia automatica di StarterGui al primo spawn.
			local active = activeScreens[child.Name]
			if active and active.Parent and active ~= child and child:IsA("ScreenGui") then
				child:Destroy()
			end
		end)
	end
	local existing = pg:FindFirstChild(name) or pg:WaitForChild(name, 2)
	if existing and existing:IsA("ScreenGui") then
		activeScreens[name] = existing
		UiView.apply(existing)
		return existing
	end
	-- Nessuna attesa infinita nei place vecchi. La clonazione mantiene un solo esemplare.
	local template = StarterGui:FindFirstChild(name)
	local made = if template and template:IsA("ScreenGui") then template:Clone() else fallback(name)
	activeScreens[name] = made
	made.Parent = pg
	UiView.apply(made)
	return made
end

-- Stile delle schede del menu: righe compatte con testi grandi e il pulsante a destra (prima
-- riquadri alti mezza finestra con scritte minuscole). Le schede in griglia (negozio, zaino,
-- draghi) tengono la cella della griglia: si ingrandiscono solo i testi.
local U = UDim2.new
local function sized(o: Instance?, size: number, bold: boolean?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		o.TextScaled = false
		o.TextSize = size
		o.TextWrapped = true
		if bold ~= nil then
			o.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
		end
	end
end
local function place(o: Instance?, pos: UDim2, size: UDim2, anchor: Vector2?)
	if o and o:IsA("GuiObject") then
		o.AnchorPoint = anchor or Vector2.zero
		o.Position = pos
		o.Size = size
	end
end
local RIGHT = Vector2.new(1, 0.5)
local CARD_STYLE: { [string]: (any) -> () } = {
	UpgradeCard = function(c)
		c.Size = U(1, -10, 0, 124)
		place(c.Icon, U(0, 16, 0, 16), U(0, 60, 0, 60))
		sized(c.Icon, 36)
		place(c.Title, U(0, 90, 0, 12), U(1, -270, 0, 24))
		sized(c.Title, 18, true)
		place(c.Description, U(0, 90, 0, 38), U(1, -270, 0, 22))
		sized(c.Description, 14)
		place(c.Effect, U(0, 90, 0, 62), U(1, -270, 0, 22))
		sized(c.Effect, 14, true)
		place(c.Cost, U(0, 90, 0, 88), U(1, -270, 0, 24))
		sized(c.Cost, 14, true)
		place(c.Action, U(1, -18, 0.5, 0), U(0, 160, 0, 48), RIGHT)
		sized(c.Action, 17, true)
	end,
	BountyCard = function(c)
		c.Size = U(1, -10, 0, 104)
		place(c.Title, U(0, 18, 0, 12), U(1, -220, 0, 24))
		sized(c.Title, 17, true)
		place(c.Progress, U(0, 18, 0, 44), U(1, -220, 0, 14))
		place(c.Reward, U(0, 18, 0, 64), U(1, -220, 0, 28))
		sized(c.Reward, 14)
		place(c.Claim, U(1, -18, 0.5, 0), U(0, 160, 0, 48), RIGHT)
		sized(c.Claim, 16, true)
	end,
	RebirthCard = function(c)
		c.Size = U(1, -10, 0, 240)
		sized(c.Title, 26, true)
		sized(c.Description, 16)
		sized(c.Cost, 16, true)
		sized(c.Action, 18, true)
	end,
	TextCard = function(c)
		sized(c.Text, 16)
	end,
	Heading = function(c)
		if c:IsA("TextLabel") then
			c.Size = U(1, -10, 0, 34)
			sized(c, 20, true)
		end
	end,
	ItemCard = function(c)
		sized(c.Title, 17, true)
		sized(c.Description, 14)
		sized(c.Cost, 16, true)
		sized(c.Buy, 16, true)
	end,
	RecipeCard = function(c)
		sized(c.Title, 17, true)
		sized(c.Description, 14)
		sized(c.Craft, 16, true)
	end,
	InventoryCard = function(c)
		sized(c.Title, 15, true)
		sized(c.Count, 16, true)
	end,
	EggCard = function(c)
		sized(c.Title, 15, true)
		sized(c.Time, 15)
		sized(c.Hatch, 16, true)
	end,
	DragonCard = function(c)
		sized(c.Title, 16, true)
		sized(c.Ability, 13)
		sized(c.Follow, 15, true)
		sized(c.Evolve, 15, true)
		sized(c.Sell, 15, true)
	end,
	Material = function(c)
		sized(c.Text, 14, true)
	end,
}

function UiView.template(name: string, parent: Instance): any
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("MainMenu")
	assert(gui, "MainMenu deve essere pronto prima delle schede")
	local copy = UiView.node(gui, "Templates/" .. name):Clone()
	copy.Visible = true
	local style = CARD_STYLE[name]
	if style then
		-- le altezze minime dei modelli tenevano le righe alte mezza finestra
		local limit = copy:FindFirstChild("SizeLimit")
		if limit and limit:IsA("UISizeConstraint") then
			limit.MinSize = Vector2.zero
		end
		pcall(style, copy)
	end
	copy.Parent = parent
	UiView.apply(copy)
	return copy
end

function UiView.clear(root: Instance)
	for _, child in root:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UiView.open(panel: GuiObject)
	panel.Visible = true
	local scale = panel:FindFirstChild("OpeningScale") :: UIScale?
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "OpeningScale"
		scale.Parent = panel
	end
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	-- Sfuma solo la superficie della finestra, senza alterare la trasparenza dei testi figli.
	local surface = panel:FindFirstChild("AssetSurface")
	if surface and surface:IsA("ImageLabel") then
		surface.ImageTransparency = 1
		TweenService:Create(surface, TweenInfo.new(0.18), { ImageTransparency = 0 }):Play()
	else
		local transparency = panel:GetAttribute("OpeningAlpha")
		if type(transparency) ~= "number" then
			transparency = panel.BackgroundTransparency
			panel:SetAttribute("OpeningAlpha", transparency)
		end
		panel.BackgroundTransparency = 1
		TweenService:Create(panel, TweenInfo.new(0.18), { BackgroundTransparency = transparency }):Play()
	end
end

-- Scala unica di una schermata: tutto si disegna in pixel "logici" per uno schermo di
-- 1280x680 e un UIScale sulla ScreenGui lo adatta (telefono piu' piccolo, monitor grande piu'
-- grande). Restituisce la grandezza logica dello schermo.
function UiView.fitScale(gui: ScreenGui, vp: Vector2): Vector2
	local s = math.clamp(math.min(vp.X / 1280, vp.Y / 680), 0.55, 1.6)
	local u = gui:FindFirstChild("ScalaUI") :: UIScale?
	if not u then
		local nu = Instance.new("UIScale")
		nu.Name = "ScalaUI"
		nu.Parent = gui
		u = nu
	end
	(u :: UIScale).Scale = s
	return vp / s
end

-- posiziona in pixel logici: (ax, x) e (ay, y) come UDim, w e h in pixel; anchor opzionale
function UiView.px(o: GuiObject?, ax: number, x: number, ay: number, y: number, w: number, h: number, anchorX: number?, anchorY: number?)
	if not o then
		return
	end
	o.AnchorPoint = Vector2.new(anchorX or 0, anchorY or 0)
	o.Position = UDim2.new(ax, x, ay, y)
	o.Size = UDim2.fromOffset(w, h)
end

-- testo leggibile: dimensione fissa (niente TextScaled che lo rimpiccioliva) e bordo scuro
function UiView.text(o: Instance?, size: number, bold: boolean?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		o.TextScaled = false
		o.TextSize = size
		o.TextWrapped = true
		o.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamBold
		o.TextStrokeTransparency = 0.45
	end
end

function UiView.viewportChanged(callback: (Vector2) -> ())
	local connection: RBXScriptConnection? = nil
	local function bind()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local function update()
			local topLeft, bottomRight = GuiService:GetGuiInset()
			local size = camera.ViewportSize - topLeft - bottomRight
			callback(Vector2.new(math.max(1, size.X), math.max(1, size.Y)))
		end
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

return UiView
