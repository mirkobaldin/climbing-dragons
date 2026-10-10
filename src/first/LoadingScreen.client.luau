--!strict
-- ReplicatedFirst mantiene il caricamento Roblox finche' i moduli UI non sono disponibili.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = RS:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("UiView"))
local Assets = require(Shared:WaitForChild("UiAssets"))
local player = Players.LocalPlayer
local t0 = os.clock()
local MIN_TIME = 3
local TIPS = {
	"Press F on the wall to place a piton.",
	"Place pitons before the hard part, not after.",
	"Dragons hatch from eggs hidden all over the mountain.",
	"Train your dragon in the arena to reach Lv 100 and evolve it.",
	"Toxic valleys: only a Gas dragon can breathe there.",
	"Each dragon has its own land on the mountain. Find them all.",
}
local gui = Ui.screen("Caricamento")
gui.Enabled = true
ReplicatedFirst:RemoveDefaultLoadingScreen()
local progress = Ui.node(gui, "Progress")
local tip = Ui.node(gui, "Tip")
local play = Ui.node(gui, "Play")
Ui.node(gui, "Title").Visible = Assets.get("logo") == nil
Ui.skin(progress, "panel_card")
local ready, chosen = false, false
play.Visible = false
play.Activated:Connect(function() if ready then chosen = true end end)
local preload = {}
for _, name in {"bg_loading", "logo", "panel_card", "btn_primary_normal"} do
	local id = Assets.get(name)
	if id then table.insert(preload, id) end
end
if #preload > 0 then task.spawn(function() pcall(function() ContentProvider:PreloadAsync(preload) end) end) end
local maxQueue = 1
task.spawn(function()
	local ticks = 0
	while gui.Parent and not ready do
		ticks += 1
		if ticks % 25 == 1 then tip.Text = TIPS[math.random(1, #TIPS)] end
		local queue = ContentProvider.RequestQueueSize
		maxQueue = math.max(maxQueue, queue)
		local p = .15 * math.min(1, (os.clock()-t0)/MIN_TIME)
		p += if game:IsLoaded() then .35 else 0
		p += .3 * (1-queue/maxQueue)
		p += if player.Character then .2 else 0
		progress.Fill.Size = UDim2.fromScale(math.clamp(p, progress.Fill.Size.X.Scale, 1), 1)
		task.wait(.2)
	end
end)
if not game:IsLoaded() then game.Loaded:Wait() end
if not player.Character then player.CharacterAdded:Wait() end
task.wait(math.max(0, MIN_TIME-(os.clock()-t0)))
progress.Fill.Size = UDim2.fromScale(1, 1)
ready = true
play.Visible = true
while gui.Parent and not chosen do task.wait(.1) end
for _, d in gui:GetDescendants() do
	if d:IsA("GuiObject") then TweenService:Create(d, TweenInfo.new(.18), {BackgroundTransparency=1}):Play() end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		TweenService:Create(d, TweenInfo.new(.18), {TextTransparency=1, TextStrokeTransparency=1}):Play()
	elseif d:IsA("ImageLabel") then TweenService:Create(d, TweenInfo.new(.18), {ImageTransparency=1}):Play() end
end
task.wait(.2)
gui:Destroy()

