--!strict
-- Sistema di stile unico del menu e dell'HUD (Mirko 16/10, riferimento: menu di Black Ops III
-- per presentazione, profondita' e geometria, non per tema o colori). Regole:
--   * angoli vivi: gli angoli tondi sono l'eccezione (cerchi veri, avatar), non la regola
--   * superfici scure e traslucide, bordi sottili da 1 px, separatori netti
--   * stati FISICI: spento = piu' scuro e indietro; hover = bordo che si accende e un filo di
--     movimento; scelto = bordo d'accento, segno a sinistra e piu' vicino; premuto = rientra
--   * una sola gerarchia di caratteri (TYPE): titolo di pagina, sezione, nome, numero/prezzo,
--     descrizione, informazione secondaria, pulsante, stato piccolo
-- Tutto leggero: niente cicli per frame, gli stati si cambiano solo agli eventi.

local TweenService = game:GetService("TweenService")
local Cornici = require(script.Parent.Cornici)

local UiKit = {}
UiKit.Cornici = Cornici

-- colori di base (le tinte dei singoli elementi restano in Theme)
UiKit.INK = Color3.fromRGB(7, 10, 16) -- il fondo piu' profondo
UiKit.PANEL = Color3.fromRGB(13, 18, 28) -- pannelli
UiKit.RAISED = Color3.fromRGB(24, 31, 45) -- superfici in rilievo (carte, righe)
UiKit.LINE = Color3.fromRGB(150, 172, 204) -- bordi sottili (sempre molto trasparenti)
UiKit.TEXT = Color3.fromRGB(240, 244, 250)
UiKit.MUTED = Color3.fromRGB(176, 189, 208)
UiKit.DIM = Color3.fromRGB(122, 136, 158)
UiKit.ACCENT = Color3.fromRGB(255, 196, 64) -- oro della brace: selezione e azioni principali
UiKit.ICE = Color3.fromRGB(120, 212, 255) -- ghiaccio: informazioni e azioni secondarie
UiKit.GOOD = Color3.fromRGB(104, 224, 120)
UiKit.BAD = Color3.fromRGB(255, 92, 100)

-- caratteri: Oswald (stretto, deciso) per titoli, nomi, numeri e pulsanti; Titillium Web per
-- le descrizioni. Al posto del Gotham "da simulatore" di prima
local OSWALD = "rbxasset://fonts/families/Oswald.json"
local TITILLIUM = "rbxasset://fonts/families/TitilliumWeb.json"
UiKit.FONT = {
	head = Font.new(OSWALD, Enum.FontWeight.Bold),
	headMed = Font.new(OSWALD, Enum.FontWeight.Medium),
	body = Font.new(TITILLIUM, Enum.FontWeight.Regular),
	bodyBold = Font.new(TITILLIUM, Enum.FontWeight.SemiBold),
}

export type TextKind = "title" | "section" | "name" | "stat" | "body" | "secondary" | "button" | "status"
type Spec = { font: Font, size: number, color: Color3, upper: boolean?, stroke: number }
UiKit.TYPE = {
	title = { font = UiKit.FONT.head, size = 34, color = UiKit.TEXT, upper = true, stroke = 0.7 },
	section = { font = UiKit.FONT.headMed, size = 18, color = UiKit.MUTED, upper = true, stroke = 1 },
	name = { font = UiKit.FONT.head, size = 21, color = UiKit.TEXT, stroke = 0.85 },
	stat = { font = UiKit.FONT.head, size = 22, color = UiKit.TEXT, stroke = 0.85 },
	body = { font = UiKit.FONT.body, size = 16, color = UiKit.MUTED, stroke = 1 },
	secondary = { font = UiKit.FONT.body, size = 14, color = UiKit.DIM, stroke = 1 },
	button = { font = UiKit.FONT.head, size = 19, color = UiKit.TEXT, upper = true, stroke = 1 },
	status = { font = UiKit.FONT.bodyBold, size = 13, color = UiKit.MUTED, upper = true, stroke = 1 },
} :: { [string]: Spec }

-- telefono: testi appena piu' piccoli, mai sotto i 13 px (i giocatori sono anche bambini)
UiKit.compact = false

function UiKit.text(label: TextLabel | TextButton | TextBox, kind: TextKind, size: number?)
	local spec = UiKit.TYPE[kind]
	label.FontFace = spec.font
	local s = size or spec.size
	if UiKit.compact then
		s = math.max(13, math.floor(s * 0.88))
	end
	label.TextScaled = false
	label.TextSize = s
	label.TextColor3 = spec.color
	label.TextStrokeTransparency = spec.stroke
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	if spec.upper and label.Text ~= "" and not string.find(label.Text, "<", 1, true) then
		label.Text = string.upper(label.Text)
	end
	label:SetAttribute("TipoTesto", kind)
end

function UiKit.label(parent: Instance, text: string, kind: TextKind, size: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.RichText = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Size = UDim2.new(1, 0, 0, (size or UiKit.TYPE[kind].size) + 8)
	UiKit.text(l, kind, size)
	l.Parent = parent
	return l
end

-- Caratteri vecchi (Gotham) -> nuova gerarchia, per i testi fatti altrove (modelli in
-- StarterGui, Theme.label): neri = titoli e nomi, grossi in grassetto = nomi, il resto corpo
local GOTHAM_BLACK = { [Enum.Font.GothamBlack] = true }
local GOTHAM_BOLD = { [Enum.Font.GothamBold] = true, [Enum.Font.GothamSemibold] = true }
local GOTHAM_BODY = { [Enum.Font.Gotham] = true, [Enum.Font.GothamMedium] = true, [Enum.Font.SourceSans] = true }
local function remap(o: TextLabel | TextButton | TextBox)
	local f = o.Font
	local kind = o:GetAttribute("TipoTesto")
	if type(kind) == "string" then
		-- gia' nella gerarchia nuova: se altro codice ci rimette il Gotham, torna il suo carattere
		local spec = UiKit.TYPE[kind]
		if spec and (GOTHAM_BLACK[f] or GOTHAM_BOLD[f] or GOTHAM_BODY[f]) then
			o.FontFace = spec.font
		end
		return
	end
	local big = o.TextSize >= 20 or o.TextScaled
	if GOTHAM_BLACK[f] then
		o.FontFace = UiKit.FONT.head
	elseif GOTHAM_BOLD[f] then
		o.FontFace = if big then UiKit.FONT.headMed else UiKit.FONT.bodyBold
	elseif GOTHAM_BODY[f] then
		o.FontFace = UiKit.FONT.body
		-- Titillium e' piu' piccolo a parita' di grandezza
		if not o.TextScaled then
			o.TextSize += 1
		end
	else
		return
	end
	-- contorno del testo molto piu' leggero: il bordo nero spesso faceva "gioco da telefono"
	if o.TextStrokeTransparency < 0.7 then
		o.TextStrokeTransparency = 0.75
	end
end
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchText(o: Instance)
	if watched[o] or not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then
		return
	end
	watched[o] = true
	local t = o :: TextLabel
	task.defer(remap, t)
	-- Ui.text e Theme.fitText rimettono il Gotham a ogni impaginazione: si rimappa
	t:GetPropertyChangedSignal("FontFace"):Connect(function()
		task.defer(remap, t)
	end)
end

-- Angoli vivi: gli UICorner diventano 2 px (bordo appena smussato, non tondo), tranne i cerchi
-- veri (raggio >= 50%) e chi ha l'attributo KeepRound
local function sharpen(o: Instance)
	if o:IsA("UICorner") then
		local c = o :: UICorner
		local parent = c.Parent
		if c.CornerRadius.Scale >= 0.45 or (parent and parent:GetAttribute("KeepRound")) then
			return
		end
		c.CornerRadius = UDim.new(0, 2)
	end
end

-- applica tutto lo stile a un albero e a quello che ci verra' aggiunto dopo
function UiKit.adopt(root: Instance)
	for _, d in root:GetDescendants() do
		sharpen(d)
		watchText(d)
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("UICorner") then
			task.defer(sharpen, d) -- il raggio si imposta dopo averlo creato
		else
			watchText(d)
		end
	end)
end

-- bordo sottile (1 px, molto trasparente) che resta anche col filtro di Theme.paint
function UiKit.edge(o: GuiObject, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local s = o:FindFirstChild("Bordo") :: UIStroke?
	if not s then
		local ns = Instance.new("UIStroke")
		ns.Name = "Bordo"
		ns.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ns:SetAttribute("KeepStroke", true)
		ns.Parent = o
		s = ns
	end
	local st = s :: UIStroke
	st.Color = color or UiKit.LINE
	st.Thickness = thickness or 1
	st.Transparency = transparency or 0.8
	return st
end

-- pannello: superficie scura traslucida, angoli vivi, bordo sottile e due tacche d'angolo
-- (in alto a sinistra e in basso a destra), come le cornici del riferimento
function UiKit.panel(o: GuiObject, opts: { transparency: number?, accent: Color3?, ticks: boolean?, border: number? }?)
	local p = opts or {}
	o.BackgroundColor3 = UiKit.PANEL
	-- quasi pieni (Mirko 16/10: lo scenario e i draghi dietro disturbavano testi e pulsanti)
	o.BackgroundTransparency = math.min(p.transparency or 0.1, 0.1)
	o.BorderSizePixel = 0
	local corner = o:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	-- cornice di Codex (oro e ferro con gli artigli negli angoli): il fondo carbone e' dentro
	-- l'immagine, il bordo sottile e le tacche non servono piu'
	if Cornici.apply(o, "frame_panel", { border = p.border or (if UiKit.compact then 9 else 12) }) then
		o.BackgroundTransparency = 1
		UiKit.edge(o, UiKit.LINE, 1, 1)
		local old = o:FindFirstChild("Tacche")
		if old then
			old:Destroy()
		end
		return
	end
	UiKit.edge(o)
	if p.ticks ~= false then
		UiKit.ticks(o, p.accent or UiKit.ACCENT)
	end
end

-- tacche d'angolo: due "L" sottili negli angoli opposti
function UiKit.ticks(o: GuiObject, color: Color3)
	local old = o:FindFirstChild("Tacche")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = "Tacche"
	local function bar(ax: number, ay: number, w: number, h: number)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(ax, ay)
		f.Position = UDim2.fromScale(ax, ay)
		f.Size = UDim2.fromOffset(w, h)
		f.ZIndex = o.ZIndex + 4
		f.Parent = holder
	end
	bar(0, 0, 18, 2)
	bar(0, 0, 2, 12)
	bar(1, 1, 18, 2)
	bar(1, 1, 2, 12)
	holder.Parent = o
end

-- separatore netto (linea di 1 px)
function UiKit.rule(parent: Instance, y: number, inset: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Riga"
	f.BackgroundColor3 = UiKit.LINE
	f.BackgroundTransparency = 0.82
	f.BorderSizePixel = 0
	f.Position = UDim2.fromOffset(inset or 14, y)
	f.Size = UDim2.new(1, -2 * (inset or 14), 0, 1)
	f.Parent = parent
	return f
end

------------------------------------------------------------------------------------------
-- Stati fisici delle carte e dei pulsanti
local QUICK = TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function scaleOf(o: GuiObject): UIScale
	local s = o:FindFirstChild("Fisica") :: UIScale?
	if not s then
		local ns = Instance.new("UIScale")
		ns.Name = "Fisica"
		ns.Parent = o
		s = ns
	end
	return s :: UIScale
end

-- segno d'accento sul lato sinistro (lo stato "scelto")
local function mark(o: GuiObject, color: Color3?, on: boolean)
	local m = o:FindFirstChild("Segno") :: Frame?
	if on and not m then
		local f = Instance.new("Frame")
		f.Name = "Segno"
		f.BorderSizePixel = 0
		f.Size = UDim2.new(0, 3, 1, 0)
		f.ZIndex = o.ZIndex + 5
		f.Parent = o
		m = f
	end
	if m then
		m.Visible = on
		if color then
			m.BackgroundColor3 = color
		end
	end
end

-- stato di una superficie: "idle" | "hover" | "selected" | "pressed" | "disabled"
function UiKit.state(o: GuiObject, state: string, accent: Color3?)
	local a = accent or UiKit.ACCENT
	local edge = UiKit.edge(o)
	local s = scaleOf(o)
	local selected = o:GetAttribute("Scelto") == true
	local goal = 1
	if state == "pressed" then
		goal = 0.97
	elseif selected then
		goal = if state == "hover" then 1.04 else 1.03
	elseif state == "hover" then
		goal = 1.015
	end
	TweenService:Create(s, QUICK, { Scale = goal }):Play()
	-- con la cornice di Codex: l'immagine dello stato (hover = oro acceso, premuto = rientra) e la
	-- scritta che scende di un filo; niente bordo sottile sopra
	local img = o:FindFirstChild("Cornice") :: ImageLabel?
	local id = img and img:GetAttribute("CorniceId")
	if img and type(id) == "string" and not id:find("_disabled$") then
		local base = id:gsub("_%a+$", "")
		-- non tutte le cornici hanno tutti gli stati (caselle e schede non hanno "premuto")
		local order = if state == "pressed" then { "_pressed", "_selected", "_hover" }
			elseif selected then { "_selected", "_hover" }
			elseif state == "hover" then { "_hover" }
			else { "_normal" }
		local want = base .. "_normal"
		for _, suffix in order do
			if Cornici.has(base .. suffix) then
				want = base .. suffix
				break
			end
		end
		if o:GetAttribute("CorniceFissa") then
			want = id -- stato deciso da chi usa la casella (es. destinazione valida)
		end
		if want ~= id then
			Cornici.apply(o, want, { color = img.ImageColor3 })
		end
		Cornici.press(o, state == "pressed")
		edge.Transparency = 1
		mark(o, a, false)
		return
	end
	if selected then
		edge.Color, edge.Thickness, edge.Transparency = a, 2, 0
	elseif state == "hover" then
		edge.Color, edge.Thickness, edge.Transparency = UiKit.LINE, 1, 0.35
	elseif state == "disabled" then
		edge.Color, edge.Thickness, edge.Transparency = UiKit.LINE, 1, 0.92
	else
		edge.Color, edge.Thickness, edge.Transparency = UiKit.LINE, 1, 0.8
	end
	mark(o, a, selected)
end

-- scelto si'/no (la carta "avanza" e prende l'accento)
function UiKit.select(o: GuiObject, on: boolean, accent: Color3?)
	o:SetAttribute("Scelto", on)
	if accent then
		o:SetAttribute("Accento", accent)
	end
	UiKit.state(o, "idle", accent)
end

-- collega hover/pressione a un pulsante (una volta sola)
function UiKit.physical(b: GuiButton, accent: Color3?)
	if b:GetAttribute("Fisico") then
		return
	end
	b:SetAttribute("Fisico", true)
	b.AutoButtonColor = false
	local function acc(): Color3?
		local v = b:GetAttribute("Accento")
		return if typeof(v) == "Color3" then v else accent
	end
	local hover = false
	b.MouseEnter:Connect(function()
		hover = true
		UiKit.state(b, "hover", acc())
	end)
	b.MouseLeave:Connect(function()
		hover = false
		UiKit.state(b, "idle", acc())
	end)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UiKit.state(b, "pressed", acc())
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UiKit.state(b, if hover then "hover" else "idle", acc())
		end
	end)
	UiKit.state(b, "idle", acc())
end

-- carta: superficie in rilievo con angoli vivi, bordo sottile e stati fisici
function UiKit.card(b: GuiButton, selected: boolean?, accent: Color3?)
	b.BackgroundColor3 = UiKit.RAISED
	b.BackgroundTransparency = 0.06
	b.BorderSizePixel = 0
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	for _, c in b:GetChildren() do
		-- i vecchi bordi (UIStroke senza nome) si tolgono: resta il nostro
		if c:IsA("UIStroke") and c.Name ~= "Bordo" then
			c:Destroy()
		end
	end
	local ring = b:FindFirstChild("AnelloLuce")
	if ring then
		ring:Destroy() -- niente anelli che girano attorno alle carte: basta l'accento
	end
	b:SetAttribute("Scelto", selected == true)
	UiKit.physical(b, accent)
end

-- casella (zaino, barra 1-5): cornice di Codex con gli artigli negli angoli. state: "normal",
-- "selected", "valid" (ci puoi mettere l'attrezzo), "disabled" (vuota)
function UiKit.slot(b: GuiObject, state: string?)
	local st = state or "normal"
	if not Cornici.apply(b, "frame_slot_" .. st) then
		return false
	end
	b.BackgroundTransparency = 1
	-- valida e vuota non cambiano con il mouse; scelta resta accesa
	b:SetAttribute("CorniceFissa", st == "valid" or st == "disabled")
	b:SetAttribute("Scelto", st == "selected")
	for _, c in b:GetChildren() do
		if c:IsA("UIStroke") then
			c.Transparency = 1
		end
	end
	return true
end

-- pulsanti: "primary" (oro pieno, testo scuro, taglio obliquo), "secondary" (solo bordo),
-- "danger", "disabled"
function UiKit.button(b: TextButton, kind: string)
	b:SetAttribute("UiNative", true)
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	local shine = b:FindFirstChild("Lucido")
	if shine then
		shine:Destroy()
	end
	local surface = b:FindFirstChild("AssetSurface")
	if surface and surface:IsA("GuiObject") then
		surface.Visible = false
	end
	UiKit.text(b, "button")
	-- cornici di Codex: oro (principale), ferro (secondario e rosso per "pericolo"), spento
	local framed = Cornici.apply(b, if kind == "primary" then "frame_button_primary_normal"
		elseif kind == "disabled" then "frame_button_secondary_disabled"
		else "frame_button_secondary_normal", {
		color = if kind == "danger" then Color3.fromRGB(255, 150, 150) else nil,
	})
	if framed then
		b.BackgroundTransparency = 1
		Cornici.caption(b, math.max(10, Cornici.logical(b).Y * 0.6))
		b.TextColor3 = if kind == "primary" then Color3.fromRGB(255, 222, 140)
			elseif kind == "danger" then Color3.fromRGB(255, 170, 170)
			elseif kind == "disabled" then UiKit.DIM
			else UiKit.TEXT
		b.TextStrokeTransparency = 0.5
		UiKit.edge(b, UiKit.LINE, 1, 1)
		b:SetAttribute("Tipo", kind)
		if kind ~= "disabled" then
			UiKit.physical(b)
			UiKit.state(b, "idle")
		end
		b.AutoButtonColor = false
		return
	end
	if kind == "primary" then
		b.BackgroundColor3 = UiKit.ACCENT
		b.BackgroundTransparency = 0
		b.TextColor3 = Color3.fromRGB(30, 20, 4)
		UiKit.edge(b, Color3.fromRGB(255, 236, 170), 1, 0.4)
	elseif kind == "danger" then
		b.BackgroundColor3 = Color3.fromRGB(120, 28, 38)
		b.BackgroundTransparency = 0.1
		b.TextColor3 = UiKit.TEXT
		UiKit.edge(b, UiKit.BAD, 1, 0.3)
	elseif kind == "disabled" then
		b.BackgroundColor3 = UiKit.RAISED
		b.BackgroundTransparency = 0.3
		b.TextColor3 = UiKit.DIM
		UiKit.edge(b, UiKit.LINE, 1, 0.88)
	else
		b.BackgroundColor3 = UiKit.INK
		b.BackgroundTransparency = 0.35
		b.TextColor3 = UiKit.TEXT
		UiKit.edge(b, UiKit.ICE, 1, 0.45)
	end
	b:SetAttribute("Tipo", kind)
	if kind ~= "disabled" then
		UiKit.physical(b)
	end
	b.AutoButtonColor = false
end

-- filtri e schede piccole: niente riempimento colorato, una riga sotto quando sono scelte
function UiKit.tab(b: TextButton, on: boolean, accent: Color3?)
	b:SetAttribute("UiNative", true)
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	b.BackgroundColor3 = if on then UiKit.RAISED else UiKit.INK
	b.BackgroundTransparency = if on then 0.1 else 0.5
	UiKit.text(b, "button", 17)
	b.TextColor3 = if on then UiKit.TEXT else UiKit.DIM
	-- scheda di Codex (lato destro obliquo): scelta = oro acceso
	b:SetAttribute("Scelto", on)
	if Cornici.apply(b, if on then "frame_tab_selected" else "frame_tab_normal") then
		b.BackgroundTransparency = 1
		Cornici.caption(b, 14)
		b.TextColor3 = if on then Color3.fromRGB(255, 222, 140) else UiKit.MUTED
		local old = b:FindFirstChild("Sotto")
		if old then
			old:Destroy()
		end
		UiKit.edge(b, UiKit.LINE, 1, 1)
		UiKit.physical(b)
		UiKit.state(b, "idle")
		return
	end
	local line = b:FindFirstChild("Sotto") :: Frame?
	if not line then
		local f = Instance.new("Frame")
		f.Name = "Sotto"
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, 1)
		f.Position = UDim2.fromScale(0, 1)
		f.Size = UDim2.new(1, 0, 0, 3)
		f.ZIndex = b.ZIndex + 2
		f.Parent = b
		line = f
	end
	local l = line :: Frame
	l.BackgroundColor3 = accent or UiKit.ACCENT
	l.Visible = on
	UiKit.edge(b, UiKit.LINE, 1, if on then 0.6 else 0.86)
	UiKit.physical(b)
end

return UiKit
