--!strict
-- Prestazioni sui telefoni e sui computer deboli (Mirko 15/10: "ottimizzazione"). Solo in locale:
--   * ombre spente su alberi, borghi, zone a tema e villaggio (14.800 parti nel bosco e 14.400
--     nei borghi: le ombre sono la spesa piu' grande sul telefono). Le parti arrivano con lo
--     streaming, quindi si sistemano anche quelle nuove, a gruppi;
--   * via profondita' di campo e raggi del sole (effetti a tutto schermo costosi sui telefoni).
-- Si accende se lo schermo e' touch o se la qualita' grafica di Roblox e' bassa (<= 4); si
-- prova dal computer con l'attributo SimTouch = true sul giocatore.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Prestazioni = {}

local FOLDERS = { "Forest", "Borghi", "ZoneATema", "Village", "Glacier", "Decorazioni" }

local function lowEnd(): boolean
	if UserInputService.TouchEnabled or Players.LocalPlayer:GetAttribute("SimTouch") == true then
		return true
	end
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	-- 0 = automatica: decide Roblox, qui non si tocca niente
	return ok and type(level) == "number" and level > 0 and level <= 4
end

function Prestazioni.start()
	if not lowEnd() then
		return
	end
	for _, name in { "DepthOfField", "SunRays" } do
		local e = Lighting:FindFirstChild(name)
		if e and e:IsA("PostEffect") then
			e.Enabled = false
		end
	end
	local queue: { BasePart } = {}
	local function add(d: Instance)
		if d:IsA("BasePart") and d.CastShadow then
			table.insert(queue, d)
		end
	end
	local function watch(folder: Instance)
		for _, d in folder:GetDescendants() do
			add(d)
		end
		folder.DescendantAdded:Connect(add)
	end
	for _, name in FOLDERS do
		task.spawn(function()
			local f = workspace:WaitForChild(name, 60)
			if f then
				watch(f)
			end
		end)
	end
	-- a gruppi di 500 per frame: decine di migliaia di parti tutte insieme bloccherebbero il gioco
	task.spawn(function()
		while true do
			local n = 0
			while #queue > 0 and n < 500 do
				local p = table.remove(queue) :: BasePart
				if p.Parent then
					p.CastShadow = false
				end
				n += 1
			end
			task.wait(if #queue > 0 then 0 else 1)
		end
	end)
end

return Prestazioni
