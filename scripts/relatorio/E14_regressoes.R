# A tabela de regressões do manuscrito: as mesmas contextuais nos três
# modelos, em três estimadores. O arquivo é gerado por scripts/pipeline_v3.R.
tabela <- read_csv("resultados/t20_regressoes_paper.csv",
                   show_col_types = FALSE)
print(as.data.frame(filter(tabela, painel == "A. Tobit")), right = FALSE)
nuances <- read_csv("resultados/t20b_nuances_contextuais.csv",
                    show_col_types = FALSE)
cat("\nsentido e número de estimadores significativos a 5%",
    "(+ = mais eficiência):\n")
print(as.data.frame(nuances), right = FALSE)
