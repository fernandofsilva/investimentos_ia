# Quem define a fronteira entre as observações sem investimento: sob VRS
# orientado a produto, uma DMU com insumo zero só pode ser dominada por
# outras com insumo zero.
sem.investimento <- which(dados$zero_inv)
y.patentes <- as.matrix(dados[, "pat", drop = FALSE])
escore.c <- Escore(dea(as.matrix(dados[, c("pubs", "inv_usd", "rd_usd")]),
                       y.patentes, RTS = "vrs", ORIENTATION = "out"))
cat("observações sem investimento:", length(sem.investimento), "de",
    nrow(dados), "| eficientes em C:",
    paste(dados$Country_Year[sem.investimento][
      escore.c[sem.investimento] >= 1 - 1e-6], collapse = ", "), "\n")
menor.pd <- sem.investimento[which.min(dados$rd_usd[sem.investimento])]
cat("menor P&D entre elas:", dados$Country_Year[menor.pd], "com US$",
    round(dados$rd_usd[menor.pd] / 1e6), "milhões e escore",
    round(escore.c[menor.pd], 3), "\n")

# O ranking por país com e sem os anos sem investimento, e o efeito de
# exigir um mínimo de anos observados.
por.pais <- tibble(Country = dados$Country, zero = dados$zero_inv,
                   escore.c) %>%
  group_by(Country) %>%
  summarise(n = n(),
            todos = mean(escore.c),
            positivos = ifelse(all(zero), NA_real_, mean(escore.c[!zero])),
            .groups = "drop") %>%
  arrange(desc(todos))
cat("top 6 com todos os anos:",
    paste(head(por.pais$Country, 6), round(head(por.pais$todos, 6), 2),
          collapse = ", "), "\n")
ordenado <- arrange(filter(por.pais, !is.na(positivos)), desc(positivos))
cat("top 6 só com anos de investimento positivo:",
    paste(head(ordenado$Country, 6), round(head(ordenado$positivos, 6), 2),
          collapse = ", "), "\n")
cat("países com menos de 3 anos observados:",
    paste(filter(por.pais, n < 3)$Country, collapse = ", "), "\n")
