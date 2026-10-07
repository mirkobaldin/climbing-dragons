--!strict
-- Schermata di caricamento (ReplicatedFirst: parte prima di tutto il resto).
-- IMAGE = l'immagine di sfondo: caricala su Roblox (Creator Hub > Decal/Image) e incolla qui il
-- suo id ("rbxassetid://123..."). Senza immagine c'e' uno sfondo a sfumatura coi colori del gioco.
-- Resta almeno MIN_TIME secondi, poi sparisce quando il gioco e il personaggio sono pronti.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local IMAGE = "rbxassetid://138361268163291" -- la key art "CLIMB - Reach higher" (ha gia' il logo)
local MIN_TIME = 3
local TIPS = {
	"No checkpoints. Every meter counts.",
	"Place pitons (F) before the hard part, not after.",
	"Dragons hatch from eggs hidden all over the mountain.",
	"Train your dragon in the arena to reach Lv 100 and evolve it.",
	"Toxic valleys: only a Gas dragon can breathe there.",
	"Each dragon has its own land on the mountain. Find them all.",
}

local player = Players.LocalPlayer
local t0 = os.clock()
ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "Caricamento"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 14, 30)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(34, 40, 78)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 40)),
})
grad.Rotation = 90
grad.Parent = bg

if IMAGE ~= "" then
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = IMAGE
	img.ScaleType = Enum.ScaleType.Crop
	img.Parent = bg
	-- velo scuro in basso: le scritte si leggono su qualunque immagine
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 0.45)
	shade.Position = UDim2.fromScale(0, 0.55)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BorderSizePixel = 0
	shade.Parent = bg
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(1, 0.25)
	fade.Parent = shade
end

local function label(text: string, y: number, h: number, font: Enum.Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.8, h)
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.Text = text
	l.Parent = bg
	return l
end
if IMAGE == "" then
	label("HARDCORE CLIMBING", 0.72, 0.09, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
	label("& DRAGONS", 0.79, 0.04, Enum.Font.GothamBold, Color3.fromRGB(255, 180, 90))
end
local tip = label(TIPS[math.random(1, #TIPS)], 0.93, 0.03, Enum.Font.Gotham, Color3.fromRGB(220, 225, 240))

-- barra
local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.86)
barBack.Size = UDim2.fromScale(0.4, 0.012)
barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
barBack.BorderSizePixel = 0
barBack.Parent = bg
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(255, 170, 70)
bar.BorderSizePixel = 0
bar.Parent = barBack
corner:Clone().Parent = bar

gui.Parent = player:WaitForChild("PlayerGui")
-- l'immagine prima di tutto il resto: appare subito, mentre la mappa si carica dietro
if IMAGE ~= "" then
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ IMAGE })
		end)
	end)
end

-- avanzamento: tempo, gioco caricato, coda dei contenuti, personaggio
local maxQueue = 1
task.spawn(function()
	local k = 0
	while gui.Parent do
		k += 1
		if k % 25 == 0 then
			tip.Text = TIPS[math.random(1, #TIPS)]
		end
		local queue = ContentProvider.RequestQueueSize
		maxQueue = math.max(maxQueue, queue)
		local p = 0.15 * math.min(1, (os.clock() - t0) / MIN_TIME)
		p += if game:IsLoaded() then 0.35 else 0
		p += 0.3 * (1 - queue / maxQueue)
		p += if player.Character then 0.2 else 0
		bar.Size = UDim2.fromScale(math.clamp(p, bar.Size.X.Scale, 1), 1)
		task.wait(0.2)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not player.Character then
	player.CharacterAdded:Wait()
end
local wait = MIN_TIME - (os.clock() - t0)
if wait > 0 then
	task.wait(wait)
end
bar.Size = UDim2.fromScale(1, 1)
task.wait(0.3)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif d:IsA("ImageLabel") then
		TweenService:Create(d, TweenInfo.new(0.6), { ImageTransparency = 1 }):Play()
	end
end
task.wait(0.7)
gui:Destroy()
