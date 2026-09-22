#!/usr/bin/env bash
# Baixa do OpenAlex, por país e ano (2008-2021), o total de artigos, os artigos
# por domínio do conhecimento e os artigos de IA (subcampo 1702), e gera
# dados/openalex_publicacoes.csv. Para os países discutidos como casos, baixa
# também os tópicos e as instituições dos trabalhos de IA (dados/openalex_nichos.csv).
#
# Serve a dois propósitos: conferir a variável AI.Publications da base contra uma
# fonte independente e medir a participação de STEM e de IA na produção total de
# cada país, que entra como contextual de especialização no segundo estágio.
#
# Uso: bash dados/baixar_openalex.sh   (requer curl e python3; ~15 MB em dados/raw_openalex/)
# São 8 consultas por país (uma por medida, agrupadas por ano) mais 2 por país-caso.
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p raw_openalex

MAILTO="mailto=fernando.silva@grancursosonline.com.br"   # polite pool: 10 req/s
API="https://api.openalex.org/works"
ANOS="publication_year:2008-2021"
ANOS_NICHO="publication_year:2013-2021"

# Códigos ISO-2 dos 37 países da base, na ordem de dados/baixar_wdi.sh.
PAISES="AR AU AT BE BR BG CL CN CO HR FR GR HU IN ID IE IL IT JP LU MY MX NL NO PE PH PL PT RO SG SI ZA ES CH UA GB US"
# Países discutidos como casos no manuscrito (topo, cauda e diagnóstico setorial).
CASOS="PE MX SI UA LU JP IL FR GB CH IE NL BR CN"

Baixa() {  # $1 = país, $2 = nome da medida, $3 = filtro extra, $4 = agrupamento
  local destino="raw_openalex/${1}_${2}.json"
  if [ -s "$destino" ]; then return 0; fi   # retomada: não rebaixa o que já veio
  curl -s --max-time 120 --retry 4 --retry-delay 3 --retry-all-errors \
    "${API}?filter=authorships.countries:${1},${3}&group_by=${4}&${MAILTO}" \
    -o "$destino"
  sleep 0.15
}

for iso in $PAISES; do
  Baixa "$iso" total       "${ANOS},type:article"                                          publication_year
  for dominio in 1 2 3 4; do   # 1 Life, 2 Social, 3 Physical, 4 Health Sciences
    Baixa "$iso" "dom${dominio}" \
      "${ANOS},type:article,primary_topic.domain.id:domains/${dominio}"                     publication_year
  done
  Baixa "$iso" ai_primario "${ANOS},type:article,primary_topic.subfield.id:1702"            publication_year
  Baixa "$iso" ai_qualquer "${ANOS},type:article,topics.subfield.id:1702"                   publication_year
  Baixa "$iso" ai_todos    "${ANOS},topics.subfield.id:1702"                                publication_year
  echo "  ${iso}: publicações"
done

for iso in $CASOS; do
  Baixa "$iso" nicho_topicos     "${ANOS_NICHO},type:article,topics.subfield.id:1702" primary_topic.id
  Baixa "$iso" nicho_instituicoes "${ANOS_NICHO},type:article,topics.subfield.id:1702" authorships.institutions.lineage
  echo "  ${iso}: nichos"
done

python3 - <<'PY'
import json, csv, glob, os

iso2pais = {
    "AR": "Argentina", "AU": "Australia", "AT": "Austria", "BE": "Belgium",
    "BR": "Brazil", "BG": "Bulgaria", "CL": "Chile", "CN": "China",
    "CO": "Colombia", "HR": "Croatia", "FR": "France", "GR": "Greece",
    "HU": "Hungary", "IN": "India", "ID": "Indonesia", "IE": "Ireland",
    "IL": "Israel", "IT": "Italy", "JP": "Japan", "LU": "Luxembourg",
    "MY": "Malaysia", "MX": "Mexico", "NL": "Netherlands", "NO": "Norway",
    "PE": "Peru", "PH": "Philippines", "PL": "Poland", "PT": "Portugal",
    "RO": "Romania", "SG": "Singapore", "SI": "Slovenia", "ZA": "South Africa",
    "ES": "Spain", "CH": "Switzerland", "UA": "Ukraine", "GB": "United Kingdom",
    "US": "United States"}
medidas = ["total", "dom1", "dom2", "dom3", "dom4",
           "ai_primario", "ai_qualquer", "ai_todos"]
# As colunas do CSV seguem a ordem de 'medidas'; dom1-dom4 saem com os nomes
# dos domínios do OpenAlex (Life, Social, Physical e Health Sciences).

def grupos(arquivo):
    """Lê um JSON de group_by e devolve a lista de grupos; [] se a consulta falhou."""
    try:
        dados = json.load(open(arquivo))
    except Exception:
        print("  falha ao ler", arquivo)
        return []
    if "group_by" not in dados:
        print("  sem group_by em", arquivo, dados.get("error", ""))
        return []
    return dados["group_by"]

linhas, falhas = {}, 0
for iso, pais in iso2pais.items():
    for medida in medidas:
        arquivo = f"raw_openalex/{iso}_{medida}.json"
        if not os.path.exists(arquivo):
            falhas += 1
            continue
        for g in grupos(arquivo):
            linhas.setdefault((pais, int(g["key"])), {})[medida] = g["count"]

colunas = ["Country", "Year", "total", "life", "social", "physical", "health",
           "ai_primario", "ai_qualquer", "ai_todos"]
with open("openalex_publicacoes.csv", "w", newline="") as saida:
    escritor = csv.writer(saida)
    escritor.writerow(colunas)
    for chave in sorted(linhas):
        valores = linhas[chave]
        escritor.writerow(list(chave) + [valores.get(m, 0) for m in medidas])
print(f"openalex_publicacoes.csv: {len(linhas)} país-ano | consultas ausentes: {falhas}")

with open("openalex_nichos.csv", "w", newline="") as saida:
    escritor = csv.writer(saida)
    escritor.writerow(["Country", "tipo", "nome", "n"])
    for arquivo in sorted(glob.glob("raw_openalex/*_nicho_*.json")):
        iso, tipo = os.path.basename(arquivo)[:-5].split("_nicho_")
        for g in grupos(arquivo)[:15]:
            if g["key"] == "unknown":
                continue
            escritor.writerow([iso2pais[iso], tipo, g["key_display_name"],
                               g["count"]])
print("openalex_nichos.csv gravado")
PY
