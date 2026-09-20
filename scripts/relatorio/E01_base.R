# O que a base mede? As patentes per capita viram inteiros quando
# multiplicadas pela população?
dados %>%
  filter(Year == 2021) %>%
  arrange(desc(AI.Patent.Applications)) %>%
  slice(1:4) %>%
  transmute(Country,
            pat_pm = round(AI.Patent.Applications, 1),
            pop_mi = round(pop_mi, 1),
            pat_cnt = round(pat),
            pubs = AI.Publications)
fracao <- dados$pat %% 1
cat("contagens a menos de 0,02 de um inteiro:",
    round(100 * mean(pmin(fracao, 1 - fracao) < 0.02)),
    "% (esperado ao acaso: 4%)\n")
cat("cor(log publicações, log população) =",
    round(cor(log(dados$AI.Publications), log(dados$pop_mi)), 2),
    "| cor(log patentes per capita, log população) =",
    round(cor(log(dados$AI.Patent.Applications), log(dados$pop_mi)), 2), "\n")
cat("zeros em AI.Investment:", sum(dados$zero_inv),
    "| menor valor positivo: US$",
    formatC(min(dados$AI.Investment[dados$AI.Investment > 0]),
            format = "d", big.mark = ".", decimal.mark = ","), "\n")
cat("colunas log_* são log1p? max|log_RD_Percentage - log1p(R.D_Percentage)| =",
    signif(max(abs(dados$log_RD_Percentage -
                     log1p(dados$R.D_Percentage))), 2), "\n")
