--!strict
-- Schermata di morte: sfumatura rossa dai bordi, "SEI MORTO", la causa (caduta da N metri,
-- congelamento, valanga...), quota massima e tempo di sopravvivenza, un consiglio, e i
-- pulsanti grandi "Rinasci" e (se attivo) "Soccorso alpino" per rinascere dove sei caduto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShopConfig"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local DeathScreen = {}

local TIPS = {
	"Pianta un chiodo (F) prima dei tratti lunghi: la corda ti ferma se cadi.",
	"Sopra i 1200 m fa freddo: stai vicino ai fuochi o costruisci la Tuta termica.",
	"Quando senti l'avviso di una frana, spostati di lato!",
	"Le pareti di ghiaccio vogliono i Ramponi.",
	"I campi base sono punti di rinascita: accampati quando ne trovi uno.",
	"Cadere in acqua non fa male.",
}

function DeathScreen.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeathScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local shade = Theme.frame(gui, Color3.new(0, 0, 0), 1)
	shade.Size = UDim2.fromScale(1, 1)
	local vignette = Theme.frame(gui, Color3.fromRGB(120, 0, 0), 0)
	vignette.Size = UDim2.fromScale(1, 1)
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.35, 0.85),
		NumberSequenceKeypoint.new(0.65, 0.85),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	grad.Parent = vignette

	local panel = Theme.frame(gui, nil, 1)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0, 330)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 330)
	limit.Parent = panel
	local layout = Theme.list(panel, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local title = Theme.label(panel, "SEI MORTO", 56, Color3.fromRGB(255, 80, 70), true)
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Size = UDim2.new(1, 0, 0, 64)
	title.TextStrokeTransparency = 0.3
	title.LayoutOrder = 1
	local cause = Theme.label(panel, "", 22, Theme.TEXT, true)
	cause.TextXAlignment = Enum.TextXAlignment.Center
	cause.LayoutOrder = 2
	local stats = Theme.label(panel, "", 15, Theme.MUTED)
	stats.TextXAlignment = Enum.TextXAlignment.Center
	stats.LayoutOrder = 3
	local tip = Theme.label(panel, "", 14, Theme.ACCENT)
	tip.TextXAlignment = Enum.TextXAlignment.Center
	tip.Size = UDim2.new(1, 0, 0, 40)
	tip.LayoutOrder = 4
	local row = Theme.frame(panel, nil, 1)
	row.Size = UDim2.new(1, 0, 0, 56)
	row.LayoutOrder = 5
	local rowLayout = Theme.list(row, 12, true)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local respawn = Theme.button(row, "Rinasci", Theme.GOOD, UDim2.new(0, 190, 0, 54))
	respawn.TextSize = 20
	local revive = Theme.button(row, "Soccorso alpino (R$)", Theme.ACCENT, UDim2.new(0, 220, 0, 54))
	revive.TextSize = 16
	revive.Visible = ShopConfig.DEV_PRODUCTS.Revive > 0

	respawn.Activated:Connect(function()
		(remotes:WaitForChild("Respawn") :: RemoteEvent):FireServer()
	end)
	revive.Activated:Connect(function()
		(remotes:WaitForChild("Shop") :: RemoteFunction):InvokeServer("robux", "Revive")
	end)

	local function show()
		local deathCause = player:GetAttribute("DeathCause")
		cause.Text = if type(deathCause) == "string" then deathCause else "Causa sconosciuta"
		local raw = player:GetAttribute("DeathStats")
		local maxY, alive = 0, 0
		if type(raw) == "string" then
			local a, b = string.match(raw, "^(%d+)|(%d+)$")
			maxY, alive = tonumber(a) or 0, tonumber(b) or 0
		end
		stats.Text = string.format("Quota massima  %d m   ·   Sopravvissuto  %d:%02d", maxY, alive // 60, alive % 60)
		tip.Text = TIPS[math.random(1, #TIPS)]
		gui.Enabled = true
		shade.BackgroundTransparency = 1
		vignette.BackgroundTransparency = 1
		title.TextTransparency = 1
		TweenService:Create(shade, TweenInfo.new(1.2), { BackgroundTransparency = 0.45 }):Play()
		TweenService:Create(vignette, TweenInfo.new(0.8), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(title, TweenInfo.new(0.8, Enum.EasingStyle.Back), { TextTransparency = 0 }):Play()
	end

	local function onCharacter(character: Model)
		gui.Enabled = false
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			task.wait(0.4) -- il server registra la causa
			show()
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

return DeathScreen
