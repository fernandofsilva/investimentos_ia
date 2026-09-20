# Proposta de Trabalho — Eficiência dos Sistemas Nacionais de Inovação em IA

**Disciplina:** Introdução à Análise de Eficiência em R (Prof. Peter Wanke)
**Base:** `AI_INVESTMENT.csv` — 208 observações, 37 países, 2013–2021, 33 variáveis

---

## 1. Diagnóstico da base

### 1.1 Estrutura

| Item | Situação |
|---|---|
| Unidade de observação | País-ano (`Country_Year`) |
| Painel | **Desbalanceado**: de 1 a 9 anos por país (mediana 5) |
| Missing values | Nenhum `NA` — a base já veio filtrada |
| Grupos | 7 regiões (`GeogLoc`), 4 níveis de renda (`IncomeLevel`) |
| Variáveis | 19 originais + 3 derivadas + 9 "log" |

Subpainéis balanceados disponíveis (importantes para Malmquist):

- **2013–2021 (9 anos × 9 países):** Áustria, China, Hungria, Israel, Japão, México, Polônia, Espanha, EUA
- **2016–2021 (6 anos × 13 países):** os 9 acima + Argentina, Grécia, Luxemburgo, Romênia
- **2013–2018 (6 anos × 14 países):** os 9 acima + Brasil, França, Índia, Singapura, Ucrânia

### 1.2 Sete achados que condicionam a modelagem

**(1) As colunas `log_*` não são logaritmos — são `log1p()`.**
Testei as nove: todas batem exatamente com `log(1+x)`, não com `log(x)`.

**(2) Duas dessas colunas são numericamente inúteis.**
`log_Patents_per_GDP` e `log_AI_Investment_per_GDP` são calculadas sobre razões da ordem de 10⁻⁸ e 10⁻⁴. Como `log1p(x) ≈ x` para x pequeno, **elas são idênticas às colunas em nível** (diferença máxima de 6,5×10⁻¹⁵). Se forem usadas como estão em qualquer regressão, a interpretação "semi-elasticidade" está errada. Recomendo recalcular tudo com `log()` após reescalar as razões (ex.: investimento em IA por milhão de PIB).

**(3) `AI.Investment` tem 17 zeros (8,2% da amostra).**
Chile-2015, Colômbia-2015, Croácia-2015, Grécia-2015, Hungria-2013, Luxemburgo-2016, Malásia-2014, Peru-2018, Romênia-2017/2018, Eslovênia-2018, África do Sul-2014, Ucrânia-2013 a 2017.
São quase certamente **zeros de não-cobertura** (o rastreador de venture capital não registrou deals), não ausência real de investimento. Em DEA, insumo zero torna a DMU artificialmente eficiente. Precisa de decisão explícita e documentada — ver §4.1.

**(4) `Corruption_Estimate` e `Government_Effectiveness` são negativos** (escala WGI, −2,5 a +2,5): 75 e 41 observações abaixo de zero. **Não podem entrar como insumo ou produto DEA** sem translação. O papel natural delas é de **variáveis contextuais** (segundo estágio), o que aliás é o uso teoricamente correto.

**(5) Há redundância estrutural conhecida — use para validar, não como insumos separados.**
`Total_Patents = PatentResidents + PatentNonResidents` (exato).
`Patents_per_GDP = Total_Patents / GDP.constant` (exato).
`AI_Investment_per_GDP = AI.Investment / GDP.constant` (com arredondamento).
Além disso, `GDP.constant / GDP.per.capita` **recupera a população com precisão** (China 1,40 bi; EUA 326,8 mi; Luxemburgo 0,61 mi em 2018) — útil para normalizações per capita.

**(6) `IncomeLevel` tem quatro grafias para a mesma categoria**: `High-Income_Economy` (101), `High-income_economy` (21), `High-income_Economy` (9), `high-income_economy` (9). Se não padronizar, o modelo de classes latentes e os testes por grupo vão quebrar em 6 categorias em vez de 3.

**(7) A especificação "ingênua" produz uma fronteira sem sentido econômico — e isso é o achado mais importante.**
Rodei um pré-teste DEA-CCR orientado a produto, ano a ano, com insumos em **nível absoluto** (investimento em IA, gasto em P&D em US$) e produtos mistos (publicações em nível, patentes de IA, % de exportações de alta tecnologia). Resultado para 2018:

| Fronteira (eficiência = 1) | Escore mais baixo |
|---|---|
| Ucrânia, Eslovênia, Romênia, Filipinas, Peru, Luxemburgo | EUA (0,050), Japão (0,053), Israel (0,080) |

Isso é o artefato clássico de **inconsistência dimensional**: insumos extensivos (US$) contra produtos intensivos (%). Países com denominador minúsculo dominam a fronteira. Um segundo teste, com **todas as variáveis em forma intensiva** (investimento por milhão de PIB, P&D %PIB → publicações por milhão de habitantes, patentes de IA, %exportações high-tech), produz fronteiras plausíveis: Japão, Singapura, EUA, Luxemburgo, China, México aparecem como benchmarks. **É esta a especificação que proponho.**

**(8) Poder de discriminação — argumento para as fronteiras robustas.**
Com a amostra anual (16 a 30 DMUs):

| Modelo | Eficientes por ano | Escore médio |
|---|---|---|
| CCR (CRS) | 3 a 6 | 0,39 – 0,54 |
| BCC (VRS) | 10 a 16 (até 75% em 2021) | 0,77 – 0,92 |

O BCC praticamente não discrimina nos anos finais. Isso **justifica metodologicamente** o uso de Order-m / Order-α e do bootstrap de Simar-Wilson, em vez de apresentá-los como enfeite.

---

## 2. Pergunta de pesquisa

> **Quão eficientes são os países em converter investimento financeiro em IA e esforço de P&D em produção científica, tecnológica e comercial em IA — e quanto dessa eficiência é explicada por qualidade institucional, estabilidade financeira e abertura comercial?**

Contribuição defensável para um Qualis: a literatura de eficiência de sistemas nacionais de inovação é grande, mas a aplicação a **IA especificamente**, com variáveis contextuais de **governança e solidez financeira** (a base traz `Z_Score` e `Non.performing.Loans`, o que é incomum nesse campo), e com tratamento robusto (Order-m + Simar-Wilson), é um nicho aberto.

---

## 3. Especificação proposta

**DMU:** país-ano (208 obs.) para as fronteiras robustas e pooled; país-ano por corte anual para o DEA clássico.

**Orientação:** produto (países não decidem reduzir seu PIB ou seu estoque de P&D no curto prazo; decidem o que extrair deles).

### Insumos (2) — intensivos
| Variável | Construção | Justificativa |
|---|---|---|
| `AI_inv_int` | `AI.Investment / GDP.constant × 10⁶` | Esforço financeiro privado em IA |
| `R.D_Percentage` | usar como está (%PIB) | Esforço agregado de P&D |

### Produtos (3) — intensivos
| Variável | Construção | Dimensão capturada |
|---|---|---|
| `pubs_pc` | `AI.Publications / (população/10⁶)` | Científica |
| `AI.Patent.Applications` | usar como está (já normalizada) | Tecnológica |
| `High_Tech_Export_Percentage` | usar como está | Comercial |

Com 2 insumos e 3 produtos, a regra prática `n ≥ 3(m+s) = 15` é satisfeita em todos os anos (mínimo 16 DMUs em 2021), embora com folga apertada — mais um argumento para o Order-m.

### Variáveis contextuais (segundo estágio)
`Corruption_Estimate`, `Government_Effectiveness`, `Z_Score`, `Non.performing.Loans`, `Trade_Percentage`, `Domestic_Credit`, `MarketCap`, mais dummies de `IncomeLevel` e `GeogLoc` e tendência de ano.

> **Atenção à endogeneidade conceitual:** `Domestic_Credit` e `MarketCap` poderiam ser insumos (profundidade financeira habilita o investimento). Optei por mantê-los no segundo estágio para preservar parcimônia na fronteira. Isso deve ser declarado como escolha e testado como robustez.

---

## 4. O algoritmo — pipeline em 6 etapas

### Etapa 0 — Preparação e auditoria da base

```r
library(tidyverse); library(Benchmarking); library(npsf)
library(sfaR); library(rDEA); library(truncreg); library(AER); library(boot)

raw <- read_csv("AI_INVESTMENT.csv")

df <- raw %>%
  # (6) padronizar IncomeLevel
  mutate(IncomeLevel = str_to_lower(IncomeLevel) %>%
           str_replace_all("[-_]", " ") %>% str_squish() %>%
           recode("high income economy"        = "High income",
                  "upper middle income economy"= "Upper-middle income",
                  "lower middle income economy"= "Lower-middle income")) %>%
  # (5) recuperar população
  mutate(pop_mi = (GDP.constant / GDP.per.capita) / 1e6) %>%
  # (3) tratar zeros de investimento — ver decisão abaixo
  mutate(zero_inv = AI.Investment == 0,
         AI_inv_int = (AI.Investment / GDP.constant) * 1e6,
         pubs_pc    = AI.Publications / pop_mi) %>%
  # (1)(2) refazer os logs corretamente
  mutate(across(c(AI_inv_int, pubs_pc, R.D_Percentage,
                  High_Tech_Export_Percentage, GDP.per.capita,
                  Trade_Percentage, Domestic_Credit),
                ~log(.x + 1e-9), .names = "ln_{.col}"))
```

#### 4.1 Decisão sobre os 17 zeros — rodar as três e reportar

| Estratégia | Implementação | Quando usar |
|---|---|---|
| **A. Amostra restrita** | excluir as 17 obs. (n = 191) | **Cenário principal** — mais defensável |
| **B. Epsilon** | substituir por 0,5 × menor positivo | Robustez; declarar o epsilon |
| **C. Insumo binário** | dummy `zero_inv` como variável contextual | Testa se a não-cobertura é sistemática |

A concordância dos rankings entre A e B (Spearman e Kendall) vira uma tabela de robustez no artigo.

### Etapa 1 — Tecnologias de produção e fronteiras determinísticas
*(Sessões 1–2)*

```r
X <- as.matrix(df_y[, c("AI_inv_int","R.D_Percentage")])
Y <- as.matrix(df_y[, c("pubs_pc","AI.Patent.Applications","High_Tech_Export_Percentage")])

fdh <- dea(X, Y, RTS = "fdh", ORIENTATION = "out")
ccr <- dea(X, Y, RTS = "crs", ORIENTATION = "out")
bcc <- dea(X, Y, RTS = "vrs", ORIENTATION = "out")

scale_eff <- eff(ccr) / eff(bcc)      # eficiência de escala
sl        <- slack(X, Y, bcc)         # folgas
peers(bcc); lambda(bcc)               # benchmarks e pesos
```

Entregáveis: plotagem bidimensional da tecnologia (um insumo agregado × um produto agregado), tabela FDH vs CCR vs BCC, decomposição de escala, análise de folgas por região.

### Etapa 2 — Detecção de outliers e superficiência
*(pré-requisito, não opcional nesta base)*

```r
sup <- sdea(X, Y, RTS = "vrs", ORIENTATION = "out")   # Andersen-Petersen
# sinalizar DMUs com superficiência extrema (ex. > 2) para inspeção
```

Dado o achado (7), essa etapa precisa vir **antes** de qualquer interpretação substantiva. Complementar com o gráfico de leverage de Wilson (1993).

### Etapa 3 — Fronteiras robustas e estocásticas
*(Sessões 3–4)*

```r
# 3a. Bootstrap de Simar-Wilson (1998) — escores corrigidos de viés + IC
bs <- dea.boot(X, Y, NREP = 2000, RTS = "vrs", ORIENTATION = "out")
bs$eff.bc; bs$conf.int; bs$bias

# 3b. Order-m (fronteira parcial robusta)
om <- npsf::teradialbc(...)   # ou FEAR::orderm(), m = 25, 50, 100
# varrer m e mostrar a convergência para a FDH quando m -> infinito

# 3c. Order-alpha  (alpha = 0.90, 0.95, 0.99)

# 3d. SFA — contraparte paramétrica
sfa_cd <- sfaR::sfacross(
  log(pubs_pc) ~ log(AI_inv_int) + log(R.D_Percentage),
  udist = "tnormal", data = df, S = 1)    # S = 1: fronteira de produção
summary(sfa_cd); efficiencies(sfa_cd)
```

Ponto de convergência do artigo: **correlacionar os rankings DEA-bootstrap, Order-m e SFA** (Spearman + teste de Kendall). Convergência alta = robustez; divergência = achado interessante sobre ruído vs ineficiência.

### Etapa 4 — Heterogeneidade tecnológica
*(Sessão 4, classes latentes)*

```r
lc <- sfaR::lcmcross(
  log(pubs_pc) ~ log(AI_inv_int) + log(R.D_Percentage),
  udist = "hnormal", data = df, S = 1, lcmClasses = 2:4)
# classes identificadas endogenamente
```

Hipótese testável e vendável: as classes latentes **não** coincidem perfeitamente com os grupos de renda do Banco Mundial — ou seja, há países de renda média operando com tecnologia de fronteira de país rico (Índia, China) e vice-versa. Comparar a classificação latente com `IncomeLevel` via tabela de contingência e índice de Rand ajustado.

### Etapa 5 — Tratamento estatístico dos escores
*(Sessão 5 — o núcleo econométrico do artigo)*

```r
# 5a. Teste de separabilidade Daraio-Simar-Wilson:
#     as contextuais afetam a FRONTEIRA ou só a distribuição de eficiência?
#     Se rejeitar separabilidade, o modelo de dois estágios é inválido
#     e é preciso ir para fronteiras condicionais (order-m condicional).

# 5b. Testes não paramétricos entre grupos
kruskal.test(eff ~ IncomeLevel, data = sc)
kruskal.test(eff ~ GeogLoc,     data = sc)
pairwise.wilcox.test(sc$eff, sc$IncomeLevel, p.adjust.method = "holm")
# Li-Racine para comparar densidades completas dos escores

# 5c. Tobit (benchmark da literatura antiga)
tob <- AER::tobit(eff ~ Corruption_Estimate + Government_Effectiveness +
                    Z_Score + Non.performing.Loans + ln_Trade_Percentage +
                    ln_Domestic_Credit + IncomeLevel + factor(Year),
                  left = 0, right = 1, data = sc)

# 5d. Simar-Wilson Algoritmo #2 — regressão truncada bootstrapped
#     ESTE é o estimador principal; o Tobit entra só como comparação
sw <- rDEA::dea.robust(X, Y, W = NULL, model = "output",
                       RTS = "variable", B = 2000)
tr <- truncreg(eff_bc ~ ..., data = sc, point = 1, direction = "left")
# bootstrap paramétrico em 2000 réplicas para os IC dos coeficientes
```

**Por que Simar-Wilson e não Tobit:** os escores DEA são estimados, serialmente correlacionados por construção (cada escore depende de toda a amostra) e enviesados. O Tobit ignora as três coisas. Argumentar isso explicitamente é meio caminho para o parecerista.

### Etapa 6 — Dinâmica temporal e checagem multicritério
*(Sessão 3)*

```r
# 6a. Malmquist no subpainel balanceado 2016-2021 (13 países)
mq <- malmq(X0, Y0, X1, Y1, RTS = "crs", ORIENTATION = "out")
# decompor: mudança de eficiência (catch-up) × mudança técnica (frontier shift)

# 6b. Meta-fronteira por grupo de renda (gap tecnológico entre grupos)

# 6c. Ganhos potenciais com fusões — aqui, "blocos de cooperação"
#     (UE, Mercosul, ASEAN): dea.merge() decompõe em
#     learning × harmony × scale
dea.merge(X, Y, M, RTS = "vrs")

# 6d. TOPSIS como validação externa do ranking
```

O item 6c é o mais criativo: reinterpretar "fusão" como **consórcio regional de P&D em IA** e medir o ganho de harmonia é um ângulo original e diretamente aplicável à discussão de política de IA (EU AI Act, estratégias nacionais).

---

## 5. Mapeamento com o cronograma da disciplina

| Sessão | Conteúdo | Etapa do pipeline |
|---|---|---|
| 1–2 (3 e 10/08) | FDH, CCR, BCC, folgas, fusões, Malmquist, TOPSIS | Etapas 0, 1, 2, 6 |
| 3–4 (17 e 24/08) | Bootstrap, SFA, Order-m/α, classes latentes | Etapas 3, 4 |
| 5 (31/08) | Contextuais, testes, Tobit, truncada bootstrapped | Etapa 5 |
| 6–7 (14 e 21/09) | Laboratório supervisionado | Consolidação + robustez |
| 8 (28/09) | Apresentação (20 min) | Deck de diagnóstico setorial |

---

## 6. Riscos e decisões a documentar no manuscrito

| Risco | Mitigação |
|---|---|
| Painel desbalanceado invalida Malmquist | Restringir a subpainéis balanceados; declarar viés de seleção |
| Zeros de investimento distorcem a fronteira | Três cenários (§4.1) + tabela de concordância de rankings |
| Baixa discriminação do BCC | Order-m/α como estimador principal, BCC como referência |
| Separabilidade rejeitada | Migrar para fronteiras condicionais (order-m condicional) |
| n pequeno por ano (16 em 2021) | Pooled + fronteira intertemporal como robustez |
| `AI.Patent.Applications` de origem ambígua | Confirmar a definição na fonte (AI Index / OECD.AI) antes de submeter |

---

## 7. Esqueleto do manuscrito

1. Introdução — corrida global por IA e a questão da *eficiência*, não do *volume*
2. Revisão — eficiência de sistemas nacionais de inovação; lacuna em IA
3. Método — DEA/FDH → Order-m/α → SFA → Simar-Wilson (Fig. 1: fluxograma do pipeline)
4. Dados — descritivas, tratamento dos zeros, justificativa da forma intensiva
5. Resultados — fronteiras, rankings corrigidos de viés, classes latentes, Malmquist
6. Determinantes — segundo estágio, o efeito de governança e solidez bancária
7. Discussão e implicações de política
8. Limitações e agenda futura

---

## 8. O que confirmar antes de começar

1. **Definição exata de `AI.Patent.Applications`** — os valores (China 59,9 e Luxemburgo 59,3 em 2021) sugerem normalização per capita ou participação percentual, não contagem. A interpretação inteira do produto tecnológico depende disso.
2. **Unidade de `AI.Investment`** — USD correntes ou constantes? Se correntes, deflacionar antes de comparar anos.
3. **Fonte dos zeros** — confirmar se são não-cobertura ou zero real.
4. As assinaturas exatas das funções de `npsf`, `rDEA` e `FEAR` variam entre versões; conferir na documentação instalada antes de rodar.
