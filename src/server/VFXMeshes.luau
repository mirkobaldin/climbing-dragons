--!strict
-- Le 66 mesh VFX di Codex (VFX_01..VFX_66) caricate su Roblox il 2026-10-13 (asset Mesh fatti
-- con EditableMesh dagli FBX di "Climbing & Dragons - VFX"). I MeshPart stanno gia' nel place in
-- ReplicatedStorage.VFXLib.Mesh; se qualcuno manca (place non salvato) si ricrea da qui.
-- Le 30 elementali (37-66) usano la palette PALETTE come texture e restano bianche.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXMeshes = {}

local PALETTE = "rbxassetid://109155444409384"

local IDS: { [string]: number } = {
	VFX_01_Vortice = 95526756828914,
	VFX_02_SpiraleConica = 125824711292736,
	VFX_03_SferaNastri = 102938037451156,
	VFX_04_SferaFrammentata = 88342774126120,
	VFX_05_OndaUrto = 104457620739773,
	VFX_06_AnelliSpezzati = 76075905488627,
	VFX_07_Fendente = 112224902414855,
	VFX_08_FendenteTriplo = 116466008215243,
	VFX_09_CoronaImpatto = 96048978517264,
	VFX_10_Colonna = 102346366695044,
	VFX_11_StellaImpatto = 97852273797192,
	VFX_12_Scia = 116722311560617,
	VFX_13_RocciaProiettile = 72886339296008,
	VFX_14_RocciaOnda = 108364680810645,
	VFX_15_GeloLance = 124760739862517,
	VFX_16_GeloEruzione = 139778224310114,
	VFX_17_CosmicoNucleo = 124247046611453,
	VFX_18_CosmicoPortale = 136577431082871,
	VFX_19_TempestaLame = 76852887261034,
	VFX_20_TempestaTornado = 84645249635001,
	VFX_21_EclissiCorona = 123807262522649,
	VFX_22_EclissiFalce = 138070649498058,
	VFX_23_FulmineDardo = 140013012425269,
	VFX_24_FulmineGabbia = 86428879407357,
	VFX_25_OssaSpina = 103448064452486,
	VFX_26_OssaMorso = 88612170213464,
	VFX_27_GasNube = 124577058441908,
	VFX_28_GasGetto = 115910529234276,
	VFX_29_YetiArtigli = 132920925313273,
	VFX_30_YetiPugno = 89935459607119,
	VFX_31_GolemFrattura = 84717672511053,
	VFX_32_GolemStalagmiti = 126019778852579,
	VFX_33_GuardianoRespiro = 90052180055724,
	VFX_34_GuardianoOnda = 87788185132181,
	VFX_35_MostroMorso = 122468102310945,
	VFX_36_MostroCoda = 111247297468060,
	VFX_37_RocciaCuoreFratturato = 115954585423652,
	VFX_38_RocciaArtiglioTellurico = 131287666300967,
	VFX_39_RocciaFagliaRadiale = 108320782879495,
	VFX_40_RocciaAriete = 112024214562735,
	VFX_41_GeloLanciaAurora = 91413916701756,
	VFX_42_GeloSigilloEsagonale = 111785135825583,
	VFX_43_GeloLotoGlaciale = 124374673239654,
	VFX_44_GeloAlaTagliente = 140535984588339,
	VFX_45_CosmicoAstrolabio = 90528444671019,
	VFX_46_CosmicoDiscoAccrescimento = 89917876244716,
	VFX_47_CosmicoCometaAstrale = 96356779194751,
	VFX_48_CosmicoStellaDimensionale = 103787287880152,
	VFX_49_TempestaAliBurrasca = 114792370987691,
	VFX_50_TempestaCicloneSpirale = 91240051849992,
	VFX_51_TempestaRasoioEolico = 136482548069173,
	VFX_52_TempestaOcchioUragano = 109471951203759,
	VFX_53_EclissiSoleNero = 87053922761908,
	VFX_54_EclissiLamaApocalisse = 81539582544848,
	VFX_55_EclissiNovaOscura = 95122881281223,
	VFX_56_EclissiSerpenteSolare = 105810601958894,
	VFX_57_FulmineLanciaRamificata = 106015141261816,
	VFX_58_FulmineArtiglioTuono = 113094104448839,
	VFX_59_FulmineSferaTesla = 133225847311918,
	VFX_60_FulmineReteParalizzante = 102814770249168,
	VFX_61_OssaFauciDraconiche = 120520795378833,
	VFX_62_OssaArtiglioScheletrico = 128349113147290,
	VFX_63_OssaSpiraleVertebre = 87914851046414,
	VFX_64_GasLotoMiasma = 92469676198241,
	VFX_65_GasBollaVorticosa = 85769223679869,
	VFX_66_GasSoffioSerpentino = 113626161279072,
}

function VFXMeshes.setup()
	local lib = ReplicatedStorage:FindFirstChild("VFXLib")
	local folder = lib and lib:FindFirstChild("Mesh")
	if not folder then
		warn("[VFX] manca ReplicatedStorage.VFXLib.Mesh: niente mesh VFX")
		return
	end
	local made = 0
	for name, id in IDS do
		if folder:FindFirstChild(name) then
			continue
		end
		local ok, mp = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id), { CollisionFidelity = Enum.CollisionFidelity.Box })
		end)
		if ok and mp then
			mp.Name = name
			mp.Anchored, mp.CanCollide, mp.CanTouch, mp.CanQuery, mp.CastShadow = true, false, false, false, false
			mp.Color = Color3.new(1, 1, 1)
			local n = tonumber(string.match(name, "VFX_(%d+)")) or 0
			if n >= 37 then
				mp.TextureID = PALETTE
				mp.Material = Enum.Material.SmoothPlastic
			else
				mp.Material = Enum.Material.Neon
			end
			mp.Parent = folder
			made += 1
		end
	end
	if made > 0 then
		warn(string.format("[VFX] %d mesh VFX ricreate dagli ID: salvare il place con VFXLib.Mesh completo", made))
	end
end

return VFXMeshes
