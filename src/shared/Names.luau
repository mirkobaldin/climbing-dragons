--!strict
-- Nomi inglesi da mostrare a schermo per gli id italiani dei dati (elementi, rarita', stadi
-- dei draghi, minerali, case, meteo). Gli id restano quelli dei salvataggi e del codice:
-- cambia solo quello che legge il giocatore. Names.t("Gelo") -> "Frost".

local Names = {}

local MAP: { [string]: string } = {
	-- elementi
	Roccia = "Rock",
	Brace = "Ember",
	Gelo = "Frost",
	Cosmico = "Cosmic",
	Tempesta = "Storm",
	Sole = "Sun",
	Ombra = "Shadow",
	Eclissi = "Eclipse",
	Fulmine = "Black Lightning",
	Ossa = "Bone",
	Gas = "Gas",
	-- rarita'
	Comune = "Common",
	Raro = "Rare",
	Epico = "Epic",
	Leggendario = "Legendary",
	-- stadi
	Cucciolo = "Hatchling",
	Giovane = "Young",
	Adulto = "Adult",
	-- minerali ("Cosmico" e' anche il minerale: Cosmic)
	Carbone = "Coal",
	Ferro = "Iron",
	Oro = "Gold",
	Cristallo = "Crystal",
	Rubino = "Ruby",
	-- case
	Tenda = "Tent",
	Baita = "Cabin",
	Chalet = "Chalet",
	-- dove si costruisce
	Banco = "Workbench",
	Ovunque = "Anywhere",
	-- meteo
	Clear = "Clear",
	Cloudy = "Cloudy",
	Rain = "Rain",
	Thunderstorm = "Thunderstorm",
	Storm = "Storm",
	Snow = "Snow",
}

function Names.t(id: any): string
	if type(id) ~= "string" then
		return tostring(id or "")
	end
	return MAP[id] or id
end

-- "Frost Dragon"
function Names.dragon(element: any): string
	return Names.t(element) .. " Dragon"
end

return Names
