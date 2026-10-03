--!strict
-- Scheda "Crafting" del menu (si apre anche dal Banco da lavoro): gli attrezzi con il costo
-- in minerali (verde = li hai, rosso = ti mancano) e "Costruisci". Il server controlla tutto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gear"))
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local CraftingUI = {}

local GEAR_COLORS = {
	Ramponi = Color3.fromRGB(170, 174, 180),
	Tuta = Color3.fromRGB(230, 120, 60),
	Rampino = Color3.fromRGB(196, 150, 80),
	PiccoRinforzato = Color3.fromRGB(255, 190, 40),
}

local function oreCount(ore: string): number
	local folder = player:FindFirstChild("Minerali")
	local v = folder and folder:FindFirstChild(ore) :: IntValue?
	return if v then v.Value else 0
end

-- icone 3D gia' pronte in Theme.itemModel per le ricette nuove
local ICON = { Chiodi = "Pitons", Bende = "Medkit", Torcia = "Torcia" }

function CraftingUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Theme.scroll(container)
	Theme.list(list, 8)
	local refreshers: { () -> () } = {}

	for _, recipe in Gear.RECIPES do
		local card = Theme.frame(list, Theme.CARD)
		card.Size = UDim2.new(1, -8, 0, 92)
		Theme.corner(card, 10)
		Theme.viewport(card, Theme.itemModel(ICON[recipe.id] or recipe.id, GEAR_COLORS[recipe.id] or Theme.ACCENT), UDim2.new(0, 76, 0, 76), false).Position =
			UDim2.new(0, 8, 0, 8)
		-- dove si costruisce: al volo ovunque, oppure solo al banco (campo o casa)
		local where = if recipe.station == "Ovunque"
			then '  <font color="#6ECD78" size="12">ovunque</font>'
			else '  <font color="#FFC450" size="12">al banco da lavoro</font>'
		local title = Theme.label(card, recipe.name .. where, 16, Theme.TEXT, true)
		title.Position = UDim2.new(0, 92, 0, 6)
		title.Size = UDim2.new(1, -220, 0, 20)
		local desc = Theme.label(card, recipe.description, 12, Theme.MUTED)
		desc.Position = UDim2.new(0, 92, 0, 28)
		desc.Size = UDim2.new(1, -220, 0, 30)
		local cost = Theme.label(card, "", 13, Theme.TEXT, true)
		cost.Position = UDim2.new(0, 92, 0, 62)
		cost.Size = UDim2.new(1, -220, 0, 20)
		local button = Theme.button(card, "Costruisci", Theme.GOOD, UDim2.new(0, 116, 0, 42))
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -10, 0.5, 0)

		local function refresh()
			local parts = {}
			local affordable = true
			for ore, amount in recipe.cost do
				local have = oreCount(ore)
				affordable = affordable and have >= amount
				table.insert(parts, string.format('<font color="%s">%s %d/%d</font>', if have >= amount then "#6ECD78" else "#EB5F55", ore, have, amount))
			end
			cost.Text = table.concat(parts, "   ")
			if not recipe.consumable and Gear.has(player, recipe.id) then
				button.Text = "Posseduto"
				button.BackgroundColor3 = Theme.MUTED
			else
				button.Text = "Costruisci"
				button.BackgroundColor3 = if affordable then Theme.GOOD else Color3.fromRGB(110, 114, 124)
			end
		end
		table.insert(refreshers, refresh)
		button.Activated:Connect(function()
			if not recipe.consumable and Gear.has(player, recipe.id) then
				return
			end
			local ok, message = (remotes:WaitForChild("Craft") :: RemoteFunction):InvokeServer(recipe.id)
			status(message or "", ok)
			for _, r in refreshers do
				r()
			end
		end)
	end

	return function()
		for _, r in refreshers do
			r()
		end
	end
end

return CraftingUI
