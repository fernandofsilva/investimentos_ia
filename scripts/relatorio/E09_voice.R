# Voice & Accountability (WGI) entra nas contextuais: Tobit (censReg) e OLS
# com erros por país sobre o escore de conversão C.
escore.c <- Escore(dea(as.matrix(dados[, c("pubs", "inv_usd", "rd_usd")]),
                       as.matrix(dados$pat), RTS = "vrs",
                       ORIENTATION = "out"))
reg <- cbind(y = escore.c, Country = dados$Country, contextuais,
             voice = dados$voice)[completas, ]
sem.voice <- y ~ manuf_pib + manuf_exp + gov + ln_gdppc + trade + z_score +
  npl + zero_inv + tend
com.voice <- update(sem.voice, . ~ . + voice)

ResumoH1 <- function(formula.reg, amostra) {
  # Coeficiente da manufatura no Tobit e no OLS com erros por país.
  estimativas <- summary(censReg(formula.reg, left = 0, right = 1,
                                 data = amostra))$estimate
  modelo <- lm(formula.reg, data = amostra)
  teste <- coeftest(modelo,
                    vcov = vcovCL(modelo, cluster = amostra$Country))
  sprintf("manuf_pib: Tobit %.4f (p %.3f) | OLS-cluster p %.3f | n = %d",
          estimativas["manuf_pib", 1], estimativas["manuf_pib", 4],
          teste["manuf_pib", 4], nrow(amostra))
}
cat("sem voice:", ResumoH1(sem.voice, reg), "\ncom voice:",
    ResumoH1(com.voice, reg), "\n")
cat("cor(manuf_pib, voice) =", round(cor(reg$manuf_pib, reg$voice), 2), "\n")
epo <- c("Switzerland", "Netherlands", "Belgium", "Ireland", "Norway",
         "Israel", "France", "Austria", "United Kingdom", "Portugal",
         "Italy", "Spain", "Greece")
reg.sem.epo <- reg[!reg$Country %in% epo, ]
cat("sem os 13 países de patente ~0, sem voice:",
    ResumoH1(sem.voice, reg.sem.epo),
    "\nsem os 13 países de patente ~0, com voice:",
    ResumoH1(com.voice, reg.sem.epo), "\n")
estimativas <- summary(censReg(com.voice, left = 0, right = 1,
                               data = reg))$estimate
cat("voice: Tobit", round(estimativas["voice", 1], 4), "(p",
    signif(estimativas["voice", 4], 2), ") | voice médio: 13 países",
    round(mean(reg$voice[reg$Country %in% epo])), "vs demais",
    round(mean(reg$voice[!reg$Country %in% epo])), "| China",
    round(mean(reg$voice[reg$Country == "China"])), "\n")
