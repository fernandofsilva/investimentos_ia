# Especificação da v2: fronteiras anuais; insumos = investimento em US$ bi
# (+ US$ 10 mi) e P&D em % do PIB; produto = publicações (contagem) no
# modelo S e patentes PER CAPITA no modelo T.
x.v2 <- cbind(dados$inv_bi + 0.01, dados$R.D_Percentage)
escore.s <- PorAno(x.v2, cbind(dados$AI.Publications))
escore.t <- PorAno(x.v2, cbind(dados$AI.Patent.Applications))
cat("Spearman(S, T) =", Spearman(escore.s, escore.t), "\n")
por.pais <- dados %>%
  mutate(gap = escore.t - escore.s) %>%
  group_by(Country) %>%
  summarise(gap = mean(gap),
            log_pop = log(mean(pop_mi)),
            log_pibpc = log(mean(GDP.per.capita))) %>%
  arrange(gap)
cat("S >> T (publica, não patenteia):",
    paste(head(por.pais$Country, 6), round(head(por.pais$gap, 6), 2),
          collapse = ", "), "\n")
cat("T >> S:",
    paste(rev(tail(por.pais$Country, 3)),
          round(rev(tail(por.pais$gap, 3)), 2), collapse = ", "), "\n")
cat("cor(gap, log população) =",
    round(cor(por.pais$gap, por.pais$log_pop), 2), "\n")
round(summary(lm(gap ~ log_pop + log_pibpc,
                 data = por.pais))$coefficients, 3)
