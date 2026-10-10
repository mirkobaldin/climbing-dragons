--!strict
-- Texture dei modelli di Blender (ambientCG CC0, preparate da tools/blender/borghi_lib.py in
-- tools/blender/out/tex e caricate su Roblox): per ogni materiale le mappe della
-- SurfaceAppearance che BorghiKit mette sui MeshPart. Il cristallo e' chiaro: in gioco si tinge
-- col colore del bioma (SurfaceAppearance.Color).

export type Maps = { color: string, normal: string?, roughness: string?, metalness: string? }

local function id(n: number): string
	return "rbxassetid://" .. n
end

local T: { [string]: Maps } = {
	TILE = { color = id(91586213140504), normal = id(110395981403483), roughness = id(135465390445138) },
	SKIRT = { color = id(91586213140504), normal = id(110395981403483), roughness = id(135465390445138) },
	RIDGE = { color = id(134588994509824), normal = id(110395981403483), roughness = id(135465390445138) },
	RIDGEWHITE = { color = id(103866486433828), normal = id(124319302417279), roughness = id(80057325646727) },
	PLASTER = { color = id(103866486433828), normal = id(124319302417279), roughness = id(80057325646727) },
	TIMBER = { color = id(93438052638998), normal = id(131569270535794), roughness = id(91838887113010) },
	TIMBERDARK = { color = id(112581319616322), normal = id(131569270535794), roughness = id(91838887113010) },
	WOOD = { color = id(90411877804564), normal = id(131569270535794), roughness = id(91838887113010) },
	LACQUER = { color = id(103249829788452), normal = id(81701406687079), roughness = id(110190737235158) },
	STONE = { color = id(107375807288564), normal = id(95538525197936), roughness = id(91309019088878) },
	STONEDARK = { color = id(112465978723663), normal = id(130169793964927), roughness = id(96968882169828) },
	THATCH = { color = id(96158152988157), normal = id(105567537021916), roughness = id(120769058486071) },
	BAMBOO = { color = id(106567829936014), normal = id(123315250715477), roughness = id(70833810972037) },
	TATAMI = { color = id(89399275114324), normal = id(123315250715477), roughness = id(70833810972037) },
	ROPE = { color = id(118548701434635), normal = id(123315250715477), roughness = id(70833810972037) },
	GOLD = { color = id(138304424546075), normal = id(136970840727270), roughness = id(138571373052207), metalness = id(80021249612245) },
	BRONZE = { color = id(89498186000250), normal = id(136970840727270), roughness = id(138571373052207), metalness = id(80021249612245) },
	METAL = { color = id(82732681736082), normal = id(73741776210190), roughness = id(103067074187093), metalness = id(80050259027437) },
	IRON = { color = id(136152262328525), normal = id(128433103733917), roughness = id(79020044865715), metalness = id(80050259027437) },
	LEATHER = { color = id(78192655586692), normal = id(126186380999975), roughness = id(139760894103625) },
	GRIP = { color = id(89591297955006), normal = id(96253664835771), roughness = id(116996353227347) },
	ROCK = { color = id(85507949720390), normal = id(111051006133955), roughness = id(121398724557178) },
	EARTH = { color = id(105031836420863), normal = id(111051006133955), roughness = id(121398724557178) },
	GRASS = { color = id(133772671910412), normal = id(111051006133955), roughness = id(121398724557178) },
	CRYSTAL = { color = id(75119609179875), normal = id(115441537747618), roughness = id(136212886817494) },
}

return T
