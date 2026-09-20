# Segundo estágio como na aula: rDEA::dea.env.robust é o Algoritmo 2 de
# Simar-Wilson com regressão truncada LINEAR em delta.
contextuais <- dados %>%
  transmute(manuf_pib, manuf_exp, gov, ln_gdppc,
            trade = Trade_Percentage, z_score = Z_Score,
            npl = Non.performing.Loans, zero_inv = as.numeric(zero_inv),
            tend)
completas <- complete.cases(contextuais)
y.patentes <- as.matrix(dados$pat)
linear <- dea.env.robust(x.extensivo[completas, ],
                         y.patentes[completas, , drop = FALSE],
                         Z = contextuais[completas, ], model = "output",
                         RTS = "variable", L1 = 50, L2 = 500, alpha = 0.05)
cat("delta = distância à fronteira: mediana",
    round(median(linear$delta_hat), 1), "| máximo",
    round(max(linear$delta_hat), 1), "| sigma_hat =",
    round(linear$sigma_hat, 1), "\n")
tabela <- cbind(beta = linear$beta_hat, IC_inf = linear$beta_ci[, 1],
                IC_sup = linear$beta_ci[, 2])
rownames(tabela) <- c("(Intercepto)", colnames(contextuais))
round(tabela[2:4, ], 2)

# Mudança: o mesmo Algoritmo 2 com a regressão truncada em log(delta),
# porque delta tem cauda pesada.
AmostraNormalTruncada <- function(media, desvio) {
  # Normal truncada à esquerda em zero: media + eps, com eps >= -media.
  u <- runif(length(media))
  limite <- pnorm(-media / desvio)
  media + desvio * qnorm(limite + u * (1 - limite))
}

AjustaTruncada <- function(y, z) {
  # Regressão truncada de y sobre as contextuais, truncatura em zero.
  dados.ajuste <- data.frame(y = y, z)
  truncreg(y ~ ., data = dados.ajuste[y > 1e-9, ], point = 0,
           direction = "left")
}

SimarWilsonLog <- function(x, y, z, l1 = 50, l2 = 500) {
  # Algoritmo 2 de Simar-Wilson com a regressão truncada em log(delta).
  z <- as.matrix(z)
  n.z <- ncol(z)
  delta <- eff(dea(x, y, RTS = "vrs", ORIENTATION = "out"))
  ajuste1 <- AjustaTruncada(log(delta), z)
  beta1 <- coef(ajuste1)[1:(n.z + 1)]
  sigma1 <- coef(ajuste1)[["sigma"]]
  media1 <- as.numeric(cbind(1, z) %*% beta1)
  delta.star <- sapply(1:l1, function(b) {
    y.star <- y * delta / exp(AmostraNormalTruncada(media1, sigma1))
    eff(dea(x, y, RTS = "vrs", ORIENTATION = "out", XREF = x, YREF = y.star))
  })
  delta.bc <- pmax(delta - (rowMeans(delta.star) - delta), 1 + 1e-6)
  ajuste2 <- AjustaTruncada(log(delta.bc), z)
  beta2 <- coef(ajuste2)[1:(n.z + 1)]
  sigma2 <- coef(ajuste2)[["sigma"]]
  media2 <- as.numeric(cbind(1, z) %*% beta2)
  betas <- t(sapply(1:l2, function(b) {
    replica <- AmostraNormalTruncada(media2, sigma2)
    coef(AjustaTruncada(replica, z))[1:(n.z + 1)]
  }))
  list(beta = beta2, ci = t(apply(betas, 2, quantile, c(.025, .975))),
       sigma = sigma2)
}

# Os avisos de NaN vêm da verossimilhança do truncreg em pontos extremos.
log.delta <- suppressWarnings(
  SimarWilsonLog(x.extensivo[completas, ],
                 y.patentes[completas, , drop = FALSE],
                 contextuais[completas, ]))
cat("sigma =", round(log.delta$sigma, 2), "\n")
round(cbind(beta = log.delta$beta, IC_inf = log.delta$ci[, 1],
            IC_sup = log.delta$ci[, 2])[2:4, ], 3)
