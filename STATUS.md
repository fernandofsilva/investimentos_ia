# STATUS — Eficiência do investimento em IA

Atualizado em 21/09/2026. Este arquivo resume o estado da pesquisa: pergunta, base, o que foi testado em cada versão, o que mudou e por quê, os resultados atuais, as decisões tomadas e o que ainda está em aberto. Os documentos completos estão em `documentos/`; os números citados aqui saem de `scripts/pipeline_v3.R` (rodada rápida, `RAPIDO=TRUE`).

---

## 1. Identificação

| Item | Situação |
|---|---|
| Disciplina | Introdução à Análise de Eficiência em R, Prof. Peter Wanke, Escola de Métodos |
| Autor | Fernando Silva |
| Avaliação | Manuscrito submetido a periódico Qualis até o lançamento das notas, mais apresentação de 20 minutos com diagnóstico setorial |
| Datas | Segunda sessão de orientação em 21/09/2026; apresentação em 28/09/2026 |
| Exigência do Syllabus | Replicar as análises das sessões numa base própria, com rotinas reprodutíveis: FDH, CCR/BCC, folgas, fusões, Malmquist, TOPSIS, bootstrap, SFA, Order-m/α, classes latentes, contextuais, testes não paramétricos, Tobit e regressão truncada bootstrap |
| Página do relatório | https://claude.ai/artifact/2CjsDUS3gwjvx7FXyQvtM1 (privada; editável na própria página; qualquer republicação a partir do repositório sobrescreve edições feitas lá) |

---

## 2. Pergunta e hipóteses

**Pergunta.** Quão eficientes são os países em converter esforço financeiro em IA (investimento privado em IA e gasto em P&D) em produção científica (publicações) e tecnológica (patentes) em IA, e a base industrial condiciona essa conversão?

- **H1.** Países com maior participação da manufatura no PIB são mais eficientes em produzir patentes (modelo T) e em converter pesquisa em patente (modelo C).
- **H2.** A base industrial importa menos para a eficiência científica (modelo S) do que para a tecnológica.
- **Exploratórias.** Qualidade institucional e solidez financeira afetam a eficiência; a fronteira se deslocou com a explosão do investimento (Malmquist).

Os quatro modelos compartilham a mesma fronteira única com as 208 observações país-ano, orientada a produto, em CCR e BCC; o que muda é o que entra como insumo e produto.

| Modelo | Insumos | Produto | Pergunta que responde |
|---|---|---|---|
| S, científico | investimento em IA, P&D | publicações | quanta ciência sai por dólar gasto |
| T, tecnológico | investimento em IA, P&D | patentes | quanta tecnologia sai por dólar gasto |
| ST, síntese | investimento em IA, P&D | publicações e patentes | os dois produtos na mesma fronteira |
| C, conversão | publicações, investimento em IA, P&D | patentes | quantas patentes saem dado o dinheiro e a ciência já produzida |

---

## 3. Base de dados e o que ela mede

- `dados/AI_INVESTMENT.csv`: 208 país-ano, 37 países, 2013–2021, 33 variáveis, sem valores ausentes. Painel desbalanceado: de 1 a 9 anos por país, de 16 a 30 países por ano.
- `dados/wdi_contextuais.csv` (World Bank, gerado por `dados/baixar_wdi.sh`): manufatura % PIB, indústria % PIB, manufaturados % das exportações, pesquisadores por milhão, P&D % PIB (conferência) e deflator do PIB dos EUA.
- `dados/wgi.voice_accountability.csv`: Voice & Accountability do WGI em escala 0–100. Não é o percentil do WGI (Noruega 90, China 31); parece reescala linear do *estimate*. Fonte exata a documentar.
- `dados/openalex_publicacoes.csv` e `dados/openalex_nichos.csv` (gerados por `dados/baixar_openalex.sh`): por país e ano de 2008 a 2021, total de artigos, repartição pelos quatro domínios do OpenAlex e artigos de inteligência artificial (subcampo 1702), nas definições de tópico primário e de qualquer tópico; e, para os países discutidos como casos, os tópicos e as instituições dos trabalhos de IA.

Antes de estimar qualquer fronteira, cada coluna foi confrontada com um fato externo que só é compatível com uma das leituras possíveis, porque a base veio sem dicionário de dados e os nomes das colunas não dizem a unidade. O código desses testes está em `scripts/relatorio/E01_base.R` e a conferência de rotina, no bloco 1 de `scripts/pipeline_v3.R` (log em `resultados/resumo_v3.txt`). Duas variáveis decidiram todo o desenho: publicações e patentes são os produtos dos modelos S e T e estavam em dimensões diferentes, de modo que qualquer comparação entre os dois escores media, em boa parte, população.

Diagnósticos que condicionaram toda a modelagem:

| Achado | Evidência | Consequência |
|---|---|---|
| `AI.Patent.Applications` é patentes **por milhão de habitantes** | China 59,9 e Luxemburgo 59,3 em 2021 (impossível em contagem: Luxemburgo tem 600 mil habitantes); multiplicada pela população, 58 % das observações caem a menos de 0,02 de um inteiro, contra 4 % esperados ao acaso; correlação −0,03 com o log da população | A contagem é recuperada como per capita × população; misturar com publicações em contagem gera artefato de tamanho |
| `AI.Publications` é contagem absoluta | Correlação 0,71 com o log da população, comportamento de contagem e não de taxa | Idem; é a origem do artefato de tamanho que derrubou o achado da v2 (gap T − S com correlação −0,53 com o log da população) |
| 17 zeros em `AI.Investment` | Menor valor positivo é exatamente US$ 1.000.000 (fonte arredonda a milhões) | Desde a sessão 2, lidos como ausência de investimento privado; o deslocamento de US$ 0,5 mi é artifício das técnicas em log, e o BCC-produto é invariante a ele |
| `AI.Publications` concorda com o OpenAlex na ordenação, não no nível | Spearman 0,957 com os artigos de IA do OpenAlex; razão mediana 1,45 (quartis 1,14–1,87), de 0,22 na Indonésia a 3,33 nas Filipinas | Bases de indexação distintas: a variável serve para comparar países, não para ler volumes absolutos |
| A composição da produção científica varia muito | Exatas e da vida vão de 33 % (Peru) a 75 % (China) do total de artigos; ciências sociais, de 7 % (China, Japão) a 45 % (Indonésia) | O produto do modelo científico representa parcela muito diferente do esforço de cada sistema; entra como contextual de sensibilidade |
| Patentes de IA acompanham depósitos de residentes | Correlação de 0,88 em log com `PatentResidents`, 0,71 com `PatentNonResidents`; razão patentes de IA por mil depósitos de residentes 5,3 nos 13 países EPO/PCT contra 8,3 nos demais | Evidência interna sugestiva, não conclusiva, de contagem por escritório nacional |
| Patentes de 2020–2021 truncadas | Em 2021, 64 % dos países caem em relação a 2020 (EUA 0,56×, Japão 0,70×) enquanto as publicações sobem (razão mediana 1,14), padrão de truncamento à direita por defasagem de publicação dos pedidos | Sensibilidade com o modelo T restrito até 2019 (Spearman 0,99 com o escore principal) |
| Colunas `log_*` são `log1p`, não `log` | Diferença máxima 7,4e-10 para `log1p` | As aplicadas a razões pequenas são iguais ao nível; não usar |
| Corrupção × efetividade do governo | Correlação 0,95 | Combinadas num índice único de governança |
| `IncomeLevel` com quatro grafias | 101/21/9/9 observações da mesma categoria | Padronizada em três níveis |
| Países que patenteiam via EPO/PCT aparecem com patentes de IA quase nulas | Suíça 0,002, Irlanda 0,004, Holanda 0,005 no modelo C | Sugere contagem por escritório nacional; pendência de dados mais importante |

---

## 4. Linha do tempo: o que foi testado, o que mudou e por quê

### v1 (19/09) — `documentos/anteriores/proposta_eficiencia_ia.md`
- **Testou.** Especificação ingênua com insumos em nível e produtos mistos: fronteira de 2018 formada por Luxemburgo, Filipinas, Romênia, Eslovênia e Ucrânia, com EUA em 0,050 e Japão em 0,053. Diagnosticou a base (log1p, zeros, WGI negativo, redundâncias) e propôs forma intensiva, três produtos, Order-m, Simar-Wilson, Malmquist, fusões e TOPSIS.
- **Ficou.** O diagnóstico da base e a forma intensiva como opção de robustez.
- **Caiu.** Três produtos misturando níveis e percentuais; funções erradas para Order-m (`npsf::teradialbc`) e classes latentes fora do template.

### Orientação do professor — `material_disciplina/comments.txt`
- Insumos: investimento em IA e P&D. Produtos: publicações e patentes. Rodar CCR e BCC para ter o contrafactual de escala. Segundo estágio com contextuais, incluindo uma proxy de base industrial (indústria % PIB ou exportações industriais). Manter os zeros com um deslocamento. Não se prender a painel balanceado. Registrar há quanto tempo cada país investe. Observação sobre periódicos que preferem mediação/moderação a DEA.

### v2 (19/09) — `documentos/anteriores/proposta_v2_revisada.md`
- **Testou.** Fronteiras anuais com 16 a 30 países; unidades mistas (investimento em dólares, P&D em % do PIB, publicações em contagem, patentes per capita); variável dependente `gap = T − S` em OLS. Resultado: "o Brasil converte investimento em artigo, não em patente".
- **Por que caiu.** O gap tem correlação −0,53 com o log da população; o ranking científico em contagem e em per capita não têm relação (Spearman 0,08); os números da seção sobre zeros vinham do modelo ST, não de S e T; os deslocamentos testados (1, 10 e 100 milhões) chegavam à mediana da amostra; a v2 atribuiu ao professor um "enxugar" que ele não pediu e cortou quatro técnicas exigidas pelo Syllabus.

### Análise crítica (19/09) — `documentos/analise_critica.md`
- Replicou a v2 exatamente (Spearman S×T 0,246, tabela de gap idêntica) com um solver próprio, sem pacotes de DEA, e mostrou os artefatos acima. Lista priorizada de melhorias que virou a v3.

### v3 (19–20/09) — `documentos/proposta_v3.md` e `scripts/pipeline_v3.R`
- **Mudou.** Unidades consistentes na forma extensiva (US$ de 2015 e contagens); fronteira agrupada com as 208 observações, como no template da aula; quatro modelos (S, T, ST, C); deslocamento de US$ 0,5 mi; robustez em nove cenários; todas as técnicas do template restauradas; segundo estágio com Tobit, OLS com erros por país e Simar-Wilson Algoritmo 2.
- **Problemas encontrados e resolvidos no caminho.** (a) A correção de viés do `rDEA::dea.robust` na escala θ devolve escores negativos (77 em 208 no modelo T); refeita na escala de Farrell com as réplicas do pacote. (b) A regressão truncada linear do `rDEA::dea.env.robust` explode em T e C (σ̂ = 720; δ mediano 21, máximo 1.456); o Algoritmo 2 foi reimplementado em log(δ) com `truncreg`. (c) O modelo S não é identificado pelo SFA (λ < 0), sinal de heterogeneidade entre países.

### Voice & Accountability (20/09)
- **Mudou.** Voice entrou nas contextuais. Correlação de −0,60 com manufatura % PIB. O coeficiente da manufatura cai pela metade e perde significância no OLS agrupado; sem os 13 países de patente quase nula, some quando voice entra. H1 passou de "respondida" a "plausível, com evidência frágil".

### Padronização e relatório (20/09)
- `scripts/pipeline_v3.R` e os trechos do relatório seguem o Google R Style Guide; saídas byte a byte idênticas às anteriores, exceto uma correlação do log de execução, que comparava países em ordens diferentes e foi corrigida (0,33 → −0,253; o número não aparecia em nenhum documento).
- `documentos/relatorio_professor.md` e a página publicada narram o percurso em terceira pessoa, com código, saída, diagnóstico e melhoria incorporada em cada etapa. A seção sobre o que a base mede saiu do relatório em 20/09 e passou a viver na seção 3 deste arquivo; o trecho de R que a sustentava (`scripts/relatorio/E01_base.R`) continua rodando em `run_prints.R` e mantém os números reprodutíveis, ainda que não apareça mais no documento.

### Orientação do professor, sessão 2 (21/09) — `documentos/orientacao_sessao_2.md`
- **O que mudou.** (a) A fronteira agrupada passou a ser apresentada como fronteira global ou intertemporal, equivalente à metafronteira convexificada, com as fronteiras anuais como fronteiras de grupo; daí saem a lacuna tecnológica por ano e um Malmquist global que cobre 34 países. (b) O zero de investimento passou a ser lido como ausência de investimento, e não como valor abaixo de um limiar; como o BCC orientado a produto é invariante a translações, os escores não mudam, mas a interpretação sim. (c) Auditoria de cobertura e de ausências, ranking por país restrito a três anos ou mais e cenário sem os seis países de painel curto. (d) Tabela de regressões em formato de periódico, com os três modelos e três estimadores, e leitura das diferenças entre eles. (e) Conferência da variável de publicações contra o OpenAlex e medidas de composição da produção científica. (f) Casos do topo e da cauda do ranking em `documentos/discussao_casos.md`.
- **O que a sessão respondeu.** A adequação da fronteira agrupada, o tratamento dos zeros, o que fazer com as observações de insumo mínimo, o formato do segundo estágio no manuscrito e o lugar da construção contrafactual, que é a discussão.
- **O que ficou pendente.** Definição da variável de patentes, modelo C como estágio único ou rede, estimador do segundo estágio, separabilidade, periódico; o professor verificará a situação do trabalho do grupo submetido com um coautor e o disponibilizará.

---

## 5. Especificação atual

- **DMU e fronteira.** País-ano; fronteira única com as 208 observações, apresentada como fronteira global ou intertemporal (metafronteira convexificada), com as fronteiras anuais como fronteiras contemporâneas de grupo; orientação a produto; escores reportados como 1/eff em (0, 1].
- **Retornos.** CCR e BCC; eficiência de escala só para as 191 observações com investimento positivo.
- **Insumos.** `inv_usd` = investimento em IA deflacionado a US$ de 2015 + US$ 0,5 mi; `rd_usd` = P&D % PIB × PIB constante.
- **Produtos.** `pubs` = publicações; `pat` = patentes per capita × população.
- **Robustez.** Forma intensiva; fronteiras anuais; deslocamento de US$ 1 mi; sem os 17 zeros, nos quatro modelos; T até 2019; sem Luxemburgo e Singapura; insumos defasados em um ano; sem os seis países com um ou dois anos observados; modelos de insumo único, só P&D, em S e T.
- **Ranking por país.** Informa o número de anos e os anos sem investimento; restrito a países com três anos ou mais e acompanhado da média calculada só sobre anos com investimento positivo (Spearman 0,96 entre as duas).
- **Dinâmica.** Lacuna tecnológica por ano (eficiência contemporânea sobre global), nas versões convexa e de união, com subamostragem de n igualado; fronteira sequencial; Malmquist global em 34 países, decomposto em aproximação à fronteira do ano e deslocamento dela.
- **Outliers.** Supereficiência de Andersen-Petersen; Order-m (m = 25, 50, 100) e Order-α (0,90; 0,95; 0,99).
- **Segundo estágio.** KS e Kruskal-Wallis por renda, região, zeros e manufatura acima/abaixo da mediana; Tobit (`censReg`) e OLS com erros agrupados por país sobre S, T, C, SE e versões intensivas; Simar-Wilson Algoritmo 2 linear (`rDEA`) e em log(δ) (implementação própria). Contextuais: manufatura % PIB (H1), manufaturados % exportações, índice de governança, Voice & Accountability, ln PIB per capita, comércio, Z-score, NPL, dummy de zero, tendência. Só em sensibilidade: participação das exatas e da vida na produção total e participação da IA no período anterior (2008–2012), esta predeterminada. A tabela em formato de periódico (`t20_regressoes_paper.md`) reúne os três modelos e os três estimadores.
- **Demais técnicas do template.** Bootstrap `rDEA::dea.robust` (B = 500 na rodada rápida, 2000 na final); SFA/COLS `Benchmarking::sfa`; classes latentes `poLCA` sobre decis; Malmquist `nonparaeff::faremalm2` no subpainel 2016–2021 (13 países); fusões como blocos regionais com `dea.merge`; TOPSIS com pesos iguais.

---

## 6. Resultados atuais

### Núcleo (fronteira agrupada, forma extensiva)

| Modelo | FDH efic. | CCR efic. | BCC efic. | BCC média | Zeros efic. (BCC) | Não-zeros efic. |
|---|---|---|---|---|---|---|
| S | 25,0 % | 2,4 % | 7,7 % | 0,459 | 23,5 % | 6,3 % |
| T | 18,3 % | 1,9 % | 3,4 % | 0,146 | 11,8 % | 2,6 % |
| ST | 46,6 % | 4,8 % | 9,1 % | 0,486 | 29,4 % | 7,3 % |
| C | 22,6 % | 1,9 % | 3,8 % | 0,165 | 17,6 % | 2,6 % |

- Spearman entre escores BCC: S×T 0,45; S×C 0,38; T×C 0,98 (acrescentar publicações como insumo quase não reordena T; C nunca fica abaixo de T e é igual a T em 103 das 208 observações).
- Conversão (C), média por país: China 0,63; Austrália 0,54; Peru 0,53; Ucrânia 0,49; Japão 0,46; México 0,44; Luxemburgo 0,35; EUA 0,23; Eslovênia 0,19; **Brasil 0,19 (10º de 37)**; … Israel 0,015; Noruega 0,011; Bélgica 0,009; Holanda 0,005; Irlanda 0,004; Suíça 0,002.
- Síntese (ST): Romênia 0,96; Peru 0,91; Malásia 0,91; Ucrânia 0,88; China 0,88; Índia 0,88; … Japão 0,41; EUA 0,40; Brasil 0,36; … Israel 0,11; Suíça 0,10. Peru, Ucrânia, Malásia e Romênia entram na fronteira por insumos minúsculos (supereficiência CRS: Ucrânia-2014 1,81; Malásia-2014 1,78).

### Robustez (Spearman com o escore principal)

| Cenário | Spearman |
|---|---|
| Intensiva S / T / C | 0,12 / 0,90 / 0,94 |
| Fronteiras anuais (ST) | 0,84 |
| Deslocamento US$ 1 mi | 1,00 |
| Sem os 17 zeros | 0,99 |
| T até 2019 | 0,99 |
| Sem Luxemburgo e Singapura | 1,00 |
| Insumos em t−1 | 0,89 |

T, C e ST são estáveis; S não é robusto entre sistemas de unidades.

### Demais técnicas
- **Bootstrap** (escala de Farrell): S 0,459 → 0,352; T 0,146 → 0,097; C 0,165 → 0,112; rankings preservados (Spearman ≥ 0,99).
- **Order-m (S):** λ_m mediano 5,8 / 6,9 / 8,5 para m = 25 / 50 / 100; 12–17 % acima da fronteira parcial. **Order-α:** 56 / 47 / 28 % acima para α = 0,90 / 0,95 / 0,99.
- **SFA:** S não identificado (λ < 0); T com λ = 0,53, elasticidades 0,14 (investimento) e 0,98 (P&D), TE média 0,61, correlação 0,62 com o BCC.
- **Classes latentes:** k = 2 pelo BIC (80 e 128 obs.); separam tamanho (log publicações 8,7 × 6,4), não renda; manufatura não difere entre classes (p = 0,19).
- **Malmquist S, 2016–2021, 13 países:** M = 0,971; catch-up 1,089; deslocamento 0,891 (a fronteira de publicações por dólar recuou enquanto o investimento mediano subiu de US$ 9 mi para US$ 243 mi).
- **Fusões (blocos regionais):** harmonia sempre < 1 (ganho de 4 a 21 %), escala sempre > 1 (1,19–1,42); Mercosul 0,39; Benelux 0,21; Leste UE 0,63.
- **TOPSIS:** Spearman 0,64 com BCC ST; China no topo em todos os anos.

### Metafronteira e dinâmica (novo em 21/09)
- **Lacuna tecnológica média** (eficiência contemporânea sobre global): S 0,684; T 0,485; ST 0,684; C 0,488. Contra a união não convexa: 0,747; 0,565; 0,774; 0,592. A convexificação vale 1,10 a 1,27 conforme o modelo, e só 9–13 % das observações estão na metatecnologia não convexa.
- **Lacuna por ano no modelo T:** 0,63 em 2013, mínimo de 0,27 em 2016, 0,83 em 2020 e 0,68 em 2021. Com n igualado ao menor ano (16): 0,53 / 0,22 / 0,75 / 0,68. O desenho não é efeito do tamanho da amostra.
- **Malmquist global (S, 34 países com dois anos ou mais):** M = 1,049; aproximação à fronteira do ano 1,067; deslocamento 0,983. A decomposição fecha (desvio 9e-16). Restrito a 2016–2021 nos 13 países do subpainel, o índice global dá 1,275 contra 0,862 do `faremalm2` acumulado, com Spearman 0,70: o índice adjacente atribui a regresso técnico o que o global lê como distância à melhor prática do período.
- **Por faixa de renda (exploratório):** a lacuna dos países de renda média é 0,95 em S e 0,99 em T, contra 0,65 e 0,31 nos de renda alta. A fronteira global é essencialmente a dos países de renda média.

### Casos e fontes externas (novo em 21/09)
- **Topo do ranking:** Peru, Ucrânia e Eslovênia devem a posição às observações sem investimento, que só se comparam entre si; Peru cai de 0,53 para 0,37 quando a média usa só anos com investimento positivo, e a Eslovênia tem uma única observação. México (0,45; nove anos; manufatura 19,7 %) e Japão (0,46; 19,9 %) são os casos substantivos.
- **Composição da produção:** exatas e da vida em 75 % dos artigos chineses e 60 % dos japoneses, contra 39 % dos brasileiros e 33 % dos peruanos; ciências sociais em 26 % dos franceses e 23 % dos britânicos, contra 7 % dos chineses.
- **Nichos de IA (OpenAlex):** México em otimização, lógica difusa e geociências (UNAM, IPN); Eslovênia em processamento de linguagem natural e criptografia (Ljubljana, Jožef Stefan); Israel em criptografia e algoritmos (Tel Aviv, Technion); Brasil em geociências e estudos de linguagem (USP, UFMG, Unicamp).

### Segundo estágio (H1: coeficiente de manufatura % PIB)

| Escore | Sem voice: Tobit (p) / OLS-cluster p / SW log-δ β [IC] | Com voice: Tobit (p) / OLS-cluster p / SW log-δ β [IC] |
|---|---|---|
| T | 0,0185 (< 1e-6) / 0,021 / −0,142 [−0,198; −0,086] | 0,0095 (0,024) / 0,195 / −0,097 [−0,153; −0,031] |
| C | 0,0183 (< 1e-5) / 0,032 / −0,132 [−0,187; −0,077] | 0,0098 (0,029) / 0,265 / −0,085 [−0,153; −0,030] |
| S | 0,0133 (0,001) / 0,154 / −0,027 [−0,050; −0,006] | 0,0064 (0,189) / 0,514 / −0,016 [−0,040; 0,009] |

- Sem os 13 países de patente quase nula (n = 136): manufatura continua forte sem voice (T 0,023, p < 0,001) e some com voice (p 0,6–0,8); voice permanece negativa (p 0,01–0,03).
- Voice: Tobit −0,008 por ponto em T e C; SW log-δ +0,045 (T) e +0,047 (C). Sinal implausível como efeito causal; a explicação mais provável é a contagem de patentes por escritório nacional, que zera os países europeus (voice médio 78, contra 64 dos demais; China 31).
- Versão linear do Algoritmo 2: estável em S (σ̂ = 4,1), instável em T e C (σ̂ = 735 e 331).

### Situação das hipóteses

| Hipótese | Situação |
|---|---|
| H1: base industrial → mais eficiência em patentes | Plausível, evidência frágil: significativa em todos os estimadores sem voice; cai pela metade com voice; some sem os países de patente ≈ 0 |
| H2: base industrial importa menos para ciência | Compatível: coeficiente fraco e instável em S; S não é robusto entre unidades |
| Instituições e solidez financeira | Inconclusivo: voice com sinal implausível; Z-score negativo sobre a ineficiência; governança perde significância com voice |
| Dinâmica | Respondida: a lacuna tecnológica cai até 2016 e se recupera até 2020; Malmquist global em 34 países |
| O que a variável de publicações mede | Respondida: mesma ordenação do OpenAlex (0,96) em níveis diferentes; composição da produção varia de 33 % a 75 % de exatas e da vida |
| Por que países improváveis lideram | Respondida: Peru, Ucrânia e Eslovênia são âncoras das observações sem investimento; México e Japão são os casos substantivos |

---

## 7. Decisões tomadas e justificativas

| Decisão | Por quê |
|---|---|
| Forma extensiva como principal, intensiva como robustez | Leitura literal da pergunta (o que se investe contra o quanto se gera); o VRS absorve o tamanho; a forma mista da v2 gerava artefato de população |
| Fronteira agrupada, não anual | Template da aula; fronteiras anuais inflavam escores com a queda de n (média de S de 0,59 para 0,75 em 2021, com 16 países) |
| Modelo C em lugar de `gap = T − S` | O gap era a diferença de dois escores limitados e dependentes, de fronteiras com unidades diferentes; C testa a conversão dentro do DEA |
| Zero é ausência de investimento, não valor abaixo de um limiar | Orientação da sessão 2: zero é informação fidedigna e célula em branco é que seria ausência; o deslocamento de US$ 0,5 mi fica como artifício das técnicas em log, e o BCC-produto é invariante a ele |
| Fronteira agrupada apresentada como metafronteira | Orientação da sessão 2: o painel desbalanceado justifica a leitura; dela saem a lacuna tecnológica e um Malmquist que não exige painel balanceado |
| Ranking por país restrito a três anos ou mais, com marcação dos anos sem investimento | Sob VRS, observações sem investimento só se comparam entre si e a de menor P&D é eficiente por construção; a Eslovênia aparecia em nono lugar com uma observação |
| Especialização científica só em sensibilidade, na versão anterior ao período | A participação contemporânea de IA é simultânea aos produtos do modelo; a de 2008–2012 é predeterminada |
| Correção de viés do bootstrap na escala de Farrell | A correção do pacote na escala θ devolve escores negativos com cauda pesada |
| Algoritmo 2 em log(δ) | δ com mediana 21 e máximo 1.456 quebra a regressão truncada linear |
| Índice único de governança | Corrupção e efetividade com correlação 0,95 |
| Todas as técnicas do template no deck | O Syllabus manda replicar as análises das sessões; o professor não pediu corte |
| Reportar a fragilidade de H1 em vez de escolher o conjunto de contextuais mais favorável | Manufatura e voice têm correlação −0,60 e não se separam com a variável de patentes atual |
| Erros do próprio ferramental ficam fora do relatório | O relatório trata da análise e das melhorias incorporadas, não da qualidade do código |

---

## 8. Pendências e decisões em aberto

Os pontos que a sessão de 21/09 não resolveu, com o que cada resposta mudaria, estão na seção 14 de `documentos/relatorio_professor.md` (e na página). Os três de maior alcance: a definição da variável de patentes, o modelo C como estágio único ou DEA em rede, e o estimador do segundo estágio no manuscrito.

1. **Patentes (prioridade máxima).** Confirmar na fonte a definição de `AI.Patent.Applications` (inventor × depositante, escritório) e obter uma série por país do inventor (OECD.AI, WIPO); reestimar T, C e H1. Decidir o tratamento dos 13 países de patente quase nula.
2. **Voice & Accountability.** Documentar escala e fonte do arquivo.
3. **Investimento.** Confirmar moeda (corrente × constante) e cobertura por país do rastreador. A origem dos zeros deixou de ser pendência desde a sessão 2.
4. **Estimador do segundo estágio no manuscrito.** Algoritmo 2 em log(δ) como principal, ou Tobit como principal com a truncada restrita a S.
5. **Manufatura × voice.** Reportar os dois conjuntos lado a lado ou construir um índice institucional único.
6. **Robustez adicional.** S só com P&D e T só com investimento; Order-m na forma intensiva; supereficiência por modelo.
7. **Deck de 28/09.** Doze slides seguindo o template, com o diagnóstico setorial nos dois últimos.
8. **Manuscrito.** Posicionar contra Fukuyama, Tan & Wanke (2025, *Socio-Economic Planning Sciences* 100:102248) e localizar o estudo econométrico correlato do grupo; escolher periódico (SEPS, TF&SC, Journal of the Knowledge Economy); escrever o parágrafo "por que fronteira e não mediação/moderação".
9. **Separabilidade** (Daraio, Simar & Wilson 2018): sem código na aula; discutir como limitação.
10. **Convexificação da metafronteira** (Kerstens, O'Donnell & Van de Woestyne 2019): decidir se a versão convexa basta como resultado principal, com a união em nota.
11. **Capital humano.** Formandos em áreas de ciência e tecnologia (UIS) cobrem 155 de 333 país-ano e faltam inteiros para China, Japão, Israel e Argentina: fora do painel. Pedir à colega Jéssica a literatura de capital humano e patentes oferecida na sessão, para a revisão e a discussão.
12. **Trabalho do grupo.** O professor verificará a situação do estudo submetido com um coautor sobre esta base e o disponibilizará no e-class.

---

## 9. Ambiente e reprodução

- R 4.5.2 (arm64), com `Benchmarking`, `rDEA` (GLPK embutido), `nonparaeff`, `poLCA`, `censReg`, `topsis`, `truncreg`, `WDI`, `countrycode`, `tidyverse`, `sandwich`, `lmtest`. `rgl` e `frontiles` não instalam sem XQuartz; por isso o Order-α é implementação própria.
- Todos os scripts localizam a raiz do repositório sozinhos e podem ser chamados de qualquer subpasta.

| Comando | O que faz | Tempo |
|---|---|---|
| `Rscript scripts/pipeline_v3.R` | Roda o template inteiro; grava `resultados/t01`–`t28`, `resultados/figuras/fig01`–`fig14`, `resultados/resumo_v3.txt` | ≈ 1 min |
| `RAPIDO=FALSE Rscript scripts/pipeline_v3.R` | Mesmo pipeline com B = 2000 e L2 = 2000 | alguns minutos |
| `Rscript scripts/replica_analise_critica.R` | Reproduz os números da análise crítica da v2 sem pacotes de DEA | ≈ 3 s |
| `Rscript scripts/relatorio/run_prints.R` | Executa os trechos do relatório e grava `resultados/prints/` | ≈ 15 s |
| `python3 scripts/relatorio/build_report.py` | Remonta `documentos/relatorio_professor.md` e `resultados/relatorio_professor.html` | instantâneo |
| `bash dados/baixar_wdi.sh` | Regenera `dados/wdi_contextuais.csv` a partir da API do WDI | depende da rede |
| `bash dados/baixar_openalex.sh` | Regenera `dados/openalex_publicacoes.csv` e `dados/openalex_nichos.csv` a partir da API do OpenAlex; pula o que já está em `dados/raw_openalex/` | ≈ 3 min |

- Semente fixa (`set.seed(1)`); a rodada rápida é determinística. Tempos e a linha "Fim" do log variam entre execuções.

---

## 10. Informações importantes

- A página do relatório tem botão "Editar textos". Edições feitas lá viram uma nova versão do artefato. Antes de republicar a partir do repositório, é preciso levar essas edições para `scripts/relatorio/template.md`, senão elas se perdem.
- O nome do artefato na galeria continua "Da Verba à Patente"; o título do documento é "Eficiência do investimento em IA".
- O relatório e a proposta estão em terceira pessoa impessoal; manter esse tom.
- O trabalho correlato do grupo do professor com o mesmo período e variáveis afins é Fukuyama, Tan & Wanke (2025). Na sessão de 21/09 o professor confirmou que há um estudo submetido com um coautor sobre esta base e que verificará a situação da submissão para disponibilizá-lo no e-class.
- O OpenAlex responde sem chave de acesso e aceita consultas agrupadas por ano, de modo que bastam oito por país. O Scimago bloqueia download por script. A razão entre a variável de publicações da base e a contagem do OpenAlex varia por país, o que impede usar uma no lugar da outra.
- Referências metodológicas centrais: Ali & Seiford (1990) e Pastor (1996) para invariância à translação; Simar & Wilson (1998, 2007); Daraio, Simar & Wilson (2018); Wilson (1993) e Andersen & Petersen (1993); Olesen, Petersen & Podinovski (2015, 2017) para razões no DEA; Tulkens & Vanden Eeckaut (1995) e Pastor & Lovell (2005) para as fronteiras sequencial e global; Battese, Rao & O'Donnell (2004) e O'Donnell, Rao & Battese (2008) para metafronteira e lacuna tecnológica; Kerstens, O'Donnell & Van de Woestyne (2019) para a convexificação; Wang & Huang (2007), Guan & Chen (2012) e Kontolaimou et al. (2016) para eficiência de sistemas nacionais de inovação.

---

## 11. Mapa do repositório

```
dados/                 base principal, contextuais do WDI e do WGI, publicações do OpenAlex, scripts de download
scripts/               pipeline_v3.R (análise completa), replica_analise_critica.R
scripts/relatorio/     modelo do relatório, trechos de R (00_setup, E01–E15), run_prints.R, build_report.py
resultados/            tabelas t01–t28, base tratada, log de execução, prints/, figuras/, escores da crítica
documentos/            relatorio_professor.md, proposta_v3.md, orientacao_sessao_2.md, discussao_casos.md, analise_critica.md; anteriores/ com v1 e v2
material_disciplina/   Syllabus, transcrição da orientação, scripts e HTML das aulas
deletar/               arquivos dispensáveis, separados para exclusão manual (fora do git)
```
