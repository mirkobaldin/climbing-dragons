# Scrive cloud/<Nome>/CONTROLLO.md (voti della sezione 3 di docs/CLOUD_SESSIONE.md, onesti) e la
# tabella dei modelli in cloud/LEGGIMI.md, leggendo info.json e Markers.json di ogni modello.
#   python3 tools/blender/controllo.py
import json
import os

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLOUD = os.path.join(REPO, "cloud")
CRIT = ["sagoma da lontano", "dettagli da vicino", "materiali (sporco, usura, colore)", "proporzioni col personaggio",
        "qualita' da gioco Roblox", "budget (triangoli, misure, collisioni)"]
# voti: (sagoma, dettagli, materiali, proporzioni, qualita', budget), cosa manca
VOTI = {
    "IsolaDraghi": ((4, 4, 4, 4, 3, 4), "le 8 statue sulle torri, le due teste del portale e le corna dell'altare sono segnaposto (Meshy): finche' non ci sono la qualita' resta 3; il prato da molto lontano mostra ancora la ripetizione della texture (in Studio meglio il Terrain Grass sotto o un Decal)"),
    "PosatoioDrago": ((4, 4, 4, 4, 4, 5), "corteccia ancora un po' liscia: con il tronco Meshy (facoltativo) sarebbe 5"),
    "MangiatoiaDrago": ((3, 4, 4, 4, 4, 5), "da lontano e' una cassa di pietra: si riconosce dal cibo"),
    "PonteTibetano": ((4, 4, 4, 5, 4, 5), ""),
    "BivaccoAlto": ((5, 4, 4, 5, 4, 5), ""),
    "StatuaDrago": ((3, 4, 4, 4, 3, 5), "la statua e' Meshy (segnaposto); qui solo piedistallo e targhe"),
    "SantuarioVetta": ((4, 4, 4, 4, 4, 5), "ometto di sassi un po' regolare"),
    "BandierePreghiera": ((4, 4, 4, 5, 4, 5), ""),
    "PinoInnevato": ((4, 4, 4, 5, 4, 5), "stile a palchi stilizzato, non realistico"),
    "RocceSet": ((4, 4, 4, 5, 4, 5), ""),
    "CarrelloMiniera": ((4, 4, 4, 5, 4, 5), ""),
    "IngressoMiniera": ((4, 4, 4, 4, 4, 5), "la roccia attorno va unita al Terrain della montagna"),
    "Incubatrice": ((4, 4, 4, 4, 4, 5), ""),
    "StallaDraghi": ((4, 4, 4, 5, 4, 5), ""),
    "BancarellaMercato": ((4, 4, 4, 5, 4, 5), ""),
    "Teleferica": ((5, 4, 4, 5, 4, 5), "le funi sono lunghe 50 m: in Studio vanno allungate fra due piloni"),
    "FaroScogliera": ((5, 4, 4, 5, 4, 5), ""),
    "FossiliDrago": ((3, 3, 4, 4, 3, 5), "i fossili sono Meshy (segnaposto); qui solo la lastra"),
    "Giunca": ((5, 4, 4, 5, 4, 5), "vele senza trasparenza; la giunca va messa con la linea di galleggiamento a quota 0 (lo scafo scende a -1,2 m)"),
}
ORDINE = list(VOTI)


def main():
    righe = []
    for nome in ORDINE:
        d = os.path.join(CLOUD, nome)
        ip = os.path.join(d, "info.json")
        if not os.path.exists(ip):
            continue
        info = json.load(open(ip, encoding="utf-8"))
        voti, manca = VOTI[nome]
        prev = sorted(f for f in os.listdir(os.path.join(d, "anteprime")) if f.endswith(".jpg")) if os.path.isdir(os.path.join(d, "anteprime")) else []
        big = max(p["triangoli"] for p in info["parti"])
        ph = [p["nome"] for p in info["parti"] if p["nome"].startswith("PLACEHOLDER")]
        md = ["# %s - controllo" % nome, "",
              "Ingombro %s m, %d triangoli in %d pezzi (il piu' grande %d), %d collisioni, marcatori: %s." % (
                  " x ".join("%.1f" % v for v in info["ingombro_m"]), info["triangoli"], len(info["parti"]), big,
                  info["collisioni"], ", ".join(info["marcatori"]) or "nessuno"), "",
              "| Criterio | Voto (1-5) |", "|---|---|"]
        md += ["| %s | %d |" % (c, v) for c, v in zip(CRIT, voti)]
        md += ["", "Sotto 4: " + (manca or "niente.") if min(voti) < 4 else "Cosa manca: " + (manca or "niente di grave."), ""]
        if ph:
            md += ["Segnaposto (Meshy, vedi MESHY_PROMPT.md): " + ", ".join(ph), ""]
        md += ["## Anteprime"] + ["![%s](anteprime/%s)" % (p[:-4], p) for p in prev]
        open(os.path.join(d, "CONTROLLO.md"), "w", encoding="utf-8").write("\n".join(md) + "\n")
        righe.append("| `%s` | %s | %d | %s | %s |" % (nome, info.get("misure_m", " x ".join("%.0f" % v for v in info["ingombro_m"])),
                                                  info["triangoli"], ", ".join(info["marcatori"][:6]) + (" ..." if len(info["marcatori"]) > 6 else ""),
                                                  "/".join(str(v) for v in voti)))
    open(os.path.join(CLOUD, "_tabella.md"), "w", encoding="utf-8").write(
        "| Modello | Misure (m) | Triangoli | Marcatori | Voti |\n|---|---|---|---|---|\n" + "\n".join(righe) + "\n")
    print("\n".join(righe))


if __name__ == "__main__":
    main()
