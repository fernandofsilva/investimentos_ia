#!/usr/bin/env Rscript
#
# pipeline_v3.R
#
# Autor: Fernando Silva (fernando.silva@grancursosonline.com.br)
#
# Proposta v3 do trabalho da disciplina "Introdução à Análise de Eficiência
# em R": mede a eficiência dos países na conversão de investimento em
# inteligência artificial em produção científica (publicações) e tecnológica
# (patentes). Replica o template da disciplina (lesson1.4, lesson1.5,
# lesson2.3, lesson3.7 e Lecture 04) sobre a base AI_INVESTMENT.csv, com
# unidades consistentes e fronteira agrupada.
#
# Entradas:
#   dados/AI_INVESTMENT.csv       base principal, 208 país-ano
#   dados/wdi_contextuais.csv     contextuais do World Bank (WDI)
#   dados/wgi.voice_accountability.csv  Voice & Accountability (WGI)
#
# Saídas:
#   resultados/base_v3.csv        base tratada
#   resultados/t01..t19*.csv      tabelas numeradas
#   resultados/resumo_v3.txt      log com os números citados no relatório
#   resultados/log_erros.txt      blocos que falharam, se houver
#   resultados/figuras/fig*.png   figuras
#
# Uso:
#   Rscript scripts/pipeline_v3.R                # exploração, bootstraps curtos
#   RAPIDO=FALSE Rscript scripts/pipeline_v3.R   # valores finais
# O script localiza a raiz do repositório sozinho; pode ser chamado de
# qualquer subpasta.

suppressPackageStartupMessages({
  library(tidyverse)
  library(Benchmarking)
  library(rDEA)
  library(nonparaeff)
  library(poLCA)
  library(censReg)
  library(topsis)
  library(sandwich)
  library(lmtest)
})

# MASS (via poLCA) e gdata (via nonparaeff) mascaram verbos do dplyr, e o
# rDEA exporta um dea() diferente do usado no template. Os apelidos abaixo
# restauram as funções originais; eles fogem da convenção FunctionName
# porque precisam manter exatamente o nome da função que substituem.
select <- dplyr::select
filter <- dplyr::filter
lag <- dplyr::lag
recode <- dplyr::recode
count <- dplyr::count
summarise <- dplyr::summarise
dea <- Benchmarking::dea

# Constantes ------------------------------------------------------------

kRapido <- !identical(Sys.getenv("RAPIDO"), "FALSE")
kBootB <- if (kRapido) 500 else 2000  # réplicas de rDEA::dea.robust
kEnvL1 <- if (kRapido) 50 else 100    # laço 1 de rDEA::dea.env.robust
kEnvL2 <- if (kRapido) 500 else 2000  # laço 2 de rDEA::dea.env.robust
kShiftUsd <- 0.5e6                    # metade do menor investimento positivo
kAnoBase <- 2013                      # origem da tendência temporal
kTolEfic <- 1e-6                      # tolerância para "escore igual a 1"
kDirResultados <- "resultados"
kDirFiguras <- file.path("resultados", "figuras")
kArquivoLog <- file.path(kDirResultados, "log_erros.txt")

# Países com patentes de IA quase nulas na base, que depositam via EPO/PCT.
kPaisesEpo <- c("Switzerland", "Netherlands", "Belgium", "Ireland", "Norway",
                "Israel", "France", "Austria", "United Kingdom", "Portugal",
                "Italy", "Spain", "Greece")

# Blocos usados na análise de fusões (consórcios regionais de P&D em IA).
kBlocosRegionais <- list(
  "Mercosul" = c("Argentina", "Brazil"),
  "Aliança do Pacífico" = c("Chile", "Colombia", "Mexico", "Peru"),
  "Benelux" = c("Belgium", "Netherlands", "Luxembourg"),
  "Ibéria" = c("Spain", "Portugal"),
  "Visegrád" = c("Hungary", "Poland"),
  "ASEAN" = c("Indonesia", "Malaysia", "Philippines", "Singapore"),
  "Leste UE" = c("Bulgaria", "Croatia", "Romania", "Slovenia"))

# Funções ---------------------------------------------------------------

Nota <- function(...) {
  # Imprime uma linha no console e a guarda no resumo da execução.
  #
  # Args:
  #   ...: pedaços de texto, colados com paste0().
  #
  # Returns:
  #   Nada. Acrescenta a linha ao vetor 'resumo' do ambiente global.
  linha <- paste0(...)
  cat(linha, "\n")
  resumo <<- c(resumo, linha)
}

Bloco <- function(nome, expr) {
  # Executa um trecho da análise isolando falhas.
  #
  # A expressão é avaliada preguiçosamente, no ambiente de quem chamou, de
  # modo que atribuições feitas dentro dela valem para o script inteiro.
  #
  # Args:
  #   nome: identificador curto do trecho, usado na mensagem de erro.
  #   expr: expressão a avaliar.
  #
  # Returns:
  #   O valor de expr, ou NULL se ela lançar erro. Nesse caso a mensagem vai
  #   para o console e para resultados/log_erros.txt.
  tryCatch(expr, error = function(e) {
    mensagem <- paste0("[ERRO ", nome, "] ", conditionMessage(e))
    message(mensagem)
    cat(mensagem, "\n", file = kArquivoLog, append = TRUE)
    NULL
  })
}

Salva <- function(x, nome) {
  # Grava uma tabela de resultados em resultados/<nome>.csv.
  #
  # Args:
  #   x: data frame ou tibble.
  #   nome: nome do arquivo, sem extensão.
  #
  # Returns:
  #   Nada; grava o arquivo.
  write_csv(as.data.frame(x), file.path(kDirResultados, paste0(nome, ".csv")))
}

Escore <- function(modelo) {
  # Converte a saída do pacote Benchmarking em escore de eficiência.
  #
  # Args:
  #   modelo: objeto devolvido por Benchmarking::dea().
  #
  # Returns:
  #   Vetor numérico em (0, 1], como no template da disciplina (1 / eff).
  pmin(1 / eff(modelo), 1)
}

PctEficientes <- function(escores) {
  # Percentual de DMUs sobre a fronteira.
  #
  # Args:
  #   escores: vetor de escores em (0, 1].
  #
  # Returns:
  #   Percentual (0 a 100) de escores iguais a 1, dentro de kTolEfic.
  100 * mean(escores >= 1 - kTolEfic, na.rm = TRUE)
}

Spearman <- function(a, b) {
  # Correlação de postos entre dois vetores, ignorando pares incompletos.
  #
  # Args:
  #   a: vetor numérico.
  #   b: vetor numérico do mesmo comprimento.
  #
  # Returns:
  #   Coeficiente de correlação de Spearman.
  cor(a, b, method = "spearman", use = "complete.obs")
}

MediaGeometrica <- function(v) {
  # Média geométrica dos valores finitos e positivos.
  #
  # Args:
  #   v: vetor numérico (índices de Malmquist).
  #
  # Returns:
  #   Média geométrica, escalar.
  exp(mean(log(v[is.finite(v) & v > 0])))
}

PreencheSerie <- function(valores, anos) {
  # Interpola e extrapola uma série anual dentro de um país.
  #
  # Args:
  #   valores: vetor numérico com possíveis NA.
  #   anos: vetor de anos, do mesmo comprimento de valores.
  #
  # Returns:
  #   Vetor sem NA quando há ao menos uma observação, e o próprio vetor
  #   quando não há nenhuma. As pontas repetem o valor extremo (rule = 2).
  observado <- !is.na(valores)
  if (sum(observado) == 0) {
    return(valores)
  }
  if (sum(observado) == 1) {
    return(ifelse(observado, valores, valores[observado]))
  }
  approx(anos[observado], valores[observado], xout = anos, rule = 2)$y
}

Decis <- function(x) {
  # Discretiza um vetor em decis, como no template de classes latentes.
  #
  # Args:
  #   x: vetor numérico.
  #
  # Returns:
  #   Vetor inteiro de 1 a 10 (menos categorias se houver quantis repetidos).
  cortes <- unique(quantile(x, 0:10 / 10))
  as.integer(cut(x, cortes, include.lowest = TRUE, labels = FALSE))
}

CoefOuNa <- function(estimativas, variavel, coluna) {
  # Lê um coeficiente de uma tabela de estimativas, tolerando ausência.
  #
  # Args:
  #   estimativas: matriz com variáveis nas linhas (saída de summary()).
  #   variavel: nome da linha procurada.
  #   coluna: índice da coluna (1 = coeficiente, 4 = valor p).
  #
  # Returns:
  #   O valor pedido, ou NA_real_ quando a variável não está no modelo.
  if (variavel %in% rownames(estimativas)) {
    estimativas[variavel, coluna]
  } else {
    NA_real_
  }
}

RodaFronteiras <- function(x, y) {
  # Estima FDH, CCR e BCC orientados a produto sobre a mesma amostra.
  #
  # Args:
  #   x: matriz de insumos, DMUs nas linhas.
  #   y: matriz de produtos, DMUs nas linhas.
  #
  # Returns:
  #   Lista com os elementos fdh, crs e vrs; o modelo vrs traz as folgas.
  list(fdh = dea(x, y, RTS = "fdh", ORIENTATION = "out"),
       crs = dea(x, y, RTS = "crs", ORIENTATION = "out"),
       vrs = dea(x, y, RTS = "vrs", ORIENTATION = "out", SLACK = TRUE))
}

OrderAlpha <- function(x, y, alpha) {
  # Fronteira parcial order-alpha orientada a produto, com um produto.
  #
  # Args:
  #   x: matriz de insumos.
  #   y: vetor do produto.
  #   alpha: quantil da fronteira parcial, entre 0 e 1.
  #
  # Returns:
  #   Vetor com o escore de cada DMU; 1 marca a fronteira parcial.
  sapply(seq_len(nrow(x)), function(o) {
    dominantes <- which(apply(x, 1, function(xi) {
      all(xi <= x[o, ] * (1 + 1e-9))
    }))
    as.numeric(quantile(y[dominantes] / y[o], alpha))
  })
}

AmostraNormalTruncada <- function(media, desvio) {
  # Sorteia de uma normal truncada à esquerda em zero.
  #
  # Args:
  #   media: vetor de médias da normal não truncada.
  #   desvio: desvio-padrão, escalar.
  #
  # Returns:
  #   Vetor do mesmo comprimento de media, com valores não negativos.
  u <- runif(length(media))
  limite <- pnorm(-media / desvio)
  media + desvio * qnorm(limite + u * (1 - limite))
}

AjustaTruncada <- function(y, z) {
  # Regressão truncada de y sobre as contextuais, com truncatura em zero.
  #
  # Args:
  #   y: vetor resposta, truncado à esquerda em zero.
  #   z: matriz de variáveis contextuais.
  #
  # Returns:
  #   Objeto truncreg ajustado sobre as observações com y positivo.
  dados.ajuste <- data.frame(y = y, z)
  truncreg::truncreg(y ~ ., data = dados.ajuste[y > 1e-9, ], point = 0,
                     direction = "left")
}

SimarWilsonLog <- function(x, y, z, l1 = 50, l2 = 500, alpha = 0.05) {
  # Algoritmo 2 de Simar-Wilson com regressão truncada em log(delta).
  #
  # A versão linear em delta (rDEA::dea.env.robust) fica instável quando
  # delta tem cauda pesada, o que ocorre nos modelos T e C desta base
  # (mediana perto de 20 e máximo acima de 700). Em log a truncatura fica
  # em zero e a normal truncada volta a ser uma aproximação razoável.
  #
  # Args:
  #   x: matriz de insumos.
  #   y: matriz de produtos.
  #   z: data frame de variáveis contextuais.
  #   l1: réplicas do laço de correção de viés.
  #   l2: réplicas do bootstrap dos coeficientes.
  #   alpha: nível do intervalo de confiança.
  #
  # Returns:
  #   Lista com beta (coeficientes), ci (intervalos), sigma, delta
  #   (distâncias originais), delta.bc (corrigidas de viés) e n.boot.ok
  #   (réplicas do bootstrap que convergiram).
  z <- as.matrix(z)
  n.dmu <- nrow(x)
  n.z <- ncol(z)
  delta <- eff(dea(x, y, RTS = "vrs", ORIENTATION = "out"))

  ajuste1 <- AjustaTruncada(log(delta), z)
  beta1 <- coef(ajuste1)[1:(n.z + 1)]
  sigma1 <- coef(ajuste1)[["sigma"]]
  media1 <- as.numeric(cbind(1, z) %*% beta1)

  delta.star <- matrix(NA_real_, n.dmu, l1)
  for (b in seq_len(l1)) {
    y.star <- y * delta / exp(AmostraNormalTruncada(media1, sigma1))
    delta.star[, b] <- eff(dea(x, y, RTS = "vrs", ORIENTATION = "out",
                               XREF = x, YREF = y.star))
  }
  vies <- rowMeans(delta.star) - delta
  delta.bc <- pmax(delta - vies, 1 + 1e-6)

  ajuste2 <- AjustaTruncada(log(delta.bc), z)
  beta2 <- coef(ajuste2)[1:(n.z + 1)]
  sigma2 <- coef(ajuste2)[["sigma"]]
  media2 <- as.numeric(cbind(1, z) %*% beta2)

  betas <- matrix(NA_real_, l2, n.z + 1)
  colnames(betas) <- names(beta2)
  for (b in seq_len(l2)) {
    replica <- AmostraNormalTruncada(media2, sigma2)
    ajuste <- tryCatch(AjustaTruncada(replica, z), error = function(e) NULL)
    if (!is.null(ajuste)) {
      betas[b, ] <- coef(ajuste)[1:(n.z + 1)]
    }
  }
  intervalos <- t(apply(betas, 2, quantile, c(alpha / 2, 1 - alpha / 2),
                        na.rm = TRUE))
  list(beta = beta2, ci = intervalos, sigma = sigma2, delta = delta,
       delta.bc = delta.bc, n.boot.ok = sum(complete.cases(betas)))
}

ComparaCenario <- function(nome, linhas, escores.novos, escores.ref) {
  # Resume um cenário de robustez e o acumula na lista 'robustez'.
  #
  # Args:
  #   nome: identificador do cenário.
  #   linhas: índices de 'dados' cobertos pelo cenário.
  #   escores.novos: escores estimados no cenário.
  #   escores.ref: escores do modelo principal, vetor completo.
  #
  # Returns:
  #   Tibble de uma linha; também grava em 'robustez' no ambiente global.
  linha <- tibble(cenario = nome,
                  n = length(linhas),
                  efic_pct = PctEficientes(escores.novos),
                  media = mean(escores.novos),
                  spearman_vs_principal = Spearman(escores.novos,
                                                   escores.ref[linhas]))
  robustez[[nome]] <<- linha
  linha
}

LocalizaRaiz <- function() {
  # Sobe diretórios até encontrar a raiz do repositório.
  #
  # Args:
  #   nenhum.
  #
  # Returns:
  #   O caminho da pasta que contém dados/AI_INVESTMENT.csv. Interrompe com
  #   erro se não encontrar em até cinco níveis acima do diretório atual.
  pasta <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(pasta, "dados", "AI_INVESTMENT.csv"))) {
      return(pasta)
    }
    pasta <- dirname(pasta)
  }
  stop("Execute a partir do repositório investimentos_ia (raiz ou subpasta).")
}

# Execução --------------------------------------------------------------

setwd(LocalizaRaiz())
set.seed(1)
options(width = 160)
dir.create(kDirResultados, showWarnings = FALSE)
dir.create(kDirFiguras, showWarnings = FALSE)
if (file.exists(kArquivoLog)) {
  file.remove(kArquivoLog)
}
resumo <- character(0)
robustez <- list()
inicio.execucao <- Sys.time()

# 1. Dados: base + WDI, unidades consistentes ---------------------------

Nota("=== 1. Dados: base + WDI, unidades consistentes ===")
base.bruta <- read_csv("dados/AI_INVESTMENT.csv", show_col_types = FALSE)
wdi <- read_csv("dados/wdi_contextuais.csv", show_col_types = FALSE)
deflator.eua <- wdi %>%
  filter(Country == "United States") %>%
  transmute(Year, defl15 = deflator / deflator[Year == 2015])

dados <- base.bruta %>%
  mutate(income = str_to_lower(IncomeLevel) %>%
           str_replace_all("[-_]", " ") %>%
           str_squish(),
         income = recode(income,
                         "high income economy" = "Alta",
                         "upper middle income economy" = "Média-alta",
                         "lower middle income economy" = "Média-baixa"),
         regiao = str_replace_all(GeogLoc, "_", " "),
         pop_mi = GDP.constant / GDP.per.capita / 1e6,
         zero_inv = AI.Investment == 0) %>%
  left_join(deflator.eua, by = "Year") %>%
  left_join(select(wdi, Country, Year, manuf_pib, ind_pib, manuf_exp,
                   pesq_pm, rd_pct_wdi),
            by = c("Country", "Year")) %>%
  group_by(Country) %>%
  arrange(Year, .by_group = TRUE) %>%
  mutate(manuf_pib_na = is.na(manuf_pib),
         pesq_pm_na = is.na(pesq_pm),
         manuf_pib = PreencheSerie(manuf_pib, Year),
         pesq_pm = PreencheSerie(pesq_pm, Year)) %>%
  ungroup() %>%
  mutate(inv_const = AI.Investment / defl15,  # US$ constantes de 2015
         inv_usd = inv_const + kShiftUsd,     # insumo 1, forma extensiva
         rd_usd = R.D_Percentage / 100 * GDP.constant,  # insumo 2
         pubs = AI.Publications,              # produto científico
         pat = AI.Patent.Applications * pop_mi,  # produto tecnológico
         inv_pc = inv_usd / (pop_mi * 1e6),   # daqui em diante, intensiva
         rd_pct = R.D_Percentage,
         pubs_pm = AI.Publications / pop_mi,
         pat_pm = AI.Patent.Applications,
         gov = (as.numeric(scale(Corruption_Estimate)) +
                  as.numeric(scale(Government_Effectiveness))) / 2,
         ln_gdppc = log(GDP.per.capita),
         tend = Year - kAnoBase) %>%
  arrange(Country, Year)

# Voice & Accountability vem de arquivo baixado do site do WGI, porque a
# API do WDI não serve mais o indicador VA.EST.
wgi.voice <- read_csv("dados/wgi.voice_accountability.csv",
                      show_col_types = FALSE) %>%
  filter(indicator == "wgi.voice_accountability") %>%
  transmute(iso3, Year = as.integer(year), voice = value)
dados <- dados %>%
  mutate(iso3 = countrycode::countrycode(Country, "country.name", "iso3c")) %>%
  left_join(wgi.voice, by = c("iso3", "Year"))

Nota("Voice & Accountability (WGI, percentil): ", sum(!is.na(dados$voice)),
     " de ", nrow(dados), " obs | cor(voice, gov) = ",
     round(cor(dados$voice, dados$gov, use = "complete.obs"), 3))
Nota("n = ", nrow(dados), " país-ano | países = ",
     n_distinct(dados$Country), " | zeros de investimento = ",
     sum(dados$zero_inv))
Nota("cobertura WDI nas 208 obs: manuf_pib ", sum(!dados$manuf_pib_na),
     " originais + ", sum(dados$manuf_pib_na), " preenchidos | manuf_exp ",
     sum(!is.na(dados$manuf_exp)), " | pesq_pm ", sum(!dados$pesq_pm_na),
     " originais + ", sum(dados$pesq_pm_na), " preenchidos | rd_pct_wdi ",
     sum(!is.na(dados$rd_pct_wdi)))
Nota("sanidade: cor(R.D_Percentage da base, GB.XPD.RSDV.GD.ZS do WDI) = ",
     round(cor(dados$R.D_Percentage, dados$rd_pct_wdi,
               use = "complete.obs"), 3),
     " | deflator EUA 2013→2021: ",
     paste(round(deflator.eua$defl15, 3), collapse = " "))
fracao.pat <- dados$pat %% 1
Nota("patentes: contagem recuperada = AI.Patent.Applications × pop; ",
     round(100 * mean(pmin(fracao.pat, 1 - fracao.pat) < 0.02)),
     "% a <0,02 de um inteiro")
if (any(is.na(dados$manuf_pib))) {
  Nota("manuf_pib sem valor no WDI (ficam fora do 2º estágio): ",
       paste(dados$Country_Year[is.na(dados$manuf_pib)], collapse = ", "))
}
Salva(dados, "base_v3")

# 2. Descritivas (template lesson1.4) -----------------------------------

Nota("=== 2. Descritivas (template lesson1.4) ===")
vars.descritivas <- c("inv_const", "rd_usd", "pubs", "pat", "manuf_pib",
                      "manuf_exp", "gov", "voice", "GDP.per.capita",
                      "Trade_Percentage", "Z_Score")
descritivas <- dados %>%
  select(all_of(vars.descritivas)) %>%
  pivot_longer(everything()) %>%
  group_by(name) %>%
  summarise(n = sum(!is.na(value)),
            min = min(value, na.rm = TRUE),
            q25 = quantile(value, .25, na.rm = TRUE),
            mediana = median(value, na.rm = TRUE),
            media = mean(value, na.rm = TRUE),
            q75 = quantile(value, .75, na.rm = TRUE),
            max = max(value, na.rm = TRUE),
            .groups = "drop")
Salva(descritivas, "t01_descritivas")

Bloco("fig01", {
  figura <- dados %>%
    transmute(`log investimento (US$ 2015)` = log(inv_usd),
              `log P&D (US$)` = log(rd_usd),
              `log publicações` = log(pubs),
              `log patentes` = log(pat)) %>%
    pivot_longer(everything()) %>%
    ggplot(aes(value)) +
    geom_density(fill = "grey70") +
    facet_wrap(~name, scales = "free") +
    theme_bw() +
    labs(x = NULL, y = "densidade")
  ggsave(file.path(kDirFiguras, "fig01_descritivas.png"), figura, width = 8,
         height = 5, dpi = 150)
})

# 3. Núcleo: FDH, CCR, BCC e folgas na fronteira agrupada ---------------

Nota("=== 3. Núcleo: FDH, CCR, BCC, folgas — fronteira agrupada ",
     "(208 DMUs), forma extensiva ===")
x.extensivo <- as.matrix(dados[, c("inv_usd", "rd_usd")])
x.conversao <- as.matrix(dados[, c("pubs", "inv_usd", "rd_usd")])
y.ciencia <- as.matrix(dados[, "pubs", drop = FALSE])
y.tecnologia <- as.matrix(dados[, "pat", drop = FALSE])
y.ambos <- as.matrix(dados[, c("pubs", "pat")])

modelos <- list(S = RodaFronteiras(x.extensivo, y.ciencia),
                T = RodaFronteiras(x.extensivo, y.tecnologia),
                ST = RodaFronteiras(x.extensivo, y.ambos),
                C = RodaFronteiras(x.conversao, y.tecnologia))

escores <- dados %>%
  select(Country_Year, Country, Year, income, regiao, zero_inv, pop_mi,
         manuf_pib, manuf_exp)
for (k in names(modelos)) {
  escores[[paste0("fdh_", k)]] <- Escore(modelos[[k]]$fdh)
  escores[[paste0("ccr_", k)]] <- Escore(modelos[[k]]$crs)
  escores[[paste0("bcc_", k)]] <- Escore(modelos[[k]]$vrs)
}
escores <- escores %>%
  mutate(se_S = ifelse(zero_inv, NA, ccr_S / bcc_S),
         se_T = ifelse(zero_inv, NA, ccr_T / bcc_T),
         se_ST = ifelse(zero_inv, NA, ccr_ST / bcc_ST))

tab.nucleo <- map_dfr(names(modelos), function(k) {
  bcc <- escores[[paste0("bcc_", k)]]
  tibble(modelo = k,
         FDH_efic = PctEficientes(escores[[paste0("fdh_", k)]]),
         CCR_efic = PctEficientes(escores[[paste0("ccr_", k)]]),
         BCC_efic = PctEficientes(bcc),
         FDH_media = mean(escores[[paste0("fdh_", k)]]),
         CCR_media = mean(escores[[paste0("ccr_", k)]]),
         BCC_media = mean(bcc),
         BCC_zeros_efic = PctEficientes(bcc[escores$zero_inv]),
         BCC_naozeros_efic = PctEficientes(bcc[!escores$zero_inv]))
})
Salva(mutate(tab.nucleo, across(where(is.numeric), ~ round(.x, 3))),
      "t02_nucleo_resumo")
for (k in names(modelos)) {
  linha <- tab.nucleo[tab.nucleo$modelo == k, ]
  Nota(sprintf(paste0("%-2s | eficientes FDH %.1f%%  CCR %.1f%%  ",
                      "BCC %.1f%% | média BCC %.3f | zeros efic. BCC ",
                      "%.1f%% vs não-zeros %.1f%%"),
               k, linha$FDH_efic, linha$CCR_efic, linha$BCC_efic,
               linha$BCC_media, linha$BCC_zeros_efic,
               linha$BCC_naozeros_efic))
}
Nota("Spearman BCC: S×T ",
     round(Spearman(escores$bcc_S, escores$bcc_T), 3), " | S×C ",
     round(Spearman(escores$bcc_S, escores$bcc_C), 3), " | T×C ",
     round(Spearman(escores$bcc_T, escores$bcc_C), 3),
     " | SE(ST) média (sem zeros) ",
     round(mean(escores$se_ST, na.rm = TRUE), 3))
for (k in c("S", "T", "C")) {
  na.fronteira <- escores[[paste0("bcc_", k)]] >= 1 - kTolEfic
  Nota("BCC-eficientes ", k, ": ",
       paste(escores$Country_Year[na.fronteira], collapse = ", "))
}

medias.pais <- escores %>%
  group_by(Country) %>%
  summarise(n = n(),
            across(c(bcc_S, bcc_T, bcc_ST, bcc_C, ccr_ST, se_ST),
                   ~ mean(.x, na.rm = TRUE)),
            manuf_pib = mean(manuf_pib),
            .groups = "drop") %>%
  mutate(gap_TS = bcc_T - bcc_S) %>%
  arrange(desc(bcc_C))
Salva(mutate(medias.pais, across(where(is.numeric), ~ round(.x, 3))),
      "t03_medias_pais")
Nota("Conversão (C) por país, top 8: ",
     paste(head(medias.pais$Country, 8),
           round(head(medias.pais$bcc_C, 8), 2), collapse = ", "))
# A população precisa ser reordenada com match(), porque medias.pais está
# ordenada por bcc_C e o agregado por país sai em ordem alfabética.
pop.pais <- escores %>%
  group_by(Country) %>%
  summarise(pop_mi = mean(pop_mi), .groups = "drop")
log.pop.pais <- log(pop.pais$pop_mi[match(medias.pais$Country,
                                          pop.pais$Country)])
Nota("Conversão (C), Brasil: ",
     round(medias.pais$bcc_C[medias.pais$Country == "Brazil"], 3), " (",
     which(medias.pais$Country == "Brazil"), "º de 37)",
     " | cor(C, manuf_pib) por país = ",
     round(cor(medias.pais$bcc_C, medias.pais$manuf_pib,
               use = "complete.obs"), 3),
     " | cor(gap T−S, log pop) = ",
     round(cor(medias.pais$gap_TS, log.pop.pais), 3))
Salva(mutate(escores, across(where(is.numeric), ~ round(.x, 4))),
      "t04_escores_dmu")

Bloco("peers/folgas", {
  pares <- peers(modelos$ST$vrs)
  nomes.pares <- apply(pares, 1, function(linha) {
    paste(dados$Country_Year[linha[!is.na(linha)]], collapse = "; ")
  })
  contagem <- sort(table(dados$Country_Year[as.vector(pares)]),
                   decreasing = TRUE)
  Salva(tibble(DMU = dados$Country_Year, bcc_ST = escores$bcc_ST,
               peers = nomes.pares),
        "t05_peers_ST")
  Nota("benchmarks mais usados (BCC ST): ",
       paste(names(head(contagem, 6)), head(contagem, 6), collapse = ", "))
  folga.x <- modelos$ST$vrs$sx / x.extensivo
  folga.y <- modelos$ST$vrs$sy
  folgas <- tibble(DMU = dados$Country_Year,
                   folga_rel_inv = folga.x[, 1],
                   folga_rel_rd = folga.x[, 2],
                   folga_pubs = folga.y[, 1],
                   folga_pat = folga.y[, 2])
  Salva(mutate(folgas, across(where(is.numeric), ~ round(.x, 4))),
        "t06_folgas_ST")
  Nota(sprintf(paste0("folgas BCC ST: DMUs com folga em investimento ",
                      "%.0f%% (média rel. %.2f), em P&D %.0f%% ",
                      "(média rel. %.2f)"),
               100 * mean(folga.x[, 1] > kTolEfic), mean(folga.x[, 1]),
               100 * mean(folga.x[, 2] > kTolEfic), mean(folga.x[, 2])))
})

Bloco("fig02-04", {
  png(file.path(kDirFiguras, "fig02_fronteira_2d.png"), 900, 700, res = 130)
  par(mfrow = c(1, 2))
  inv.bi <- dados$inv_usd / 1e9
  dea.plot(inv.bi, dados$pubs, RTS = "fdh", ORIENTATION = "out",
           xlab = "Investimento em IA (US$ bi 2015)",
           ylab = "Publicações em IA", main = "1 insumo × 1 produto",
           lty = 1, lwd = 2, col = 1)
  dea.plot(inv.bi, dados$pubs, RTS = "crs", ORIENTATION = "out",
           add = TRUE, lty = 1, col = 3)
  dea.plot(inv.bi, dados$pubs, RTS = "vrs", ORIENTATION = "out",
           add = TRUE, lty = 1, col = 2)
  legend("bottomright", c("FDH", "CRS", "VRS"), pch = 15,
         col = c("black", "green", "red"))
  escore.1x1 <- Escore(dea(as.matrix(dados$inv_usd), as.matrix(dados$pubs),
                           RTS = "vrs", ORIENTATION = "out"))
  destaque <- which(escore.1x1 >= 1 - kTolEfic)
  plot(inv.bi, dados$pubs, log = "xy",
       xlab = "Investimento em IA (US$ bi 2015, log)",
       ylab = "Publicações em IA (log)",
       main = "eficientes VRS 1×1 em destaque", col = "grey50")
  points(inv.bi[destaque], dados$pubs[destaque], col = 2, pch = 19)
  text(inv.bi[destaque], dados$pubs[destaque],
       dados$Country_Year[destaque], pos = 4, cex = .6, col = 2)
  dev.off()

  longo <- escores %>%
    select(Country_Year, starts_with("fdh_"), starts_with("ccr_"),
           starts_with("bcc_")) %>%
    pivot_longer(-Country_Year, names_to = c("metodo", "modelo"),
                 names_sep = "_")
  fig03 <- longo %>%
    filter(metodo == "bcc") %>%
    ggplot(aes(value, colour = modelo)) +
    geom_density() +
    theme_bw() +
    labs(x = "escore BCC (1/eff)", y = "densidade", colour = "modelo")
  ggsave(file.path(kDirFiguras, "fig03_densidades_bcc.png"), fig03, width = 7,
         height = 4, dpi = 150)
  fig04 <- longo %>%
    mutate(metodo = toupper(metodo)) %>%
    ggplot(aes(metodo, value, fill = metodo)) +
    geom_boxplot() +
    facet_wrap(~modelo, nrow = 1) +
    theme_bw() +
    labs(x = NULL, y = "escore") +
    theme(legend.position = "none")
  ggsave(file.path(kDirFiguras, "fig04_boxplot_metodos.png"), fig04, width = 9,
         height = 4, dpi = 150)
})

# 4. Robustez da especificação ------------------------------------------

Nota("=== 4. Robustez da especificação (BCC, comparação com o núcleo ",
     "agrupado) ===")

Bloco("rob-intensiva", {
  x.intensivo <- as.matrix(dados[, c("inv_pc", "rd_pct")])
  y.pubs.pm <- as.matrix(dados[, "pubs_pm", drop = FALSE])
  y.pat.pm <- as.matrix(dados[, "pat_pm", drop = FALSE])
  escore.s <- Escore(dea(x.intensivo, y.pubs.pm, RTS = "vrs",
                         ORIENTATION = "out"))
  escore.t <- Escore(dea(x.intensivo, y.pat.pm, RTS = "vrs",
                         ORIENTATION = "out"))
  escore.c <- Escore(dea(as.matrix(dados[, c("pubs_pm", "inv_pc",
                                             "rd_pct")]),
                         y.pat.pm, RTS = "vrs", ORIENTATION = "out"))
  todas <- seq_len(nrow(dados))
  ComparaCenario("intensiva_S", todas, escore.s, escores$bcc_S)
  ComparaCenario("intensiva_T", todas, escore.t, escores$bcc_T)
  ComparaCenario("intensiva_C", todas, escore.c, escores$bcc_C)
  escores$bcc_S_int <- escore.s
  escores$bcc_T_int <- escore.t
  escores$bcc_C_int <- escore.c
  Nota("intensiva: eficientes BCC S ", round(PctEficientes(escore.s), 1),
       "% T ", round(PctEficientes(escore.t), 1), "% C ",
       round(PctEficientes(escore.c), 1),
       "% | eficientes em T intensiva: ",
       paste(dados$Country_Year[escore.t >= 1 - kTolEfic], collapse = ", "))
})

Bloco("rob-anual", {
  escore.anual <- rep(NA_real_, nrow(dados))
  for (ano in unique(dados$Year)) {
    linhas <- which(dados$Year == ano)
    escore.anual[linhas] <- Escore(dea(x.extensivo[linhas, ],
                                       y.ambos[linhas, ], RTS = "vrs",
                                       ORIENTATION = "out"))
  }
  ComparaCenario("anual_ST", seq_len(nrow(dados)), escore.anual,
                 escores$bcc_ST)
})

Bloco("rob-shift1mi", {
  x.shift <- x.extensivo
  x.shift[, 1] <- dados$inv_const + 1e6
  ComparaCenario("shift_1mi_ST", seq_len(nrow(dados)),
                 Escore(dea(x.shift, y.ambos, RTS = "vrs",
                            ORIENTATION = "out")),
                 escores$bcc_ST)
})

Bloco("rob-semzeros", {
  linhas <- which(!dados$zero_inv)
  ComparaCenario("sem_zeros_ST", linhas,
                 Escore(dea(x.extensivo[linhas, ], y.ambos[linhas, ],
                            RTS = "vrs", ORIENTATION = "out")),
                 escores$bcc_ST)
})

Bloco("rob-T2019", {
  linhas <- which(dados$Year <= 2019)
  ComparaCenario("T_ate_2019", linhas,
                 Escore(dea(x.extensivo[linhas, ],
                            y.tecnologia[linhas, , drop = FALSE],
                            RTS = "vrs", ORIENTATION = "out")),
                 escores$bcc_T)
})

Bloco("rob-semLUXSGP", {
  linhas <- which(!dados$Country %in% c("Luxembourg", "Singapore"))
  ComparaCenario("sem_LUX_SGP_ST", linhas,
                 Escore(dea(x.extensivo[linhas, ], y.ambos[linhas, ],
                            RTS = "vrs", ORIENTATION = "out")),
                 escores$bcc_ST)
})

Bloco("rob-lag", {
  defasado <- dados %>%
    group_by(Country) %>%
    mutate(inv_l1 = lag(inv_usd), rd_l1 = lag(rd_usd),
           ano_l1 = lag(Year)) %>%
    ungroup()
  linhas <- which(!is.na(defasado$ano_l1) &
                    defasado$Year - defasado$ano_l1 == 1)
  ComparaCenario("lag_t-1_ST", linhas,
                 Escore(dea(as.matrix(defasado[linhas,
                                               c("inv_l1", "rd_l1")]),
                            y.ambos[linhas, ], RTS = "vrs",
                            ORIENTATION = "out")),
                 escores$bcc_ST)
})

tab.robustez <- bind_rows(robustez) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))
Salva(tab.robustez, "t07_robustez")
print(as.data.frame(tab.robustez))
resumo <- c(resumo, capture.output(print(as.data.frame(tab.robustez))))

# 5. Outliers: supereficiência de Andersen-Petersen ---------------------

Nota("=== 5. Outliers: supereficiência de Andersen-Petersen (ST) ===")
Bloco("sdea", {
  super.vrs <- sdea(x.extensivo, y.ambos, RTS = "vrs", ORIENTATION = "out")
  super.crs <- sdea(x.extensivo, y.ambos, RTS = "crs", ORIENTATION = "out")
  supereficiencia <- tibble(DMU = dados$Country_Year,
                            super_VRS = 1 / eff(super.vrs),
                            super_CRS = 1 / eff(super.crs)) %>%
    arrange(desc(super_CRS))
  Salva(mutate(supereficiencia, across(where(is.numeric), ~ round(.x, 3))),
        "t08_supereficiencia_ST")
  Nota("supereficiência CRS (ST), top 6: ",
       paste(head(supereficiencia$DMU, 6),
             round(head(supereficiencia$super_CRS, 6), 2), collapse = ", "))
  Nota("VRS infactíveis (extremas): ",
       sum(!is.finite(supereficiencia$super_VRS) |
             is.na(supereficiencia$super_VRS)), " DMUs")
})

# 6. Bootstrap de Simar-Wilson ------------------------------------------

Nota("=== 6. Bootstrap de Simar-Wilson (rDEA::dea.robust, B = ", kBootB,
     ") ===")
bootstraps <- list()
for (k in c("S", "T", "C")) {
  Bloco(paste0("boot-", k), {
    x.modelo <- if (k == "C") x.conversao else x.extensivo
    y.modelo <- if (k == "S") y.ciencia else y.tecnologia
    boot.dea <- dea.robust(x.modelo, y.modelo, model = "output",
                           RTS = "variable", B = kBootB, alpha = 0.05)
    # O rDEA corrige o viés na escala theta (0, 1]; com cauda pesada o
    # resultado fica negativo, como já ocorre na Lecture 03. Refazemos a
    # correção na escala de Farrell (phi = 1 / theta), como em Simar &
    # Wilson (1998), usando as réplicas theta_hat_star.
    phi <- 1 / boot.dea$theta_hat
    phi.star <- 1 / boot.dea$theta_hat_star
    if (nrow(phi.star) != length(phi)) {
      phi.star <- t(phi.star)
    }
    diferenca <- phi.star - phi
    vies.phi <- rowMeans(diferenca)
    phi.bc <- phi - vies.phi
    quantis <- t(apply(diferenca, 1, quantile, c(.975, .025)))
    phi.inf <- pmax(phi - quantis[, 1], 1)
    phi.sup <- phi - quantis[, 2]
    bootstraps[[k]] <- tibble(DMU = dados$Country_Year,
                              original = escores[[paste0("bcc_", k)]],
                              rDEA_theta_bc = boot.dea$theta_hat_hat,
                              boot_bc = 1 / phi.bc,
                              ic_inf = 1 / phi.sup,
                              ic_sup = 1 / phi.inf,
                              vies_phi = vies.phi)
    Nota(sprintf(paste0("%s: escore original médio %.3f | corrigido de ",
                        "viés (escala phi) %.3f | rDEA na escala theta ",
                        "%.3f (%d negativos) | Spearman ",
                        "original×corrigido %.3f | largura média do IC ",
                        "%.3f"),
                 k, mean(bootstraps[[k]]$original),
                 mean(bootstraps[[k]]$boot_bc),
                 mean(boot.dea$theta_hat_hat),
                 sum(boot.dea$theta_hat_hat < 0),
                 Spearman(bootstraps[[k]]$original,
                          bootstraps[[k]]$boot_bc),
                 mean(bootstraps[[k]]$ic_sup - bootstraps[[k]]$ic_inf)))
  })
}

Bloco("fig05", {
  tab.boot <- bind_rows(bootstraps, .id = "modelo")
  Salva(mutate(tab.boot, across(where(is.numeric), ~ round(.x, 4))),
        "t09_bootstrap")
  figura <- tab.boot %>%
    pivot_longer(c(original, boot_bc)) %>%
    ggplot(aes(value, colour = name)) +
    geom_density() +
    facet_wrap(~modelo) +
    theme_bw() +
    labs(x = "escore", y = "densidade", colour = NULL)
  ggsave(file.path(kDirFiguras, "fig05_bootstrap.png"), figura, width = 9,
         height = 3.5, dpi = 150)
})

# 7. Fronteiras parciais: Order-m e Order-alpha -------------------------

Nota("=== 7. Fronteiras parciais: Order-m (nonparaeff::orderm) e ",
     "Order-alpha (implementação própria) ===")
order.m <- list()
for (m in c(25, 50, 100)) {
  Bloco(paste0("orderm-", m), {
    parcial <- orderm(data.frame(x.extensivo, y.ciencia), noutput = 1,
                      orientation = 2, M = m,
                      B = if (kRapido) 100 else 200)
    order.m[[as.character(m)]] <- parcial$eff
    Nota(sprintf(paste0("order-m S, M = %3d: mediana %.3f | %% acima da ",
                        "fronteira parcial (eff < 1) %.0f%% | Spearman ",
                        "com BCC_S %.3f"),
                 m, median(parcial$eff, na.rm = TRUE),
                 100 * mean(parcial$eff < 1, na.rm = TRUE),
                 Spearman(1 / parcial$eff, escores$bcc_S)))
  })
}

Bloco("orderalpha", {
  alphas <- c(0.90, 0.95, 0.99, 1)
  tab.alpha <- sapply(alphas, function(a) {
    OrderAlpha(x.extensivo, dados$pubs, a)
  })
  colnames(tab.alpha) <- paste0("alpha_", c(90, 95, 99, 100))
  Salva(tibble(DMU = dados$Country_Year,
               !!!as.data.frame(round(tab.alpha, 4)),
               orderm_25 = round(order.m[["25"]], 4),
               orderm_50 = round(order.m[["50"]], 4),
               orderm_100 = round(order.m[["100"]], 4)),
        "t10_orderm_alpha_S")
  Nota(sprintf(paste0("order-alpha S (eficiência de produto, 1 = na ",
                      "fronteira parcial): α=0,90 → %.0f%% acima (<1); ",
                      "α=0,95 → %.0f%%; α=0,99 → %.0f%%; α=1 (FDH) → ",
                      "%.0f%% eficientes"),
               100 * mean(tab.alpha[, 1] < 1),
               100 * mean(tab.alpha[, 2] < 1),
               100 * mean(tab.alpha[, 3] < 1),
               100 * mean(tab.alpha[, 4] <= 1 + 1e-9)))
  figura <- tibble(`Order-m 25` = 1 / order.m[["25"]],
                   `Order-m 100` = 1 / order.m[["100"]],
                   `Order-α 0,95` = 1 / tab.alpha[, 2],
                   BCC = escores$bcc_S) %>%
    pivot_longer(everything()) %>%
    ggplot(aes(pmin(value, 2), colour = name)) +
    geom_density() +
    theme_bw() +
    labs(x = "escore (truncado em 2)", y = "densidade", colour = NULL)
  ggsave(file.path(kDirFiguras, "fig06_orderm_alpha.png"), figura, width = 7,
         height = 4, dpi = 150)
})

# 8. SFA e COLS (template lesson3.7) ------------------------------------

Nota("=== 8. SFA e COLS (Benchmarking::sfa, template lesson3.7) ===")
sfa.resultados <- list()
for (k in c("S", "T")) {
  Bloco(paste0("sfa-", k), {
    y.log <- if (k == "S") log(dados$pubs) else log(dados$pat)
    x.log <- log(x.extensivo)
    ols <- lm(y.log ~ x.log)
    cols <- exp(residuals(ols) - max(residuals(ols)))
    modelo.sfa <- sfa(x.log, y.log)
    te <- as.numeric(te.sfa(modelo.sfa))
    lambda <- as.numeric(lambda.sfa(modelo.sfa)[1])
    bcc <- escores[[paste0("bcc_", k)]]
    sfa.resultados[[k]] <- tibble(DMU = dados$Country_Year, cols = cols,
                                  sfa = te, bcc = bcc)
    Nota(sprintf(paste0("SFA %s: coef log inv %.3f, log P&D %.3f | ",
                        "lambda %.2f (%.0f%% da variação é ineficiência) ",
                        "| TE média %.3f | cor(SFA, BCC) %.3f | ",
                        "cor(SFA, COLS) %.3f"),
                 k, coef(modelo.sfa)[2], coef(modelo.sfa)[3], lambda,
                 100 * lambda^2 / (lambda^2 + 1), mean(te),
                 cor(te, bcc), cor(te, cols)))
  })
}

Bloco("fig07", {
  tab.sfa <- bind_rows(sfa.resultados, .id = "modelo")
  Salva(mutate(tab.sfa, across(where(is.numeric), ~ round(.x, 4))),
        "t11_sfa_cols")
  figura <- ggplot(tab.sfa, aes(bcc, sfa)) +
    geom_point(alpha = .6) +
    geom_abline(linetype = 3) +
    facet_wrap(~modelo) +
    theme_bw() +
    labs(x = "DEA BCC", y = "SFA (eficiência técnica)")
  ggsave(file.path(kDirFiguras, "fig07_sfa_dea.png"), figura, width = 8,
         height = 4, dpi = 150)
})

# 9. Classes latentes (template lesson3.7) ------------------------------

Nota("=== 9. Classes latentes (poLCA sobre decis, template lesson3.7) ===")
Bloco("poLCA", {
  dados.lca <- data.frame(inv = Decis(log(dados$inv_usd)),
                          rd = Decis(log(dados$rd_usd)),
                          pubs = Decis(log(dados$pubs)),
                          pat = Decis(log(dados$pat)))
  ajustes <- lapply(2:4, function(k) {
    poLCA(cbind(inv, rd, pubs, pat) ~ 1, dados.lca, nclass = k, nrep = 5,
          verbose = FALSE, calc.se = FALSE)
  })
  bics <- sapply(ajustes, function(f) f$bic)
  melhor <- which.min(bics)
  lca <- ajustes[[melhor]]
  escores$classe <- lca$predclass
  Nota("poLCA: BIC k=2..4 = ", paste(round(bics), collapse = " / "),
       " → k = ", (2:4)[melhor], " | tamanhos: ",
       paste(table(lca$predclass), collapse = "/"))
  tabela <- table(classe = lca$predclass, renda = dados$income)
  print(tabela)
  resumo <<- c(resumo, capture.output(print(tabela)))
  teste <- kruskal.test(dados$manuf_pib ~ factor(lca$predclass))
  Nota("Kruskal manuf_pib ~ classe: p = ", signif(teste$p.value, 2),
       " | BCC ST médio por classe: ",
       paste(round(tapply(escores$bcc_ST, lca$predclass, mean), 3),
             collapse = " / "),
       " | log pubs médio por classe: ",
       paste(round(tapply(log(dados$pubs), lca$predclass, mean), 2),
             collapse = " / "))
  Salva(rownames_to_column(as.data.frame.matrix(tabela), "classe"),
        "t12_classes_x_renda")
  figura <- tibble(classe = factor(lca$predclass), renda = dados$income) %>%
    count(classe, renda) %>%
    ggplot(aes(classe, n, fill = renda)) +
    geom_col() +
    theme_bw() +
    labs(y = "país-ano")
  ggsave(file.path(kDirFiguras, "fig09_classes_latentes.png"), figura,
         width = 6,
         height = 4, dpi = 150)
})

# 10. Malmquist no subpainel balanceado ---------------------------------

Nota("=== 10. Malmquist (nonparaeff::faremalm2, painel balanceado ",
     "2016–2021, modelo S) ===")
Bloco("malmquist", {
  balanceado <- dados %>%
    group_by(Country) %>%
    filter(all(2016:2021 %in% Year)) %>%
    ungroup() %>%
    filter(Year %in% 2016:2021) %>%
    arrange(Country, Year)
  entrada <- data.frame(id = balanceado$Country, year = balanceado$Year,
                        y = balanceado$pubs, x1 = balanceado$inv_usd,
                        x2 = balanceado$rd_usd)
  malm <- faremalm2(entrada, noutput = 1, id = "id", year = "year")
  indices <- tibble(id = malm$id, year = malm$year, ec = malm$ec,
                    tc = malm$tc, pc = malm$pc)
  Salva(mutate(indices, across(where(is.numeric), ~ round(.x, 4))),
        "t13_malmquist_S")
  Nota("Malmquist S (", n_distinct(balanceado$Country),
       " países, 2016–2021): média geométrica M = ",
       round(MediaGeometrica(indices$pc), 3), " | EC = ",
       round(MediaGeometrica(indices$ec), 3), " | TC = ",
       round(MediaGeometrica(indices$tc), 3))
  por.ano <- indices %>%
    group_by(year) %>%
    summarise(M = round(MediaGeometrica(pc), 3),
              EC = round(MediaGeometrica(ec), 3),
              TC = round(MediaGeometrica(tc), 3),
              .groups = "drop")
  print(as.data.frame(por.ano))
  resumo <<- c(resumo, capture.output(print(as.data.frame(por.ano))))
  por.pais <- indices %>%
    group_by(id) %>%
    summarise(M = round(MediaGeometrica(pc), 3),
              EC = round(MediaGeometrica(ec), 3),
              TC = round(MediaGeometrica(tc), 3),
              .groups = "drop") %>%
    arrange(desc(M))
  Salva(por.pais, "t13b_malmquist_S_pais")
  figura <- indices %>%
    pivot_longer(c(ec, tc, pc)) %>%
    mutate(name = recode(name, ec = "catch-up", tc = "deslocamento",
                         pc = "Malmquist")) %>%
    ggplot(aes(name, pmin(value, 3), fill = name)) +
    geom_boxplot() +
    theme_bw() +
    labs(x = NULL, y = "índice (truncado em 3)") +
    theme(legend.position = "none")
  ggsave(file.path(kDirFiguras, "fig08_malmquist.png"), figura, width = 6,
         height = 4, dpi = 150)
})

# 11. Ganhos com fusões: blocos regionais -------------------------------

Nota("=== 11. Ganhos com fusões: blocos regionais ",
     "(Benchmarking::make.merge / dea.merge, template lesson2.3) ===")
Bloco("fusoes", {
  linhas.fusao <- list()
  for (nome.bloco in names(kBlocosRegionais)) {
    paises.bloco <- kBlocosRegionais[[nome.bloco]]
    for (ano in sort(unique(dados$Year))) {
      idx <- which(dados$Country %in% paises.bloco & dados$Year == ano)
      if (length(idx) < 2 || length(idx) < length(paises.bloco)) {
        next
      }
      matriz <- make.merge(list(idx), nFirm = nrow(dados), X = x.extensivo)
      fusao <- dea.merge(x.extensivo, y.ambos, matriz, RTS = "vrs",
                         ORIENTATION = "out")
      linhas.fusao[[paste(nome.bloco, ano)]] <- tibble(
        bloco = nome.bloco,
        ano = ano,
        membros = length(idx),
        efic_fusao = 1 / fusao$Eff,
        aprendizado = 1 / fusao$learning,
        harmonia = 1 / fusao$harmony,
        escala = 1 / fusao$size,
        efic_membros_media = mean(escores$bcc_ST[idx]))
    }
  }
  tab.fusoes <- bind_rows(linhas.fusao)
  Salva(mutate(tab.fusoes, across(where(is.numeric), ~ round(.x, 3))),
        "t14_fusoes_blocos")
  por.bloco <- tab.fusoes %>%
    group_by(bloco) %>%
    summarise(anos = n(),
              efic_fusao = mean(efic_fusao),
              aprendizado = mean(aprendizado),
              harmonia = mean(harmonia),
              escala = mean(escala),
              .groups = "drop") %>%
    mutate(across(where(is.numeric), ~ round(.x, 3)))
  print(as.data.frame(por.bloco))
  resumo <<- c(resumo, capture.output(print(as.data.frame(por.bloco))))
})

# 12. TOPSIS ------------------------------------------------------------

Nota("=== 12. TOPSIS (pacote topsis, pesos iguais) ===")
Bloco("topsis", {
  matriz.decisao <- as.matrix(dados[, c("inv_usd", "rd_usd", "pubs",
                                        "pat")])
  ranking <- topsis(matriz.decisao, c(1, 1, 1, 1), c("-", "-", "+", "+"))
  escores$topsis <- ranking$score
  Salva(tibble(DMU = dados$Country_Year, topsis = round(ranking$score, 4),
               rank = ranking$rank),
        "t15_topsis")
  Nota("TOPSIS: Spearman com BCC ST = ",
       round(Spearman(ranking$score, escores$bcc_ST), 3), " | top 5: ",
       paste(dados$Country_Year[order(-ranking$score)][1:5],
             collapse = ", "))
})

# 13. Segundo estágio (Lecture 04) --------------------------------------

Nota("=== 13. Segundo estágio (Lecture 04): testes não paramétricos, ",
     "Tobit, Simar-Wilson alg. 2 ===")
z.contextuais <- dados %>%
  transmute(manuf_pib, manuf_exp, gov, voice, ln_gdppc,
            trade = Trade_Percentage, z_score = Z_Score,
            npl = Non.performing.Loans, zero_inv = as.numeric(zero_inv),
            tend)
obs.completas <- complete.cases(z.contextuais)
Nota("obs. completas para o 2º estágio: ", sum(obs.completas), " de ",
     nrow(dados))

Bloco("testes-np", {
  testes <- list()
  for (k in c("bcc_S", "bcc_T", "bcc_C")) {
    for (nome.grupo in c("income", "regiao", "zero_inv")) {
      grupo <- if (nome.grupo == "zero_inv") {
        ifelse(escores$zero_inv, "zero", "positivo")
      } else {
        escores[[nome.grupo]]
      }
      teste <- kruskal.test(escores[[k]] ~ factor(grupo))
      testes[[paste(k, nome.grupo)]] <- tibble(escore = k,
                                               grupo = nome.grupo,
                                               kruskal_p = teste$p.value)
    }
  }
  for (k in c("bcc_S", "bcc_T", "bcc_C")) {
    acima <- dados$manuf_pib > median(dados$manuf_pib, na.rm = TRUE)
    valido <- !is.na(acima)
    ks <- ks.test(escores[[k]][valido & acima],
                  escores[[k]][valido & !acima])
    kw <- kruskal.test(escores[[k]][valido] ~ acima[valido])
    testes[[paste(k, "manuf")]] <- tibble(
      escore = k,
      grupo = "manuf_pib > mediana",
      kruskal_p = kw$p.value,
      ks_p = ks$p.value,
      media_alta = mean(escores[[k]][valido & acima]),
      media_baixa = mean(escores[[k]][valido & !acima]))
  }
  tab.testes <- bind_rows(testes) %>%
    mutate(across(where(is.numeric), ~ signif(.x, 3)))
  Salva(tab.testes, "t16_testes_nao_parametricos")
  print(as.data.frame(tab.testes))
  resumo <<- c(resumo, capture.output(print(as.data.frame(tab.testes))))
})

tobits <- list()
ols.cluster <- list()
for (k in c("bcc_S", "bcc_T", "bcc_C", "se_ST", "bcc_S_int", "bcc_T_int",
            "bcc_C_int")) {
  Bloco(paste0("tobit-", k), {
    linhas <- obs.completas & !is.na(escores[[k]])
    dados.reg <- cbind(y = escores[[k]], z.contextuais)[linhas, ]
    formula.reg <- y ~ manuf_pib + manuf_exp + gov + voice + ln_gdppc +
      trade + z_score + npl + zero_inv + tend
    tobit <- censReg(formula.reg, left = 0, right = 1, data = dados.reg)
    estimativas <- summary(tobit)$estimate
    tobits[[k]] <- tibble(escore = k,
                          variavel = rownames(estimativas),
                          coef = estimativas[, 1],
                          ep = estimativas[, 2],
                          p = estimativas[, 4])
    modelo.ols <- lm(formula.reg, data = dados.reg)
    teste.ols <- coeftest(modelo.ols,
                          vcov = vcovCL(modelo.ols,
                                        cluster = dados$Country[linhas]))
    ols.cluster[[k]] <- tibble(escore = k,
                               variavel = rownames(teste.ols),
                               coef_ols = teste.ols[, 1],
                               p_cluster = teste.ols[, 4])
  })
}

Bloco("tab-tobit", {
  tab.tobit <- bind_rows(tobits) %>%
    left_join(bind_rows(ols.cluster), by = c("escore", "variavel")) %>%
    mutate(across(where(is.numeric), ~ signif(.x, 3)))
  Salva(tab.tobit, "t17_tobit_ols")
  h1 <- filter(tab.tobit, variavel == "manuf_pib")
  print(as.data.frame(h1))
  resumo <<- c(resumo, "H1 (manuf_pib) por escore — Tobit e OLS-cluster:",
               capture.output(print(as.data.frame(h1))))
})

# Sensibilidade do segundo estágio: conjuntos de contextuais
# institucionais e amostra sem os países que depositam via EPO/PCT.
Bloco("tobit-sensibilidade", {
  conjuntos <- list("nenhuma" = "",
                    "so governanca" = "+ gov",
                    "so voice" = "+ voice",
                    "governanca e voice" = "+ gov + voice")
  base.reg <- cbind(Country = dados$Country,
                    z.contextuais)[obs.completas, ]
  linhas.sens <- list()
  for (k in c("bcc_S", "bcc_T", "bcc_C")) {
    dados.reg <- base.reg
    dados.reg$y <- escores[[k]][obs.completas]
    for (nome.conjunto in names(conjuntos)) {
      for (amostra in c("todos", "sem 13 paises EPO")) {
        recorte <- if (amostra == "todos") {
          dados.reg
        } else {
          dados.reg[!dados.reg$Country %in% kPaisesEpo, ]
        }
        formula.reg <- as.formula(
          paste("y ~ manuf_pib + manuf_exp", conjuntos[[nome.conjunto]],
                "+ ln_gdppc + trade + z_score + npl + zero_inv + tend"))
        estimativas <- summary(censReg(formula.reg, left = 0, right = 1,
                                       data = recorte))$estimate
        modelo.ols <- lm(formula.reg, data = recorte)
        teste.ols <- coeftest(modelo.ols,
                              vcov = vcovCL(modelo.ols,
                                            cluster = recorte$Country))
        linhas.sens[[length(linhas.sens) + 1]] <- tibble(
          escore = k,
          contextuais = nome.conjunto,
          amostra = amostra,
          n = nrow(recorte),
          manuf_tobit = CoefOuNa(estimativas, "manuf_pib", 1),
          manuf_p_tobit = CoefOuNa(estimativas, "manuf_pib", 4),
          manuf_p_ols_cluster = teste.ols["manuf_pib", 4],
          voice_tobit = CoefOuNa(estimativas, "voice", 1),
          voice_p_tobit = CoefOuNa(estimativas, "voice", 4),
          gov_tobit = CoefOuNa(estimativas, "gov", 1),
          gov_p_tobit = CoefOuNa(estimativas, "gov", 4))
      }
    }
  }
  tab.sens <- bind_rows(linhas.sens) %>%
    mutate(across(where(is.numeric), ~ signif(.x, 3)))
  Salva(tab.sens, "t19_sensibilidade_2o_estagio")
  Nota("cor(manuf_pib, voice) = ",
       round(cor(z.contextuais$manuf_pib, z.contextuais$voice,
                 use = "complete.obs"), 3),
       " | cor(manuf_pib, gov) = ",
       round(cor(z.contextuais$manuf_pib, z.contextuais$gov,
                 use = "complete.obs"), 3),
       " | voice médio: 13 EPO ",
       round(mean(z.contextuais$voice[dados$Country %in% kPaisesEpo]), 1),
       " vs demais ",
       round(mean(z.contextuais$voice[!dados$Country %in% kPaisesEpo]), 1))
  print(as.data.frame(tab.sens %>%
                        filter(escore != "bcc_S") %>%
                        select(escore, contextuais, amostra, n,
                               manuf_tobit, manuf_p_tobit,
                               manuf_p_ols_cluster, voice_tobit,
                               voice_p_tobit)))
  resumo <<- c(resumo, capture.output(print(as.data.frame(tab.sens))))
})

env.linear <- list()
env.log <- list()
for (k in c("S", "T", "C")) {
  Bloco(paste0("env-", k), {
    x.modelo <- if (k == "C") x.conversao else x.extensivo
    y.modelo <- if (k == "S") y.ciencia else y.tecnologia
    z.modelo <- as.data.frame(z.contextuais[obs.completas, ])
    inicio <- Sys.time()
    linear <- dea.env.robust(x.modelo[obs.completas, ],
                             y.modelo[obs.completas, , drop = FALSE],
                             Z = z.modelo, model = "output",
                             RTS = "variable", L1 = kEnvL1, L2 = kEnvL2,
                             alpha = 0.05)
    nomes <- if (length(linear$beta_hat) == ncol(z.contextuais) + 1) {
      c("(Intercepto)", colnames(z.contextuais))
    } else {
      colnames(z.contextuais)
    }
    env.linear[[k]] <- tibble(modelo = k,
                              versao = "linear em delta (rDEA)",
                              variavel = nomes,
                              beta = as.numeric(linear$beta_hat),
                              ic_inf = linear$beta_ci[, 1],
                              ic_sup = linear$beta_ci[, 2],
                              sigma = as.numeric(linear$sigma_hat)) %>%
      mutate(signif = ic_inf > 0 | ic_sup < 0)
    manuf <- filter(env.linear[[k]], variavel == "manuf_pib")
    aviso <- if (linear$sigma_hat > 5) {
      paste0(" → INSTÁVEL (delta com cauda pesada; usar a versão em log)")
    } else {
      ""
    }
    Nota(sprintf(paste0("dea.env.robust %s linear (%.0fs): sigma = ",
                        "%.2f%s | beta manuf_pib = %.3f [%.3f; %.3f]"),
                 k, as.numeric(Sys.time() - inicio, units = "secs"),
                 linear$sigma_hat, aviso, manuf$beta, manuf$ic_inf,
                 manuf$ic_sup))

    inicio <- Sys.time()
    log.delta <- SimarWilsonLog(x.modelo[obs.completas, ],
                                y.modelo[obs.completas, , drop = FALSE],
                                z.modelo, l1 = kEnvL1, l2 = kEnvL2)
    env.log[[k]] <- tibble(modelo = k,
                           versao = "log(delta) (implementação própria)",
                           variavel = c("(Intercepto)",
                                        colnames(z.contextuais)),
                           beta = as.numeric(log.delta$beta),
                           ic_inf = log.delta$ci[, 1],
                           ic_sup = log.delta$ci[, 2],
                           sigma = as.numeric(log.delta$sigma)) %>%
      mutate(signif = ic_inf > 0 | ic_sup < 0)
    escores[[paste0("sw_", k)]] <- NA_real_
    escores[[paste0("sw_", k)]][obs.completas] <- 1 / log.delta$delta.bc
    tab.log <- env.log[[k]]
    significativos <- tab.log$variavel[tab.log$signif &
                                         tab.log$variavel != "(Intercepto)"]
    Nota(sprintf(paste0("SW alg. 2 em log(delta) %s (%.0fs, %d/%d ",
                        "réplicas ok): sigma %.2f | beta manuf_pib = ",
                        "%.4f [%.4f; %.4f] | beta voice = %.4f ",
                        "[%.4f; %.4f] (beta < 0 = menos ineficiência) | ",
                        "significativos: %s"),
                 k, as.numeric(Sys.time() - inicio, units = "secs"),
                 log.delta$n.boot.ok, kEnvL2, log.delta$sigma,
                 log.delta$beta[["manuf_pib"]],
                 log.delta$ci["manuf_pib", 1],
                 log.delta$ci["manuf_pib", 2],
                 log.delta$beta[["voice"]], log.delta$ci["voice", 1],
                 log.delta$ci["voice", 2],
                 paste(significativos, collapse = ", ")))
  })
}

Bloco("tab-env", {
  tab.env <- bind_rows(c(env.linear, env.log)) %>%
    mutate(across(where(is.numeric), ~ signif(.x, 3)))
  Salva(tab.env, "t18_simar_wilson_alg2")
  figura <- bind_rows(env.log) %>%
    filter(variavel != "(Intercepto)") %>%
    ggplot(aes(beta, modelo, xmin = ic_inf, xmax = ic_sup,
               colour = modelo)) +
    geom_pointrange() +
    geom_vline(xintercept = 0, linetype = 3) +
    facet_wrap(~variavel, scales = "free_x") +
    theme_bw() +
    theme(legend.position = "none") +
    labs(y = NULL,
         x = paste0("β sobre log(δ), IC 95% bootstrap: negativo = menos ",
                    "ineficiência (Simar-Wilson alg. 2 em log-δ)"))
  ggsave(file.path(kDirFiguras, "fig10_segundo_estagio.png"), figura, width = 8,
         height = 5, dpi = 150)
})

Bloco("fig11", {
  figura <- medias.pais %>%
    mutate(Country = fct_reorder(Country, bcc_C)) %>%
    ggplot(aes(Country, bcc_C, fill = manuf_pib)) +
    geom_col() +
    coord_flip() +
    theme_bw() +
    labs(x = NULL,
         y = paste0("eficiência de conversão pesquisa → patente (BCC, ",
                    "média dos anos)"),
         fill = "manufatura\n% PIB")
  ggsave(file.path(kDirFiguras, "fig11_conversao_pais.png"), figura, width = 7,
         height = 8, dpi = 150)
})
Salva(mutate(escores, across(where(is.numeric), ~ round(.x, 4))),
      "t04_escores_dmu")

# Encerramento ----------------------------------------------------------

n.erros <- if (file.exists(kArquivoLog)) {
  length(readLines(kArquivoLog))
} else {
  0
}
Nota("=== Fim: ",
     round(as.numeric(Sys.time() - inicio.execucao, units = "mins"), 1),
     " min | erros: ", n.erros, " (ver resultados/log_erros.txt) ===")
writeLines(resumo, file.path(kDirResultados, "resumo_v3.txt"))
