# Executa os trechos do relatório em sequência, no mesmo ambiente, e grava
# a saída literal de cada um em resultados/prints/. Pode ser chamado da raiz
# do repositório ou de qualquer subpasta dele.

LocalizaRaiz <- function() {
  # Sobe diretórios até encontrar a pasta dados/ com a base principal.
  pasta <- getwd()
  for (i in 1:5) {
    if (file.exists(file.path(pasta, "dados", "AI_INVESTMENT.csv"))) {
      return(pasta)
    }
    pasta <- dirname(pasta)
  }
  stop("Execute a partir do repositório investimentos_ia.")
}
setwd(LocalizaRaiz())

ambiente <- new.env()
arquivos <- sort(list.files("scripts/relatorio",
                            pattern = "^(00|E[0-9]{2})_.*\\.R$",
                            full.names = TRUE))
for (arquivo in arquivos) {
  avisos <- character(0)
  saida <- withCallingHandlers(
    capture.output(tryCatch(source(arquivo, local = ambiente, echo = FALSE,
                                   print.eval = TRUE),
                            error = function(e) {
                              cat("ERRO:", conditionMessage(e), "\n")
                            })),
    warning = function(w) {
      avisos <<- c(avisos, paste("Warning message:", conditionMessage(w)))
      invokeRestart("muffleWarning")
    })
  saida <- saida[!grepl("^gdata|perl", saida)]
  destino <- file.path("resultados/prints",
                       sub("\\.R$", ".out.txt", basename(arquivo)))
  writeLines(c(saida, avisos), destino)
  cat("==", basename(arquivo), "->", length(saida), "linhas\n")
}
