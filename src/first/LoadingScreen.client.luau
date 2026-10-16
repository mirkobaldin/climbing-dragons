--!strict
-- ReplicatedFirst mantiene il caricamento Roblox finche' i moduli UI non sono disponibili.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Assets = require(Shared:WaitForChild("UiAssets"))
local player = Players.LocalPlayer
local t0 = os.clock()
local MIN_TIME = 3
local TIPS = {
	"Place pitons on the wall: if you fall, the rope catches you.",
	"Place pitons before the hard part, not after.",
	"Dragons hatch from eggs hidden all over the mountain.",
	"Train your dragon in the arena to reach Lv 100 and evolve it.",
	"Toxic valleys: only a Gas dragon can breathe there.",
	"Each dragon has its own land on the mountain. Find them all.",
}
local gui = Ui.screen("Caricamento")
gui.Enabled = true
ReplicatedFirst:RemoveDefaultLoadingScreen()
-- la barra degli attrezzi di Roblox (1 Ice Axe, 2 Pickaxe...) finiva sopra il pulsante PLAY e si
-- prendeva il click e la schermata restava bloccata. Nascosta finche' c'e' il caricamento
local function setBackpack(on: boolean)
	for _ = 1, 20 do
		if pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, on)
		end) then
			return
		end
		task.wait(0.25)
	end
end
task.spawn(setBackpack, false)
local progress = Ui.node(gui, "Progress")
local tip = Ui.node(gui, "Tip")
local play = Ui.node(gui, "Play")
Ui.node(gui, "Title").Visible = Assets.get("logo") == nil
Ui.skin(progress, "panel_card")
local ready, chosen = false, false
play.Visible = false
play.Activated:Connect(function()
	if ready then
		chosen = true
	end
end)
-- si parte anche con Invio, Spazio o un click (o tocco) in qualunque punto
local anyInput = UserInputService.InputBegan:Connect(function(input)
	if not ready then
		return
	end
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		chosen = true
	end
end)
local preload = {}
for _, name in { "bg_loading", "logo", "panel_card", "btn_primary_normal" } do
	local id = Assets.get(name)
	if id then
		table.insert(preload, id)
	end
end
if #preload > 0 then
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preload)
		end)
	end)
end
local maxQueue = 1
task.spawn(function()
	local ticks = 0
	while gui.Parent and not ready do
		ticks += 1
		if ticks % 25 == 1 then
			tip.Text = TIPS[math.random(1, #TIPS)]
		end
		local queue = ContentProvider.RequestQueueSize
		maxQueue = math.max(maxQueue, queue)
		local p = 0.15 * math.min(1, (os.clock() - t0) / MIN_TIME)
		p += if game:IsLoaded() then 0.35 else 0
		p += 0.3 * (1 - queue / maxQueue)
		p += if player.Character then 0.2 else 0
		progress.Fill.Size = UDim2.fromScale(math.clamp(p, progress.Fill.Size.X.Scale, 1), 1)
		task.wait(0.2)
	end
end)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not player.Character then
	player.CharacterAdded:Wait()
end
task.wait(math.max(0, MIN_TIME - (os.clock() - t0)))
progress.Fill.Size = UDim2.fromScale(1, 1)
ready = true
play.Visible = true
-- se non si tocca niente si parte da soli dopo 15 s (mai piu' bloccati qui)
local readyAt = os.clock()
while gui.Parent and not chosen and os.clock() - readyAt < 15 do
	task.wait(0.1)
end
anyInput:Disconnect()
for _, d in gui:GetDescendants() do
	if d:IsA("GuiObject") then
		TweenService:Create(d, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, TweenInfo.new(0.18), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif d:IsA("ImageLabel") then
		TweenService:Create(d, TweenInfo.new(0.18), { ImageTransparency = 1 }):Play()
	end
end
task.wait(0.2)
gui:Destroy()
setBackpack(true)
