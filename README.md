# Eficiência do investimento em IA

Eficiência dos países na conversão de investimento em inteligência artificial em produção científica (publicações) e tecnológica (patentes). Trabalho da disciplina *Introdução à Análise de Eficiência em R* (Prof. Peter Wanke).

O estado da pesquisa, o que foi testado, o que mudou e por quê estão em [STATUS.md](STATUS.md).

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `dados/` | `AI_INVESTMENT.csv` (208 país-ano, 37 países, 2013–2021), `wdi_contextuais.csv` (World Bank), `wgi.voice_accountability.csv` (WGI), `openalex_publicacoes.csv` e `openalex_nichos.csv` (OpenAlex) e os scripts `baixar_wdi.sh` e `baixar_openalex.sh` |
| `scripts/` | `pipeline_v3.R`, a análise completa no template da disciplina; `replica_analise_critica.R`, replicação da crítica à v2 sem pacotes de DEA |
| `scripts/relatorio/` | Geração do relatório: `template.md`, trechos de R (`00_setup.R`, `E01`–`E15`), `run_prints.R` e `build_report.py` |
| `resultados/` | Tabelas `t01`–`t28`, base tratada, `resumo_v3.txt`, `prints/` (saídas dos trechos), `figuras/` e `analise_critica_scores.csv` |
| `documentos/` | `relatorio_professor.md`, `proposta_v3.md`, `orientacao_sessao_2.md`, `discussao_casos.md` e `analise_critica.md`; versões anteriores em `anteriores/` |

## Como rodar

Da raiz do repositório (os scripts também aceitam ser chamados de subpastas):

```bash
Rscript scripts/pipeline_v3.R                 # análise completa, rodada rápida (~50 s)
RAPIDO=FALSE Rscript scripts/pipeline_v3.R    # valores finais, bootstraps longos
Rscript scripts/replica_analise_critica.R     # números da análise crítica
Rscript scripts/relatorio/run_prints.R        # saídas dos trechos do relatório
python3 scripts/relatorio/build_report.py     # remonta o relatório (.md e página)
bash dados/baixar_wdi.sh                      # regenera as contextuais do WDI
bash dados/baixar_openalex.sh                 # regenera as publicações do OpenAlex
```

Pacotes R: `Benchmarking`, `rDEA`, `nonparaeff`, `poLCA`, `censReg`, `topsis`, `truncreg`, `WDI`, `countrycode`, `tidyverse`, `sandwich`, `lmtest`. Testado em R 4.5.2.

## Documentos

- [documentos/relatorio_professor.md](documentos/relatorio_professor.md): relatório de percurso, com código, saídas, diagnósticos e melhorias incorporadas. Também publicado como página editável.
- [documentos/proposta_v3.md](documentos/proposta_v3.md): proposta atual, especificação e resultados preliminares.
- [documentos/orientacao_sessao_2.md](documentos/orientacao_sessao_2.md): registro da segunda sessão de orientação, o que ela muda e o que continua em aberto.
- [documentos/discussao_casos.md](documentos/discussao_casos.md): casos do topo e da cauda do ranking, com os dados do trabalho e a especialização de cada país.
- [documentos/analise_critica.md](documentos/analise_critica.md): crítica das versões v1 e v2 e da orientação recebida.

## Fluxo de edição do relatório

`scripts/relatorio/template.md` é a fonte. `run_prints.R` gera as saídas e `build_report.py` monta o Markdown e a página. A página publicada permite editar textos no navegador; uma edição feita lá precisa ser levada de volta ao `template.md` antes de qualquer republicação a partir do repositório.
