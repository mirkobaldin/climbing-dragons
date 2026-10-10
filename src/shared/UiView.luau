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

function UiView.asset(target: ImageLabel, name: string): boolean
	local id = UiAssets.get(name)
	target.Image = id or ""
	target.Visible = id ~= nil
	local slice = (UiAssets.slices :: { [string]: Rect })[name]
	if slice then
		target.ScaleType = Enum.ScaleType.Slice
		target.SliceCenter = slice
		target.SliceScale = 0.5
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
	if string.find(name, "btn_round", 1, true) then
		local img = image :: ImageLabel
		local function resize()
			img.SliceScale = math.max(0.01, target.AbsoluteSize.X / 256)
		end
		resize()
		if not target:GetAttribute("RoundScaleBound") then
			target:SetAttribute("RoundScaleBound", true)
			target:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
		end
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
end

function UiView.screen(name: string): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	if not watchedPlayerGui then
		watchedPlayerGui = true
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

function UiView.template(name: string, parent: Instance): any
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("MainMenu")
	assert(gui, "MainMenu deve essere pronto prima delle schede")
	local copy = UiView.node(gui, "Templates/" .. name):Clone()
	copy.Visible = true
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
