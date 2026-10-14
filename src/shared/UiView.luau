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

-- Stile delle schede del menu, tutto in pixel logici (la ScreenGui ha una scala unica, vedi
-- fitScale). Prima le schede erano alte in percentuale della lista (0.5 = mezza finestra):
-- enormi, con i testi minuscoli e, nella lista a scorrimento automatico, gli ultimi elementi
-- non si raggiungevano. Righe: immagine a sinistra, testi al centro, pulsanti a destra.
local U = UDim2.new
local function sized(o: Instance?, size: number, bold: boolean?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		o.TextScaled = false
		o.TextSize = size
		o.TextWrapped = true
		o.TextTruncate = Enum.TextTruncate.AtEnd
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
local function left(o: Instance?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		o.TextXAlignment = Enum.TextXAlignment.Left
		o.TextYAlignment = Enum.TextYAlignment.Center
	end
end
local RIGHT = Vector2.new(1, 0.5)
local BUTTONS = 172 -- spazio a destra per i pulsanti
local CARD_STYLE: { [string]: (any) -> () } = {
	UpgradeCard = function(c)
		c.Size = U(1, -12, 0, 118)
		place(c.Icon, U(0, 14, 0, 14), U(0, 64, 0, 64))
		sized(c.Icon, 36)
		place(c.Title, U(0, 92, 0, 10), U(1, -92 - BUTTONS, 0, 24))
		sized(c.Title, 18, true)
		place(c.Description, U(0, 92, 0, 34), U(1, -92 - BUTTONS, 0, 20))
		sized(c.Description, 14)
		place(c.Effect, U(0, 92, 0, 56), U(1, -92 - BUTTONS, 0, 20))
		sized(c.Effect, 14, true)
		place(c.Cost, U(0, 92, 0, 82), U(1, -92 - BUTTONS, 0, 22))
		sized(c.Cost, 14, true)
		for _, o in { c.Title, c.Description, c.Effect, c.Cost } do
			left(o)
		end
		place(c.Action, U(1, -14, 0.5, 0), U(0, BUTTONS - 26, 0, 46), RIGHT)
		sized(c.Action, 16, true)
	end,
	BountyCard = function(c)
		c.Size = U(1, -12, 0, 96)
		place(c.Title, U(0, 16, 0, 10), U(1, -16 - BUTTONS, 0, 24))
		sized(c.Title, 17, true)
		place(c.Progress, U(0, 16, 0, 40), U(1, -16 - BUTTONS, 0, 16))
		place(c.Reward, U(0, 16, 0, 62), U(1, -16 - BUTTONS, 0, 24))
		sized(c.Reward, 14)
		left(c.Title)
		left(c.Reward)
		place(c.Claim, U(1, -14, 0.5, 0), U(0, BUTTONS - 26, 0, 46), RIGHT)
		sized(c.Claim, 16, true)
	end,
	RebirthCard = function(c)
		c.Size = U(1, -12, 0, 230)
		place(c.Title, U(0, 16, 0, 12), U(1, -32, 0, 30))
		sized(c.Title, 24, true)
		place(c.Description, U(0, 16, 0, 48), U(1, -32, 0, 96))
		sized(c.Description, 15)
		c.Description.TextTruncate = Enum.TextTruncate.None
		place(c.Cost, U(0, 16, 0, 148), U(1, -32, 0, 22))
		sized(c.Cost, 15, true)
		place(c.Action, U(0.5, 0, 1, -14), U(0, 240, 0, 46), Vector2.new(0.5, 1))
		sized(c.Action, 17, true)
	end,
	TextCard = function(c)
		-- alta quanto il testo (AutomaticSize dentro la lista non contava le righe a capo)
		local label = c.Text :: TextLabel
		c.Size = U(1, -12, 0, 60)
		place(label, U(0, 16, 0, 12), U(1, -32, 0, 36))
		sized(label, 15)
		label.TextTruncate = Enum.TextTruncate.None
		left(label)
		label.TextYAlignment = Enum.TextYAlignment.Top
		local function fit()
			-- larghezza vera senza la scala della schermata (UIScale), poi l'altezza del testo a capo
			local scale = 1
			local gui = c:FindFirstAncestorWhichIsA("ScreenGui")
			local u = gui and gui:FindFirstChild("ScalaUI")
			if u and u:IsA("UIScale") then
				scale = u.Scale
			end
			local width = label.AbsoluteSize.X / scale
			if width < 10 then
				return
			end
			local size = game:GetService("TextService"):GetTextSize(label.Text, label.TextSize, label.Font, Vector2.new(width, 10000))
			local h = math.max(20, size.Y + 4)
			label.Size = U(1, -32, 0, h)
			c.Size = U(1, -12, 0, h + 26)
		end
		label:GetPropertyChangedSignal("Text"):Connect(fit)
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
	end,
	Heading = function(c)
		if c:IsA("TextLabel") then
			c.Size = U(1, -12, 0, 32)
			sized(c, 19, true)
			left(c)
		end
	end,
	ItemCard = function(c)
		c.Size = U(1, -12, 0, 104)
		place(c.Icon, U(0, 12, 0.5, 0), U(0, 80, 0, 80), Vector2.new(0, 0.5))
		place(c.Title, U(0, 104, 0, 10), U(1, -104 - BUTTONS, 0, 24))
		sized(c.Title, 17, true)
		place(c.Description, U(0, 104, 0, 34), U(1, -104 - BUTTONS, 0, 32))
		sized(c.Description, 14)
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		place(c.Coin, U(0, 104, 0, 68), U(0, 22, 0, 22))
		place(c.Cost, U(0, 132, 0, 67), U(1, -132 - BUTTONS, 0, 24))
		sized(c.Cost, 15, true)
		for _, o in { c.Title, c.Description, c.Cost } do
			left(o)
		end
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		place(c.Buy, U(1, -14, 0.5, 0), U(0, BUTTONS - 26, 0, 46), RIGHT)
		sized(c.Buy, 16, true)
		place(c.SellActions, U(1, -14, 0.5, 0), U(0, BUTTONS - 26, 0, 88), RIGHT)
		place(c.SellActions.One, U(0, 0, 0, 0), U(1, 0, 0, 40))
		place(c.SellActions.All, U(0, 0, 1, 0), U(1, 0, 0, 40), Vector2.new(0, 1))
		sized(c.SellActions.One, 15, true)
		sized(c.SellActions.All, 15, true)
	end,
	RecipeCard = function(c)
		c.Size = U(1, -12, 0, 118)
		place(c.Preview, U(0, 12, 0.5, 0), U(0, 92, 0, 92), Vector2.new(0, 0.5))
		place(c.Title, U(0, 116, 0, 10), U(1, -116 - BUTTONS, 0, 24))
		sized(c.Title, 17, true)
		place(c.Description, U(0, 116, 0, 34), U(1, -116 - BUTTONS, 0, 36))
		sized(c.Description, 13)
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		place(c.Materials, U(0, 116, 0, 76), U(1, -116 - BUTTONS, 0, 30))
		left(c.Title)
		left(c.Description)
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		place(c.Craft, U(1, -14, 0.5, 0), U(0, BUTTONS - 26, 0, 46), RIGHT)
		sized(c.Craft, 16, true)
	end,
	Material = function(c)
		place(c.Icon, U(0, 0, 0.5, 0), U(0, 28, 0, 28), Vector2.new(0, 0.5))
		place(c.Text, U(0, 32, 0, 0), U(1, -32, 1, 0))
		sized(c.Text, 14, true)
		left(c.Text)
	end,
	-- zaino: tessere quadrate in griglia (cella fissa, vedi MainMenu)
	InventoryCard = function(c)
		place(c.Icon, U(0.5, 0, 0, 10), U(0, 84, 0, 84), Vector2.new(0.5, 0))
		place(c.Title, U(0, 8, 1, -34), U(1, -16, 0, 22))
		sized(c.Title, 14, true)
		c.Title.TextXAlignment = Enum.TextXAlignment.Center
		place(c.Count, U(1, -12, 0, 12), U(0, 70, 0, 20), Vector2.new(1, 0))
		sized(c.Count, 15, true)
		c.Count.TextXAlignment = Enum.TextXAlignment.Right
		c.Count.TextStrokeTransparency = 0.3
		c.Count.ZIndex = 5
	end,
	EggCard = function(c)
		c.Size = U(1, -10, 0, 104)
		place(c.Icon, U(0, 10, 0.5, 0), U(0, 76, 0, 76), Vector2.new(0, 0.5))
		place(c.Title, U(0, 94, 0, 8), U(1, -102, 0, 40))
		sized(c.Title, 15, true)
		place(c.Time, U(0, 94, 0, 50), U(1, -102, 0, 18))
		sized(c.Time, 13)
		place(c.Hatch, U(0, 94, 1, -8), U(1, -102, 0, 32), Vector2.new(0, 1))
		sized(c.Hatch, 15, true)
		left(c.Title)
		left(c.Time)
	end,
	-- draghi: anteprima grande a sinistra, testi, barra XP e una riga di pulsanti (DragonUI li
	-- distribuisce secondo quelli visibili)
	DragonCard = function(c)
		c.Size = U(1, -12, 0, 140)
		place(c.Preview, U(0, 10, 0.5, 0), U(0, 120, 0, 120), Vector2.new(0, 0.5))
		place(c.Element, U(0, 12, 0, 12), U(0, 30, 0, 30))
		c.Element.ZIndex = 5
		place(c.Title, U(0, 142, 0, 10), U(1, -154, 0, 22))
		sized(c.Title, 16, true)
		place(c.Ability, U(0, 142, 0, 34), U(1, -154, 0, 32))
		sized(c.Ability, 13)
		left(c.Title)
		left(c.Ability)
		c.Ability.TextYAlignment = Enum.TextYAlignment.Top
		place(c.XP, U(0, 142, 0, 70), U(1, -154, 0, 18))
		sized(c.XP.Text, 12, true)
		for _, b in { c.Follow, c.Evolve, c.Sell } do
			sized(b, 14, true)
		end
	end,
}

-- scheda scelta (Buy/Sell/Robux, Upgrades/Bounties...): con l'immagine il colore di fondo non
-- si vede, quindi le altre si scuriscono
function UiView.selected(button: GuiObject, on: boolean, onColor: Color3, offColor: Color3)
	button.BackgroundColor3 = if on then onColor else offColor
	local surface = button:FindFirstChild("AssetSurface")
	if surface and surface:IsA("ImageLabel") then
		surface.ImageColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(110, 120, 140)
	end
end

-- distribuisce in una riga i pulsanti visibili (da x a destra, alti h, alla quota y)
function UiView.row(buttons: { GuiObject }, x: number, y: number, h: number, gap: number?)
	local shown = {}
	for _, b in buttons do
		if b.Visible then
			table.insert(shown, b)
		end
	end
	local n = #shown
	local g = gap or 8
	for i, b in shown do
		b.AnchorPoint = Vector2.zero
		b.Position = UDim2.new((i - 1) / n, x - (i - 1) * (x + 12) / n + (i - 1) * g / n, 0, y)
		b.Size = UDim2.new(1 / n, -(x + 12) / n - g * (n - 1) / n, 0, h)
	end
end

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
			limit.MaxSize = Vector2.new(math.huge, math.huge)
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
	-- le liste si ricostruiscono spesso (monete, draghi, minerali): si resta dove si era
	-- arrivati scorrendo invece di tornare in cima
	if root:IsA("ScrollingFrame") then
		local at = root.CanvasPosition
		if at.Y > 0 then
			task.defer(function()
				root.CanvasPosition = at
				task.delay(0.05, function()
					root.CanvasPosition = at
				end)
			end)
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
-- Schermi bassi (telefono, 844x390 meno la barra di Roblox) usano l'impaginazione compatta,
-- pensata per 1000x430 logici: con la scala del computer i testi diventavano di 7 pixel.
function UiView.compact(vp: Vector2): boolean
	return vp.Y < 560 or (game:GetService("UserInputService").TouchEnabled and vp.Y < 760)
end

-- Prova del telefono dal computer: attributo SimViewport (Vector2, es. 844x354) sul giocatore.
-- Le schermate si impaginano come su quello schermo, ingrandite fino alla larghezza vera (in
-- basso resta un po' di spazio in piu').
local simReal: Vector2? = nil

function UiView.fitScale(gui: ScreenGui, vp: Vector2): Vector2
	local s = if UiView.compact(vp)
		then math.clamp(math.min(vp.X / 960, vp.Y / 430), 0.6, 1.2)
		else math.clamp(math.min(vp.X / 1280, vp.Y / 680), 0.55, 1.6)
	local logical = vp / s
	if simReal then
		s = simReal.X / logical.X
	end
	local u = gui:FindFirstChild("ScalaUI") :: UIScale?
	if not u then
		local nu = Instance.new("UIScale")
		nu.Name = "ScalaUI"
		nu.Parent = gui
		u = nu
	end
	(u :: UIScale).Scale = s
	return logical
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

-- come text, ma il testo si rimpicciolisce (fino a min) se non ci sta nel riquadro: prima i
-- testi lunghi (uovo piu' vicino, scudo, XP) uscivano dai bordi o erano minuscoli
function UiView.fit(o: Instance?, size: number, min: number, bold: boolean?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		UiView.text(o, size, bold)
		o.TextScaled = true
		local c = o:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		c.MaxTextSize = size
		c.MinTextSize = min
		c.Parent = o
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
			local sim = Players.LocalPlayer:GetAttribute("SimViewport")
			if typeof(sim) == "Vector2" then
				simReal = size
				size = sim
			else
				simReal = nil
			end
			callback(Vector2.new(math.max(1, size.X), math.max(1, size.Y)))
		end
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
		Players.LocalPlayer:GetAttributeChangedSignal("SimViewport"):Connect(update)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

return UiView
