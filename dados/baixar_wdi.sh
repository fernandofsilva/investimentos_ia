#!/usr/bin/env bash
# Baixa as contextuais do WDI (API v2 do Banco Mundial) para os 37 países da base e gera dados/wdi_contextuais.csv.
# Uso: bash dados/baixar_wdi.sh   (requer curl e python3; ~5 MB em dados/raw_wdi/)
# Voice & Accountability (WGI) não é mais servido pela API do WDI: usa-se o arquivo wgi.voice_accountability.csv (percentil 0-100) baixado do site do WGI.
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p raw_wdi
for code in NV.IND.MANF.ZS NV.IND.TOTL.ZS TX.VAL.MANF.ZS.UN TX.VAL.TECH.MF.ZS SP.POP.SCIE.RD.P6 GB.XPD.RSDV.GD.ZS NY.GDP.DEFL.ZS IP.JRN.ARTC.SC; do
  curl -s --max-time 120 "https://api.worldbank.org/v2/country/all/indicator/${code}?date=2013:2021&format=json&per_page=20000" -o "raw_wdi/${code}.json"
done
python3 - <<'PY'
import json, csv
paises = ["Argentina","Australia","Austria","Belgium","Brazil","Bulgaria","Chile","China","Colombia","Croatia","France","Greece","Hungary","India","Indonesia","Ireland","Israel","Italy","Japan","Luxembourg","Malaysia","Mexico","Netherlands","Norway","Peru","Philippines","Poland","Portugal","Romania","Singapore","Slovenia","South Africa","Spain","Switzerland","Ukraine","United Kingdom","United States"]
ind = {"NV.IND.MANF.ZS":"manuf_pib","NV.IND.TOTL.ZS":"ind_pib","TX.VAL.MANF.ZS.UN":"manuf_exp","TX.VAL.TECH.MF.ZS":"hitech_exp_wdi",
       "SP.POP.SCIE.RD.P6":"pesq_pm","GB.XPD.RSDV.GD.ZS":"rd_pct_wdi","NY.GDP.DEFL.ZS":"deflator","IP.JRN.ARTC.SC":"artigos_se_nsf"}
rows = {}
for code, name in ind.items():
    data = json.load(open(f"raw_wdi/{code}.json"))
    for it in data[1]:
        c = it["country"]["value"]; y = int(it["date"])
        if c in paises: rows.setdefault((c, y), {})[name] = it["value"]
cols = ["Country","Year"] + list(ind.values())
with open("wdi_contextuais.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(cols)
    for (c, y) in sorted(rows): w.writerow([c, y] + ["" if rows[(c, y)].get(k) is None else rows[(c, y)][k] for k in ind.values()])
for k in ind.values(): print(f"cobertura {k:15s}: {sum(1 for d in rows.values() if d.get(k) is not None)}/{len(paises)*9}")
PY
