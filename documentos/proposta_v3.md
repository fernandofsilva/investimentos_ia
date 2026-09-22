# Proposta v3 — Eficiência na conversão de investimento em IA em ciência e tecnologia

**Versão executável.** Esta proposta substitui a v2 e vem acompanhada de `scripts/pipeline_v3.R`, que replica o template da disciplina na base `dados/AI_INVESTMENT.csv` e gera todas as tabelas (`resultados/`) e figuras (`resultados/figuras/`) citadas abaixo. Os números desta versão são **preliminares** (rodada rápida: B = 500 no bootstrap, L1 = 50 e L2 = 500 no Simar-Wilson); os valores finais saem de `RAPIDO=FALSE Rscript scripts/pipeline_v3.R`.
**Data:** 19/09/2026; atualizada em 20/09/2026 com Voice & Accountability (WGI) no segundo estágio e em 21/09/2026 com a orientação da segunda sessão. Apresentação de 20 min em 28/09; manuscrito Qualis até o lançamento das notas.
**Origem das mudanças:** `documentos/analise_critica.md` (crítica da v1, da orientação do professor e da v2) e `documentos/orientacao_sessao_2.md` (segunda sessão de orientação).

---

## 1. O que muda da v2 para a v3

| Ponto | v2 | v3 | Motivo (evidência em `documentos/analise_critica.md`) |
|---|---|---|---|
| Unidades | Investimento em US\$ correntes + P&D em % PIB → publicações em contagem e patentes **per capita** | **Extensiva**: investimento em US\$ de 2015, P&D em US\$ → publicações e patentes em **contagem** (patentes = per capita × população). Intensiva (tudo per capita) como robustez | O gap da v2 tinha correlação −0,53 com log população; o ranking S mudava de um sistema de unidades para outro (Spearman 0,08) |
| Fronteira / DMU | Uma fronteira por ano (16–30 DMUs) | **Agrupada** (208 país-ano), como no template; anual como robustez | Escores anuais subiam com a queda de n (0,59 → 0,75); template da aula agrupa o painel |
| Modelos | S, T, ST (ST só "para comparação") | **ST** (síntese, o modelo que o professor sugeriu), **S** e **T** (decomposição ciência/tecnologia), **C** (conversão: publicações + investimento + P&D → patentes; teste direto de H1) | O "gap = T − S" em OLS não é o segundo estágio da aula e não testa "pesquisa vira patente" |
| Zeros | Shift em 1/10/100 mi | Zero lido como **ausência de investimento**; o shift de US\$ 0,5 mi fica como artifício das técnicas em log, a que o BCC-produto é invariante; amostra sem zeros nos quatro modelos como robustez; eficiência de escala só sem zeros; dummy `zero_inv` no 2º estágio | Os shifts da v2 iam até a mediana da amostra; a eficiência de escala é indefinida para os zeros sob CCR; a leitura literal do zero veio da orientação da segunda sessão |
| Segundo estágio | OLS sobre o gap, 20 parâmetros | **Tobit** (`censReg`, template) + **Simar-Wilson alg. 2** (`rDEA::dea.env.robust`; versão em log(δ) para T e C) + OLS com erros por país + KS/Kruskal-Wallis | A versão linear do alg. 2 explode quando δ tem cauda pesada (σ̂ = 720 em T) |
| Contextuais | 12 variáveis, `TX.VAL.TECH.MF.ZS` duplicada | 10: manufatura % PIB (**H1**), manufaturados % exportações, índice de governança (corrupção + efetividade), Voice & Accountability (WGI), ln PIB pc, comércio, Z-score, NPL, `zero_inv`, tendência | Corrupção × efetividade têm correlação 0,95; `TX.VAL.TECH` já está na base; Voice foi pedida pelo professor |
| Técnicas da aula | Malmquist, fusões, TOPSIS e classes latentes cortados | **Todas restauradas**: FDH, folgas, fusões (blocos regionais), Malmquist, TOPSIS, bootstrap, SFA/COLS, Order-m/α, poLCA, KS/KW, Tobit, truncada bootstrap | O Syllabus manda replicar as análises das sessões; o professor não pediu corte |
| Dados externos | Merge WDI planejado | Feito: `dados/wdi_contextuais.csv` via `dados/baixar_wdi.sh` (manufatura, exportações, pesquisadores, deflator dos EUA) e `dados/wgi.voice_accountability.csv` (Voice & Accountability) | — |
| Reprodutibilidade | Nenhum script | `scripts/pipeline_v3.R` (50 s), pacotes da aula instalados, saídas versionáveis | Syllabus: "rotinas empíricas reprodutíveis" |
| Patentes 2020–21 | Não tratado | Sensibilidade com T até 2019; defasagem t−1 | 64 % dos países caem em 2021 enquanto publicações sobem (truncamento) |

O que a segunda sessão de orientação acrescentou, em 21/09, está detalhado em `documentos/orientacao_sessao_2.md`: a fronteira agrupada passou a ser apresentada como metafronteira, com lacuna tecnológica por ano e Malmquist global; o zero virou ausência de investimento; a cobertura da base virou objeto de auditoria e condiciona o ranking por país; o segundo estágio ganhou a tabela em formato de periódico; a variável de publicações foi conferida contra o OpenAlex e a composição da produção científica entrou na discussão; e os países do topo e da cauda viraram casos, em `documentos/discussao_casos.md`.

---

## 2. Pergunta e hipóteses

**Pergunta.** Quão eficientes são os países em converter esforço financeiro em IA — investimento privado em IA e gasto em P&D — em produção científica (publicações) e tecnológica (patentes) em IA, e a base industrial condiciona essa conversão?

- **H1.** Países com maior participação da manufatura no PIB são mais eficientes na produção de patentes (T) e na conversão de pesquisa em patente (C). *Origem: orientação do professor ("você precisa de uma base industrial para que a tua pesquisa vire patente").*
- **H2.** A base industrial importa menos para a eficiência científica (S) do que para a tecnológica (T): a assimetria ciência–tecnologia é institucional, não de volume.
- **Exploratórias.** Qualidade institucional (governança) e solidez financeira (Z-score, NPL) afetam a eficiência; a fronteira de publicações por dólar recuou com a explosão do investimento (Malmquist).

Contribuição pretendida: primeira aplicação de fronteiras de eficiência à conversão de investimento em IA por país com contextuais de base industrial e solidez financeira, posicionada contra Fukuyama, Tan & Wanke (2025, *SEPS*) e a literatura de eficiência de sistemas nacionais de inovação (Wang & Huang 2007; Guan & Chen 2012; Kontolaimou et al. 2016).

---

## 3. Dados e variáveis

Base: 208 país-ano, 37 países, 2013–2021, painel desbalanceado (1 a 9 anos por país). Merge com WDI por `Country` + `Year` (37 correspondências conferidas).

| Variável | Construção | Papel | Fonte |
|---|---|---|---|
| `inv_usd` | `AI.Investment` / deflator do PIB dos EUA (2015 = 1) + US\$ 0,5 mi | insumo 1 | base + WDI `NY.GDP.DEFL.ZS` |
| `rd_usd` | `R.D_Percentage` / 100 × `GDP.constant` | insumo 2 | base |
| `pubs` | `AI.Publications` | produto científico | base |
| `pat` | `AI.Patent.Applications` × população (população = PIB / PIB per capita) | produto tecnológico | base (recuperação verificada: 58 % das contagens a < 0,02 de um inteiro) |
| `inv_pc`, `rd_pct`, `pubs_pm`, `pat_pm` | per capita / % PIB / por milhão | forma intensiva (robustez) | base |
| `manuf_pib` | manufatura, % do PIB | **H1** | WDI `NV.IND.MANF.ZS` (205 obs.; Bulgária 2018/19/21 ausentes) |
| `manuf_exp` | manufaturados, % das exportações de mercadorias | robustez de H1 ("corrente de comércio") | WDI `TX.VAL.MANF.ZS.UN` |
| `gov` | média de `Corruption_Estimate` e `Government_Effectiveness` padronizados | institucional | base (WGI) |
| `voice` | Voice & Accountability, escala 0–100 | institucional (pedida pelo professor) | `dados/wgi.voice_accountability.csv` (WGI; 208 obs.; a escala não é o percentil: Noruega 90, China 31 — parece reescala linear do *estimate*) |
| `ln_gdppc`, `Trade_Percentage`, `Z_Score`, `Non.performing.Loans` | como na base | estrutural / financeira | base |
| `zero_inv`, `tend` | dummy de investimento zero; ano − 2013 | controles de desenho | — |
| `pesq_pm` | pesquisadores por milhão | capacidade de absorção (opcional) | WDI `SP.POP.SCIE.RD.P6` (177 obs. + 31 interpolados) |

Sanidade do merge: `R.D_Percentage` da base coincide com `GB.XPD.RSDV.GD.ZS` do WDI (correlação 1,00); deflator dos EUA de 0,974 (2013) a 1,132 (2021).

**Ressalvas de dados que ficam abertas** (confirmar na fonte antes da submissão): (i) `AI.Patent.Applications` é per capita, mas não se sabe se conta por inventor ou depositante nem qual escritório — Suíça, Holanda, Bélgica, Irlanda e Israel aparecem com pouquíssimas patentes de IA, o que sugere contagem por escritório nacional sem EPO/PCT; (ii) os 17 zeros de investimento podem ser "< US\$ 0,5 mi" (a fonte arredonda a milhões) ou não-cobertura; (iii) as patentes de 2020–2021 parecem truncadas; (iv) a escala de `dados/wgi.voice_accountability.csv` (0–100) não é o percentil do WGI e precisa ser documentada.

---

## 4. Especificação

- **DMU:** país-ano; **fronteira agrupada** (208), como no template da aula, apresentada como fronteira global ou intertemporal, isto é, a metafronteira que envolve as fronteiras contemporâneas de cada ano; orientação a produto; escores reportados como 1/eff em (0, 1].
- **Retornos:** CCR e BCC; eficiência de escala SE = CCR/BCC reportada só para as 191 observações com investimento positivo.
- **Modelos:**
  - **S** (ciência): (`inv_usd`, `rd_usd`) → `pubs`
  - **T** (tecnologia): (`inv_usd`, `rd_usd`) → `pat`
  - **ST** (síntese): (`inv_usd`, `rd_usd`) → (`pubs`, `pat`)
  - **C** (conversão): (`pubs`, `inv_usd`, `rd_usd`) → `pat`
- **Robustez do núcleo (todas no script, tabela `t07_robustez.csv`):** forma intensiva; fronteiras anuais; shift de US\$ 1 mi; sem os 17 zeros, nos quatro modelos; T só até 2019; sem Luxemburgo e Singapura; insumos defasados em t−1; sem os seis países com um ou dois anos observados; modelos de insumo único, só P&D, em S e T.
- **Zeros:** lidos como ausência de investimento privado registrado, conforme a orientação da segunda sessão. O deslocamento de US\$ 0,5 mi permanece como artifício das técnicas que tomam o logaritmo do insumo; o BCC orientado a produto é invariante a ele. As observações sem investimento só podem ser envelopadas por outras sem investimento, e são marcadas como tais nas tabelas de eficientes e no ranking por país.
- **Dinâmica:** lacuna tecnológica por ano (eficiência contemporânea sobre global), nas versões convexa e de união, com subamostragem de n igualado; fronteira sequencial; Malmquist global em 34 países, decomposto em aproximação à fronteira do ano e deslocamento dela em relação à global.
- **Outliers:** supereficiência de Andersen-Petersen (VRS e CRS) e fronteiras parciais (Order-m, Order-α).
- **Segundo estágio:** KS e Kruskal-Wallis por renda, região, `zero_inv` e manufatura acima/abaixo da mediana; Tobit (`censReg`, censura em 0 e 1) e OLS com erros agrupados por país sobre BCC_S, BCC_T, BCC_C, SE e as versões intensivas, com contextuais manufatura % PIB, manufaturados % exportações, governança, Voice & Accountability, ln PIB pc, comércio, Z-score, NPL, `zero_inv` e tendência; sensibilidade ao conjunto de contextuais institucionais, à amostra sem os países de patente ≈ 0 e às medidas de especialização científica (`t19`); Simar-Wilson Algoritmo 2 com `rDEA::dea.env.robust` (linear em δ, como na aula) e com regressão truncada em **log(δ)** (implementação própria com `truncreg`), necessária porque δ chega a 1.429 em T. Os resultados vão ao manuscrito na tabela `t20_regressoes_paper.md`, com as contextuais nas linhas, os modelos S, T e C nas colunas e um painel por estimador.

---

## 5. Mapa do pipeline sobre o template da disciplina

| Bloco do script | Técnica | Função da aula | Saídas |
|---|---|---|---|
| 1 | Preparação, conferência das publicações contra o OpenAlex, auditoria de cobertura | `material_disciplina/lesson1.4.r` | `base_v3.csv`, `t21`, `t22`, `t28`, `fig12`, `fig14` |
| 2 | Descritivas | `material_disciplina/lesson1.4.r` | `t01`, `fig01` |
| 3 | FDH, CCR, BCC, peers, folgas, `dea.plot` | `Benchmarking::dea`, `peers`, `SLACK = TRUE`, `dea.plot` | `t02`–`t06`, `fig02`–`fig04` |
| 4 | Robustez de especificação | `Benchmarking::dea` | `t07` |
| 5 | Supereficiência | `Benchmarking::sdea` | `t08` |
| 6 | Bootstrap de Simar-Wilson | `rDEA::dea.robust` (+ correção de viés na escala de Farrell) | `t09`, `fig05` |
| 7 | Order-m, Order-α | `nonparaeff::orderm`; Order-α própria (`frontiles` exige XQuartz) | `t10`, `fig06` |
| 8 | SFA, COLS | `Benchmarking::sfa`, `lm` | `t11`, `fig07` |
| 9 | Classes latentes | `poLCA` sobre decis | `t12`, `fig09` |
| 10 | Malmquist | `nonparaeff::faremalm2` (painel balanceado 2016–2021, 13 países) | `t13`, `fig08` |
| 10b | Metafronteira: fronteiras contemporânea, sequencial e união; lacuna tecnológica; Malmquist global | `Benchmarking::dea` com `XREF`/`YREF`; implementação própria | `t23`–`t25`, `fig13` |
| 11 | Fusões como blocos regionais | `Benchmarking::make.merge`, `dea.merge` | `t14` |
| 12 | TOPSIS | `topsis::topsis` | `t15` |
| 13 | KS/KW, Tobit, OLS-cluster, Simar-Wilson alg. 2, tabela de regressões | `ks.test`, `kruskal.test`, `censReg`, `rDEA::dea.env.robust`, `truncreg` | `t16`–`t20`, `fig10`, `fig11` |
| 15b | Casos do topo e da cauda; conferência da variável de patentes | `Benchmarking::peers` | `t26`, `t27` |

Como rodar: `Rscript scripts/pipeline_v3.R` (≈ 1 min) ou `RAPIDO=FALSE Rscript scripts/pipeline_v3.R` (valores finais; alguns minutos). Fontes externas: `bash dados/baixar_wdi.sh` e `bash dados/baixar_openalex.sh`. Pacotes: `Benchmarking`, `rDEA`, `nonparaeff`, `poLCA`, `censReg`, `topsis`, `truncreg`, `tidyverse`, `sandwich`, `lmtest`.

---

## 6. Resultados preliminares

### 6.1 Núcleo (fronteira agrupada, forma extensiva)

| Modelo | FDH efic. | CCR efic. | BCC efic. | BCC média | BCC: zeros efic. | BCC: não-zeros efic. |
|---|---|---|---|---|---|---|
| S | 25,0 % | 2,4 % | 7,7 % | 0,459 | 23,5 % | 6,3 % |
| T | 18,3 % | 1,9 % | 3,4 % | 0,146 | 11,8 % | 2,6 % |
| ST | 46,6 % | 4,8 % | 9,1 % | 0,486 | 29,4 % | 7,3 % |
| C | 22,6 % | 1,9 % | 3,8 % | 0,165 | 17,6 % | 2,6 % |

- A fronteira agrupada discrimina: 7,7 % de eficientes em S contra 31,7 % nas fronteiras anuais da v2. FDH continua pouco informativo (25–47 %).
- Spearman entre escores BCC: S × T = 0,45 (era 0,25 na v2 com unidades mistas); T × C = 0,98 — incluir publicações como insumo quase não altera o ranking tecnológico; S × C = 0,38.
- Eficiência de escala média (ST, sem zeros) = 0,59.
- BCC-eficientes em S: Austrália-2013, China (2013, 2019–2021), Índia (2013, 2016, 2019, 2020), Malásia-2014, Peru (2018, 2021), Romênia (2018, 2020), Ucrânia (2017, 2018). Em T: Austrália-2013, China (2013, 2020, 2021), México-2018, Peru-2018, Ucrânia-2014. Benchmarks mais usados em ST: Romênia-2020 (94 vezes), Índia-2013 (75), China-2013 (66).
- Folgas (BCC ST): só 5–6 % das DMUs têm folga de insumo; a ineficiência é quase toda radial.
- **Leitura crítica que permanece:** Peru, Ucrânia, Malásia e Romênia entram na fronteira por terem insumos minúsculos (o investimento privado em IA é concentrado em EUA, China, Reino Unido e Israel); Israel, com o maior investimento por habitante, é o menos eficiente em ST (0,11). O modelo mede "publicações e patentes por dólar de capital de risco e de P&D"; onde há muito capital de risco, essa razão é naturalmente baixa. Isso deve ser dito no artigo e motiva a robustez "S só com P&D" (a acrescentar).

### 6.2 Ranking por país (média dos anos, BCC)

Conversão pesquisa → patente (C): China 0,63; Austrália 0,54; Peru 0,53; Ucrânia 0,49; Japão 0,46; México 0,44; Luxemburgo 0,35; EUA 0,23; Eslovênia 0,19; **Brasil 0,19 (10º de 37)**; Malásia 0,19; Romênia 0,15; … Israel 0,015; Noruega 0,011; Bélgica 0,009; Holanda 0,005; Irlanda 0,004; Suíça 0,002.

Síntese (ST): Romênia 0,96; Peru 0,91; Malásia 0,91; Ucrânia 0,88; China 0,88; Índia 0,88; Itália 0,75; Indonésia 0,69; Austrália 0,67; … Japão 0,41; EUA 0,40; Brasil 0,36; … Argentina 0,18; Irlanda 0,18; Noruega 0,17; Israel 0,11; Suíça 0,10.

Sob unidades consistentes, o gap T − S é negativo para todos os países (a fronteira de patentes é definida pela China, que tem 60 % das patentes de IA do mundo). Os países de patente quase zero (Suíça, Holanda, Bélgica, Irlanda, Israel) são exatamente os que patenteiam via EPO/PCT — a definição da variável de patentes decide esse resultado (ressalva §3).

### 6.3 Robustez de especificação (Spearman com o escore principal)

| Cenário | n | BCC efic. | média | Spearman |
|---|---|---|---|---|
| Intensiva S | 208 | 7,7 % | 0,394 | **0,12** |
| Intensiva T | 208 | 4,3 % | 0,197 | 0,90 |
| Intensiva C | 208 | 4,3 % | 0,208 | 0,94 |
| Fronteiras anuais (ST) | 208 | 36,1 % | 0,700 | 0,84 |
| Shift US\$ 1 mi (ST) | 208 | 9,1 % | 0,486 | 1,00 |
| Sem os 17 zeros (ST) | 191 | 10,5 % | 0,486 | 0,99 |
| T até 2019 | 174 | 3,4 % | 0,159 | 0,99 |
| Sem Luxemburgo e Singapura (ST) | 195 | 9,7 % | 0,495 | 1,00 |
| Insumos em t−1 (ST) | 154 | 9,1 % | 0,476 | 0,89 |
| Sem os zeros, S / T / C | 191 | 8,4 / 5,2 / 6,3 % | 0,463 / 0,161 / 0,193 | 0,99 / 0,98 / 0,97 |
| Sem países de menos de 3 anos, S / T / ST / C | 199 | 8,0 / 3,5 / 9,5 / 4,0 % | 0,460 / 0,151 / 0,488 / 0,170 | 1,00 |
| Só P&D como insumo, S / T | 208 | 1,9 / 1,0 % | 0,289 / 0,055 | 0,79 |

T, C e ST são estáveis. **S não é**: o ranking científico em unidades extensivas e em per capita não tem relação (0,12) — a forma extensiva premia sistemas grandes, a intensiva premia os pequenos. A v3 adota a extensiva como principal (é a leitura literal da orientação do professor: "o que se investe → o quanto gera") e reporta a intensiva integralmente; nenhuma conclusão sobre S deve depender de uma só forma.

Supereficiência (ST, CRS): Ucrânia-2014 1,81; Malásia-2014 1,78; Austrália-2013 1,27; China-2020 1,27; China-2021 1,19 — as extremas são DMUs de insumo minúsculo, não Luxemburgo (que deixa de ser outlier em contagens). Nenhuma DMU infactível no VRS.

### 6.4 Estocástico, paramétrico e extensões do template

- **Bootstrap (B = 500):** escores corrigidos de viés na escala de Farrell — S 0,459 → 0,352; T 0,146 → 0,097; C 0,165 → 0,112; rankings preservados (Spearman ≥ 0,99); largura média dos IC de 95 %: 0,07 (S), 0,04 (T e C). A correção do `rDEA` na escala θ produz escores negativos (83 em T, 86 em C; o mesmo aparece na Lecture 03), por isso a correção é refeita com as réplicas na escala φ = 1/θ.
- **Order-m (S):** λ_m mediano 5,8 (m = 25), 6,9 (50), 8,5 (100); 12–17 % das DMUs acima da fronteira parcial. **Order-α (S):** 56 %, 47 % e 28 % acima da fronteira para α = 0,90, 0,95 e 0,99. A correlação de posto com o BCC é negativa (−0,22): na fronteira agrupada, sistemas grandes têm muitos pares dominados e ficam longe da fronteira parcial esperada — a interpretação precisa ser feita por tamanho.
- **SFA (Cobb-Douglas em log):** em T, λ = 0,53 (22 % da variância é ineficiência), elasticidades 0,14 (investimento) e 0,98 (P&D), TE média 0,61, correlação com BCC 0,62. Em S, λ < 0: o SFA não identifica ineficiência — a heterogeneia entre países domina; isso sustenta a leitura de "tecnologias distintas" das classes latentes.
- **Classes latentes (poLCA, decis):** k = 2 pelo BIC (80 e 128 obs.); as classes separam tamanho (log publicações 8,7 × 6,4), não renda; manufatura não difere entre classes (p = 0,19).
- **Malmquist (S, 13 países, 2016–2021):** M = 0,971, catch-up 1,089, deslocamento 0,891 — a fronteira de publicações por dólar recuou enquanto o investimento mediano subiu de US\$ 9 mi para US\$ 243 mi. Por país: Japão 1,15, EUA 1,11, China 1,11, Israel 1,11; Argentina 0,71, Romênia 0,79, Grécia 0,80.
- **Metafronteira e Malmquist global:** a lacuna tecnológica média (eficiência contemporânea sobre global) é 0,68 em S e ST e 0,49 em T e C; contra a união não convexa das fronteiras anuais, 0,75 e 0,57–0,59, de modo que a convexificação vale de 10 % a 27 % e só 9–13 % das observações estão na metatecnologia não convexa. No modelo de patentes a lacuna cai de 0,63 (2013) a 0,27 (2016) e sobe a 0,83 (2020), desenho preservado com n igualado ao menor ano. O Malmquist global cobre 34 países: M = 1,049 em S, com aproximação à fronteira do ano de 1,067 e deslocamento de 0,983; restrito a 2016–2021 nos 13 países do subpainel, dá 1,275 contra 0,862 do índice adjacente, com Spearman 0,70. Por faixa de renda, a lacuna do grupo de renda média é 0,95 em S e 0,99 em T: a fronteira global é essencialmente a dele.
- **Conferência das publicações (OpenAlex):** Spearman 0,957 com a contagem de artigos de IA, razão mediana 1,45 e variação por país de 0,22 a 3,33 — bases de indexação distintas. A participação das exatas e da vida vai de 33 % (Peru) a 75 % (China); as ciências sociais, de 7 % (China, Japão) a 45 % (Indonésia).
- **Fusões como blocos regionais (ST, VRS):** eficiência do bloco fundido entre 0,21 (Benelux) e 0,63 (Leste UE); o componente de aprendizado domina (0,16–0,62); harmonia sempre < 1 (ganho de composição de 4 a 21 %); tamanho sempre > 1 (1,19–1,42: o bloco fundido cai na região de retornos decrescentes). Mercosul (Argentina + Brasil, 6 anos): 0,39. ASEAN nunca tem os quatro membros no mesmo ano.
- **TOPSIS (pesos iguais):** Spearman 0,64 com BCC ST; China 2017–2021 no topo — o TOPSIS premia volume.

### 6.5 Segundo estágio

- **Testes não paramétricos.** Kruskal-Wallis rejeita igualdade por renda e por região em S, T e C (p < 1e-4). Manufatura acima da mediana: S 0,52 × 0,39 (KW p = 0,002; KS 0,006), T 0,19 × 0,11 (0,0007; 0,009), C 0,20 × 0,13 (0,007; 0,03).
- **H1 nos três estimadores, com Voice & Accountability entre as contextuais (coeficiente de `manuf_pib`):**

| Escore | Tobit coef. | Tobit p | OLS coef. | OLS p (cluster país) | SW alg. 2 em log(δ): β [IC 95 %] |
|---|---|---|---|---|---|
| BCC_S | 0,0064 | 0,189 | 0,0060 | 0,514 | −0,016 [−0,040; 0,009] |
| BCC_T | 0,0095 | 0,024 | 0,0094 | 0,195 | −0,097 [−0,153; −0,031] |
| BCC_C | 0,0098 | 0,029 | 0,0097 | 0,265 | −0,085 [−0,153; −0,030] |
| Intensiva S | 0,0035 | 0,425 | 0,0043 | 0,582 | — |
| Intensiva T | 0,0108 | 0,032 | 0,0108 | 0,291 | — |
| Intensiva C | 0,0114 | 0,029 | 0,0114 | 0,290 | — |

- **Sensibilidade ao conjunto de contextuais institucionais e à amostra (Tobit e OLS-cluster; `t19`):**

| Escore | Institucionais | Amostra | n | manuf coef. | manuf p (Tobit) | manuf p (OLS-cluster) | voice coef. (p) |
|---|---|---|---|---|---|---|---|
| T | nenhuma | todos | 205 | 0,0190 | < 0,001 | 0,017 | — |
| T | só governança | todos | 205 | 0,0185 | < 0,001 | 0,021 | — |
| T | nenhuma | sem 13 países de patente ≈ 0 | 136 | 0,0233 | < 0,001 | 0,015 | — |
| T | só voice | todos | 205 | 0,0095 | 0,023 | 0,197 | −0,0079 (< 0,001) |
| T | governança + voice | todos | 205 | 0,0095 | 0,024 | 0,195 | −0,0080 (< 0,001) |
| T | governança + voice | sem 13 países de patente ≈ 0 | 136 | 0,0049 | 0,597 | 0,745 | −0,0090 (0,011) |
| C | nenhuma | todos | 205 | 0,0188 | < 0,001 | 0,025 | — |
| C | só governança | todos | 205 | 0,0183 | < 0,001 | 0,032 | — |
| C | nenhuma | sem 13 países de patente ≈ 0 | 136 | 0,0198 | < 0,001 | 0,032 | — |
| C | só voice | todos | 205 | 0,0098 | 0,029 | 0,276 | −0,0075 (< 0,001) |
| C | governança + voice | todos | 205 | 0,0098 | 0,029 | 0,265 | −0,0075 (0,001) |
| C | governança + voice | sem 13 países de patente ≈ 0 | 136 | 0,0036 | 0,704 | 0,795 | −0,0080 (0,027) |

  Os 13 países excluídos na última linha de cada bloco são os que aparecem com patentes de IA quase nulas e patenteiam via EPO/PCT: Suíça, Holanda, Bélgica, Irlanda, Noruega, Israel, França, Áustria, Reino Unido, Portugal, Itália, Espanha e Grécia.

  O que a tabela diz: (i) `manuf_pib` e `voice` têm correlação −0,60 — nesta amostra, base industrial e democracia são quase o mesmo eixo (economias manufatureiras asiáticas e emergentes de um lado, democracias ocidentais de outro); (ii) quando `voice` entra, o coeficiente da manufatura cai pela metade e perde a significância com erros agrupados por país, embora continue significativo no Tobit e no Simar-Wilson em log(δ); (iii) sem os 13 países de patente ≈ 0, a manufatura continua forte enquanto `voice` fica fora (0,023, p < 0,001), mas deixa de explicar qualquer coisa quando `voice` entra (p 0,6–0,8), e `voice` continua negativa em todas as amostras. Ou seja, **o que decide é a colinearidade manufatura × voice: quando as duas entram, `voice` vence, com ou sem os países europeus** — e `voice` separa a China (31, que define a fronteira de patentes) das democracias que aparecem com patente zero por construção da variável. Com a variável de patentes atual não é possível separar "base industrial" de "regime político ou escritório de patentes".
- **Voice & Accountability.** Tobit: −0,008 por ponto da escala 0–100 nos escores T e C (médias 0,15–0,17); Simar-Wilson em log(δ): +0,045 (T) e +0,047 (C) — dez pontos a mais de voice corresponderiam a 55–60 % mais distância à fronteira. Um efeito causal dessa magnitude não é plausível; a explicação mais provável é o artefato de contagem de patentes (os 13 países acima têm voice médio 78 contra 64 dos demais). O índice de governança perde significância quando `voice` entra (p 0,94 em T e C) e a base já tinha corrupção e efetividade com correlação 0,95 entre si.
- **Simar-Wilson alg. 2:** a versão linear do `rDEA` funciona em S (σ̂ = 4,1; β manuf −0,27, IC inclui zero) e explode em T e C (σ̂ = 735 e 331; ICs que não contêm o ponto estimado), porque δ tem mediana 21 e máximo 1.429. Em log(δ) (σ̂ = 0,55, 1,46, 1,35; 500 de 500 réplicas convergiram) os resultados são estáveis (`t18`, `fig10`). Outros coeficientes em T e C: `zero_inv` ≈ −2 (o artefato de *self-identifier* capturado como "eficiência"); `z_score` negativo (bancos mais sólidos, menos ineficiência); `manuf_exp` positivo (sinal oposto ao de `manuf_pib`; as duas proxies não medem a mesma coisa). Em S: ln PIB pc +0,43 (países ricos gastam mais por publicação), governança −0,33, `voice` +0,013, tendência negativa (ganho de eficiência ao longo do tempo).

### 6.6 Leitura preliminar

1. A base industrial está associada a mais eficiência tecnológica (T) e de conversão (C) em todos os estimadores e amostras **enquanto Voice & Accountability fica fora**; com ela, o coeficiente cai pela metade, só sobrevive no Tobit e no Simar-Wilson e desaparece na amostra sem os 13 países de patente ≈ 0. H1 é uma hipótese plausível com evidência frágil — e é assim que deve ser apresentada em 28/09.
2. O ranking tecnológico é estável entre especificações; o científico não é — reportar as duas formas e não vender ranking de S como achado.
3. A fronteira agrupada com contagens resolve o artefato de Luxemburgo/Singapura da v2, mas cria o de insumo minúsculo (Peru, Ucrânia, Malásia, Romênia): supereficiência, Order-m e a robustez sem zeros são obrigatórias no texto. A razão é estrutural: sob retornos variáveis, uma observação sem investimento só é envelopada por outras sem investimento, e a de menor gasto em pesquisa entre elas é eficiente por construção. Peru e Eslovênia estão no topo por isso, não por especialização; México e Japão são os casos substantivos.
6. A fronteira agrupada é uma metafronteira, e lê-la como tal dá três resultados que o desenho anterior não extraía: a lacuna tecnológica por ano, a medida do efeito da convexificação e um Malmquist que não exige painel balanceado.
7. A variável de publicações concorda com o OpenAlex na ordenação, não no nível, e cobre uma parcela muito diferente do esforço científico de cada país: de 33 % a 75 % da produção em exatas e da vida. Entra na discussão e na sensibilidade, não na especificação principal.
4. A definição da variável de patentes decide H1 e o sinal de `voice` e da governança. É a pendência número um: obter patentes de IA por país do **inventor** (OECD.AI ou WIPO) e reestimar antes do manuscrito.
5. A colinearidade manufatura × voice (−0,60) é estrutural da amostra; o segundo estágio deve reportar os conjuntos alternativos de contextuais (`t19`), não um único modelo.

---

## 7. Limitações e pendências

1. **Patentes (prioridade máxima):** confirmar na fonte a definição de `AI.Patent.Applications` (inventor × depositante, escritório) e obter uma série alternativa por país do inventor (OECD.AI, WIPO); reestimar T, C e H1. Sem isso, o sinal de `voice` e o efeito da manufatura não são interpretáveis.
2. Documentar a escala e a fonte de `dados/wgi.voice_accountability.csv` (0–100; não é o percentil do WGI: Noruega 90, China 31; parece reescala linear do *estimate*).
3. Unidade de `AI.Investment` (corrente × constante) e cobertura por país do rastreador de investimento. A origem dos zeros deixou de ser pendência: desde a sessão de 21/09 eles são lidos como ausência de investimento privado registrado.
4. Separabilidade (Daraio, Simar & Wilson 2018): sem código na aula; discutir como limitação e, se houver tempo, order-m condicional.
5. Order-m sobre a forma intensiva (pares comparáveis por tamanho) e supereficiência por modelo.
6. Efeitos de país são inviáveis (96–99 % da variância das contextuais é entre países, inclusive `voice`); manter erros agrupados e dummies de ano; discutir como limitação.
7. Convexificação da metafronteira (Kerstens, O'Donnell & Van de Woestyne 2019): a fronteira agrupada admite combinações de anos diferentes, e o efeito vale de 10 % a 27 % conforme o modelo; decidir se a versão convexa basta como resultado principal.
8. Capital humano: a série de formandos em áreas de ciência e tecnologia cobre 155 de 333 país-ano e falta inteira para China, Japão, Israel e Argentina; fica na revisão e na discussão.

Resolvidas desde a versão anterior: a robustez "só com P&D" entrou no pipeline para S e T; o Malmquist deixou de depender do subpainel balanceado, na versão global que cobre 34 países.

---

## 8. Deck de 28/09 (20 min, 12 slides)

| # | Slide | Material |
|---|---|---|
| 1 | Pergunta, base, por que fronteira (1 min) | §2 |
| 2 | Dados e unidades: o que cada variável mede; patentes per capita recuperadas em contagem (2 min) | `fig01`, §3 |
| 3 | Diagnóstico de dados: cobertura 37 países × 9 anos, zeros como ausência de investimento, truncamento das patentes, conferência contra o OpenAlex (2 min) | `fig12`, `t21`, `t22`, `t28` |
| 4 | Tecnologias e fronteiras: FDH × CCR × BCC, quem está na fronteira (2 min) | `fig02`, `fig04`, `t02` |
| 5 | Escores S, T, ST, C; benchmarks; folgas (2 min) | `fig03`, `t03`, `t05`, `t06` |
| 6 | Robustez: unidades, anual × agrupada, outliers e supereficiência (1 min) | `t07`, `t08` |
| 7 | Bootstrap e fronteiras parciais (2 min) | `fig05`, `fig06`, `t09`, `t10` |
| 8 | SFA × DEA e classes latentes (2 min) | `fig07`, `fig09`, `t11`, `t12` |
| 9 | Metafronteira: lacuna tecnológica por ano e Malmquist global; fusões regionais e TOPSIS (2 min) | `fig13`, `t23`–`t25`, `t14`, `t15` |
| 10 | Segundo estágio: testes, Tobit, Simar-Wilson e a tabela das três colunas (3 min) | `fig10`, `t16`–`t20` |
| 11 | Diagnóstico setorial: quem converte, quem não, papel da base industrial; casos do topo e da cauda; Brasil (2 min) | `fig11`, `fig14`, `t26`, `documentos/discussao_casos.md` |
| 12 | Limitações e agenda (1 min) | §7 |

O slide 3 passou a ter dois minutos, tirados do slide 9, porque a auditoria da base responde diretamente a uma orientação da segunda sessão.

---

## 9. Manuscrito

1. Introdução — a corrida por IA é medida em volume; a pergunta é conversão.
2. Referencial — eficiência de sistemas nacionais de inovação (Wang & Huang 2007; Guan & Chen 2012; Kontolaimou et al. 2016); ineficiências nacionais e corrupção (Fukuyama, Tan & Wanke 2025); base industrial como condição de absorção; por que fronteira e não mediação/moderação.
3. Método — DEA agrupado (CCR/BCC) lido como metafronteira intertemporal, modelos S/T/ST/C, bootstrap, Order-m/α, SFA, segundo estágio (Tobit; Simar-Wilson alg. 2 em log δ), robustez (Fig. 1: fluxograma = tabela de §5).
4. Dados — variáveis e unidades, merge WDI, cobertura do painel, zeros como ausência de investimento, truncamento das patentes, conferência das publicações contra o OpenAlex.
5. Resultados — fronteiras, escores, benchmarks, robustez, dinâmica (lacuna tecnológica e Malmquist global).
6. Determinantes — H1/H2 nos três estimadores, na tabela de regressões com um painel por estimador; institucionais e financeiras; leitura das diferenças entre modelos.
7. Discussão — construção contrafactual com os casos do topo e da cauda (`documentos/discussao_casos.md`): âncoras da fronteira, potências regionais de nicho, rota de depósito da patente e composição da produção científica; o caso brasileiro; limites da variável de patentes.
8. Limitações e agenda — separabilidade, convexificação da metafronteira, DEA em rede, order-m condicional, classes latentes em SFA, capital humano.

Periódicos a decidir com o professor: *Socio-Economic Planning Sciences*, *Technological Forecasting & Social Change*, *Journal of the Knowledge Economy*; nacionais: BAR, RAUSP, BJOPM.

---

## 10. Cronograma até 28/09

| Dia | Tarefa |
|---|---|
| 20/09 (dom) | Voice & Accountability incorporada (feito) |
| 21/09 (sessão 2) | Orientação recebida e incorporada no mesmo dia (feito): metafronteira e lacuna tecnológica, zeros como ausência de investimento, auditoria de cobertura, tabela de regressões, conferência das publicações e casos do topo e da cauda. Registro em `documentos/orientacao_sessao_2.md` |
| 22–24/09 | Deck (12 slides) a partir de `resultados/figuras/` e `resultados/`; texto dos slides 10–11. Procurar patentes de IA por país do inventor (OECD.AI, WIPO) e rodar `RAPIDO=FALSE` para os valores finais |
| 25–26/09 | Ensaio cronometrado; ajustes de figuras; versão final do pipeline |
| 27/09 | Reserva |
| 28/09 | Apresentação |
| Depois | Manuscrito: referencial, posicionamento contra Fukuyama–Tan–Wanke (2025), escolha do periódico |

---

## Apêndice — Arquivos gerados

`resultados/`: `base_v3.csv` (base tratada), `t01`–`t28` (tabelas numeradas como em §5; `t19` = sensibilidade do segundo estágio, `t20` = tabela de regressões do manuscrito, `t21`–`t22` = auditoria da base, `t23`–`t25` = metafronteira e Malmquist global, `t26`–`t27` = casos e conferência das patentes, `t28` = conferência das publicações), `resumo_v3.txt` (log com os números citados), `log_erros.txt` (não gerado quando não há falhas).
`resultados/figuras/`: `fig01_descritivas`, `fig02_fronteira_2d`, `fig03_densidades_bcc`, `fig04_boxplot_metodos`, `fig05_bootstrap`, `fig06_orderm_alpha`, `fig07_sfa_dea`, `fig08_malmquist`, `fig09_classes_latentes`, `fig10_segundo_estagio`, `fig11_conversao_pais`, `fig12_cobertura_pais_ano`, `fig13_tgr_por_ano`, `fig14_especializacao`.
`dados/`: `wdi_contextuais.csv` e `baixar_wdi.sh`; `openalex_publicacoes.csv`, `openalex_nichos.csv` e `baixar_openalex.sh` (o JSON bruto das duas fontes fica fora do git); `wgi.voice_accountability.csv` (Voice & Accountability, WGI).
