# Os 17 zeros de investimento e o deslocamento proposto na v2 (US$ 1, 10 e
# 100 mi) no CCR anual, modelo ST com as unidades da v2.
for (shift in c(0.001, 0.01, 0.1)) {
  ccr <- PorAno(cbind(dados$inv_bi + shift, dados$R.D_Percentage),
                cbind(dados$AI.Publications, dados$AI.Patent.Applications),
                "crs")
  cat(sprintf(paste0("shift US$ %3.0f mi | CCR médio dos 17 zeros %.3f | ",
                     "eficientes %.1f%%\n"),
              shift * 1e3, mean(ccr[dados$zero_inv]),
              100 * mean(ccr[dados$zero_inv] >= 1 - 1e-6)))
}
cat("menor investimento positivo: US$ 1 mi | mediana: US$ 89,6 mi\n")
# O BCC orientado a produto é invariante a translações do insumo
# (Ali & Seiford, 1990):
bcc.1mi <- PorAno(cbind(dados$inv_bi + 0.001, dados$R.D_Percentage),
                  cbind(dados$AI.Publications))
bcc.100mi <- PorAno(cbind(dados$inv_bi + 0.1, dados$R.D_Percentage),
                    cbind(dados$AI.Publications))
cat("max |BCC(shift 1 mi) - BCC(shift 100 mi)| =",
    signif(max(abs(bcc.1mi - bcc.100mi)), 2), "\n")
# v3: deslocamento de metade do menor positivo (US$ 0,5 mi) e robustez sem
# os zeros, na fronteira agrupada.
positivos <- which(!dados$zero_inv)
sem.zeros <- Escore(dea(x.extensivo[positivos, ], y.ambos[positivos, ],
                        RTS = "vrs", ORIENTATION = "out"))
cat("Spearman(ST agrupada com os zeros, sem os zeros) =",
    Spearman(st.agrupada[positivos], sem.zeros), "\n")
