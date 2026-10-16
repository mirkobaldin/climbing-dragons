--!strict
-- Forme a parallelogramma per l'interfaccia (Mirko 15/10: "i riquadri non rettangolari ma tipo
-- parallelogramma, solo la parte che punta verso il centro"). Roblox non ha forme oblique: il
-- riquadro e' un corpo rettangolare piu' una "punta" larga quanto l'obliquo, tagliata in
-- diagonale da una UIGradient di trasparenza (gradino a 0.5). La sfumatura lavora in pixel:
-- la rotazione che porta il taglio da un angolo all'altro e' atan2(larghezza, altezza) (provato
-- in Studio il 15/10), e si ricalcola quando cambia la grandezza.
--
--   Slant.new(parent, color, transparency, slant, side) -> Frame (contenitore trasparente)
--   Slant.paint(shape, color, transparency)
--   Slant.bar(parent, back, fill, slant, side)  -> barra obliqua; Slant.setFill(bar, 0..1)
--   Slant.setSlant(shape, slant)  -> cambia la larghezza dell'obliquo (barre che cambiano altezza)
-- side "para": parallelogramma vero (obliqui paralleli ai due lati, in alto spostato a destra),
-- come le cornici oblique delle barre (artifacts/ui-rifinitura-20261017)

local Slant = {}

local CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.497, 0),
	NumberSequenceKeypoint.new(0.503, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function cutTip(tip: Frame, side: string)
	local g = Instance.new("UIGradient")
	g.Name = "Taglio"
	g.Transparency = CUT
	g.Parent = tip
	local function update()
		local s = tip.AbsoluteSize
		if s.Y <= 0 then
			return
		end
		local a = math.deg(math.atan2(s.X, s.Y))
		-- destra: pieno in alto a sinistra ("/"); sinistra: pieno in alto a destra ("\");
		-- "para" (punta sinistra del parallelogramma): pieno in basso a destra ("/")
		g.Rotation = if side == "left" then 180 - a elseif side == "para" then a + 180 else a
	end
	tip:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

-- slant: larghezza della parte obliqua in pixel; side: "right" (default), "left" o "both"
function Slant.new(parent: Instance, color: Color3, transparency: number?, slant: number?, side: string?): Frame
	local w = slant or 18
	local where = side or "right"
	local holder = Instance.new("Frame")
	holder.Name = "Obliquo"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(200, 40)
	holder:SetAttribute("Slant", w)
	holder:SetAttribute("Lati", where)
	local left = if where == "left" or where == "both" or where == "para" then w else 0
	local right = if where == "right" or where == "both" or where == "para" then w else 0
	local body = Instance.new("Frame")
	body.Name = "Corpo"
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(left, 0)
	body.Size = UDim2.new(1, -(left + right), 1, 0)
	body.ZIndex = holder.ZIndex
	body.Parent = holder
	for _, s in { "left", "right" } do
		if (s == "left" and left > 0) or (s == "right" and right > 0) then
			local tip = Instance.new("Frame")
			tip.Name = if s == "left" then "PuntaSx" else "PuntaDx"
			tip.BorderSizePixel = 0
			tip.Position = if s == "left" then UDim2.fromOffset(0, 0) else UDim2.new(1, -w, 0, 0)
			tip.Size = UDim2.new(0, w + 1, 1, 0) -- +1: niente fessura fra corpo e punta
			if s == "left" then
				tip.Position = UDim2.fromOffset(-1, 0)
			end
			tip.ZIndex = holder.ZIndex
			tip.Parent = holder
			cutTip(tip, if s == "left" and where == "para" then "para" else s)
		end
	end
	Slant.paint(holder, color, transparency or 0)
	holder.Parent = parent
	return holder
end

function Slant.paint(shape: Instance, color: Color3, transparency: number?)
	for _, n in { "Corpo", "PuntaSx", "PuntaDx" } do
		local f = shape:FindFirstChild(n)
		if f and f:IsA("Frame") then
			f.BackgroundColor3 = color
			f.BackgroundTransparency = transparency or 0
		end
	end
end

-- sfumatura verticale (riflesso in alto) sul solo corpo: le punte hanno gia' il taglio
function Slant.shine(shape: Instance, top: Color3, bottom: Color3)
	local body = shape:FindFirstChild("Corpo")
	if body then
		local g = body:FindFirstChild("Lucido") :: UIGradient? or Instance.new("UIGradient")
		g.Name = "Lucido"
		g.Rotation = 90
		g.Color = ColorSequence.new(top, bottom)
		g.Parent = body
	end
end

-- cambia la larghezza dell'obliquo di una forma (e del suo riempimento, se e' una barra)
function Slant.setSlant(shape: Instance, slant: number)
	if not shape:IsA("Frame") then
		return
	end
	local w = math.max(0, slant)
	shape:SetAttribute("Slant", w)
	local where = (shape:GetAttribute("Lati") or "right") :: string
	local left = if where == "left" or where == "both" or where == "para" then w else 0
	local right = if where == "right" or where == "both" or where == "para" then w else 0
	local body = shape:FindFirstChild("Corpo") :: Frame?
	if body then
		body.Position = UDim2.fromOffset(left, 0)
		body.Size = UDim2.new(1, -(left + right), 1, 0)
	end
	local tl = shape:FindFirstChild("PuntaSx") :: Frame?
	if tl then
		tl.Visible = w > 0
		tl.Position = UDim2.fromOffset(-1, 0)
		tl.Size = UDim2.new(0, w + 1, 1, 0)
	end
	local tr = shape:FindFirstChild("PuntaDx") :: Frame?
	if tr then
		tr.Visible = w > 0
		tr.Position = UDim2.new(1, -w, 0, 0)
		tr.Size = UDim2.new(0, w + 1, 1, 0)
	end
	local f = shape:FindFirstChild("Pieno")
	if f then
		Slant.setSlant(f, w)
	end
end

-- barra obliqua: fondo scuro e riempimento obliquo dello stesso taglio
function Slant.bar(parent: Instance, back: Color3, fill: Color3, slant: number?, side: string?): Frame
	local bar = Slant.new(parent, back, 0.25, slant, side)
	bar.Name = "Barra"
	bar.ClipsDescendants = false
	local f = Slant.new(bar, fill, 0, slant, side)
	f.Name = "Pieno"
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = bar.ZIndex + 1
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c.ZIndex = f.ZIndex
		end
	end
	return bar
end

function Slant.setFill(bar: Instance, ratio: number)
	local f = bar:FindFirstChild("Pieno")
	if f and f:IsA("Frame") then
		local r = math.clamp(ratio, 0, 1)
		local s = (bar:GetAttribute("Slant") or 0) :: number
		-- la punta resta della sua larghezza: sotto quella il pieno sparisce
		f.Visible = r > 0.001
		f.Size = UDim2.new(r, if r < 1 then math.floor(s * (1 - r)) else 0, 1, 0)
	end
end

function Slant.setZ(shape: Instance, z: number)
	if shape:IsA("GuiObject") then
		shape.ZIndex = z
	end
	for _, c in shape:GetChildren() do
		if c:IsA("Frame") and (c.Name == "Corpo" or c.Name == "PuntaSx" or c.Name == "PuntaDx") then
			c.ZIndex = z
		elseif c:IsA("Frame") and c.Name == "Pieno" then
			Slant.setZ(c, z + 1) -- riempimento delle barre sopra il fondo
		end
	end
end

return Slant
