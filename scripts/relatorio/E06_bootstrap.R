# Bootstrap de Simar-Wilson como na aula (rDEA::dea.robust), modelo T na
# fronteira agrupada.
boot <- dea.robust(x.extensivo, as.matrix(dados$pat), model = "output",
                   RTS = "variable", B = 500, alpha = 0.05)
summary(boot$theta_hat_hat)  # corrigidos de viés, como saem do pacote
cat("escores negativos:", sum(boot$theta_hat_hat < 0), "de",
    length(boot$theta_hat_hat), "\n")
# Mudança: a mesma correção, feita na escala de Farrell (phi = 1 / theta)
# com as réplicas que o pacote devolve.
phi <- 1 / boot$theta_hat
phi.star <- 1 / boot$theta_hat_star
vies <- rowMeans(phi.star - phi)
theta.bc <- 1 / (phi - vies)
summary(theta.bc)
cat("negativos:", sum(theta.bc < 0), "| Spearman com o escore original:",
    Spearman(theta.bc, boot$theta_hat), "\n")
