# A v2 rebaixou o Malmquist alegando painel desbalanceado. No subpainel
# 2016-2021 ele roda como na aula (nonparaeff::faremalm2).
balanceado <- dados %>%
  group_by(Country) %>%
  filter(all(2016:2021 %in% Year)) %>%
  ungroup() %>%
  filter(Year %in% 2016:2021) %>%
  arrange(Country, Year)
entrada <- data.frame(id = balanceado$Country, year = balanceado$Year,
                      y = balanceado$pubs, x1 = balanceado$inv_usd,
                      x2 = balanceado$rd_usd)
invisible(capture.output(
  malm <- faremalm2(entrada, noutput = 1, id = "id", year = "year")))
MediaGeometrica <- function(v) exp(mean(log(v)))
cat(n_distinct(balanceado$Country), "países | Malmquist =",
    round(MediaGeometrica(malm$pc), 3), "| catch-up =",
    round(MediaGeometrica(malm$ec), 3), "| deslocamento da fronteira =",
    round(MediaGeometrica(malm$tc), 3), "\n")
# FDH e Order-m (nonparaeff::orderm), modelo S na fronteira agrupada.
fdh <- Escore(dea(x.extensivo, as.matrix(dados$pubs), RTS = "fdh",
                  ORIENTATION = "out"))
cat("FDH agrupada: eficientes", round(100 * mean(fdh >= 1 - 1e-6)),
    "% (anual: 53%)\n")
invisible(capture.output(
  order.m <- orderm(data.frame(x.extensivo, dados$pubs), noutput = 1,
                    orientation = 2, M = 25, B = 100)))
cat("order-m (m = 25): lambda_m mediano", round(median(order.m$eff), 2),
    "| acima da fronteira parcial (eff < 1):",
    round(100 * mean(order.m$eff < 1)), "%\n")
