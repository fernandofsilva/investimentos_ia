# Fronteiras anuais (16 a 30 DMUs) contra fronteira agrupada (208 DMUs),
# forma extensiva, modelo ST.
st.anual <- PorAno(x.extensivo, y.ambos)
st.agrupada <- Escore(dea(x.extensivo, y.ambos, RTS = "vrs",
                          ORIENTATION = "out"))
cat("n por ano:          ", paste(table(dados$Year), collapse = "   "), "\n")
cat("anual    | eficientes", round(100 * mean(st.anual >= 1 - 1e-6), 1),
    "% | média por ano:",
    paste(sprintf("%.2f", tapply(st.anual, dados$Year, mean)),
          collapse = " "), "\n")
cat("agrupada | eficientes",
    round(100 * mean(st.agrupada >= 1 - 1e-6), 1), " % | média por ano:",
    paste(sprintf("%.2f", tapply(st.agrupada, dados$Year, mean)),
          collapse = " "), "\n")
cat("Spearman(anual, agrupada) =", Spearman(st.anual, st.agrupada), "\n")
