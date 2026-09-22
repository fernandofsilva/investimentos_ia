# A produção de IA da base contra o OpenAlex e a composição da produção
# científica de cada país (dados/baixar_openalex.sh).
conferencia <- read_csv("resultados/t28_conferencia_publicacoes.csv",
                        show_col_types = FALSE)
cat("Spearman(AI.Publications, artigos de IA no OpenAlex) =",
    Spearman(conferencia$pubs, conferencia$oa_ai), "| razão mediana",
    round(median(conferencia$pubs / conferencia$oa_ai), 2), "\n")
composicao <- conferencia %>%
  group_by(Country) %>%
  summarise(exatas_e_vida = 100 * mean(stem_share),
            ciencias_sociais = 100 * mean(social_share),
            ia = 100 * mean(ai_share_oa), .groups = "drop") %>%
  arrange(desc(exatas_e_vida))
print(as.data.frame(mutate(head(composicao, 5),
                           across(where(is.numeric),
                                  ~ round(.x, 1)))))
print(as.data.frame(mutate(tail(composicao, 5),
                           across(where(is.numeric), ~ round(.x, 1)))))
