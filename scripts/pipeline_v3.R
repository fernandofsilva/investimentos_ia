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
#   dados/openalex_publicacoes.csv      publicações por domínio (opcional)
#
# Saídas:
#   resultados/base_v3.csv        base tratada
#   resultados/t01..t28*.csv      tabelas numeradas
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
kMinAnosPais <- 3                     # anos mínimos para entrar no ranking
kSubamostraB <- if (kRapido) 100 else 200  # sorteios do TGR com n igualado
kDirResultados <- "resultados"
kDirFiguras <- file.path("resultados", "figuras")
kArquivoLog <- file.path(kDirResultados, "log_erros.txt")

# Países com patentes de IA quase nulas na base, que depositam via EPO/PCT.
kPaisesEpo <- c("Switzerland", "Netherlands", "Belgium", "Ireland", "Norway",
                "Israel", "France", "Austria", "United Kingdom", "Portugal",
                "Italy", "Spain", "Greece")

# Países discutidos como casos no manuscrito: os do topo do ranking de
# conversão, os da cauda (que depositam patente fora do escritório nacional) e
# o Brasil, do diagnóstico setorial.
kPaisesCaso <- c("Peru", "Mexico", "Slovenia", "Ukraine", "Luxembourg",
                 "Japan", "China", "Israel", "France", "United Kingdom",
                 "Switzerland", "Ireland", "Netherlands", "Brazil")

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
       delta.bc = delta.bc, betas = betas,
       n.boot.ok = sum(complete.cases(betas)))
}

EficienciaPorGrupo <- function(x, y, grupo, Referencia = NULL) {
  # Eficiência de Farrell (produto, VRS) contra a fronteira do próprio grupo.
  #
  # Args:
  #   x: matriz de insumos, DMUs nas linhas.
  #   y: matriz de produtos, DMUs nas linhas.
  #   grupo: vetor que define a fronteira de cada DMU (ano, faixa de renda).
  #   Referencia: função opcional que recebe o rótulo do grupo e devolve os
  #     índices das DMUs de referência; permite a fronteira sequencial
  #     (anos <= t). Quando NULL, a referência é o próprio grupo.
  #
  # Returns:
  #   Vetor de eficiências de Farrell, sempre >= 1.
  resultado <- rep(NA_real_, nrow(x))
  for (g in unique(grupo)) {
    avaliadas <- which(grupo == g)
    referencia <- if (is.null(Referencia)) avaliadas else Referencia(g)
    resultado[avaliadas] <- eff(dea(x[avaliadas, , drop = FALSE],
                                    y[avaliadas, , drop = FALSE],
                                    RTS = "vrs", ORIENTATION = "out",
                                    XREF = x[referencia, , drop = FALSE],
                                    YREF = y[referencia, , drop = FALSE]))
  }
  resultado
}

EficienciaUniao <- function(x, y, grupo) {
  # Metafronteira como união (não convexa) das tecnologias de grupo.
  #
  # Para cada DMU, toma a maior eficiência de Farrell entre as fronteiras de
  # grupo em que o programa é factível. A fronteira agrupada é a versão
  # convexificada dessa união (Kerstens, O'Donnell & Van de Woestyne, 2019).
  #
  # Args:
  #   x: matriz de insumos.
  #   y: matriz de produtos.
  #   grupo: vetor que define as tecnologias de grupo.
  #
  # Returns:
  #   Vetor de eficiências de Farrell contra a união das fronteiras.
  por.grupo <- sapply(unique(grupo), function(g) {
    referencia <- which(grupo == g)
    eff(dea(x, y, RTS = "vrs", ORIENTATION = "out",
            XREF = x[referencia, , drop = FALSE],
            YREF = y[referencia, , drop = FALSE]))
  })
  apply(por.grupo, 1, function(linha) max(linha[is.finite(linha)]))
}

TgrSubamostrado <- function(x, y, ano, eff.global, n.alvo, b = kSubamostraB) {
  # Lacuna tecnológica por ano com fronteiras contemporâneas de n igualado.
  #
  # Anos com poucas DMUs têm eficiência contemporânea inflada, o que rebaixa a
  # lacuna por razão amostral. Sortear sempre n.alvo DMUs separa o gap
  # tecnológico desse viés de dimensionalidade.
  #
  # Args:
  #   x: matriz de insumos.
  #   y: matriz de produtos.
  #   ano: vetor do ano de cada DMU.
  #   eff.global: eficiências contra a fronteira agrupada.
  #   n.alvo: número de DMUs sorteadas em cada ano.
  #   b: número de sorteios.
  #
  # Returns:
  #   Vetor com a lacuna média de cada ano, na ordem de sort(unique(ano)).
  # O estado do gerador é salvo e restaurado para que os sorteios daqui não
  # desloquem a sequência aleatória dos bootstraps estimados depois.
  estado <- if (exists(".Random.seed", .GlobalEnv)) {
    get(".Random.seed", .GlobalEnv)
  } else {
    NULL
  }
  on.exit(if (!is.null(estado)) assign(".Random.seed", estado, .GlobalEnv))
  sapply(sort(unique(ano)), function(a) {
    linhas <- which(ano == a)
    replicas <- replicate(b, {
      amostra <- if (length(linhas) > n.alvo) {
        sample(linhas, n.alvo)
      } else {
        linhas
      }
      eficiencias <- eff(dea(x[amostra, , drop = FALSE],
                             y[amostra, , drop = FALSE],
                             RTS = "vrs", ORIENTATION = "out"))
      mean(eficiencias / eff.global[amostra])
    })
    mean(replicas)
  })
}

Estrelas <- function(p) {
  # Marcas de significância no padrão das tabelas de periódico.
  #
  # Args:
  #   p: vetor de valores-p.
  #
  # Returns:
  #   Vetor de caracteres com ***, ** , * ou vazio.
  ifelse(is.na(p), "",
         ifelse(p < 0.01, "***",
                ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", ""))))
}

FormataCelula <- function(coeficiente, erro.padrao, p, digitos = 3) {
  # Célula "coeficiente*** (erro padrão)" da tabela de regressões.
  #
  # Args:
  #   coeficiente: estimativa pontual.
  #   erro.padrao: erro padrão da estimativa.
  #   p: valor-p usado nas estrelas.
  #   digitos: casas decimais.
  #
  # Returns:
  #   Vetor de caracteres; vazio onde a estimativa é NA.
  formato <- paste0("%.", digitos, "f%s (%.", digitos, "f)")
  ifelse(is.na(coeficiente), "",
         sprintf(formato, coeficiente, Estrelas(p), erro.padrao))
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
                   pesq_pm, rd_pct_wdi, artigos_se_nsf),
            by = c("Country", "Year")) %>%
  group_by(Country) %>%
  arrange(Year, .by_group = TRUE) %>%
  # Só manuf_pib é interpolada, porque entra no segundo estágio; pesq_pm fica
  # como vem do WDI, com a marca de ausência, e não é usada nas regressões.
  mutate(manuf_pib_na = is.na(manuf_pib),
         pesq_pm_na = is.na(pesq_pm),
         manuf_pib = PreencheSerie(manuf_pib, Year)) %>%
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
     " originais + ", sum(dados$manuf_pib_na & !is.na(dados$manuf_pib)),
     " interpolados + ", sum(is.na(dados$manuf_pib)), " sem valor | manuf_exp ",
     sum(!is.na(dados$manuf_exp)), " | pesq_pm ", sum(!dados$pesq_pm_na),
     " originais + ", sum(dados$pesq_pm_na), " sem valor (não entra no 2º ",
     "estágio) | rd_pct_wdi ", sum(!is.na(dados$rd_pct_wdi)),
     " | artigos_se_nsf ", sum(!is.na(dados$artigos_se_nsf)))
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
# 1b. Conferência das publicações e especialização do sistema ---------

# A segunda sessão observou que a variável de publicações cobre um recorte da
# produção do país, e pediu a participação desse recorte no total. O arquivo
# gerado por dados/baixar_openalex.sh traz, do OpenAlex, o total de artigos
# por país e ano, a repartição por domínio do conhecimento e os artigos de
# inteligência artificial. Serve a duas coisas: conferir AI.Publications
# contra uma fonte independente e medir a especialização do sistema
# científico, que entra no segundo estágio apenas como sensibilidade.

if (file.exists("dados/openalex_publicacoes.csv")) {
  Bloco("openalex", {
    openalex <- read_csv("dados/openalex_publicacoes.csv",
                         show_col_types = FALSE)
    # Especialização anterior ao período analisado: predeterminada em relação
    # aos produtos do modelo, ao contrário da participação contemporânea.
    ai.share.pre <- openalex %>%
      filter(Year <= 2012) %>%
      group_by(Country) %>%
      summarise(ai_share_pre = sum(ai_qualquer) / sum(total),
                .groups = "drop")
    openalex.painel <- openalex %>%
      filter(Year >= kAnoBase) %>%
      transmute(Country, Year,
                oa_total = total,
                oa_ai = ai_qualquer,
                stem_share = (physical + life) / total,
                social_share = social / total,
                ai_share_oa = ai_qualquer / total)
    dados <- dados %>%
      left_join(openalex.painel, by = c("Country", "Year")) %>%
      left_join(ai.share.pre, by = "Country")

    conferencia <- dados %>%
      transmute(Country, Year, pubs, oa_ai, oa_total, artigos_se_nsf,
                razao_base_openalex = pubs / oa_ai,
                ai_share_oa, stem_share, social_share)
    Salva(mutate(conferencia, across(where(is.numeric), ~ signif(.x, 4))),
          "t28_conferencia_publicacoes")
    Nota("publicações: Spearman(AI.Publications, OpenAlex IA) = ",
         Spearman(dados$pubs, dados$oa_ai),
         " | razão base/OpenAlex mediana ",
         round(median(dados$pubs / dados$oa_ai), 2), " (quartis ",
         round(quantile(dados$pubs / dados$oa_ai, 0.25), 2), "–",
         round(quantile(dados$pubs / dados$oa_ai, 0.75), 2),
         "): mesma ordenação, níveis diferentes, sinal de bases de ",
         "indexação distintas")
    Nota("conferência do total: cor(log OpenAlex total, log artigos S&E do ",
         "WDI) = ",
         round(cor(log(dados$oa_total), log(dados$artigos_se_nsf),
                   use = "complete.obs"), 3))
    extremos <- dados %>%
      group_by(Country) %>%
      summarise(stem = mean(stem_share), social = mean(social_share),
                ai = mean(ai_share_oa), .groups = "drop") %>%
      arrange(social)
    Nota("participação das ciências sociais na produção total: menor em ",
         paste(sprintf("%s %.0f%%", head(extremos$Country, 3),
                       100 * head(extremos$social, 3)), collapse = ", "),
         "; maior em ",
         paste(sprintf("%s %.0f%%", rev(tail(extremos$Country, 3)),
                       100 * rev(tail(extremos$social, 3))),
               collapse = ", "))

    figura <- extremos %>%
      mutate(Country = fct_reorder(Country, stem)) %>%
      pivot_longer(c(stem, social), names_to = "recorte",
                   values_to = "participacao") %>%
      mutate(recorte = recode(recorte,
                              stem = "exatas e da vida",
                              social = "ciências sociais")) %>%
      ggplot(aes(participacao, Country, fill = recorte)) +
      geom_col(position = "dodge") +
      theme_bw() +
      theme(legend.position = "top") +
      labs(x = "participação na produção total de artigos (OpenAlex)",
           y = NULL, fill = NULL)
    ggsave(file.path(kDirFiguras, "fig14_especializacao.png"), figura,
           width = 7, height = 8, dpi = 150)
  })
} else {
  Nota("dados/openalex_publicacoes.csv ausente: rode ",
       "bash dados/baixar_openalex.sh para a conferência das publicações")
}

Salva(dados, "base_v3")

# 1c. Auditoria da base: cobertura e ausências --------------------------

# A orientação da segunda sessão pede a base mais compacta possível com o
# menor número de ausências: quantos anos cada país tem, onde estão os zeros
# de investimento e quais contextuais faltam antes de qualquer preenchimento.

Bloco("auditoria-base", {
  cobertura <- dados %>%
    group_by(Country) %>%
    summarise(n_anos = n(),
              primeiro = min(Year),
              ultimo = max(Year),
              anos = paste(Year, collapse = " "),
              n_zeros = sum(zero_inv),
              anos_zero = paste(Year[zero_inv], collapse = " "),
              no_ranking = n() >= kMinAnosPais,
              .groups = "drop") %>%
    arrange(n_anos, Country)
  Salva(cobertura, "t21_cobertura_pais_ano")
  curtos <- cobertura$Country[!cobertura$no_ranking]
  Nota("cobertura: ", sum(cobertura$n_anos == 9), " países com os 9 anos | ",
       length(curtos), " com menos de ", kMinAnosPais, " anos (",
       paste(curtos, collapse = ", "), ") | DMUs por ano: ",
       paste(table(dados$Year), collapse = " "))
  Nota("zeros de investimento: ", sum(dados$zero_inv), " observações em ",
       sum(cobertura$n_zeros > 0), " países | ",
       paste(sprintf("%s %d/%d", cobertura$Country[cobertura$n_zeros > 0],
                     cobertura$n_zeros[cobertura$n_zeros > 0],
                     cobertura$n_anos[cobertura$n_zeros > 0]),
             collapse = ", "))

  contextuais.auditadas <- c(manuf_pib = "manuf_pib", manuf_exp = "manuf_exp",
                             gov = "gov", voice = "voice",
                             ln_gdppc = "ln_gdppc", trade = "Trade_Percentage",
                             z_score = "Z_Score",
                             npl = "Non.performing.Loans",
                             pesq_pm = "pesq_pm",
                             artigos_se_nsf = "artigos_se_nsf")
  na.contextuais <- map_dfr(names(contextuais.auditadas), function(v) {
    faltas <- is.na(dados[[contextuais.auditadas[[v]]]])
    tibble(variavel = v,
           n_na = sum(faltas),
           paises_na = paste(unique(dados$Country[faltas]), collapse = ", "),
           usada_2o_estagio = !v %in% c("pesq_pm", "artigos_se_nsf"))
  })
  Salva(na.contextuais, "t22_na_contextuais")
  Nota("ausências nas contextuais: ",
       paste(sprintf("%s %d", na.contextuais$variavel, na.contextuais$n_na),
             collapse = " | "))

  figura <- dados %>%
    transmute(Country, Year,
              status = ifelse(zero_inv, "investimento = 0", "observado")) %>%
    complete(Country, Year = 2013:2021,
             fill = list(status = "sem observação")) %>%
    mutate(Country = factor(Country, levels = rev(cobertura$Country)),
           status = factor(status, levels = c("observado",
                                              "investimento = 0",
                                              "sem observação"))) %>%
    ggplot(aes(factor(Year), Country, fill = status)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    scale_fill_manual(values = c("observado" = "grey35",
                                 "investimento = 0" = "firebrick",
                                 "sem observação" = "grey93")) +
    theme_bw() +
    theme(legend.position = "top") +
    labs(x = NULL, y = NULL, fill = NULL)
  ggsave(file.path(kDirFiguras, "fig12_cobertura_pais_ano.png"), figura,
         width = 6.5, height = 8, dpi = 150)
})

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
# Sob retornos variáveis, uma observação sem investimento só pode ser
# envelopada por outras sem investimento: a de menor gasto em P&D entre elas
# é eficiente por construção. O asterisco marca esses casos.
for (k in c("S", "T", "C")) {
  na.fronteira <- escores[[paste0("bcc_", k)]] >= 1 - kTolEfic
  rotulos <- paste0(escores$Country_Year[na.fronteira],
                    ifelse(escores$zero_inv[na.fronteira], "*", ""))
  Nota("BCC-eficientes ", k, ": ", paste(rotulos, collapse = ", "),
       " (* eficiente entre as observações sem investimento)")
}

# O ranking por país só é informativo onde há anos suficientes, e as médias
# calculadas apenas sobre os anos com investimento positivo separam o
# desempenho do efeito de âncora das observações sem investimento.
medias.pais <- escores %>%
  group_by(Country) %>%
  summarise(n = n(),
            n_zeros = sum(zero_inv),
            bcc_T_pos = ifelse(all(zero_inv), NA_real_,
                               mean(bcc_T[!zero_inv])),
            bcc_C_pos = ifelse(all(zero_inv), NA_real_,
                               mean(bcc_C[!zero_inv])),
            across(c(bcc_S, bcc_T, bcc_ST, bcc_C, ccr_ST, se_ST),
                   ~ mean(.x, na.rm = TRUE)),
            manuf_pib = mean(manuf_pib),
            .groups = "drop") %>%
  mutate(gap_TS = bcc_T - bcc_S,
         no_ranking = n >= kMinAnosPais) %>%
  arrange(desc(bcc_C))
Salva(mutate(medias.pais, across(where(is.numeric), ~ round(.x, 3))),
      "t03_medias_pais")
Nota("Conversão (C) por país, top 8: ",
     paste(head(medias.pais$Country, 8),
           round(head(medias.pais$bcc_C, 8), 2), collapse = ", "))
ranking.longo <- filter(medias.pais, no_ranking)
Nota("Conversão (C), top 8 entre os ", nrow(ranking.longo), " países com ",
     kMinAnosPais, " anos ou mais: ",
     paste(head(ranking.longo$Country, 8),
           round(head(ranking.longo$bcc_C, 8), 2), collapse = ", "))
Nota("Conversão (C) só nos anos com investimento positivo, top 8: ",
     paste(head(arrange(medias.pais, desc(bcc_C_pos))$Country, 8),
           round(head(arrange(medias.pais, desc(bcc_C_pos))$bcc_C_pos, 8), 2),
           collapse = ", "),
     " | Spearman com a média de todos os anos = ",
     Spearman(medias.pais$bcc_C, medias.pais$bcc_C_pos))
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

# Cenários pedidos na segunda sessão: a base "de cirurgião", sem os países
# com um ou dois anos observados, e a leitura literal dos zeros, com os três
# modelos reestimados sem eles e com um modelo de insumo único (só P&D), que
# põe todas as 208 observações no mesmo conjunto de comparação.

Bloco("rob-paises-curtos", {
  anos.por.pais <- table(dados$Country)
  longos <- names(anos.por.pais)[anos.por.pais >= kMinAnosPais]
  linhas <- which(dados$Country %in% longos)
  for (k in c("S", "T", "ST", "C")) {
    x.modelo <- if (k == "C") x.conversao else x.extensivo
    y.modelo <- switch(k, S = y.ciencia, T = y.tecnologia, ST = y.ambos,
                       C = y.tecnologia)
    ComparaCenario(paste0("sem_paises_curtos_", k), linhas,
                   Escore(dea(x.modelo[linhas, ],
                              y.modelo[linhas, , drop = FALSE],
                              RTS = "vrs", ORIENTATION = "out")),
                   escores[[paste0("bcc_", k)]])
  }
  Nota("sem países de menos de ", kMinAnosPais, " anos: ", length(linhas),
       " DMUs, ", length(longos), " países")
})

Bloco("rob-semzeros-STC", {
  linhas <- which(!dados$zero_inv)
  for (k in c("S", "T", "C")) {
    x.modelo <- if (k == "C") x.conversao else x.extensivo
    y.modelo <- if (k == "S") y.ciencia else y.tecnologia
    escore.novo <- Escore(dea(x.modelo[linhas, ],
                              y.modelo[linhas, , drop = FALSE],
                              RTS = "vrs", ORIENTATION = "out"))
    ComparaCenario(paste0("sem_zeros_", k), linhas, escore.novo,
                   escores[[paste0("bcc_", k)]])
    escores[[paste0("bcc_", k, "_semzeros")]] <- NA_real_
    escores[[paste0("bcc_", k, "_semzeros")]][linhas] <- escore.novo
  }
  ranking.com <- escores %>%
    group_by(Country) %>%
    summarise(com = mean(bcc_C), sem = mean(bcc_C_semzeros, na.rm = TRUE),
              .groups = "drop")
  Nota("ranking de conversão por país, com e sem os zeros: Spearman = ",
       Spearman(ranking.com$com, ranking.com$sem))
})

Bloco("rob-so-PD", {
  x.rd <- x.extensivo[, "rd_usd", drop = FALSE]
  todas <- seq_len(nrow(dados))
  ComparaCenario("so_PD_S", todas,
                 Escore(dea(x.rd, y.ciencia, RTS = "vrs",
                            ORIENTATION = "out")),
                 escores$bcc_S)
  ComparaCenario("so_PD_T", todas,
                 Escore(dea(x.rd, y.tecnologia, RTS = "vrs",
                            ORIENTATION = "out")),
                 escores$bcc_T)
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

# 10b. Metafronteira: fronteira global contra fronteiras contemporâneas --

# A segunda sessão apontou que o painel desbalanceado justifica ler a
# fronteira agrupada como metafronteira. Ela é a fronteira global ou
# intertemporal (Tulkens & Vanden Eeckaut, 1995; Pastor & Lovell, 2005), que
# envolve as fronteiras contemporâneas de cada ano; a razão entre a
# eficiência contra a fronteira do ano e a eficiência contra a fronteira
# global é a lacuna tecnológica (TGR) de O'Donnell, Rao & Battese (2008).
# Como o envelope agrupado convexifica a união das tecnologias anuais, a
# versão não convexa é estimada ao lado (Kerstens, O'Donnell & Van de
# Woestyne, 2019), e a lacuna por ano é recalculada com o número de DMUs
# igualado, porque anos com poucas observações têm eficiência contemporânea
# inflada.

Nota("=== 10b. Metafronteira: fronteira global, contemporânea, sequencial ",
     "e união; lacuna tecnológica (TGR) ===")
metafronteira <- list()
for (k in c("S", "T", "ST", "C")) {
  Bloco(paste0("metafronteira-", k), {
    x.modelo <- if (k == "C") x.conversao else x.extensivo
    y.modelo <- switch(k, S = y.ciencia, T = y.tecnologia, ST = y.ambos,
                       C = y.tecnologia)
    eff.global <- eff(modelos[[k]]$vrs)
    eff.contemp <- EficienciaPorGrupo(x.modelo, y.modelo, dados$Year)
    eff.seq <- EficienciaPorGrupo(x.modelo, y.modelo, dados$Year,
                                  Referencia = function(ano) {
                                    which(dados$Year <= ano)
                                  })
    eff.uniao <- EficienciaUniao(x.modelo, y.modelo, dados$Year)
    metafronteira[[k]] <- tibble(
      modelo = k,
      Country_Year = dados$Country_Year,
      Country = dados$Country,
      Year = dados$Year,
      zero_inv = dados$zero_inv,
      esc_contemp = pmin(1 / eff.contemp, 1),
      esc_seq = pmin(1 / eff.seq, 1),
      esc_uniao = pmin(1 / eff.uniao, 1),
      esc_global = pmin(1 / eff.global, 1),
      tgr = eff.contemp / eff.global,
      tgr_uniao = eff.contemp / eff.uniao,
      convexificacao = eff.global / eff.uniao)
    n.minimo <- min(table(dados$Year))
    por.ano <- metafronteira[[k]] %>%
      group_by(Year) %>%
      summarise(n = n(),
                efic_contemp_pct = PctEficientes(esc_contemp),
                efic_global_pct = PctEficientes(esc_global),
                tgr_medio = mean(tgr),
                tgr_geometrico = MediaGeometrica(tgr),
                tgr_uniao = mean(tgr_uniao),
                gap_sequencial = mean(esc_seq / esc_contemp),
                .groups = "drop") %>%
      mutate(tgr_n_igualado = TgrSubamostrado(x.modelo, y.modelo, dados$Year,
                                              eff.global, n.minimo))
    Salva(mutate(por.ano, across(where(is.numeric), ~ round(.x, 3))),
          paste0("t24_metafronteira_ano_", k))
    Nota(k, ": TGR médio ", round(mean(metafronteira[[k]]$tgr), 3),
         " | união ", round(mean(metafronteira[[k]]$tgr_uniao), 3),
         " | convexificação média ",
         round(mean(metafronteira[[k]]$convexificacao), 3),
         " | DMUs na metatecnologia não convexa ",
         round(100 * mean(metafronteira[[k]]$convexificacao < 1 + kTolEfic)),
         "%")
    Nota(k, ": TGR por ano ",
         paste(por.ano$Year, round(por.ano$tgr_medio, 2), collapse = " "),
         " | com n igualado em ", n.minimo, ": ",
         paste(round(por.ano$tgr_n_igualado, 2), collapse = " "))
  })
}

Bloco("malmquist-global", {
  tab.meta <- bind_rows(metafronteira)
  Salva(mutate(tab.meta, across(where(is.numeric), ~ round(.x, 4))),
        "t23_metafronteira_dmu")
  # Malmquist global (Pastor & Lovell, 2005) entre o primeiro e o último ano
  # observado de cada país: M = EC × BPC, sem exigir painel balanceado.
  malm.global <- tab.meta %>%
    filter(modelo == "S") %>%
    group_by(Country) %>%
    filter(n() >= 2) %>%
    arrange(Year, .by_group = TRUE) %>%
    summarise(ano_ini = first(Year),
              ano_fim = last(Year),
              n = n(),
              M_global = last(esc_global) / first(esc_global),
              EC = last(esc_contemp) / first(esc_contemp),
              BPC = last(tgr) / first(tgr),
              .groups = "drop") %>%
    arrange(desc(M_global))
  Salva(mutate(malm.global, across(where(is.numeric), ~ round(.x, 3))),
        "t25_malmquist_global_pais")
  Nota("Malmquist global S (", nrow(malm.global),
       " países com 2 anos ou mais, contra 13 no subpainel balanceado): ",
       "M = ", round(MediaGeometrica(malm.global$M_global), 3), " | EC = ",
       round(MediaGeometrica(malm.global$EC), 3), " | BPC = ",
       round(MediaGeometrica(malm.global$BPC), 3))
  Nota("decomposição M = EC × BPC: desvio máximo ",
       signif(max(abs(malm.global$M_global -
                        malm.global$EC * malm.global$BPC)), 2))
  # A comparação com o faremalm2 só é legítima no mesmo período e nos mesmos
  # países, porque o índice global acima cobre todo o intervalo observado de
  # cada país, que varia de dois a nove anos.
  if (exists("indices")) {
    comum <- intersect(malm.global$Country, unique(indices$id))
    global.mesmo.periodo <- tab.meta %>%
      filter(modelo == "S", Country %in% comum,
             Year %in% c(2016, 2021)) %>%
      group_by(Country) %>%
      filter(n() == 2) %>%
      arrange(Year, .by_group = TRUE) %>%
      summarise(M = last(esc_global) / first(esc_global), .groups = "drop")
    balanceado.pais <- indices %>%
      group_by(id) %>%
      summarise(M = MediaGeometrica(pc)^5, .groups = "drop")
    pareado <- inner_join(global.mesmo.periodo,
                          rename(balanceado.pais, Country = id, M_fare = M),
                          by = "Country")
    Nota("Malmquist 2016→2021 nos ", nrow(pareado),
         " países do subpainel: global M = ",
         round(MediaGeometrica(pareado$M), 3), " | faremalm2 acumulado M = ",
         round(MediaGeometrica(pareado$M_fare), 3), " | Spearman = ",
         Spearman(pareado$M, pareado$M_fare))
  }
  figura <- tab.meta %>%
    group_by(modelo, Year) %>%
    summarise(n = n(), tgr = mean(tgr), .groups = "drop") %>%
    ggplot(aes(factor(Year), tgr, fill = modelo)) +
    geom_col(position = "dodge") +
    geom_text(aes(label = n, y = 0.03), position = position_dodge(0.9),
              size = 2.4) +
    theme_bw() +
    labs(x = NULL, fill = "modelo",
         y = paste0("lacuna tecnológica: eficiência contemporânea / ",
                    "eficiência global"))
  ggsave(file.path(kDirFiguras, "fig13_tgr_por_ano.png"), figura, width = 8,
         height = 4, dpi = 150)
})

# Metafronteira por faixa de renda, exploratória: a amostra só comporta dois
# grupos (renda alta contra as demais).
Bloco("metafronteira-renda", {
  grupo.renda <- ifelse(dados$income == "Alta", "Alta", "Média")
  linhas.renda <- map_dfr(c("S", "T"), function(k) {
    x.modelo <- x.extensivo
    y.modelo <- if (k == "S") y.ciencia else y.tecnologia
    eff.global <- eff(modelos[[k]]$vrs)
    eff.grupo <- EficienciaPorGrupo(x.modelo, y.modelo, grupo.renda)
    tibble(modelo = k, grupo = grupo.renda, tgr = eff.grupo / eff.global,
           esc_grupo = pmin(1 / eff.grupo, 1)) %>%
      group_by(modelo, grupo) %>%
      summarise(n = n(), esc_grupo = mean(esc_grupo), tgr = mean(tgr),
                .groups = "drop")
  })
  Salva(mutate(linhas.renda, across(where(is.numeric), ~ round(.x, 3))),
        "t24b_metafronteira_renda")
  Nota("metafronteira por renda (exploratória): ",
       paste(sprintf("%s/%s n=%d TGR=%.2f", linhas.renda$modelo,
                     linhas.renda$grupo, linhas.renda$n, linhas.renda$tgr),
             collapse = " | "))
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
                               ep_cluster = teste.ols[, 2],
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
  # A especialização do sistema científico entra só aqui. A participação
  # contemporânea de IA é simultânea aos produtos do modelo; por isso a
  # versão usada é a anterior ao período (2008-2012), predeterminada, ao lado
  # da participação das ciências exatas e da vida.
  extras <- c("stem_share", "ai_share_pre")
  tem.especializacao <- all(extras %in% names(dados)) &&
    !any(is.na(dados$stem_share[obs.completas])) &&
    !any(is.na(dados$ai_share_pre[obs.completas]))
  if (tem.especializacao) {
    conjuntos[["governanca, voice e STEM"]] <- "+ gov + voice + stem_share"
    conjuntos[["governanca, voice e IA prévia"]] <-
      "+ gov + voice + ai_share_pre"
  }
  base.reg <- cbind(Country = dados$Country,
                    z.contextuais)[obs.completas, ]
  if (tem.especializacao) {
    base.reg$stem_share <- dados$stem_share[obs.completas]
    base.reg$ai_share_pre <- dados$ai_share_pre[obs.completas]
  }
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
          gov_p_tobit = CoefOuNa(estimativas, "gov", 4),
          espec_tobit = coalesce(CoefOuNa(estimativas, "stem_share", 1),
                                 CoefOuNa(estimativas, "ai_share_pre", 1)),
          espec_p_tobit = coalesce(CoefOuNa(estimativas, "stem_share", 4),
                                   CoefOuNa(estimativas, "ai_share_pre", 4)))
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
    # O erro padrão e o valor-p saem da distribuição bootstrap dos betas, para
    # que o painel do Simar-Wilson entre na tabela de regressões no mesmo
    # formato dos demais estimadores.
    env.log[[k]] <- tibble(
      modelo = k,
      versao = "log(delta) (implementação própria)",
      variavel = c("(Intercepto)", colnames(z.contextuais)),
      beta = as.numeric(log.delta$beta),
      ic_inf = log.delta$ci[, 1],
      ic_sup = log.delta$ci[, 2],
      ep_boot = apply(log.delta$betas, 2, sd, na.rm = TRUE),
      p_boot = apply(log.delta$betas, 2, function(b) {
        2 * min(mean(b <= 0, na.rm = TRUE), mean(b >= 0, na.rm = TRUE))
      }),
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

# A segunda sessão pediu, para o manuscrito, a tabela das regressões com os
# três modelos avaliados à luz das mesmas contextuais, e uma discussão
# baseada nas diferenças entre eles.

Bloco("tab-regressoes-paper", {
  ordem.contextuais <- c("manuf_pib", "manuf_exp", "gov", "voice",
                         "ln_gdppc", "trade", "z_score", "npl", "zero_inv",
                         "tend")
  rotulos <- c(manuf_pib = "Manufatura (% do PIB)",
               manuf_exp = "Manufaturados (% das exportações)",
               gov = "Governança (índice)",
               voice = "Voz e responsabilização",
               ln_gdppc = "ln PIB per capita",
               trade = "Comércio (% do PIB)",
               z_score = "Z-score bancário",
               npl = "Empréstimos inadimplentes",
               zero_inv = "Investimento igual a zero",
               tend = "Tendência")
  painel.tobit <- bind_rows(tobits) %>%
    filter(escore %in% c("bcc_S", "bcc_T", "bcc_C"),
           variavel %in% ordem.contextuais) %>%
    transmute(painel = "A. Tobit", modelo = sub("bcc_", "", escore),
              variavel, coeficiente = coef, erro_padrao = ep, p)
  painel.ols <- bind_rows(ols.cluster) %>%
    filter(escore %in% c("bcc_S", "bcc_T", "bcc_C"),
           variavel %in% ordem.contextuais) %>%
    transmute(painel = "B. MQO com erros agrupados por país",
              modelo = sub("bcc_", "", escore), variavel,
              coeficiente = coef_ols, erro_padrao = ep_cluster,
              p = p_cluster)
  painel.sw <- bind_rows(env.log) %>%
    filter(variavel %in% ordem.contextuais) %>%
    transmute(painel = "C. Simar-Wilson em log(delta)", modelo, variavel,
              coeficiente = beta, erro_padrao = ep_boot, p = p_boot)
  regressoes <- bind_rows(painel.tobit, painel.ols, painel.sw) %>%
    mutate(variavel = factor(variavel, levels = ordem.contextuais)) %>%
    arrange(painel, variavel, modelo)
  Salva(mutate(regressoes, across(where(is.numeric), ~ signif(.x, 4))),
        "t20_regressoes_longa")

  larga <- regressoes %>%
    mutate(celula = FormataCelula(coeficiente, erro_padrao, p)) %>%
    select(painel, variavel, modelo, celula) %>%
    pivot_wider(names_from = modelo, values_from = celula) %>%
    arrange(painel, variavel) %>%
    mutate(contextual = rotulos[as.character(variavel)], .before = variavel) %>%
    select(-variavel)
  Salva(larga, "t20_regressoes_paper")
  nota.rodape <- paste0(
    "n = ", sum(obs.completas), " observações país-ano. Erros padrão entre ",
    "parênteses; *** p < 0,01, ** p < 0,05, * p < 0,10. Painéis A e B: ",
    "coeficiente positivo indica mais eficiência. Painel C: coeficiente ",
    "sobre o logaritmo da distância à fronteira, de modo que o sinal ",
    "negativo indica mais eficiência; erro padrão e valor-p vêm de ",
    kEnvL2, " réplicas bootstrap.")
  writeLines(c("| Painel | Contextual | S | T | C |",
               "|---|---|---|---|---|",
               sprintf("| %s | %s | %s | %s | %s |", larga$painel,
                       larga$contextual, larga$S, larga$T, larga$C),
               "", nota.rodape),
             file.path(kDirResultados, "t20_regressoes_paper.md"))

  # Leitura das nuances: em que modelos cada contextual é significativa e em
  # que sentido, já com o sinal do painel C invertido para que "+" signifique
  # sempre mais eficiência.
  nuances <- regressoes %>%
    mutate(sinal = ifelse(grepl("^C\\.", painel), -sign(coeficiente),
                          sign(coeficiente)),
           relevante = !is.na(p) & p < 0.05) %>%
    group_by(contextual = rotulos[as.character(variavel)], modelo) %>%
    summarise(n_signif = sum(relevante),
              sentido = ifelse(n_signif == 0, "·",
                               ifelse(n_distinct(sinal[relevante]) > 1, "±",
                                      ifelse(first(sinal[relevante]) > 0,
                                             "+", "−"))),
              .groups = "drop") %>%
    mutate(marca = paste0(sentido, n_signif)) %>%
    select(contextual, modelo, marca) %>%
    pivot_wider(names_from = modelo, values_from = marca)
  Salva(nuances, "t20b_nuances_contextuais")
  print(as.data.frame(nuances))
  resumo <<- c(resumo,
               paste0("Nuances entre modelos (sentido e nº de estimadores ",
                      "significativos a 5%; + = mais eficiência):"),
               capture.output(print(as.data.frame(nuances))))
})

Bloco("fig11", {
  # O rótulo marca os países cuja média vem de menos de kMinAnosPais anos e os
  # que só têm anos sem investimento, para que o topo do ranking não seja lido
  # sem essa ressalva.
  figura <- medias.pais %>%
    mutate(rotulo = paste0(Country,
                           ifelse(no_ranking, "", " (n<3)"),
                           ifelse(n_zeros > 0,
                                  paste0(" \u2020", n_zeros), "")),
           rotulo = fct_reorder(rotulo, bcc_C)) %>%
    ggplot(aes(rotulo, bcc_C, fill = manuf_pib)) +
    geom_col(aes(alpha = no_ranking)) +
    scale_alpha_manual(values = c(`TRUE` = 1, `FALSE` = 0.45), guide = "none") +
    coord_flip() +
    theme_bw() +
    labs(x = NULL,
         y = paste0("eficiência de conversão pesquisa → patente (BCC, ",
                    "média dos anos); \u2020 = anos sem investimento"),
         fill = "manufatura\n% PIB")
  ggsave(file.path(kDirFiguras, "fig11_conversao_pais.png"), figura, width = 7,
         height = 8, dpi = 150)
})
# 15b. Casos discutidos no manuscrito -----------------------------------

# A segunda sessão pediu que os países que quebram o padrão, no topo e na
# cauda do ranking, virem casos na discussão. A tabela reúne, para cada um, o
# que o trabalho mede, quem lhe serve de referência e as marcas que explicam
# posições surpreendentes: anos sem investimento, poucos anos observados e
# supereficiência.

Nota("=== 15b. Casos discutidos no manuscrito ===")
Bloco("casos", {
  pares.conversao <- peers(modelos$C$vrs)
  nomes.pares.c <- apply(pares.conversao, 1, function(linha) {
    paste(dados$Country_Year[linha[!is.na(linha)]], collapse = "; ")
  })
  casos <- escores %>%
    transmute(Country, Year, Country_Year, zero_inv,
              inv_const_mi = dados$inv_const / 1e6,
              rd_mi = dados$rd_usd / 1e6,
              pubs = dados$pubs,
              pat = dados$pat,
              manuf_pib,
              bcc_S, bcc_T, bcc_C,
              pares_C = nomes.pares.c) %>%
    filter(Country %in% kPaisesCaso) %>%
    left_join(select(escores, Country_Year, bcc_ST), by = "Country_Year") %>%
    arrange(Country, Year)
  if (exists("supereficiencia")) {
    casos <- left_join(casos,
                       select(supereficiencia, Country_Year = DMU,
                              super_CRS),
                       by = "Country_Year")
  }
  if (length(metafronteira) > 0) {
    tgr.c <- bind_rows(metafronteira) %>%
      filter(modelo == "C") %>%
      select(Country_Year, tgr)
    casos <- left_join(casos, tgr.c, by = "Country_Year")
  }
  Salva(mutate(casos, across(where(is.numeric), ~ round(.x, 4))),
        "t26_casos_discussao")
  ancoras <- casos %>%
    filter(zero_inv, bcc_C >= 1 - kTolEfic)
  Nota("casos: ", n_distinct(casos$Country), " países, ", nrow(casos),
       " observações | eficientes em C sem investimento: ",
       paste(ancoras$Country_Year, collapse = ", "))
})

# Conferência da variável de patentes: se AI.Patent.Applications acompanha os
# depósitos de residentes no escritório nacional, a leitura de que os países
# que depositam via EPO e PCT aparecem com patente quase nula ganha evidência
# dentro da própria base.
Bloco("patentes-escritorio", {
  por.pais <- dados %>%
    group_by(Country) %>%
    summarise(pat = mean(pat),
              residentes = mean(PatentResidents),
              nao_residentes = mean(PatentNonResidents),
              total = mean(Total_Patents),
              pop_mi = mean(pop_mi),
              epo = first(Country %in% kPaisesEpo),
              .groups = "drop")
  Nota("patentes de IA × depósitos na base (médias por país): ",
       "cor(log pat, log residentes) = ",
       round(cor(log(por.pais$pat), log(por.pais$residentes),
                 use = "complete.obs"), 3),
       " | cor(log pat, log não residentes) = ",
       round(cor(log(por.pais$pat), log(por.pais$nao_residentes),
                 use = "complete.obs"), 3))
  Nota("razão patentes de IA / depósitos de residentes: mediana ",
       round(1000 * median(por.pais$pat[por.pais$epo] /
                             por.pais$residentes[por.pais$epo]), 2),
       " por mil nos 13 países que depositam via EPO/PCT contra ",
       round(1000 * median(por.pais$pat[!por.pais$epo] /
                             por.pais$residentes[!por.pais$epo]), 2),
       " por mil nos demais (valores sobre médias por país)")
  Salva(mutate(por.pais, across(where(is.numeric), ~ round(.x, 4))),
        "t27_patentes_escritorio")
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
