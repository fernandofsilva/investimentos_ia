# A cobertura da base: anos observados por país, observações sem
# investimento e ausências nas contextuais, antes de qualquer preenchimento.
cobertura <- dados %>%
  group_by(Country) %>%
  summarise(n_anos = n(), n_zeros = sum(zero_inv), .groups = "drop")
cat("países com os 9 anos:", sum(cobertura$n_anos == 9),
    "| com menos de 3:",
    paste(filter(cobertura, n_anos < 3)$Country, collapse = ", "), "\n")
cat("DMUs por ano:", paste(table(dados$Year), collapse = " "), "\n")
cat("anos sem investimento por país:",
    paste(sprintf("%s %d/%d", filter(cobertura, n_zeros > 0)$Country,
                  filter(cobertura, n_zeros > 0)$n_zeros,
                  filter(cobertura, n_zeros > 0)$n_anos),
          collapse = ", "), "\n")
contextuais.auditadas <- c("manuf_pib", "manuf_exp", "gov", "voice",
                           "ln_gdppc", "Trade_Percentage", "Z_Score",
                           "Non.performing.Loans", "pesq_pm")
faltas <- sapply(contextuais.auditadas, function(v) sum(is.na(dados[[v]])))
cat("ausências nas contextuais:",
    paste(names(faltas), faltas, collapse = " | "), "\n")
