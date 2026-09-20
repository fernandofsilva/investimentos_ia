# Proposta Revisada (v2) — Eficiência na Conversão de Investimento em IA

**Revisão após a orientação do professor.** Esta versão substitui a v1 no que for conflitante.

---

## 1. O que a orientação mudou

| Ponto | v1 (minha proposta) | Orientação do professor | v2 |
|---|---|---|---|
| Zeros de investimento | Excluir (cenário principal) | **Não excluir** — fenômeno recente; usar shift ou min-max | Manter todos; shift + análise de sensibilidade |
| Painel balanceado | Subpainéis balanceados | **Não se prender a isso**; resolver via contextuais | Amostra completa (208 obs.); painéis só para Malmquist (rebaixado) |
| Produtos | 3 (publicações, patentes, %exportações high-tech) | **2** — publicações e patentes de IA | 2 produtos; high-tech export vira contextual |
| Modelos | Order-m/α como principal | **CCR e BCC**, contrafactual de escala | CCR + BCC como núcleo; robustos no apêndice |
| Base industrial | Ausente | **Exigência central** — proxy de indústria no PIB | Novo bloco: merge com WDI |
| Escopo | 6 etapas (Malmquist, fusões, TOPSIS, classes latentes) | Enxugar | Núcleo enxuto + robustez |

Duas coisas que verifiquei empiricamente e que **refinam** — não contradizem — a orientação estão em §2 e §3.

---

## 2. O shift nos zeros: o BCC está protegido, o CCR não

O professor sugeriu somar uma constante para eliminar os zeros. Testei três magnitudes (US$ 1 mi, 10 mi e 100 mi) na especificação dele, orientada a produto.

**BCC: escores idênticos nas três.** Isso não é coincidência — é o resultado clássico de *invariância à translação* (Ali & Seiford, 1990; Pastor, 1996): o modelo BCC orientado a produto é invariante a translações dos **insumos**. Como o zero está no insumo e a orientação é a produto, o shift é literalmente inócuo para o BCC. Ótima notícia, e vale como parágrafo metodológico no artigo.

**CCR: a escolha do shift decide o resultado.** O CCR não tem essa propriedade, e o efeito nas 17 observações com investimento zero é brutal:

| Shift | Escore CCR médio (17 zeros) | % na fronteira | Posição relativa |
|---|---|---|---|
| US$ 1 mi | 0,791 | 58,8% | **Dominam** a fronteira |
| US$ 10 mi | 0,585 | 23,5% | Indistinguíveis dos demais (0,584) |
| US$ 100 mi | 0,319 | 5,9% | **Piores** da amostra |

Ou seja: uma escolha arbitrária do analista faz a Ucrânia e a Romênia saírem de "mais eficientes do mundo" para "menos eficientes do mundo". Isso **precisa** virar tabela de sensibilidade no artigo — é um ponto que um parecerista atento cobraria, e antecipá-lo é vantagem.

**E há um efeito residual que o shift não resolve.** Mesmo no BCC invariante, as 17 observações com zero têm escore médio 0,993 e 88,2% delas estão na fronteira, contra 42,4% do resto. É o problema do *self-identifier* sob retornos variáveis: quem tem insumo mínimo não pode ser dominado. Tratamento: incluir a dummy `zero_inv` como contextual no segundo estágio (testa se a não-cobertura é sistemática) e reportar a amostra restrita (n = 191) como robustez — não como cenário principal, conforme a orientação.

---

## 3. A melhor resposta à pergunta dos "dois modelos" — e ela testa a hipótese do professor

O professor levantou duas questões que parecem separadas: (a) rodar um modelo por produto ou um só com dois produtos; (b) a base industrial como condição para pesquisa virar patente. **Elas são a mesma questão**, e juntá-las é o que dá contribuição ao artigo.

A divisão "DEA físico × DEA financeiro" da literatura de infraestrutura não é aplicável aqui: os dois produtos disponíveis (publicações e patentes) são ambos contagens físicas. Mas existe uma divisão melhor e teoricamente mais forte — **por estágio da cadeia de inovação**:

- **Modelo S (ciência):** investimento em IA + P&D → **publicações em IA**
- **Modelo T (tecnologia):** investimento em IA + P&D → **patentes de IA**
- **Modelo ST (conjunto):** os dois produtos, para comparação

Rodei os três (BCC orientado a produto, todos os anos). O resultado justifica a separação:

> **Correlação de Spearman entre eficiência científica e eficiência tecnológica: 0,246.**

São praticamente ortogonais. Rodar um modelo único com os dois produtos **esconde** a informação mais interessante da base. E o padrão do gap é exatamente a hipótese do professor:

| Ciência sem virar tecnologia (S ≫ T) | Tecnologia acima da ciência (T ≫ S) |
|---|---|
| Índia (−0,93), Itália (−0,86), Polônia (−0,73), Espanha (−0,68), Malásia (−0,62), **Brasil (−0,57)** | Luxemburgo (+0,83), Singapura (+0,77), Eslovênia (+0,72), EUA (+0,16), Austrália (+0,08), Japão (+0,05) |

**O Brasil converte investimento em IA em artigo, não em patente.** Isso é o gancho do paper, e é diretamente o argumento do professor sobre tecido industrial.

### A pergunta de pesquisa revisada

> O que explica o **gap entre eficiência científica e eficiência tecnológica** na conversão de investimento em IA? Especificamente: a base industrial do país condiciona a passagem de pesquisa a patente?

A variável dependente do segundo estágio deixa de ser um escore e passa a ser **`gap = eff_T − eff_S`** (com os escores separados também modelados). Isso transforma a exigência do professor de "coloque uma proxy de indústria" numa **hipótese central testável**, e não numa variável de controle a mais.

---

## 4. A proxy de base industrial — o que falta na base

A `AI_INVESTMENT.csv` **não tem** participação da indústria no PIB. O mais próximo é `High_Tech_Export_Percentage`, mas testei: a correlação dela com o gap é de apenas 0,14. Ela é insuficiente sozinha — o que confirma a necessidade do merge externo que o professor pediu.

Indicadores do World Bank WDI a incorporar (chave `Country` + `Year`, cobertura completa para os 37 países no período):

| Código WDI | Variável | Papel |
|---|---|---|
| `NV.IND.MANF.ZS` | Indústria de transformação, % do PIB | **Proxy principal de tecido industrial** |
| `NV.IND.TOTL.ZS` | Indústria (total), % do PIB | Alternativa mais ampla |
| `TX.VAL.TECH.MF.ZS` | Exportações de alta tecnologia, % das exportações manufaturadas | Sofisticação industrial |
| `SP.POP.SCI.RD.P6` | Pesquisadores em P&D por milhão de hab. | Capacidade de absorção |

```r
library(WDI)
ind <- WDI(country = "all",
           indicator = c(manuf_pib = "NV.IND.MANF.ZS",
                         ind_pib   = "NV.IND.TOTL.ZS",
                         pesq_pm   = "SP.POP.SCI.RD.P6"),
           start = 2013, end = 2021) %>%
  mutate(Country = countrycode::countrycode(iso2c, "iso2c", "country.name"))

df <- left_join(df, ind, by = c("Country", "Year" = "year"))
```

Conferir o join: os nomes de país da base usam grafia inglesa simples, mas vale checar as 37 correspondências manualmente antes de seguir.

**Variável adicional derivável da própria base** (e que atende ao comentário do professor sobre "há quanto tempo cada país começou a investir"):

```r
df <- df %>% group_by(Country) %>%
  mutate(anos_desde_1o_inv = ifelse(any(AI.Investment > 0),
           Year - min(Year[AI.Investment > 0]), NA_real_)) %>% ungroup()
```

---

## 5. Especificação final

**DMU:** país-ano, amostra completa (n = 208). **Orientação:** produto.

**Insumos (2)**
- `AI.Investment` em US$ bilhões, com shift (sensibilidade em três magnitudes)
- `R.D_Percentage` (% do PIB)

**Produtos — três modelos**
- Modelo S: `AI.Publications`
- Modelo T: `AI.Patent.Applications`
- Modelo ST: os dois (comparação)

**Retornos de escala:** CCR e BCC, com decomposição de eficiência de escala (SE = CCR/BCC) — o contrafactual que o professor pediu.

**Contextuais (segundo estágio)**
1. *Base industrial* — `manuf_pib` (**H1**), `High_Tech_Export_Percentage`
2. *Institucionais* — `Corruption_Estimate`, `Government_Effectiveness`
3. *Financeiras* — `Domestic_Credit`, `MarketCap`, `Z_Score`, `Non.performing.Loans`
4. *Estruturais* — `ln(GDP.per.capita)`, `Trade_Percentage`, `IncomeLevel`, `GeogLoc`
5. *Controles do desenho* — `zero_inv`, `anos_desde_1o_inv`, efeito de ano

> **Sobre dimensionalidade:** com 2 insumos e 2 produtos, `n ≥ 3(m+s) = 12` é satisfeito em todos os anos (mínimo 16 em 2021). A especificação do professor é mais parcimoniosa e mais defensável que a minha v1 — retirar o terceiro produto foi ganho, não perda.

> **Ressalva que permanece:** `AI.Publications` é contagem absoluta e `AI.Patent.Applications` parece já normalizada. Misturá-las num mesmo vetor de produtos (Modelo ST) é dimensionalmente inconsistente. Nos modelos S e T separados o problema desaparece — mais um motivo para a separação de §3. Confirmar a definição de `AI.Patent.Applications` na fonte segue sendo pré-requisito.

---

## 6. Pipeline em R (núcleo)

```r
library(tidyverse); library(Benchmarking); library(rDEA); library(truncreg)

# --- Etapa 0: preparação
df <- df %>%
  mutate(IncomeLevel = str_to_lower(IncomeLevel) %>% str_replace_all("[-_]"," ") %>% str_squish(),
         zero_inv    = AI.Investment == 0,
         AI_inv_bi   = AI.Investment / 1e9)

roda_dea <- function(dados, produtos, shift) {
  X <- cbind(dados$AI_inv_bi + shift, dados$R.D_Percentage)
  Y <- as.matrix(dados[, produtos, drop = FALSE])
  tibble(Country = dados$Country, Year = dados$Year,
         ccr = eff(dea(X, Y, RTS = "crs", ORIENTATION = "out")),
         bcc = eff(dea(X, Y, RTS = "vrs", ORIENTATION = "out"))) %>%
    mutate(se = ccr / bcc)
}

# --- Etapa 1: três modelos × dois RTS × três shifts, ano a ano
grid <- expand_grid(shift = c(.001, .01, .1),
                    modelo = list(S  = "AI.Publications",
                                  T  = "AI.Patent.Applications",
                                  ST = c("AI.Publications","AI.Patent.Applications")))
# map sobre anos e sobre o grid → tabela de sensibilidade

# --- Etapa 2: folgas e benchmarks (só no shift central)
slack(X, Y, mod_bcc); peers(mod_bcc); lambda(mod_bcc)

# --- Etapa 3: o gap e seus determinantes
sc <- sc %>% mutate(gap = bcc_T - bcc_S)

# H1: base industrial explica o gap
m_gap <- lm(gap ~ manuf_pib + High_Tech_Export_Percentage +
              Corruption_Estimate + Government_Effectiveness +
              Z_Score + Non.performing.Loans + log(GDP.per.capita) +
              Trade_Percentage + zero_inv + anos_desde_1o_inv +
              IncomeLevel + factor(Year), data = sc)

# Escores individuais: truncada bootstrapped (Simar-Wilson alg. #2)
sw_S <- rDEA::dea.robust(X, Y_S, model = "output", RTS = "variable", B = 2000)
tr_S <- truncreg(eff_bc ~ ..., data = sc, point = 1, direction = "left")

# Tobit como comparação com a literatura
AER::tobit(bcc_S ~ ..., left = 0, right = 1, data = sc)

# --- Etapa 4: testes não paramétricos por grupo
kruskal.test(gap ~ IncomeLevel, data = sc)
kruskal.test(gap ~ GeogLoc, data = sc)
```

**Sobre o segundo estágio e o comentário do professor:** com a amostra desbalanceada completa não há como identificar efeitos fixos de país (as contextuais são lentas e quase colineares com a identidade do país). A especificação é, de fato, de efeitos aleatórios / *pooled* com dummies de ano. Vale declarar isso explicitamente e usar erros-padrão *clustered* por país como mitigação.

---

## 7. O que sai da v1

| Bloco | Destino |
|---|---|
| Malmquist / subpainéis balanceados | **Rebaixado** a apêndice opcional, ou cortado |
| Ganhos com fusões (`dea.merge`) | Cortado |
| TOPSIS | Cortado |
| Classes latentes | Opcional — só se o gap S/T sugerir mais de uma tecnologia |
| Order-m / Order-α | **Mantido como robustez** — justificativa: o BCC coloca 42% da amostra na fronteira |
| Bootstrap de Simar-Wilson | **Mantido** — é o estimador do segundo estágio |
| SFA | Mantido como contraparte paramétrica (exigência do syllabus) |

Isso mantém cobertura suficiente das técnicas da disciplina sem dispersar o argumento do artigo.

---

## 8. Estrutura do artigo

1. Introdução — a corrida por IA é medida em volume de investimento; a questão é a conversão
2. Referencial — eficiência de sistemas nacionais de inovação; **base industrial como condição de absorção tecnológica**
3. Método — CCR/BCC, modelos S e T separados, tratamento dos zeros, segundo estágio
4. Dados — descritivas, merge WDI, sensibilidade ao shift
5. Resultados — escores, o gap ciência-tecnologia, ranking por modelo
6. Determinantes do gap — teste de H1 (indústria) e institucionais
7. Discussão — implicações para países que publicam e não patenteiam (Brasil, Índia, Espanha, Polônia)
8. Limitações e agenda

---

## 9. Próximos passos

1. Confirmar a definição de `AI.Patent.Applications` na fonte
2. Fazer o merge WDI e conferir as 37 correspondências de país
3. Rodar a matriz completa: 3 modelos × 2 RTS × 3 shifts × 9 anos
4. Tabela de sensibilidade ao shift (§2) — decidir e justificar o shift central
5. Estimar o modelo do gap e levar os resultados para a próxima aula
