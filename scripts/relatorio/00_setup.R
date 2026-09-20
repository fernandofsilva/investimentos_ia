# Preparação comum aos trechos deste relatório: base tratada pelo pipeline
# (resultados/base_v3.csv) e funções auxiliares no padrão do template.
suppressPackageStartupMessages({
  library(tidyverse)
  library(Benchmarking)
  library(rDEA)
  library(nonparaeff)
  library(censReg)
  library(truncreg)
  library(sandwich)
  library(lmtest)
})
select <- dplyr::select
filter <- dplyr::filter
lag <- dplyr::lag
dea <- Benchmarking::dea
set.seed(1)

dados <- read_csv("resultados/base_v3.csv", show_col_types = FALSE) %>%
  mutate(inv_bi = AI.Investment / 1e9)
x.extensivo <- as.matrix(dados[, c("inv_usd", "rd_usd")])  # forma da v3
y.ambos <- as.matrix(dados[, c("pubs", "pat")])

Escore <- function(modelo) {
  # Escore em (0, 1], como no template da disciplina (1 / eff).
  pmin(1 / eff(modelo), 1)
}

PorAno <- function(x, y, rts = "vrs") {
  # Estima uma fronteira por ano e devolve o escore de cada DMU.
  escore <- rep(NA_real_, nrow(dados))
  for (ano in unique(dados$Year)) {
    linhas <- which(dados$Year == ano)
    escore[linhas] <- Escore(dea(x[linhas, , drop = FALSE],
                                 y[linhas, , drop = FALSE],
                                 RTS = rts, ORIENTATION = "out"))
  }
  escore
}

Spearman <- function(a, b) {
  # Correlação de postos, arredondada para leitura.
  round(cor(a, b, method = "spearman", use = "complete.obs"), 3)
}
