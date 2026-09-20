# SFA como na aula (Benchmarking::sfa), Cobb-Douglas em log: modelo S
# (publicações) e modelo T (patentes).
sfa.s <- sfa(log(x.extensivo), log(dados$pubs))
sfa.t <- sfa(log(x.extensivo), log(dados$pat))
cat("S: lambda =", round(lambda.sfa(sfa.s)[1], 2), "| T: lambda =",
    round(lambda.sfa(sfa.t)[1], 2), "\n")
bcc.t <- Escore(dea(x.extensivo, as.matrix(dados$pat), RTS = "vrs",
                    ORIENTATION = "out"))
cat("T: elasticidades (investimento, P&D) =",
    paste(round(coef(sfa.t)[2:3], 2), collapse = " / "), "| TE média =",
    round(mean(te.sfa(sfa.t)), 2), "| cor(TE_SFA, BCC_T) =",
    round(cor(te.sfa(sfa.t), bcc.t), 2), "\n")
