--!strict
-- Cornici di Codex (16/10, artifacts/ui-cornici-20261016, approvate da Mirko): immagini a 2x con
-- profondita' vera (oro e ferro scolpiti, luce dall'alto a sinistra) sotto pulsanti, schede,
-- caselle, pannelli, barre, avvisi e ritratti. Regole del manifest (UiAssets.slices/frames):
--   * 9-slice: SliceCenter dai margini; la grandezza si regola con SliceScale secondo l'ALTEZZA
--     vera dell'elemento (cosi' i terminali ornati restano proporzionati e si allunga solo il
--     tratto semplice in mezzo)
--   * ritratti, medaglioni, ornamento della morte: solo scala uniforme
-- Un'immagine sopra un TextButton coprirebbe il suo testo (i figli si disegnano sopra il
-- genitore): il testo del pulsante si copia in un'etichetta "Scritta" sopra la cornice e il
-- testo vero resta invisibile (altri script continuano a cambiare b.Text come prima).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiAssets"))

local Cornici = {}

local IMAGE = "Cornice"
-- per ogni immagine la funzione che la rimisura (chiamata quando l'elemento cambia grandezza)
local fits: { [ImageLabel]: () -> () } = setmetatable({}, { __mode = "k" }) :: any
-- ultima cornice chiesta per ogni elemento: se un altro script la cancella (molte schede si
-- rifanno distruggendo tutti i figli) torna da sola
local lastOf: { [GuiObject]: { id: string, opts: any } } = setmetatable({}, { __mode = "k" }) :: any
local removing: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local ownOf: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

-- fattore delle UIScale sopra (e sull') elemento: le misure della cornice sono in pixel "logici"
local function scaleOf(o: Instance): number
	local k = 1
	local p: Instance? = o
	while p do
		for _, c in p:GetChildren() do
			if c:IsA("UIScale") and c.Scale > 0 then
				k *= c.Scale
			end
		end
		if p:IsA("LayerCollector") then
			break -- la ScreenGui compresa (ScalaUI sta li')
		end
		p = p.Parent
	end
	return k
end

-- grandezza logica (senza le UIScale)
function Cornici.logical(o: GuiObject): Vector2
	return o.AbsoluteSize / scaleOf(o)
end

local function info(id: string): any
	local base = id:gsub("_normal$", ""):gsub("_hover$", ""):gsub("_pressed$", ""):gsub("_selected$", "")
		:gsub("_valid$", ""):gsub("_disabled$", "")
	local frames = UiAssets.frames :: any
	-- i livelli da tingere (gemme, filo della rarita') hanno le misure del ritratto
	return frames[base] or frames[id] or frames[(id:gsub("_gem$", ""):gsub("_rarity$", ""))]
end

-- il riquadro dell'immagine (lo crea se manca)
local function imageOf(o: GuiObject, name: string): ImageLabel
	local img = o:FindFirstChild(name) :: ImageLabel?
	if not img then
		local n = Instance.new("ImageLabel")
		n.Name = name
		n.BackgroundTransparency = 1
		n.BorderSizePixel = 0
		n.ScaleType = Enum.ScaleType.Slice
		n.ZIndex = 0 -- sotto gli altri figli (ZIndexBehavior Sibling)
		n.Active = false
		n:SetAttribute("UiNative", true)
		n.Parent = o
		img = n
		n.Destroying:Connect(function()
			if removing[o] then
				return
			end
			if name ~= IMAGE then
				return
			end
			task.defer(function()
				local last = lastOf[o]
				if last and o.Parent and not o:FindFirstChild(IMAGE) then
					Cornici.apply(o, last.id, last.opts)
				end
			end)
		end)
	end
	return img :: ImageLabel
end

export type Opts = {
	-- "fill": l'immagine copre l'elemento (pulsanti, schede, caselle). "outset": lo spazio
	-- libero dell'immagine coincide con l'elemento e la cornice sta fuori (pannelli piccoli)
	mode: string?,
	-- scala fissa (pannelli); senza, si calcola dall'altezza (o dal lato per le caselle)
	scale: number?,
	-- per i pannelli: spessore del bordo in pixel logici (sceglie la scala)
	border: number?,
	-- nome dell'immagine (per piu' livelli sullo stesso elemento: gemme, filo della rarita')
	name: string?,
	-- fondo scuro dentro lo spazio libero (caselle: l'interno dell'immagine e' trasparente)
	fill: Color3?,
	fillTransparency: number?,
	color: Color3?,
	transparency: number?,
	z: number?,
}

-- mette (o cambia) la cornice id sull'elemento. Ritorna l'immagine
function Cornici.apply(o: GuiObject, id: string, opts: Opts?): ImageLabel?
	local asset = UiAssets.get(id)
	if not asset then
		return nil
	end
	local p = opts or {}
	local name = p.name or IMAGE
	if name == IMAGE then
		lastOf[o] = { id = id, opts = opts }
	end
	local back: Frame? = nil
	if p.fill then
		back = o:FindFirstChild("Fondo") :: Frame?
		if not back then
			local f = Instance.new("Frame")
			f.Name = "Fondo"
			f.BorderSizePixel = 0
			f.ZIndex = 0
			f.Active = false
			f.Parent = o
			back = f
			-- l'immagine dopo il fondo (stesso ZIndex: si disegna nell'ordine dei figli)
			local old = o:FindFirstChild(name)
			if old then
				old.Parent = nil
				old.Parent = o
			end
		end
		local bf = back :: Frame
		bf.BackgroundColor3 = p.fill :: Color3
		bf.BackgroundTransparency = p.fillTransparency or 0.15
	end
	local img = imageOf(o, name)
	img.Image = asset
	img.ImageColor3 = p.color or Color3.new(1, 1, 1)
	img.ImageTransparency = p.transparency or 0
	if p.z then
		img.ZIndex = p.z
	end
	local slice = (UiAssets.slices :: any)[id] :: Rect?
	local fi = info(id)
	img:SetAttribute("CorniceId", id)
	local mode = p.mode or "fill"
	local function fit()
		local size = Cornici.logical(o)
		if size.X < 1 or size.Y < 1 or not fi then
			return
		end
		local png = fi.size :: Vector2
		local s: number
		if mode == "circle" and fi.circle then
			-- ritratti: il foro (centro e diametro dal manifest) coincide col cerchio dell'elemento
			local c = fi.circle :: Vector3
			local k = math.min(size.X, size.Y) / c.Z
			img.ScaleType = Enum.ScaleType.Stretch
			img.Position = UDim2.fromOffset(size.X / 2 - c.X * k, size.Y / 2 - c.Y * k)
			img.Size = UDim2.fromOffset(png.X * k, png.Y * k)
			return
		end
		local fixed = o:GetAttribute("CorniceScala")
		if p.scale then
			s = p.scale
		elseif type(fixed) == "number" and fixed > 0 then
			s = fixed -- cornice piu' sottile del normale (caselle piccole dell'Inventory)
		elseif mode == "outset" and fi.free and not p.border then
			-- l'altezza libera dell'immagine = altezza dell'elemento (barre)
			s = size.Y / math.max(1, (fi.free :: Rect).Height)
		elseif p.border and fi.free then
			-- bordo dello spessore chiesto (il lato sinistro dello spazio libero)
			s = p.border / math.max(1, (fi.free :: Rect).Min.X)
		elseif png.X <= png.Y * 1.3 then
			s = math.min(size.X / png.X, size.Y / png.Y) -- caselle e ritratti: dal lato
		else
			s = size.Y / png.Y -- strisce (pulsanti, schede, barre): dall'altezza
		end
		if slice then
			img.ScaleType = Enum.ScaleType.Slice
			img.SliceCenter = slice
			-- mai terminali piu' larghi della meta' dell'elemento
			local caps = math.max(slice.Min.X, png.X - slice.Max.X) * 2
			s = math.min(s, size.X * 0.98 / math.max(1, caps))
			img.SliceScale = s
		else
			img.ScaleType = Enum.ScaleType.Stretch
		end
		-- margine del testo dentro la cornice (Cornici.caption senza padX): i terminali ornati
		-- occupano solo la parte esterna del margine 9-slice, il testo puo' entrarci un po'
		if fi.free and mode ~= "outset" then
			o:SetAttribute("CorniceMargine", math.floor((fi.free :: Rect).Min.X * s * 0.7))
		end
		if mode == "outset" and fi.free then
			local f = fi.free :: Rect
			local l, t = f.Min.X * s, f.Min.Y * s
			local r, b = (png.X - f.Max.X) * s, (png.Y - f.Max.Y) * s
			img.Position = UDim2.fromOffset(-l, -t)
			img.Size = UDim2.new(1, l + r, 1, t + b)
		else
			img.Position = UDim2.fromOffset(0, 0)
			img.Size = UDim2.fromScale(1, 1)
			if back and (fi.fill or fi.free) then
				local f = (fi.fill or fi.free) :: Rect
				local l, t = f.Min.X * s, f.Min.Y * s
				local r, b = (png.X - f.Max.X) * s, (png.Y - f.Max.Y) * s
				back.Position = UDim2.fromOffset(l, t)
				back.Size = UDim2.new(1, -(l + r), 1, -(t + b))
			end
		end
	end
	if not img:GetAttribute("Misura") then
		img:SetAttribute("Misura", true)
		local function refit()
			local f = fits[img]
			if f then
				f()
			end
		end
		o:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
		-- prima misura vera: appena l'elemento e' impaginato
		task.defer(refit)
	end
	fits[img] = fit -- l'ultima regola vince
	fit()
	return img
end

-- esiste l'immagine?
function Cornici.has(id: string): boolean
	return UiAssets.get(id) ~= nil
end

-- toglie la cornice
function Cornici.remove(o: GuiObject)
	removing[o] = true
	lastOf[o] = nil
	local img = o:FindFirstChild(IMAGE)
	if img then
		img:Destroy()
	end
	local cap = o:FindFirstChild("Scritta")
	if cap and (o:IsA("TextButton") or o:IsA("TextLabel")) then
		cap:Destroy()
		o.TextTransparency = ownOf[o] or 0
	end
	removing[o] = nil
end

-- testo del pulsante sopra la cornice (vedi in cima). pad: margine ai lati in pixel logici
local PROPS = { "Text", "TextColor3", "FontFace", "TextSize", "TextScaled", "TextWrapped", "RichText",
	"TextXAlignment", "TextYAlignment", "TextStrokeTransparency", "TextStrokeColor3", "TextTruncate" }
function Cornici.caption(b: TextButton | TextLabel, padX: number?): TextLabel
	local cap = b:FindFirstChild("Scritta") :: TextLabel?
	if cap then
		return cap
	end
	local l = Instance.new("TextLabel")
	l.Name = "Scritta"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.ZIndex = 3
	-- margine: quello chiesto, oppure quello dei terminali della cornice (CorniceMargine)
	local function pad()
		local auto = b:GetAttribute("CorniceMargine")
		local px = padX or (if type(auto) == "number" then auto else 10)
		-- mai piu' di un quarto della larghezza per lato (pulsanti stretti come "Sell 1")
		local w = Cornici.logical(b).X
		if w > 1 then
			px = math.min(px, w * 0.25)
		end
		l.Size = UDim2.new(1, -2 * px, 1, -4)
	end
	pad()
	local padConns = {
		b:GetAttributeChangedSignal("CorniceMargine"):Connect(pad),
		b:GetPropertyChangedSignal("AbsoluteSize"):Connect(pad),
	}
	-- il testo si rimpicciolisce se non ci sta (mai "...": Mirko 16/10, "Sell 1" diventava "SE...")
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.Parent = l
	l:SetAttribute("UiNative", true)
	l:SetAttribute("TipoTesto", b:GetAttribute("TipoTesto"))
	l.Parent = b
	-- trasparenza voluta da chi usa il pulsante (il testo vero resta sempre a 1)
	local own = ownOf[b] or (if b.TextTransparency < 1 then b.TextTransparency else 0)
	ownOf[b] = own
	local busy = false
	local function sync()
		for _, prop in PROPS do
			(l :: any)[prop] = (b :: any)[prop]
		end
		l.TextTransparency = own
		l.TextScaled = true
		l.TextWrapped = false
		l.TextTruncate = Enum.TextTruncate.None
		limit.MaxTextSize = math.max(8, math.floor(b.TextSize))
	end
	local conns: { RBXScriptConnection } = {}
	for _, prop in PROPS do
		table.insert(conns, b:GetPropertyChangedSignal(prop):Connect(sync))
	end
	table.insert(conns, b:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		if busy then
			return
		end
		if b.TextTransparency < 1 then
			own = b.TextTransparency
			ownOf[b] = own
			busy = true
			b.TextTransparency = 1
			busy = false
			l.TextTransparency = own
		end
	end))
	-- cancellata da chi rifa' i figli del pulsante: torna (se no il testo restava invisibile)
	l.Destroying:Connect(function()
		for _, c in conns do
			c:Disconnect()
		end
		for _, c in padConns do
			c:Disconnect()
		end
		if removing[b] then
			return
		end
		task.defer(function()
			if b.Parent and not b:FindFirstChild("Scritta") then
				Cornici.caption(b, padX)
			end
		end)
	end)
	sync()
	busy = true
	b.TextTransparency = 1
	busy = false
	return l
end

-- premuto: la scritta (e l'icona) scendono di un filo, come un tasto vero
function Cornici.press(b: GuiObject, down: boolean)
	local cap = b:FindFirstChild("Scritta") :: GuiObject?
	if cap then
		cap.Position = UDim2.new(0.5, 0, 0.5, if down then 2 else 0)
	end
end

return Cornici
