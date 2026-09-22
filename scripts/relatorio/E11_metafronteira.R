# A fronteira agrupada como metafronteira: eficiência contra a fronteira do
# próprio ano (contemporânea), contra a união das fronteiras anuais e contra
# a fronteira global, e a lacuna tecnológica que resulta da comparação.
EficienciaPorGrupo <- function(x, y, grupo) {
  # Eficiência de Farrell contra a fronteira do próprio grupo.
  resultado <- rep(NA_real_, nrow(x))
  for (g in unique(grupo)) {
    linhas <- which(grupo == g)
    resultado[linhas] <- eff(dea(x[linhas, , drop = FALSE],
                                 y[linhas, , drop = FALSE],
                                 RTS = "vrs", ORIENTATION = "out"))
  }
  resultado
}
EficienciaUniao <- function(x, y, grupo) {
  # Metafronteira não convexa: melhor fronteira de grupo para cada DMU.
  por.grupo <- sapply(unique(grupo), function(g) {
    ref <- which(grupo == g)
    eff(dea(x, y, RTS = "vrs", ORIENTATION = "out",
            XREF = x[ref, , drop = FALSE], YREF = y[ref, , drop = FALSE]))
  })
  apply(por.grupo, 1, function(linha) max(linha[is.finite(linha)]))
}

y.patentes <- as.matrix(dados[, "pat", drop = FALSE])
eff.global <- eff(dea(x.extensivo, y.patentes, RTS = "vrs",
                      ORIENTATION = "out"))
eff.contemp <- EficienciaPorGrupo(x.extensivo, y.patentes, dados$Year)
eff.uniao <- EficienciaUniao(x.extensivo, y.patentes, dados$Year)
tgr <- eff.contemp / eff.global
cat("modelo T | eficientes contra o próprio ano",
    round(100 * mean(eff.contemp <= 1 + 1e-6), 1), "% | contra a fronteira",
    "global", round(100 * mean(eff.global <= 1 + 1e-6), 1), "%\n")
cat("lacuna tecnológica média:", round(mean(tgr), 3),
    "| contra a união não convexa:", round(mean(eff.contemp / eff.uniao), 3),
    "| efeito da convexificação:",
    round(mean(eff.global / eff.uniao), 3), "\n")
cat("lacuna por ano:\n")
print(round(tapply(tgr, dados$Year, mean), 2))

# Malmquist global (Pastor & Lovell, 2005): a fronteira global serve de
# referência única, de modo que o índice não exige painel balanceado.
esc.global <- pmin(1 / eff.global, 1)
esc.contemp <- pmin(1 / eff.contemp, 1)
malm <- tibble(Country = dados$Country, Year = dados$Year,
               esc.global, esc.contemp, tgr) %>%
  group_by(Country) %>%
  filter(n() >= 2) %>%
  arrange(Year, .by_group = TRUE) %>%
  summarise(M = last(esc.global) / first(esc.global),
            EC = last(esc.contemp) / first(esc.contemp),
            BPC = last(tgr) / first(tgr), .groups = "drop")
MediaGeometrica <- function(v) exp(mean(log(v)))
cat("Malmquist global do modelo T em", nrow(malm),
    "países (contra 13 no subpainel balanceado): M =",
    round(MediaGeometrica(malm$M), 3), "| EC =",
    round(MediaGeometrica(malm$EC), 3), "| BPC =",
    round(MediaGeometrica(malm$BPC), 3), "\n")
