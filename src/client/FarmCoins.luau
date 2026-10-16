--!strict
-- Monete che escono dai draghi della fattoria (recinto dietro la casa, server/Economy). Ogni 10
-- secondi il server paga e alza l'attributo "Paga" della cartella Roost (tag FattoriaDraghi):
-- ogni drago accumula la sua "Rendita" e quando arriva a una moneta intera gli esce sopra
-- "+N" con la moneta, che sale e sparisce. Solo se la camera e' vicina.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)

local FarmCoins = {}

local RANGE = 260
local saved: { [Instance]: number } = {} -- monete accumulate (frazioni) per drago

local function pop(model: Model, amount: number)
	local cf, size = model:GetBoundingBox()
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - cf.Position).Magnitude > RANGE then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "MoneteFattoria"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 + 2, 0))
	anchor.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 52)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = RANGE
	bb.Adornee = anchor
	bb.Parent = anchor
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Position = UDim2.fromOffset(18, 6)
	icon.Parent = bb
	if not Ui.asset(icon, "icon_coin") then
		icon.Image = ""
		icon.BackgroundTransparency = 0
		icon.BackgroundColor3 = Theme.ACCENT
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = icon
	end
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(62, 0)
	text.Size = UDim2.fromOffset(88, 52)
	text.Font = Enum.Font.GothamBlack
	text.TextSize = 32
	text.TextColor3 = Theme.ACCENT
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Text = "+" .. tostring(amount)
	text.Parent = bb
	local info = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame + Vector3.new(0, 7, 0) }):Play()
	task.delay(0.9, function()
		local fade = TweenInfo.new(0.9)
		TweenService:Create(text, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(icon, fade, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
	task.delay(1.9, function()
		anchor:Destroy()
	end)
end

local function watch(folder: Instance)
	folder:GetAttributeChangedSignal("Paga"):Connect(function()
		for _, m in folder:GetChildren() do
			local rate = m:GetAttribute("Rendita")
			if m:IsA("Model") and type(rate) == "number" and rate > 0 then
				local total = (saved[m] or 0) + rate
				local whole = math.floor(total)
				saved[m] = total - whole
				if whole > 0 then
					-- un drago alla volta, sfalsati: non escono tutte insieme
					task.delay(math.random() * 1.5, pop, m, whole)
				end
			end
		end
	end)
end

function FarmCoins.start()
	for _, f in CollectionService:GetTagged("FattoriaDraghi") do
		watch(f)
	end
	CollectionService:GetInstanceAddedSignal("FattoriaDraghi"):Connect(watch)
	CollectionService:GetInstanceRemovedSignal("Riposo"):Connect(function(m)
		saved[m] = nil
	end)
end

return FarmCoins
