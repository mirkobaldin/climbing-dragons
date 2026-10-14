-- Versione semplice di esporta_scheletri: stampa nell'Output uno scheletro compatto per drago,
-- da copiare (clic nell'Output, Ctrl+A, Ctrl+C) e incollare nella chat della sessione cloud.
-- Righe: "D|nome|numero ossa|ingombro|Seat", "B|indice|nome|indice genitore|x,y,z" (spazio del perno),
-- "A|collo|coda|zampe|ali" (indici delle ossa riconosciute da MapGen.AnimDraghi.analizza).
local SS = game:GetService("ServerStorage")
local an
pcall(function() an = require(SS.MapGen.AnimDraghi:Clone()).analizza end)
local function f(x) return string.format("%.2f", x) end
local function p3(v) return f(v.X) .. "," .. f(v.Y) .. "," .. f(v.Z) end
local roots, seen, out = {}, {}, {}
for _, r in { SS:FindFirstChild("Draghi"), workspace:FindFirstChild("RigDraghi") } do
	for _, m in r and r:GetChildren() or {} do table.insert(roots, m) end
end
for _, m in SS:GetChildren() do if string.sub(m.Name, 1, 5) == "Drago" then table.insert(roots, m) end end
for _, m in roots do
	if m:IsA("Model") and not seen[m] then
		seen[m] = true
		local pv, idx, bones = m:GetPivot(), {}, {}
		for _, d in m:GetDescendants() do
			if d:IsA("Bone") then table.insert(bones, d); idx[d] = #bones end
		end
		local seat = m:GetAttribute("Seat")
		table.insert(out, "D|" .. m.Name .. "|" .. #bones .. "|" .. p3(m:GetExtentsSize()) .. "|" .. (seat and p3(seat) or "-"))
		for i, b in bones do
			table.insert(out, "B|" .. i .. "|" .. b.Name .. "|" .. (idx[b.Parent] or 0) .. "|" .. p3(pv:PointToObjectSpace(b.WorldPosition)))
		end
		if an and #bones > 0 then
			local ok, sk = pcall(an, m)
			local function L(t) local s = {} for _, b in t or {} do table.insert(s, idx[b] or "?") end return table.concat(s, " ") end
			if ok then
				local z, a = {}, {}
				for _, l in sk.legs or {} do table.insert(z, (l.front and "A" or "P") .. l.side .. ":" .. L(l.bones)) end
				for _, w in sk.wings or {} do table.insert(a, w.side .. ":" .. L(w.arm) .. "/" .. #(w.fingers or {})) end
				table.insert(out, "A|" .. L(sk.neck) .. "|" .. L(sk.tail) .. "|" .. table.concat(z, ";") .. "|" .. table.concat(a, ";"))
			else
				table.insert(out, "A|errore " .. tostring(sk))
			end
		end
	end
end
for i = 1, #out, 40 do print(table.concat(out, "\n", i, math.min(i + 39, #out))) end
print("[Scheletri] fine, " .. #out .. " righe")
