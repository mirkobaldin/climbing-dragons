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
local styler: ((Instance) -> ())? = nil
local palette: any = nil
function UiView.setStyler(callback: (Instance) -> (), colors: any)
	styler = callback
	palette = colors
end

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
	if name:find("_v3_", 1, true) or name:find("_v2_", 1, true) then
		return if name:sub(1, 4) == "tab_" then Vector2.new(384, 112) else Vector2.new(512, 160)
	elseif IMAGE_SIZE[name] then
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
 local state = name:match("_(%w+)$") or "normal"
 if state ~= "hover" and state ~= "pressed" then state = "normal" end
 if name:sub(1, 4) == "btn_" and name ~= "btn_close" and not name:find("_v3_", 1, true) then
  local kind = target:GetAttribute("ButtonKind") or "alt"
  name = "btn_" .. tostring(kind) .. "_v3_" .. state
 end
 target:SetAttribute("UiAsset", name)
 if target:IsA("ImageLabel") then UiView.asset(target, name); return end
 -- pulsanti con la cornice di Codex (client/UiKit, attributo UiNative): niente vecchie immagini
 -- e NON si tocca la trasparenza. Prima UIPolish, al passaggio del mouse, chiamava skin che
 -- rimetteva BackgroundTransparency = 0: sotto la cornice compariva il fondo rosso del vecchio
 -- pulsante "sell" (Mirko 16/10: "diventano rossi tutti i Sell")
 if target:GetAttribute("UiNative") and target:FindFirstChild("Cornice") then
  for _, n in { "AssetSurface", "AssetCaption" } do
   local old = target:FindFirstChild(n)
   if old then old:Destroy() end
  end
  return
 end
 local id = UiAssets.get(name)
 -- I pannelli nuovi sono nativi: nessuna vecchia cornice scura o alone.
 if name:sub(1, 6) == "panel_" or target:GetAttribute("UiNative") then id = nil end
 local image = target:FindFirstChild("AssetSurface") :: ImageLabel?
 local oldCaption = target:FindFirstChild("AssetCaption")
 if oldCaption then oldCaption:Destroy() end
 if target:IsA("TextButton") or target:IsA("TextLabel") then target.TextTransparency = 0 end
 if not id then
  if image then image:Destroy() end
  if target:IsA("GuiButton") or name:sub(1, 6) == "panel_" then target.BackgroundTransparency = 0 end
  return
 end
 if not image then
  image = Instance.new("ImageLabel")
  image.Name = "AssetSurface"
  image.Size = UDim2.fromScale(1, 1)
  image.BackgroundTransparency = 1
  image.ZIndex = 0
  image.Parent = target
 end
 target.BackgroundTransparency = 1
 UiView.asset(image :: ImageLabel, name)
 -- chi ha gia' la sua etichetta (tasti del telefono: "Etichetta") non vuole la seconda scritta
 -- (Mirko 16/10: "su telefono escono due scritte sui pulsanti")
 if target:GetAttribute("OwnCaption") and (target:IsA("TextButton") or target:IsA("TextLabel")) then
  target.TextTransparency = 1
  return
 end
 if target:IsA("TextButton") or target:IsA("TextLabel") then
  -- Una sola etichetta, aggiornata anche quando cambiano tipo o stato.
  local caption = Instance.new("TextLabel")
  caption.Name = "AssetCaption"
  caption.BackgroundTransparency = 1
  caption.Position = UDim2.fromOffset(6, 4)
  caption.Size = UDim2.new(1, -12, 1, -8)
  caption.ZIndex = target.ZIndex + 2
  if target:IsA("TextButton") and target:FindFirstChild("Icon") and not target:FindFirstChild("NavTitle") then
   caption.Position = UDim2.new(0, 4, 1, -26)
   caption.Size = UDim2.new(1, -8, 0, 22)
  end
  caption.Parent = target
  local function sync()
   caption.Text = if name == "btn_close" then "" else target.Text
   caption.Font = target.Font
   caption.TextSize = target.TextSize
   caption.TextScaled = true
   caption.TextWrapped = not target:IsA("TextButton") and target.TextWrapped
   caption.TextColor3 = target.TextColor3
   caption.TextStrokeColor3 = target.TextStrokeColor3
   caption.TextStrokeTransparency = target.TextStrokeTransparency
   caption.TextXAlignment = target.TextXAlignment
   caption.RichText = target.RichText
  end
  local connections = {}
  for _, prop in {"Text", "TextColor3", "Font", "TextSize", "TextWrapped"} do
   table.insert(connections, target:GetPropertyChangedSignal(prop):Connect(sync))
  end
  caption.Destroying:Connect(function() for _, c in connections do c:Disconnect() end end)
  sync()
  if styler then styler(caption) end
  target.TextTransparency = 1
 end
end

-- colore di un pulsante o riquadro con l'immagine (cornice dorata): un riempimento colorato con
-- sfumatura dentro la cornice, fra l'immagine e il testo. Prima tutti i pulsanti erano dello
-- stesso blu scuro e non si distinguevano. round = tondo; inset = margine della cornice (0..0.5)
function UiView.tint(target: GuiObject, color: Color3, round: boolean?, inset: number?)
	if target:IsA("TextButton") or target:IsA("TextLabel") then
		target.BackgroundColor3 = color
		local old = target:FindFirstChild("Tinta")
		if old then old:Destroy() end
		return
	end
	local fill = target:FindFirstChild("Tinta") :: Frame?
	if not fill then
		local f = Instance.new("Frame")
		f.Name = "Tinta"
		f.BorderSizePixel = 0
		f.ZIndex = 1
		local corner = Instance.new("UICorner")
		corner.Parent = f
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Parent = f
		f.Parent = target
		fill = f
	end
	local f = fill :: Frame
	target.ClipsDescendants = true
	local k = inset or (if round then 0.11 else 0.06)
	-- senza immagine sotto (pannelli nativi) il colore riempie tutto il riquadro e la cornice
	-- esterna sparisce: prima c'era un riquadro dentro un altro col bordo dorato (Mirko 15/10:
	-- "un botto di cornici inutili" su giocatore, drago, monete, meteo)
	local plain = not target:FindFirstChild("AssetSurface")
	if plain then
		k = 0
		local outer = target:FindFirstChildOfClass("UIStroke")
		if outer then
			outer.Enabled = false
		end
		local grad = target:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Enabled = false
		end
	end
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(1 - k * 2, 1 - k * 2)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.08
	local corner = f:FindFirstChildOfClass("UICorner") :: UICorner
	local own = target:FindFirstChildOfClass("UICorner")
	corner.CornerRadius = if round then UDim.new(0.5, 0) elseif plain and own then own.CornerRadius else UDim.new(0, 8)
	local h, s, v = color:ToHSV()
	local light = Color3.fromHSV(h, math.max(0, s * 0.75), math.min(1, v * 1.25 + 0.08))
	local dark = Color3.fromHSV(h, math.min(1, s * 1.1), v * 0.85)
	local grad = f:FindFirstChildOfClass("UIGradient") :: UIGradient
	grad.Color = ColorSequence.new(light, dark)
	f.Visible = true
	-- l'icona e la scritta sopra il colore
	for _, child in target:GetChildren() do
		if child:IsA("GuiObject") and child ~= f and child.Name ~= "AssetSurface" and child.ZIndex < 2 then
			child.ZIndex = 2
		end
	end
	-- se non c'e' l'immagine il colore e' lo sfondo stesso
	if not target:FindFirstChild("AssetSurface") then
		target.BackgroundTransparency = 1
	end
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
	if styler then styler(root) end
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
		o.TextScaled = true
		o.TextSize = size
		o.TextWrapped = not o:IsA("TextButton")
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
	-- potenziamento: icona in un riquadro colorato, titolo grande, descrizione, effetto "ora ->
	-- dopo", costo, pulsante grande a destra. Prima i margini erano quasi zero e le scritte
	-- piccole (feedback di un giocatore: "serve piu' padding e caratteri piu' grandi")
	UpgradeCard = function(c)
		local W = 214 -- spazio a destra per il pulsante
		c.Size = U(1, -12, 0, 156)
		place(c.Icon, U(0, 20, 0.5, 0), U(0, 92, 0, 92), Vector2.new(0, 0.5))
		sized(c.Icon, 48)
		c.Icon.TextXAlignment = Enum.TextXAlignment.Center
		c.Icon.BackgroundTransparency = 0.25
		if palette then c.Icon.BackgroundColor3 = palette.CARD end
		local ic = c.Icon:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
		ic.CornerRadius = UDim.new(0, 18)
		ic.Parent = c.Icon
		local is = c.Icon:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		if palette then is.Color = palette.ACCENT end
		is.Thickness = 2
		is.Transparency = 0.35
		is.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		is.Parent = c.Icon
		place(c.Title, U(0, 132, 0, 16), U(1, -132 - W, 0, 28))
		sized(c.Title, 22, true)
		place(c.Description, U(0, 132, 0, 48), U(1, -132 - W, 0, 22))
		sized(c.Description, 16)
		if palette then c.Description.TextColor3 = palette.MUTED end
		place(c.Effect, U(0, 132, 0, 76), U(1, -132 - W, 0, 24))
		sized(c.Effect, 16, true)
		c.Effect.RichText = true
		place(c.Cost, U(0, 132, 0, 110), U(1, -132 - W, 0, 28))
		sized(c.Cost, 18, true)
		c.Cost.RichText = true
		for _, o in { c.Title, c.Description, c.Effect, c.Cost } do
			left(o)
		end
		place(c.Action, U(1, -22, 0.5, 0), U(0, W - 30, 0, 60), RIGHT)
		sized(c.Action, 22, true)
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
	-- negozio: carta verticale in griglia (MainMenu.cards). Prima era una riga larga tutto lo
	-- schermo con un grande vuoto in mezzo (Mirko: "UI incompleta, piena di spazi vuoti")
	ItemCard = function(c)
		local center = function(o: any)
			if o then
				o.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
		place(c.Icon, U(0.5, 0, 0, 10), U(0.62, 0, 0.38, 0), Vector2.new(0.5, 0))
		place(c.Title, U(0, 8, 0.42, 4), U(1, -16, 0, 24))
		sized(c.Title, 17, true)
		center(c.Title)
		place(c.Description, U(0, 10, 0.42, 30), U(1, -20, 0, 48))
		sized(c.Description, 12)
		center(c.Description)
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		-- prezzo e pulsanti grandi: su PC "Buy" e "Sell" erano piccoli e si leggevano male
		place(c.Coin, U(0.5, -52, 1, -82), U(0, 24, 0, 24))
		place(c.Cost, U(0.5, -24, 1, -84), U(0.5, 18, 0, 28))
		sized(c.Cost, 18, true)
		left(c.Cost)
		place(c.Buy, U(0.5, 0, 1, -10), U(1, -20, 0, 52), Vector2.new(0.5, 1))
		sized(c.Buy, 22, true)
		place(c.SellActions, U(0.5, 0, 1, -10), U(1, -20, 0, 52), Vector2.new(0.5, 1))
		place(c.SellActions.One, U(0, 0, 0, 0), U(0.5, -4, 1, 0))
		place(c.SellActions.All, U(1, 0, 0, 0), U(0.5, -4, 1, 0), Vector2.new(1, 0))
		sized(c.SellActions.One, 20, true)
		sized(c.SellActions.All, 20, true)
	end,
	-- crafting: carta verticale in griglia (anteprima, nome, materiali, pulsante)
	RecipeCard = function(c)
		place(c.Preview, U(0.5, 0, 0, 8), U(0.6, 0, 0.34, 0), Vector2.new(0.5, 0))
		place(c.Title, U(0, 8, 0.36, 4), U(1, -16, 0, 24))
		sized(c.Title, 17, true)
		c.Title.TextXAlignment = Enum.TextXAlignment.Center
		place(c.Description, U(0, 10, 0.36, 30), U(1, -20, 0, 56))
		sized(c.Description, 12)
		c.Description.TextXAlignment = Enum.TextXAlignment.Center
		c.Description.TextYAlignment = Enum.TextYAlignment.Top
		place(c.Materials, U(0, 10, 1, -102), U(1, -20, 0, 32))
		place(c.Craft, U(0.5, 0, 1, -10), U(1, -20, 0, 52), Vector2.new(0.5, 1))
		sized(c.Craft, 22, true)
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
		place(c.Title, U(0, 8, 1, -46), U(1, -16, 0, 40))
		sized(c.Title, 14, true)
		c.Title.TextXAlignment = Enum.TextXAlignment.Center
		place(c.Count, U(1, -12, 0, 12), U(0, 70, 0, 20), Vector2.new(1, 0))
		sized(c.Count, 15, true)
		c.Count.TextXAlignment = Enum.TextXAlignment.Right
		c.Count.TextStrokeTransparency = 0.3
		c.Count.ZIndex = 5
	end,
}

-- scheda scelta (Buy/Sell/Robux, Upgrades/Bounties...): con l'immagine il colore di fondo non
-- si vede, quindi le altre si scuriscono
function UiView.selected(button: GuiObject, on: boolean, onColor: Color3, offColor: Color3)
	button.BackgroundColor3 = if palette then (if on then palette.ACCENT else palette.BLUE) else (if on then onColor else offColor)
	local surface = button:FindFirstChild("AssetSurface")
	if surface and surface:IsA("ImageLabel") then
		surface.ImageColor3 = Color3.new(1, 1, 1)
	end
	UiView.skin(button, if on then "tab_on_v3_normal" else "tab_off_v3_normal")
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
 if name == "ItemCard" or name == "RecipeCard" then
  local function arrangeCard()
   local guiScale = gui:FindFirstChild("ScalaUI") :: UIScale?
   local height = copy.AbsoluteSize.Y / (if guiScale then guiScale.Scale else 1)
   if height <= 0 then return end
   if height > 200 then
    local cardStyle = CARD_STYLE[name]
    cardStyle(copy)
    if styler then styler(copy) end
    return
   end
   local icon = if name == "ItemCard" then copy.Icon else copy.Preview
   place(icon, U(0, 8, 0, 8), U(0, 56, 0, 56), Vector2.zero)
   place(copy.Title, U(0, 68, 0, 6), U(1, -76, 0, 30))
   place(copy.Description, U(0, 68, 0, 38), U(1, -76, 0, 48))
   if name == "ItemCard" then
    place(copy.Cost, U(0, 8, 0, 88), U(1, -16, 0, 22))
    copy.Coin.Visible = false
    place(copy.Buy, U(0, 8, 1, -8), U(1, -16, 0, 44), Vector2.new(0, 1))
    place(copy.SellActions, U(0, 8, 1, -8), U(1, -16, 0, 44), Vector2.new(0, 1))
   else
    place(copy.Materials, U(0, 8, 0, 86), U(1, -16, 0, 26))
    place(copy.Craft, U(0, 8, 1, -8), U(1, -16, 0, 44), Vector2.new(0, 1))
   end
  end
  copy:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrangeCard)
  task.defer(arrangeCard)
 end
 if name == "UpgradeCard" or name == "BountyCard" then
  local function arrange()
   local guiScale = gui:FindFirstChild("ScalaUI") :: UIScale?
   local w = copy.AbsoluteSize.X / (if guiScale then guiScale.Scale else 1)
   if w <= 0 then return end
   if w >= 600 then
    local style = CARD_STYLE[name]
    style(copy)
    if styler then styler(copy) end
    return
   end
   if name == "UpgradeCard" then
    copy.Size = U(1, -12, 0, 260)
    place(copy.Icon, U(0, 12, 0, 12), U(0, 60, 0, 60), Vector2.zero)
    place(copy.Title, U(0, 80, 0, 14), U(1, -92, 0, 50))
    place(copy.Description, U(0, 12, 0, 80), U(1, -24, 0, 40))
    place(copy.Effect, U(0, 12, 0, 124), U(1, -24, 0, 32))
    place(copy.Cost, U(0, 12, 0, 160), U(1, -24, 0, 32))
    place(copy.Action, U(0, 12, 0, 200), U(1, -24, 0, 48), Vector2.zero)
   else
    copy.Size = U(1, -12, 0, 170)
    place(copy.Title, U(0, 12, 0, 8), U(1, -24, 0, 30))
    place(copy.Progress, U(0, 12, 0, 46), U(1, -24, 0, 16))
    place(copy.Reward, U(0, 12, 0, 70), U(1, -24, 0, 32))
    place(copy.Claim, U(0, 12, 0, 110), U(1, -24, 0, 48), Vector2.zero)
   end
  end
  copy:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
  task.defer(arrange)
 end
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

-- Scala unica di una schermata (docs/UI_ADATTAMENTO.md, 17/10): UNA sola impaginazione,
-- disegnata per un'area logica di almeno 1280x540, e un UIScale "ScalaUI" sulla ScreenGui che la
-- adatta allo schermo vero. Sul telefono (S24 Ultra 891x353) la scala e' 0,654 e l'area logica
-- 1362x540: la stessa UI del computer, piu' piccola, come Blox Fruits. Prima il telefono aveva
-- scala 1 e un'area di 891x353 con un'impaginazione "compact" a parte che si rompeva.
UiView.REF = Vector2.new(1280, 540)
UiView.MIN_SCALE = 0.55
UiView.MAX_SCALE = 2.5
function UiView.scaleFor(vp: Vector2): number
	return math.clamp(math.min(vp.X / UiView.REF.X, vp.Y / UiView.REF.Y), UiView.MIN_SCALE, UiView.MAX_SCALE)
end

-- impaginazione stretta: solo schermi in verticale (area logica piu' stretta del riferimento).
-- Il telefono in orizzontale NON e' piu' "compact": usa la stessa impaginazione del computer
function UiView.compact(vp: Vector2): boolean
	local logical = vp / UiView.scaleFor(vp)
	return logical.X < 760
end

-- schermo touch (telefono, tablet); dal computer si prova con l'attributo SimTouch = true sul
-- giocatore (insieme a SimViewport): compaiono i pulsanti del telefono
function UiView.touch(): boolean
	return game:GetService("UserInputService").TouchEnabled or Players.LocalPlayer:GetAttribute("SimTouch") == true
end

-- Testi del tutorial e delle missioni con i comandi giusti per il computer o il telefono: il
-- server scrive {KEY1}, {CLIMB}... e qui diventano "press 1" o "tap the Ice Axe below" (prima sul
-- telefono c'era scritto "press Space"). {UI:Nome} indica il pulsante del menu da evidenziare
-- (client/TutorialHints) e sparisce dal testo.
-- tre versioni: computer, telefono, gamepad (Mirko 16/10: sul telefono c'era scritto
-- "Release the key", che sul telefono non esiste)
local HINTS: { [string]: { pc: string, touch: string, pad: string } } = {
	KEY1 = { pc = "Press [1] for the Ice Axes", touch = "Tap slot 1 in the bar below", pad = "Pick slot 1 in the bar" },
	KEY2 = { pc = "Press [2] for the Pickaxe", touch = "Tap slot 2 in the bar below", pad = "Pick slot 2 in the bar" },
	CLIMB = { pc = "Click the rock, then hold [W]", touch = "Tap CLIMB, then push the stick up", pad = "Press [R2] on the rock, then push the stick up" },
	PITON = { pc = "Hold [F], aim at the rock: green circle = good spot. Release [F] to place", touch = "Hold PITON, aim at the rock: green circle = good spot. Release to place", pad = "Hold [X], aim at the rock: green circle = good spot. Release [X] to place" },
	UNCLIP = { pc = "Stay near the piton and press [R]: you unclip and get the piton back (+1)", touch = "Stay near the piton and tap UNCLIP: you get the piton back (+1)", pad = "Stay near the piton and press [Y]: you get the piton back (+1)" },
	MINE = { pc = "Click the shiny rock", touch = "Tap MINE next to the rock", pad = "Press [R2] next to the rock" },
	JUMP = { pc = "Press [Space]", touch = "Tap JUMP", pad = "Press [A]" },
	RIDE = { pc = "Press [H] to ride", touch = "Tap RIDE", pad = "Press [H] to ride" },
	FIRE = { pc = "Click to fire", touch = "Tap FIRE", pad = "Press [R2] to fire" },
}

-- come sta giocando adesso: "touch", "pad" o "pc" (cambia se prende in mano il gamepad)
function UiView.inputMode(): string
	if UiView.touch() then
		return "touch"
	end
	local UIS = game:GetService("UserInputService")
	local last = UIS:GetLastInputType()
	if last == Enum.UserInputType.Gamepad1 or last == Enum.UserInputType.Gamepad2 then
		return "pad"
	end
	return "pc"
end

-- il testo di un comando per il dispositivo in uso ("PITON" -> "Hold [F] to aim...")
function UiView.prompt(key: string): string
	local h = HINTS[key]
	if not h then
		return ""
	end
	local mode = UiView.inputMode()
	local out = if mode == "touch" then h.touch elseif mode == "pad" then h.pad else h.pc
	-- piccozze e piccone: la casella vera della barra (si possono spostare nello zaino)
	if key == "KEY1" or key == "KEY2" then
		local ok, slot = pcall(function()
			local Hotbar = require(script.Parent.Hotbar)
			local ClimbConfig = require(script.Parent.ClimbConfig)
			return table.find(Hotbar.current(Players.LocalPlayer), if key == "KEY1" then ClimbConfig.TOOL_NAME else ClimbConfig.PICKAXE_NAME)
		end)
		local n = if ok and slot then tostring(slot) else (if key == "KEY1" then "1" else "2")
		out = (out:gsub("%[[12]%]", "[" .. n .. "]"):gsub("slot [12]", "slot " .. n))
	end
	return out
end

function UiView.hintText(text: string): string
	local out = text:gsub("{UI:%w+}", ""):gsub("{(%w+)}", function(key: string)
		return UiView.prompt(key)
	end)
	return (out:gsub("%s+$", ""):gsub("  +", " "))
end

-- il pulsante del menu che il testo chiede di premere ({UI:Store} -> "Store"), o nil
function UiView.hintButton(text: string): string?
	return text:match("{UI:(%w+)}")
end

-- Prova del telefono dal computer: attributo SimViewport (Vector2, es. 844x354) sul giocatore.
-- Le schermate si impaginano come su quello schermo, ingrandite fino alla larghezza vera (in
-- basso resta un po' di spazio in piu').
local simReal: Vector2? = nil

function UiView.fitScale(gui: ScreenGui, vp: Vector2): Vector2
	local s = UiView.scaleFor(vp)
	local logical = vp / s
	if simReal then
		-- tutto lo schermo simulato dentro la finestra di Studio (prima si adattava solo alla
		-- larghezza e il fondo del telefono finiva fuori dalla vista)
		s = math.min(simReal.X / logical.X, simReal.Y / logical.Y)
	end
	local u = gui:FindFirstChild("ScalaUI") :: UIScale?
	if not u then
		local nu = Instance.new("UIScale")
		nu.Name = "ScalaUI"
		nu.Parent = gui
		u = nu
	end
	(u :: UIScale).Scale = s
	-- scala vera sullo schermo (anche simulando): serve al testo minimo (UiKit.minText)
	gui:SetAttribute("ScalaVera", UiView.scaleFor(vp))
	return logical
end

-- spazio libero nella fila della barra di Roblox (GuiService.TopbarInset), in pixel logici
-- di una ScreenGui con scala s e IgnoreGuiInset = true: x da cui si puo' iniziare a sinistra,
-- larghezza libera, altezza della barra. Sul telefono i tasti di Roblox sono piu' grandi che in
-- Studio: per questo monete e "Home ... m" finivano sotto il menu e la chat di Roblox
function UiView.topbar(s: number): (number, number, number)
	local ok, r = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and typeof(r) == "Rect" and r.Height > 0 then
		return r.Min.X / s, r.Width / s, r.Height / s
	end
	local inset = GuiService:GetGuiInset()
	return 0, 10000, math.max(36, inset.Y) / s
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
		o.TextStrokeTransparency = 0
		if styler then styler(o) end
	end
end

-- come text, ma il testo si rimpicciolisce (fino a min) se non ci sta nel riquadro: prima i
-- testi lunghi (uovo piu' vicino, scudo, XP) uscivano dai bordi o erano minuscoli
function UiView.fit(o: Instance?, size: number, min: number, bold: boolean?)
	if o and (o:IsA("TextLabel") or o:IsA("TextButton")) then
		UiView.text(o, size, bold)
		o.TextScaled = true
		local c = o:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		c.MaxTextSize = math.max(12, size)
		c.MinTextSize = math.max(12, min)
		c.Parent = o
	end
end

-- chiama callback con l'area utile (pixel veri). Con gui: l'area vera di quella ScreenGui
-- (AbsoluteSize, cioe' gia' senza la barra di Roblox e le tacche del telefono secondo i suoi
-- ScreenInsets). Prima si usava la telecamera meno GetGuiInset: sul telefono vero la barra e'
-- piu' alta e la finestra del menu usciva dallo schermo in basso (Mirko 16/10)
function UiView.viewportChanged(callback: (Vector2) -> (), gui: ScreenGui?)
	local connection: RBXScriptConnection? = nil
	local last = ""
	local function bind()
		if connection then
			connection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local function update()
			local size: Vector2
			if gui and gui.AbsoluteSize.X > 1 and gui.AbsoluteSize.Y > 1 then
				size = gui.AbsoluteSize
			else
				local topLeft, bottomRight = GuiService:GetGuiInset()
				size = camera.ViewportSize - topLeft - bottomRight
			end
			local sim = Players.LocalPlayer:GetAttribute("SimViewport")
			if typeof(sim) == "Vector2" then
				simReal = size
				size = sim
			else
				simReal = nil
			end
			size = Vector2.new(math.max(1, size.X), math.max(1, size.Y))
			local key = string.format("%d,%d,%s", math.floor(size.X), math.floor(size.Y), tostring(simReal))
			if key == last then
				return -- AbsoluteSize e telecamera cambiano insieme: una volta sola
			end
			last = key
			callback(size)
		end
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
		update()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("SimViewport"):Connect(function()
		last = ""
		bind()
	end)
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			local camera = workspace.CurrentCamera
			if camera then
				-- stessa strada di update (passa dal confronto con l'ultima misura)
				bind()
			end
		end)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bind)
	bind()
end

-- Misure della fila dei pulsanti del menu (Shop, Backpack...) e della finestra sotto.
-- compact (telefono, schermi bassi): cerchi da 44 con la sola icona in alto a sinistra, finestra
-- quasi a tutto schermo; computer: pillole da 46 con icona e nome al centro. Prima sul telefono i
-- pulsanti erano alti 56 e larghi tutto lo schermo: coprivano 2/3 dei menu (Mirko 15/10)
function UiView.menuMetrics(vp: Vector2)
	local compact = UiView.compact(vp) or vp.X < 900
	local gap = if compact then 6 else 8
	local cellH = if compact then 44 else 46
	local cell = if compact then cellH else math.min(158, (vp.X - 140 - 5 * gap) / 6)
	local navWidth = 6 * cell + 5 * gap
	local top = if compact then 6 else 8
	local y = top + cellH + (if compact then 8 else 12)
	local width = math.min(1120, vp.X - 16)
	return {
		compact = compact, cols = 6, cell = cell, cellH = cellH, gap = gap,
		navWidth = navWidth, navHeight = cellH, x = (vp.X - width) / 2, y = y,
		width = width, height = math.max(160, vp.Y - y - 8),
	}
end

return UiView
