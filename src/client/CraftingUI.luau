--!strict
-- Ricette e costi aggiornano i modelli di StarterGui; il server controlla gli acquisti.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Gear = require(Shared:WaitForChild("Gear"))
local Names = require(Shared:WaitForChild("Names"))
local Ui = require(Shared:WaitForChild("UiView"))
local Theme = require(script.Parent.Theme)
local player = Players.LocalPlayer
local CraftingUI = {}
local function count(ore: string): number
	local f = player:FindFirstChild("Ores")
	local v = f and f:FindFirstChild(ore)
	return if v and v:IsA("IntValue") then v.Value else 0
end
function CraftingUI.mount(container: Frame, status: (string, boolean) -> ()): () -> ()
	local list = Ui.node(container, "List")
	local refreshers: { () -> () } = {}
	for k, recipe in Gear.RECIPES do
		local card = Ui.template("RecipeCard", list)
		card.LayoutOrder = k
		-- icona dell'attrezzo (stesse immagini dello zaino); il modellino 3D solo se manca
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icona"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Parent = card.Preview
		Theme.itemIcon(icon, recipe.id, Theme.itemModel(if recipe.id == "Chiodi" then "Pitons" else recipe.id, Theme.ACCENT))
		card.Title.Text = recipe.name
		card.Description.Text = recipe.description
			.. (if recipe.station == "Ovunque" then " · Craft anywhere" else " · At a workbench")
		local materialRows = {}
		local ores = {}
		for ore in recipe.cost do
			table.insert(ores, ore)
		end
		table.sort(ores)
		for i, ore in ores do
			local row = Ui.template("Material", card.Materials)
			-- materiali in fila sotto la descrizione (icona + "Ferro 2/5")
			row.Size = UDim2.new(1 / math.max(1, #ores), -6, 1, 0)
			row.Position = UDim2.fromScale((i - 1) / math.max(1, #ores), 0)
			row.BackgroundTransparency = 1
			local surface = row:FindFirstChild("AssetSurface")
			if surface then
				surface:Destroy() -- niente cornice attorno a ogni materiale
			end
			row.SizeLimit.MinSize = Vector2.zero
			row.SizeLimit.MaxSize = Vector2.new(10000, 10000)
			Theme.assetPreview(row.Icon, "ore_" .. ore, Theme.oreModel(ore))
			materialRows[ore] = row
		end
		local function refresh()
			local affordable = true
			for ore, amount in recipe.cost do
				local have = count(ore)
				affordable = affordable and have >= amount
				materialRows[ore].Text.Text = string.format("%s %d/%d", Names.t(ore), have, amount)
				materialRows[ore].Text.TextColor3 = if have >= amount then Theme.GOOD else Theme.BAD
			end
			local owned = not recipe.consumable and Gear.has(player, recipe.id)
			card.Craft.Text = if owned then "Owned" else "Craft"
			card.Craft.BackgroundColor3 = if owned then Theme.MUTED elseif affordable then Theme.GOOD else Theme.CARD
		end
		table.insert(refreshers, refresh)
		card.Craft.Activated:Connect(function()
			if not recipe.consumable and Gear.has(player, recipe.id) then
				return
			end
			local ok, message = (RS.Remotes:WaitForChild("Craft") :: RemoteFunction):InvokeServer(recipe.id)
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
