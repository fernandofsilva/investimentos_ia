# Mesmos modelos com unidades consistentes: (a) tudo per capita;
# (b) tudo em contagem e dólares, que é a forma adotada na v3.
x.intensivo <- cbind(dados$inv_pc, dados$rd_pct)
escore.s.pc <- PorAno(x.intensivo, cbind(dados$pubs_pm))
escore.t.pc <- PorAno(x.intensivo, cbind(dados$pat_pm))
escore.s.cont <- PorAno(x.extensivo, cbind(dados$pubs))
escore.t.cont <- PorAno(x.extensivo, cbind(dados$pat))

GapPais <- function(ciencia, tecnologia) {
  # Gap médio por país entre o escore tecnológico e o científico.
  dados %>%
    mutate(gap = tecnologia - ciencia) %>%
    group_by(Country) %>%
    summarise(gap = round(mean(gap), 2)) %>%
    deframe()
}
paises <- c("Brazil", "India", "Spain", "Italy", "Luxembourg", "Singapore",
            "United States")
cbind(v2_mista = GapPais(escore.s, escore.t)[paises],
      per_capita = GapPais(escore.s.pc, escore.t.pc)[paises],
      contagem = GapPais(escore.s.cont, escore.t.cont)[paises])
cat("Spearman do escore S: v2 × per capita =",
    Spearman(escore.s, escore.s.pc), "| v2 × contagem =",
    Spearman(escore.s, escore.s.cont), "\n")
cat("Spearman do escore T: v2 × per capita =",
    Spearman(escore.t, escore.t.pc), "| v2 × contagem =",
    Spearman(escore.t, escore.t.cont), "\n")
