# =============================================================================
# replica_analise_critica.R
# Reproduz todos os numeros citados em analise_critica.md a partir de
# AI_INVESTMENT.csv. Usa apenas base R + tidyverse (+ sandwich/lmtest para
# erros-padrao agrupados). O DEA e resolvido por um simplex denso proprio
# (regra de Bland) para nao depender de pacotes ausentes nesta maquina.
# O pipeline definitivo deve usar Benchmarking/rDEA como no template da aula.
#
# Uso: Rscript scripts/replica_analise_critica.R   (roda em poucos segundos)
# =============================================================================
suppressPackageStartupMessages({library(tidyverse); library(sandwich); library(lmtest)})
set.seed(1)
options(width = 140)
# Executa a partir da raiz do repositório (a pasta que contém dados/).
for (i in 1:5) if (!file.exists("dados/AI_INVESTMENT.csv")) setwd("..")
stopifnot(file.exists("dados/AI_INVESTMENT.csv"))
sec <- function(t) cat("\n", strrep("=", 100), "\n", t, "\n", strrep("=", 100), "\n", sep = "")

d <- read_csv("dados/AI_INVESTMENT.csv", show_col_types = FALSE) %>%
  mutate(pop_mi    = GDP.constant / GDP.per.capita / 1e6,       # populacao recuperada (milhoes)
         zero_inv  = AI.Investment == 0,
         inv_bi    = AI.Investment / 1e9,                        # US$ bilhoes
         inv_pc    = AI.Investment / (pop_mi * 1e6),             # US$ por habitante
         inv_int   = AI.Investment / GDP.constant * 1e6,         # US$ por milhao de PIB (v1)
         rd_usd_bi = R.D_Percentage / 100 * GDP.constant / 1e9,  # P&D em US$ bilhoes
         pubs_pm   = AI.Publications / pop_mi,                   # publicacoes por milhao de hab.
         pat_cnt   = AI.Patent.Applications * pop_mi,            # contagem implicita de patentes
         income    = str_to_lower(IncomeLevel) %>% str_replace_all("[-_]", " ") %>% str_squish())

# ----------------------------------------------------------------------------
# Solver: simplex denso, regra de Bland.  max c'v  s.a.  A v <= b (b >= 0), v >= 0
# ----------------------------------------------------------------------------
simplex_max <- function(A, b, cvec, maxit = 5000) {
  m <- nrow(A); n <- ncol(A)
  Tb <- cbind(A, diag(m), b); z <- c(cvec, rep(0, m), 0); basis <- n + (1:m)
  for (it in 1:maxit) {
    e <- which(z[1:(n + m)] > 1e-9)[1]; if (is.na(e)) break
    col <- Tb[, e]; ratios <- ifelse(col > 1e-12, Tb[, n + m + 1] / col, Inf)
    if (all(is.infinite(ratios))) return(NA_real_)
    l <- which(ratios == min(ratios)); if (length(l) > 1) l <- l[which.min(basis[l])]
    Tb[l, ] <- Tb[l, ] / Tb[l, e]
    for (r in setdiff(1:m, l)) Tb[r, ] <- Tb[r, ] - Tb[r, e] * Tb[l, ]
    z <- z - z[e] * Tb[l, ]; basis[l] <- e
  }
  -z[n + m + 1]
}
# DEA radial orientado a produto (phi de Farrell >= 1). VRS por substituicao
# lambda_o = 1 - sum(lambda_j); CRS direto. Escala por maximo de coluna.
dea_out <- function(X, Y, rts = "vrs") {
  X <- as.matrix(X); Y <- as.matrix(Y)
  X <- sweep(X, 2, apply(X, 2, max), "/"); Y <- sweep(Y, 2, apply(Y, 2, max), "/")
  n <- nrow(X); phi <- rep(NA_real_, n)
  for (o in 1:n) {
    if (rts == "vrs") {
      j <- setdiff(1:n, o)
      A <- rbind(cbind(0, t(X[j, , drop = FALSE]) - X[o, ]),
                 cbind(Y[o, ], -(t(Y[j, , drop = FALSE]) - Y[o, ])),
                 c(0, rep(1, n - 1)))
      b <- c(rep(0, ncol(X)), Y[o, ], 1)
      phi[o] <- simplex_max(A, b, c(1, rep(0, n - 1)))
    } else {
      A <- rbind(cbind(0, t(X)), cbind(Y[o, ], -t(Y))); b <- c(X[o, ], rep(0, ncol(Y)))
      phi[o] <- simplex_max(A, b, c(1, rep(0, n)))
    }
  }
  phi
}
# Avalia um ponto (xo, yo) contra um conjunto de referencia sob CRS (usado em
# supereficiencia e Malmquist); phi pode ser < 1 se o ponto esta alem da fronteira.
dea_eval_crs <- function(Xref, Yref, xo, yo) {
  Xref <- as.matrix(Xref); Yref <- as.matrix(Yref)
  sx <- apply(rbind(Xref, xo), 2, max); sy <- apply(rbind(Yref, yo), 2, max)
  Xref <- sweep(Xref, 2, sx, "/"); Yref <- sweep(Yref, 2, sy, "/"); xo <- xo / sx; yo <- yo / sy
  A <- rbind(cbind(0, t(Xref)), cbind(yo, -t(Yref))); b <- c(xo, rep(0, length(yo)))
  simplex_max(A, b, c(1, rep(0, nrow(Xref))))
}
run_spec <- function(dat, X, Y, rts, by_year = TRUE) {   # escore = 1/phi em (0,1]
  sc <- rep(NA_real_, nrow(dat))
  if (by_year) { for (yr in unique(dat$Year)) { i <- which(dat$Year == yr)
    sc[i] <- 1 / dea_out(X[i, , drop = FALSE], Y[i, , drop = FALSE], rts) } }
  else sc <- 1 / dea_out(X, Y, rts)
  pmin(sc, 1)
}
fdh_out <- function(dat, X, Y) {
  sc <- rep(NA_real_, nrow(dat)); X <- as.matrix(X); Y <- as.matrix(Y)
  for (yr in unique(dat$Year)) { i <- which(dat$Year == yr)
    for (o in i) { dom <- i[apply(X[i, , drop = FALSE], 1, function(x) all(x <= X[o, ] * (1 + 1e-9)))]
      sc[o] <- Y[o, 1] / max(Y[dom, 1]) } }
  sc
}
eff <- function(v) 100 * mean(v >= 1 - 1e-6, na.rm = TRUE)
sp  <- function(a, b) round(cor(a, b, method = "spearman", use = "complete.obs"), 3)

# =============================================================================
sec("0. Estrutura da base e checagens da v1")
cat("dim:", dim(d), "| NAs:", sum(is.na(d)), "| paises:", n_distinct(d$Country), "\n")
yc <- count(d, Country); cat("anos por pais: min", min(yc$n), "max", max(yc$n), "mediana", median(yc$n), "(v1 diz 5)\n")
cat("n por ano:", paste(names(table(d$Year)), table(d$Year), sep = "=", collapse = " "), "\n")
cat("grafias de IncomeLevel:", paste(names(table(d$IncomeLevel)), table(d$IncomeLevel), sep = "=", collapse = " | "), "\n")
cat("zeros em AI.Investment:", sum(d$zero_inv), "|", paste(d$Country_Year[d$zero_inv], collapse = ", "), "\n")
cat("menor AI.Investment positivo: US$", min(d$AI.Investment[d$AI.Investment > 0]),
    "(", paste(d$Country_Year[d$AI.Investment == min(d$AI.Investment[d$AI.Investment > 0])], collapse = ", "), ")\n")
cat("mediana AI.Investment positivo: US$", round(median(d$AI.Investment[d$AI.Investment > 0]) / 1e6, 1), "mi\n")
cat("log_* sao log1p:  max|log_RD - log1p(RD)| =", signif(max(abs(d$log_RD_Percentage - log1p(d$R.D_Percentage))), 2),
    "| max|log_AI_inv_perGDP - nivel| =", signif(max(abs(d$log_AI_Investment_per_GDP - d$AI_Investment_per_GDP)), 2),
    "| max|log_Patents_perGDP - nivel| =", signif(max(abs(d$log_Patents_per_GDP - d$Patents_per_GDP)), 2), "\n")
cat("negativos: Corruption", sum(d$Corruption_Estimate < 0), "| GovEff", sum(d$Government_Effectiveness < 0),
    "| cor(Corruption, GovEff) =", round(cor(d$Corruption_Estimate, d$Government_Effectiveness), 3), "\n")
cat("Total_Patents identidade:", max(abs(d$Total_Patents - d$PatentResidents - d$PatentNonResidents)), "\n")
print(as.data.frame(d %>% filter(Year == 2018, Country %in% c("China", "United States", "Luxembourg", "Brazil")) %>%
                      transmute(Country, pop_mi = round(pop_mi, 1))))

# =============================================================================
sec("1. Unidades: AI.Patent.Applications e per capita; AI.Publications e contagem")
frac <- (d$AI.Patent.Applications * d$pop_mi) %% 1
cat("patentes x populacao a menos de 0,02 de um inteiro:", round(100 * mean(pmin(frac, 1 - frac) < 0.02), 1),
    "% das obs (base aleatoria ~4%)\n")
print(as.data.frame(d %>% filter(Year == 2021) %>% arrange(desc(AI.Patent.Applications)) %>% slice(1:5) %>%
  transmute(Country, pat_pm = round(AI.Patent.Applications, 1), pop_mi = round(pop_mi, 1), pat_cnt = round(pat_cnt), pubs = AI.Publications)))
cat(sprintf("cor(log pubs, log pop) = %.2f | cor(log patentes_pm, log pop) = %.2f | cor(log patentes_pm, log PIBpc) = %.2f | cor(log pubs, log PIBpc) = %.2f\n",
    cor(log(d$AI.Publications), log(d$pop_mi)), cor(log(d$AI.Patent.Applications), log(d$pop_mi)),
    cor(log(d$AI.Patent.Applications), log(d$GDP.per.capita)), cor(log(d$AI.Publications), log(d$GDP.per.capita))))

# =============================================================================
sec("2. Replicacao da v2: X = (AI.Inv US$ bi + shift, P&D %), fronteiras anuais")
YS <- cbind(d$AI.Publications); YT <- cbind(d$AI.Patent.Applications); YST <- cbind(d$AI.Publications, d$AI.Patent.Applications)
res <- list()
for (sh in c(0.001, 0.01, 0.1)) { X <- cbind(d$inv_bi + sh, d$R.D_Percentage)
  res[[as.character(sh)]] <- tibble(sh = sh,
    bccS = run_spec(d, X, YS, "vrs"),  bccT = run_spec(d, X, YT, "vrs"),  bccST = run_spec(d, X, YST, "vrs"),
    ccrS = run_spec(d, X, YS, "crs"),  ccrT = run_spec(d, X, YT, "crs"),  ccrST = run_spec(d, X, YST, "crs")) }
c0 <- res[["0.01"]]; cat("NAs do solver:", sum(is.na(unlist(res))), "\n")
fdhS <- fdh_out(d, cbind(d$inv_bi + 0.01, d$R.D_Percentage), YS)
cat("sanidade: max(BCC_S - FDH_S) =", signif(max(c0$bccS - fdhS), 2), "(esperado <= 0) | max(CCR_S - BCC_S) =",
    signif(max(c0$ccrS - c0$bccS), 2), "(esperado <= 0) | invariancia BCC ao shift: max|S(1mi)-S(100mi)| =",
    signif(max(abs(res[["0.001"]]$bccS - res[["0.1"]]$bccS)), 2), "\n")
cat(sprintf("eficientes BCC: S %.1f%% | T %.1f%% | ST %.1f%% (nao-zeros ST %.1f%%) || CCR: S %.1f%% | T %.1f%% | ST %.1f%% || FDH_S %.1f%%\n",
    eff(c0$bccS), eff(c0$bccT), eff(c0$bccST), eff(c0$bccST[!d$zero_inv]), eff(c0$ccrS), eff(c0$ccrT), eff(c0$ccrST), eff(fdhS)))
cat(sprintf("medias BCC: S %.3f T %.3f ST %.3f | CCR: S %.3f T %.3f ST %.3f\n", mean(c0$bccS), mean(c0$bccT), mean(c0$bccST), mean(c0$ccrS), mean(c0$ccrT), mean(c0$ccrST)))
cat(sprintf("17 zeros, BCC: S media %.3f (%.1f%% efic.) | T %.3f (%.1f%%) | ST %.3f (%.1f%%)  [v2 secao 2 reporta 0,993 e 88,2%%]\n",
    mean(c0$bccS[d$zero_inv]), eff(c0$bccS[d$zero_inv]), mean(c0$bccT[d$zero_inv]), eff(c0$bccT[d$zero_inv]), mean(c0$bccST[d$zero_inv]), eff(c0$bccST[d$zero_inv])))
cat(sprintf("nao-zeros, BCC eficientes: S %.1f%% | T %.1f%% | ST %.1f%%\n", eff(c0$bccS[!d$zero_inv]), eff(c0$bccT[!d$zero_inv]), eff(c0$bccST[!d$zero_inv])))
cat("sensibilidade CCR dos 17 zeros ao shift (v2 secao 2 reporta 0,791/58,8 - 0,585/23,5 - 0,319/5,9, que sao os valores de ST):\n")
print(as.data.frame(bind_rows(res) %>% mutate(zero = rep(d$zero_inv, 3)) %>% filter(zero) %>% group_by(shift_USDbi = sh) %>%
  summarise(S_media = round(mean(ccrS), 3), S_efic = round(eff(ccrS), 1), T_media = round(mean(ccrT), 3), T_efic = round(eff(ccrT), 1),
            ST_media = round(mean(ccrST), 3), ST_efic = round(eff(ccrST), 1))))
cat("Spearman CCR_ST entre shift 1mi e 100mi (todas as obs):", sp(res[["0.001"]]$ccrST, res[["0.1"]]$ccrST), "\n")
cat("Spearman(BCC_S, BCC_T) =", sp(c0$bccS, c0$bccT), "[v2: 0,246] | Spearman(CCR_S, CCR_T) =", sp(c0$ccrS, c0$ccrT), "\n")
cat("eficientes por ano:\n")
print(as.data.frame(d %>% mutate(f = fdhS >= 1 - 1e-6, bS = c0$bccS >= 1 - 1e-6, cS = c0$ccrS >= 1 - 1e-6, bT = c0$bccT >= 1 - 1e-6, cT = c0$ccrT >= 1 - 1e-6, mS = c0$bccS) %>%
  group_by(Year) %>% summarise(n = n(), FDH_S = sum(f), BCC_S = sum(bS), CCR_S = sum(cS), BCC_T = sum(bT), CCR_T = sum(cT), media_BCC_S = round(mean(mS), 2))))
gap_obs <- c0$bccT - c0$bccS
g <- d %>% mutate(S = c0$bccS, T = c0$bccT, gap = gap_obs) %>% group_by(Country) %>%
  summarise(n = n(), S = mean(S), T = mean(T), gap = mean(gap), log_pop = log(mean(pop_mi)), log_PIBpc = log(mean(GDP.per.capita))) %>% arrange(gap)
cat("gap medio por pais (BCC_T - BCC_S), da v2:\n"); print(as.data.frame(g %>% mutate(across(where(is.double), ~ round(.x, 2)))))
cat(sprintf("cor(gap, log pop): pais %.2f, obs %.2f | cor(gap, log PIBpc): pais %.2f, obs %.2f | Spearman(gap obs, High_Tech_Export) = %.3f [v2: 0,14]\n",
    cor(g$gap, g$log_pop), cor(gap_obs, log(d$pop_mi)), cor(g$gap, g$log_PIBpc), cor(gap_obs, log(d$GDP.per.capita)), cor(gap_obs, d$High_Tech_Export_Percentage, method = "spearman")))
m <- lm(gap ~ log_pop + log_PIBpc, data = g); cat("regressao gap_pais ~ log pop + log PIBpc:\n"); print(round(summary(m)$coefficients, 3)); cat("R2 =", round(summary(m)$r.squared, 3), "\n")
cat("Kruskal-Wallis do gap: por renda p =", signif(kruskal.test(gap_obs ~ d$income)$p.value, 2), "| por regiao p =", signif(kruskal.test(gap_obs ~ d$GeogLoc)$p.value, 2), "\n")
cat("eficientes em T na media dos anos (> 0,99):", paste(g$Country[g$T > 0.99], collapse = ", "), "| em S:", paste(g$Country[g$S > 0.99], collapse = ", "), "\n")

# =============================================================================
sec("3. Especificacoes com unidades consistentes (BCC anual)")
alt <- function(X, YS_, YT_, label) {
  S <- run_spec(d, X, YS_, "vrs"); T <- run_spec(d, X, YT_, "vrs")
  gg <- d %>% mutate(S = S, T = T, gap = T - S) %>% group_by(Country) %>%
    summarise(S = mean(S), T = mean(T), gap = mean(gap), log_pop = log(mean(pop_mi)), log_PIBpc = log(mean(GDP.per.capita))) %>% arrange(gap)
  cat(sprintf("[%s]\n  Spearman(S,T) = %.3f | efic. S %.0f%% T %.0f%% | medias S %.2f T %.2f | cor(gap, log pop) pais %.2f obs %.2f | cor(gap, log PIBpc) pais %.2f\n",
      label, cor(S, T, method = "spearman"), eff(S), eff(T), mean(S), mean(T), cor(gg$gap, gg$log_pop), cor(T - S, log(d$pop_mi)), cor(gg$gap, gg$log_PIBpc)))
  cat("  S>>T:", paste(head(gg$Country, 6), round(head(gg$gap, 6), 2), collapse = ", "), "\n  T>>S:", paste(rev(tail(gg$Country, 6)), round(rev(tail(gg$gap, 6)), 2), collapse = ", "), "\n  ")
  for (cc in c("Brazil", "India", "Luxembourg", "Singapore", "United States", "China", "Spain", "Poland", "Italy")) cat(cc, round(gg$gap[gg$Country == cc], 2), "| "); cat("\n")
  invisible(list(S = S, T = T, g = gg))
}
a1 <- alt(cbind(d$inv_pc + 0.01, d$R.D_Percentage), cbind(d$pubs_pm), YT, "INTENSIVA: inv per capita, P&D% -> pubs/mi, patentes/mi")
a2 <- alt(cbind(d$inv_bi + 0.01, d$rd_usd_bi), YS, cbind(d$pat_cnt), "EXTENSIVA: inv US$, P&D US$ -> pubs (contagem), patentes (contagem)")
og <- order(g$Country)
cat("Spearman dos escores S: v2~intensiva", sp(c0$bccS, a1$S), "| v2~extensiva", sp(c0$bccS, a2$S), "| intensiva~extensiva", sp(a1$S, a2$S), "\n")
cat("Spearman dos escores T: v2~intensiva", sp(c0$bccT, a1$T), "| v2~extensiva", sp(c0$bccT, a2$T), "| intensiva~extensiva", sp(a1$T, a2$T), "\n")
cat("Spearman do gap por pais: v2~intensiva", sp(g$gap[og], a1$g$gap[order(a1$g$Country)]), "| v2~extensiva", sp(g$gap[og], a2$g$gap[order(a2$g$Country)]),
    "| intensiva~extensiva", sp(a1$g$gap[order(a1$g$Country)], a2$g$gap[order(a2$g$Country)]), "\n")

# =============================================================================
sec("4. Modelo de conversao: pesquisa -> patente (BCC anual)")
conv  <- run_spec(d, cbind(d$AI.Publications, d$inv_bi + 0.01, d$rd_usd_bi), cbind(d$pat_cnt), "vrs")       # extensivo
conv2 <- run_spec(d, cbind(d$pubs_pm, d$inv_pc + 0.01, d$R.D_Percentage), YT, "vrs")                        # per capita
gc <- d %>% mutate(conv = conv, conv2 = conv2) %>% group_by(Country) %>% summarise(conv = mean(conv), conv2 = mean(conv2), hte = mean(High_Tech_Export_Percentage)) %>% arrange(desc(conv))
cat("extensivo (pubs, inv US$, P&D US$ -> patentes contagem):\n ", paste(gc$Country, round(gc$conv, 2), collapse = ", "), "\n")
cat("Brasil e", which(gc$Country == "Brazil"), "o de 37 | efic.", round(eff(conv)), "% | Spearman(conv, gap v2) =", sp(gc$conv[order(gc$Country)], g$gap[og]),
    "| cor(conv, High_Tech_Export) =", round(cor(gc$conv, gc$hte), 2), "\n")
gc2 <- gc %>% arrange(desc(conv2))
cat("per capita (pubs/mi, inv pc, P&D% -> patentes/mi): top", paste(head(gc2$Country, 6), round(head(gc2$conv2, 6), 2), collapse = ", "),
    "\n  piores:", paste(tail(gc2$Country, 6), round(tail(gc2$conv2, 6), 2), collapse = ", "), "| Brasil", round(gc2$conv2[gc2$Country == "Brazil"], 2), "\n")

# =============================================================================
sec("5. Fronteira agrupada (208 DMUs, template da aula) vs fronteiras anuais, espec. v2")
X <- cbind(d$inv_bi + 0.01, d$R.D_Percentage)
pS <- run_spec(d, X, YS, "vrs", FALSE); pT <- run_spec(d, X, YT, "vrs", FALSE); pST <- run_spec(d, X, YST, "vrs", FALSE); pSc <- run_spec(d, X, YS, "crs", FALSE)
cat(sprintf("agrupada BCC efic.: S %.1f%% T %.1f%% ST %.1f%% | CCR_S %.1f%% | medias S %.2f T %.2f | Spearman(agrupada, anual): S %.3f T %.3f | Spearman(S,T) agrupada %.3f\n",
    eff(pS), eff(pT), eff(pST), eff(pSc), mean(pS), mean(pT), cor(pS, c0$bccS, method = "spearman"), cor(pT, c0$bccT, method = "spearman"), cor(pS, pT, method = "spearman")))
cat("eficientes agrupada S:", paste(d$Country_Year[pS >= 1 - 1e-6], collapse = ", "), "\neficientes agrupada T:", paste(d$Country_Year[pT >= 1 - 1e-6], collapse = ", "), "\n")
cat("media por ano, agrupada: S", paste(round(tapply(pS, d$Year, mean), 2), collapse = " "), "| T", paste(round(tapply(pT, d$Year, mean), 2), collapse = " "), "\n")
cat("media por ano, anual:    S", paste(round(tapply(c0$bccS, d$Year, mean), 2), collapse = " "), "| T", paste(round(tapply(c0$bccT, d$Year, mean), 2), collapse = " "), "\n")

# =============================================================================
sec("6. Supereficiencia (Andersen-Petersen, CRS, anual): outliers que definem a fronteira")
supef <- function(Xall, Yall) { s <- rep(NA_real_, nrow(d))
  for (yr in unique(d$Year)) { i <- which(d$Year == yr)
    for (o in i) { r <- setdiff(i, o); s[o] <- 1 / dea_eval_crs(Xall[r, , drop = FALSE], Yall[r, , drop = FALSE], Xall[o, ], Yall[o, ]) } }
  s }   # > 1 = supereficiente (quanto o produto poderia cair mantendo-se eficiente)
sT <- supef(X, YT); sST <- supef(X, YST)
top <- d %>% mutate(sT = sT, sST = sST) %>% arrange(desc(sST)) %>% slice(1:8) %>% transmute(Country_Year, super_T = round(sT, 1), super_ST = round(sST, 1))
print(as.data.frame(top))

# =============================================================================
sec("7. Malmquist CRS adjacente sem painel balanceado (modelo S: publicacoes)")
pairs <- d %>% group_by(Country) %>% arrange(Year) %>% mutate(prev = lag(Year), i_prev = lag(row_number())) %>% ungroup() %>%
  mutate(row = row_number()) %>% filter(!is.na(prev), Year - prev == 1)
Xs <- X; Ys <- YS
mq <- pmap_dfr(list(pairs$Country, pairs$Year, pairs$row), function(cty, yr, r1) {
  r0 <- which(d$Country == cty & d$Year == yr - 1); i0 <- which(d$Year == yr - 1); i1 <- which(d$Year == yr)
  D <- function(ref, pt) 1 / dea_eval_crs(Xs[ref, , drop = FALSE], Ys[ref, , drop = FALSE], Xs[pt, ], Ys[pt, ])   # distancia de Shephard (produto)
  d00 <- D(i0, r0); d11 <- D(i1, r1); d01 <- D(i0, r1); d10 <- D(i1, r0)
  tibble(Country = cty, Year = yr, EC = d11 / d00, TC = sqrt((d01 / d11) * (d00 / d10)), M = EC * sqrt((d01 / d11) * (d00 / d10)))
})
gm <- function(v) exp(mean(log(v)))
cat("pares pais-ano:", nrow(mq), "| media geometrica: M =", round(gm(mq$M), 3), "EC (catch-up) =", round(gm(mq$EC), 3), "TC (deslocamento) =", round(gm(mq$TC), 3), "\n")
print(as.data.frame(mq %>% group_by(Year) %>% summarise(n = n(), M = round(gm(M), 3), EC = round(gm(EC), 3), TC = round(gm(TC), 3))))

# =============================================================================
sec("8. Truncamento a direita das patentes e tendencias temporais")
ratio_tab <- function(v) d %>% mutate(v = {{ v }}) %>% group_by(Country) %>% arrange(Year) %>% mutate(r = v / lag(v), prev = lag(Year)) %>% ungroup() %>%
  filter(!is.na(r), Year - prev == 1) %>% group_by(Year) %>% summarise(n = n(), razao_mediana = round(median(r), 2), pct_queda = round(100 * mean(r < 1)))
cat("patentes por milhao, razao ano/ano anterior:\n"); print(as.data.frame(ratio_tab(AI.Patent.Applications)))
cat("publicacoes, mesma razao:\n"); print(as.data.frame(ratio_tab(AI.Publications)))
q21 <- d %>% group_by(Country) %>% arrange(Year) %>% mutate(r = AI.Patent.Applications / lag(AI.Patent.Applications), prev = lag(Year)) %>% ungroup() %>% filter(Year == 2021, prev == 2020, r < 1)
cat("quedas em 2021:", paste(q21$Country, round(q21$r, 2), collapse = ", "), "\n")
print(as.data.frame(d %>% group_by(Year) %>% summarise(n = n(), med_pubs = median(AI.Publications), med_pat_pm = round(median(AI.Patent.Applications), 2),
                                                        med_inv_musd = round(median(AI.Investment) / 1e6, 1), med_PD_pct = round(median(R.D_Percentage), 2), zeros = sum(zero_inv))))
print(as.data.frame(d %>% filter(Country %in% c("Luxembourg", "Singapore", "United States", "China", "Japan", "Brazil")) %>%
  transmute(Country, Year, v = round(AI.Patent.Applications, 1)) %>% pivot_wider(names_from = Year, values_from = v)))

# =============================================================================
sec("9. Segundo estagio: regressao do gap (v2, sem WDI), colinearidade, variancia entre paises, anos_desde_1o_inv, defasagens")
d2 <- d %>% group_by(Country) %>% mutate(anos_desde_1o_inv = ifelse(any(AI.Investment > 0), Year - min(Year[AI.Investment > 0]), NA_real_),
                                          primeiro_pos_e_primeiro_obs = any(AI.Investment > 0) && min(Year[AI.Investment > 0]) == min(Year)) %>% ungroup() %>%
  mutate(gap = gap_obs, lgdppc = log(GDP.per.capita))
cat("anos_desde_1o_inv: em", sum(distinct(d2, Country, primeiro_pos_e_primeiro_obs)$primeiro_pos_e_primeiro_obs), "de",
    n_distinct(d2$Country[!is.na(d2$anos_desde_1o_inv)]), "paises com investimento positivo o 1o ano positivo e o 1o ano observado (mede 'anos na amostra')\n")
mv2 <- lm(gap ~ High_Tech_Export_Percentage + Corruption_Estimate + Government_Effectiveness + Z_Score + Non.performing.Loans + lgdppc +
            Trade_Percentage + zero_inv + anos_desde_1o_inv + income + factor(Year), data = d2)
cat("regressao do gap da v2 (sem manuf_pib): n =", nobs(mv2), "| parametros =", length(coef(mv2)), "| R2 =", round(summary(mv2)$r.squared, 3), "\n")
ct <- coeftest(mv2, vcov = vcovCL(mv2, cluster = d2$Country[!is.na(d2$anos_desde_1o_inv)]))
print(round(ct[!grepl("factor\\(Year\\)|Intercept", rownames(ct)), ], 3))
vif <- function(m) { Xm <- model.matrix(m)[, -1]; sapply(colnames(Xm), function(v) 1 / (1 - summary(lm(Xm[, v] ~ Xm[, colnames(Xm) != v]))$r.squared)) }
v <- vif(mv2); cat("VIF (maiores):", paste(names(sort(v, decreasing = TRUE))[1:4], round(sort(v, decreasing = TRUE)[1:4], 1), collapse = ", "), "\n")
bt <- sapply(c("Corruption_Estimate", "Government_Effectiveness", "Z_Score", "Domestic_Credit", "MarketCap", "Trade_Percentage", "High_Tech_Export_Percentage", "R.D_Percentage"),
             function(v) round(100 * summary(lm(d[[v]] ~ factor(d$Country)))$r.squared))
cat("% da variancia entre paises (R2 de dummies de pais):", paste(names(bt), bt, sep = "=", collapse = " "), "\n")
lagd <- d %>% group_by(Country) %>% arrange(Year) %>% mutate(inv_l1 = lag(AI.Investment), pubs_l1 = lag(AI.Publications), prev = lag(Year)) %>% ungroup() %>% filter(!is.na(prev), Year - prev == 1)
cat(sprintf("defasagem: cor(log1p inv_t, log pubs_t) = %.2f | cor(log1p inv_t-1, log pubs_t) = %.2f | cor das variacoes dentro do pais = %.2f | pares = %d\n",
    cor(log1p(lagd$AI.Investment), log(lagd$AI.Publications)), cor(log1p(lagd$inv_l1), log(lagd$AI.Publications)),
    cor(log1p(lagd$AI.Investment) - log1p(lagd$inv_l1), log(lagd$AI.Publications) - log(lagd$pubs_l1)), nrow(lagd)))

# =============================================================================
sec("10. Checagens da v1: achado (7) e tabela (8)")
d18 <- d %>% filter(Year == 2018)
s <- 1 / dea_out(cbind(d18$AI.Investment + 1e6, d18$rd_usd_bi), cbind(d18$AI.Publications, d18$AI.Patent.Applications, d18$High_Tech_Export_Percentage), "crs"); o <- order(s)
cat("v1 (7) espec. ingenua 2018 CCR: eficientes =", paste(d18$Country[s >= 1 - 1e-6], collapse = ", "), "| piores =", paste(d18$Country[o][1:3], round(s[o][1:3], 3), collapse = ", "), "\n")
Xi <- cbind(d$inv_int + 1e-3, d$R.D_Percentage); Yi <- cbind(d$pubs_pm, d$AI.Patent.Applications, d$High_Tech_Export_Percentage)
cc <- run_spec(d, Xi, Yi, "crs"); bb <- run_spec(d, Xi, Yi, "vrs")
cat("v1 (8) espec. intensiva, eficientes por ano: CCR", paste(tapply(cc >= 1 - 1e-6, d$Year, sum), collapse = "/"), "(v1: 3 a 6) | BCC",
    paste(tapply(bb >= 1 - 1e-6, d$Year, sum), collapse = "/"), "(v1: 10 a 16) | BCC 2021:", round(eff(bb[d$Year == 2021])), "% (v1: 75%)\n")

# =============================================================================
out <- d %>% transmute(Country_Year, Country, Year, zero_inv, pop_mi = round(pop_mi, 3),
                       v2_bcc_S = c0$bccS, v2_bcc_T = c0$bccT, v2_bcc_ST = c0$bccST, v2_ccr_S = c0$ccrS, v2_ccr_T = c0$ccrT, v2_gap = gap_obs,
                       intensiva_S = a1$S, intensiva_T = a1$T, extensiva_S = a2$S, extensiva_T = a2$T,
                       conversao_ext = conv, conversao_pc = conv2, agrupada_S = pS, agrupada_T = pT, super_crs_T = sT, super_crs_ST = sST)
write_csv(out %>% mutate(across(where(is.double), ~ round(.x, 4))), "resultados/analise_critica_scores.csv")
cat("\nEscores gravados em analise_critica_scores.csv (", nrow(out), "linhas ).\n")
