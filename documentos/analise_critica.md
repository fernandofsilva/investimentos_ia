# Análise crítica — proposta v1, orientação do professor e proposta v2

**Objeto:** `documentos/anteriores/proposta_eficiencia_ia.md` (v1), `material_disciplina/comments.txt` (orientação oral do professor, transcrita) e `documentos/anteriores/proposta_v2_revisada.md` (v2), lidos à luz do `material_disciplina/Syllabus.docx` e do material das aulas (`material_disciplina/lesson1.4.r`, `material_disciplina/lesson1.5.r`, `material_disciplina/lesson2.3.r`, `material_disciplina/lesson3.7.r`, Lectures 01, 03 e 04). As citações do transcrito estão normalizadas apenas em espaçamento (o arquivo tem palavras coladas); onde a transcrição registrou "ideia" por DEA, aparece [DEA].
**Base:** `dados/AI_INVESTMENT.csv` — 208 país-ano, 37 países, 2013–2021, 33 variáveis.
**Reprodução:** todos os números deste documento saem de `Rscript scripts/replica_analise_critica.R` (3 s; só base R + tidyverse; o DEA é resolvido por um simplex próprio porque nenhum pacote da aula está instalado nesta máquina). O script grava `resultados/analise_critica_scores.csv` com os escores de todas as especificações.
**Data:** 19/09/2026. Último laboratório em 21/09; apresentação de 20 min em 28/09; manuscrito Qualis até o lançamento das notas.

---

## 0. Sumário executivo

1. **O gancho da v2 — "o Brasil converte investimento em artigo, não em patente" — é em grande parte artefato de unidades.** O modelo S usa publicações em contagem absoluta; o modelo T usa patentes *por milhão de habitantes*. O gap T − S tem correlação −0,53 com o log da população. Sob unidades consistentes, o gap do Brasil vai a 0,00 (tudo per capita) ou −0,31 (tudo em contagem, meio da tabela).
2. **A v2 atribui ao professor um "enxugar" que ele não pediu** e corta quatro técnicas que o Syllabus exige e o template da aula contém (Malmquist, fusões, TOPSIS, classes latentes).
3. **O desenho por fronteiras anuais (16–30 DMUs) foge do template** (uma única fronteira para o painel inteiro) e infla os escores conforme n cai: a média do BCC_S sobe de 0,59 em 2013 para 0,75 em 2021; 26–32 % das DMUs são eficientes, contra 3–5 % na fronteira agrupada.
4. **O segundo estágio proposto (`gap` em OLS) não é o da aula** (Tobit + `rDEA::dea.env.robust`) e não testa "pesquisa vira patente". Replicando a regressão da v2 com erros-padrão agrupados por país, nada é significativo a 5 % exceto `anos_desde_1o_inv`, que em 28 dos 36 países mede apenas "anos na amostra".
5. **Nada está codificado a nove dias da apresentação.** Nenhum número da v1 ou da v2 é reproduzível a partir do repositório e nenhum pacote da aula está instalado. A prioridade é pipeline reproduzível + deck; o refinamento do manuscrito vem depois.

Dois achados de dados que nenhuma das propostas viu: (a) a série de patentes parece **truncada à direita** em 2020–2021 (em 2021, 64 % dos países caem em relação a 2020 — EUA 0,56×, Japão 0,70× — enquanto publicações continuam subindo); (b) `Corruption_Estimate` e `Government_Effectiveness` têm correlação 0,95 (VIF ≈ 20 na regressão da v2).

---

## 1. O que o professor disse × o que a v2 registrou

| Tema | Professor (`material_disciplina/comments.txt`) | v2 | Avaliação |
|---|---|---|---|
| Produtos | "tem dois aqui, que é AI Publications e AI Patents Applications" (fala do aluno; o professor concorda: "o quanto gera de paper e de patente") | 2 produtos; high-tech export vira contextual | Fiel. Mas a escolha foi do aluno, não "orientação do professor" como diz a tabela §1 da v2; ele nunca pediu para retirar exportações high-tech. |
| Insumos | "você tem as granas que tão sendo investidas"; "o que você investe em pesquisa e desenvolvimento por cada país, que é o teu input" | Investimento em IA (US\$) + P&D (% PIB) | Fiel nas variáveis. As **unidades** foram escolha da v2 (ver §2). |
| Modelos | "cabe rodar dois modelos, um CCR e um BCC, para avaliar isso, para ter um contrafactual de retorno de escala, e aí ter uma segunda regressão com essas contextuais" | CCR + BCC + SE; robustos no apêndice | Fiel. |
| Físico × financeiro | "vamos rodar um DEA físico e um DEA financeiro"; "se não der para separar não é [...] um pecado capital" | Reinterpretado como S (ciência) × T (tecnologia) | Defensável, mas a separação S/T compara fronteiras com produtos em unidades diferentes (§2). |
| Contextuais | "tudo que for sociodemografia, ela seria contextual"; "sociedade livre, controle de corrupção, vice [voice] accountability" | WGI, financeiras, estruturais | Voice & Accountability não está na base nem na lista de merge da v2. |
| Base industrial | "alguma proxy que seja com relação à indústria, a indústria como participação no PIB"; "percentual de exportações industriais na corrente de comércio" | `NV.IND.MANF.ZS` + `TX.VAL.TECH.MF.ZS` | Manufatura % PIB, certo. `TX.VAL.TECH.MF.ZS` **é a `High_Tech_Export_Percentage` que já está na base** (high-tech % das exportações manufaturadas). A proxy pedida é `TX.VAL.MANF.ZS.UN` (manufaturados % das exportações de mercadorias). |
| Zeros | "você pode deixar zero, até porque isso é uma coisa relativamente recente"; "fazer alguma transformação minimax e fazer um shift, se alguém terminar em zero soma 0.1 em todo mundo" | Manter; shift em três magnitudes | Fiel. Min-max não foi testado (e recriaria zeros: mapeia o mínimo em 0). Sobre as magnitudes, ver §2.5. |
| Painel | "não preocuparia você [...] de um painel exatamente balanceado"; "a regressão que você fizer no segundo estágio seria mais um efeito aleatório" | Amostra completa; pooled com cluster por país | Fiel. |
| Tempo | "há quanto tempo cada país começou a investir em inteligência artificial" | `anos_desde_1o_inv` | Mal implementada: em 28 dos 36 países com investimento positivo, o primeiro ano positivo é o primeiro ano observado. |
| Escopo | "você não precisa ficar preso a essas ideias"; "se você puder explorar essa coisa pelo [DEA], seria bem legal acho que tem um espaço aí" | "Orientação do professor: Enxugar"; corta Malmquist, fusões, TOPSIS, classes latentes | **Atribuição indevida.** Não há uma linha sobre cortar técnicas; o Syllabus manda "replicar as análises desenvolvidas nas sessões anteriores". |
| Periódico | "dependendo do journal que você leva, o pessoal nem quer saber de [DEA], quer saber aqueles modelos de mediação, moderação" | — | Ignorado: nenhuma decisão de periódico, nenhum parágrafo "por que fronteira e não mediação". |
| Trabalho anterior | "a base que eu me lembro, foi o Aaron que me mandou, a gente explorou de uma maneira diferente [...] tudo econometria" | — | Ignorado: é preciso identificar e citar (§7). |

**Nuance sobre os zeros.** O menor investimento positivo é exatamente US\$ 1.000.000 (Bulgária-2021, Peru-2021): a fonte arredonda a milhões. Um zero pode ser "abaixo de US\$ 0,5 mi", o que apoia a leitura do professor (fenômeno recente, valor desprezível) tanto quanto a da v1 (não-cobertura do rastreador). A Ucrânia (zero em 2013–2017, US\$ 1 mi em 2018) é compatível com as duas. Só a fonte (AI Index / Quid) resolve; enquanto isso, os dois cenários (amostra completa e restrita) devem ser reportados, como a v2 já propõe.

---

## 2. Unidades e consistência dimensional — o problema central

### 2.1 O que as variáveis são

- `AI.Patent.Applications` é **patentes por milhão de habitantes**. Multiplicada pela população recuperada (PIB / PIB per capita), 58 % das observações ficam a menos de 0,02 de um inteiro (esperado ao acaso: 4 %). Em 2021: China 59,9 (≈ 84.611 patentes), Luxemburgo 59,3 (≈ 38), Japão 23,6 (≈ 2.964), EUA 20,9 (≈ 6.945). Correlação com log população: −0,03; com log PIB per capita: 0,61.
- `AI.Publications` é **contagem absoluta**: correlação com log população 0,71; com log PIB per capita 0,09.
- `R.D_Percentage` é razão (% do PIB); `AI.Investment` é nível (US\$ correntes).

A v2 registra a ressalva (§5: "misturá-las num mesmo vetor de produtos é dimensionalmente inconsistente") e conclui que "nos modelos S e T separados o problema desaparece". Não desaparece: o **gap** compara o escore de uma fronteira de contagens (S, que favorece países grandes) com o de uma fronteira per capita (T, que favorece países ricos e pequenos).

### 2.2 O que a replicação mostra (especificação da v2: BCC anual, shift US\$ 10 mi)

- Spearman(S, T) = 0,246 — igual ao da v2 — e a tabela de gap por país é idêntica (Índia −0,93, Itália −0,86, Polônia −0,73, Espanha −0,68, Malásia −0,62, Brasil −0,57; Luxemburgo +0,83, Singapura +0,77, Eslovênia +0,72, EUA +0,16).
- Correlação do gap com log população: −0,53 (médias por país), −0,41 (observações). Com log PIB per capita: +0,40 / +0,43. Regressão gap ~ log pop + log PIB pc nos 37 países: log pop −0,105 (p = 0,013), PIB pc n.s., R² = 0,30. Kruskal-Wallis do gap por renda (p = 2e-5) e por região (p = 5e-8) reflete o mesmo artefato.
- Eficientes em T na média dos anos: Indonésia, Peru, Austrália, Eslovênia, Singapura, Luxemburgo. Em S: Romênia, China, Indonésia, Peru. Indonésia e Peru são eficientes nos dois modelos com investimento de US\$ 1–2 milhões — denominador minúsculo, não desempenho.

### 2.3 O mesmo exercício com unidades consistentes

| Especificação | Spearman(S,T) | cor(gap, log pop) | S ≫ T | T ≫ S | Brasil | Índia | Luxemburgo | Singapura | EUA |
|---|---|---|---|---|---|---|---|---|---|
| v2 (mista) | 0,246 | −0,53 | Índia, Itália, Polônia, Espanha, Malásia, Brasil | Luxemburgo, Singapura, Eslovênia, EUA | −0,57 | −0,93 | +0,83 | +0,77 | +0,16 |
| Intensiva (inv per capita, P&D % → pubs/mi, patentes/mi) | 0,273 | +0,53 | Itália, Áustria, Grécia, Holanda, Suíça, Romênia | China, EUA, Japão, México | 0,00 | −0,08 | −0,05 | −0,07 | +0,59 |
| Extensiva (inv US\$, P&D US\$ → contagens) | 0,466 | −0,20 | Itália, Grécia, Polônia, Espanha, Índia, Portugal | Eslovênia, Luxemburgo | −0,31 | −0,75 | +0,07 | −0,21 | −0,13 |

Correlações de posto entre especificações: escores S da v2 × intensiva **0,08** (rankings sem relação); escores T 0,92 (T já era per capita na v2); gap por país v2 × intensiva 0,37, v2 × extensiva 0,72.

Conclusão: um "gap ciência–tecnologia" existe em qualquer especificação, mas **quem está em cada lista muda com as unidades**. O Brasil só é caso emblemático na especificação mista. Se o artigo mantiver a espec. da v2, um parecerista que peça per capita derruba a seção de resultados inteira.

### 2.4 Os números da §2 da v2 vêm do modelo ST

Os valores reportados na v2 — zeros com BCC 0,993 e 88,2 % eficientes contra 42,4 % do resto; CCR 0,791/58,8 %, 0,585/23,5 %, 0,319/5,9 % — reproduzem **exatamente com o modelo ST** (dois produtos), o mesmo que a v2 declara "dimensionalmente inconsistente" e diz usar só "para comparação". Com S e T os valores são outros:

| Modelo | BCC eficientes (todos) | Zeros: BCC médio / % eficientes | CCR zeros, shift 1 mi | 10 mi | 100 mi |
|---|---|---|---|---|---|
| S | 31,7 % | 0,820 / 64,7 % | 0,555 / 29,4 % | 0,427 / 17,6 % | 0,225 / 0 % |
| T | 26,0 % | 0,871 / 64,7 % | 0,493 / 29,4 % | 0,302 / 5,9 % | 0,143 / 5,9 % |
| ST | 46,2 % | 0,993 / 88,2 % | 0,791 / 58,8 % | 0,585 / 23,5 % | 0,319 / 5,9 % |

(Nos não-zeros: BCC eficientes 28,8 % em S, 22,5 % em T, 42,4 % em ST.) O efeito *self-identifier* é real em todos os modelos, mas o texto precisa dizer de qual modelo são os números.

### 2.5 O shift não é um shift

As magnitudes testadas — US\$ 1 mi, 10 mi, 100 mi — são 1×, 10× e 100× o menor valor positivo da base; US\$ 100 mi supera a mediana da amostra (US\$ 89,6 mi). Somar 100 mi a todos comprime a distribuição inteira (Argentina-2013 passa de US\$ 1,2 mi para 101 mi; a correlação de posto do CCR_ST entre 1 mi e 100 mi cai a 0,74 em todas as observações). A tabela mede distorção da variável, não translação dos zeros — e isso explica a "sensibilidade brutal" do CCR. Recomendação: shift = metade do menor positivo (US\$ 0,5 mi), sensibilidade em 1 mi, e explicitar que **a eficiência de escala (CCR/BCC) é indefinida para os 17 zeros**: reportar SE só na amostra restrita. Insumo em razão (`R.D_Percentage`) é problema conhecido no DEA (Hollingsworth & Smith 2003; Olesen, Petersen & Podinovski 2015, 2017): na forma extensiva, usar P&D em US\$ (% × PIB).

### 2.6 Recomendação

Uma especificação principal com unidades consistentes — **extensiva** (investimento em US\$, P&D em US\$ → publicações e patentes em contagem; o VRS absorve o tamanho) — e a **intensiva** como robustez. O gap só vira achado se sobreviver às duas.

---

## 3. Desenho da DMU e da fronteira

### 3.1 Fronteira anual × fronteira agrupada

- Template da aula: as 115 companhia-ano entram numa única fronteira; ano/tendência é contextual. v1 e v2: uma fronteira por ano, com 16 a 30 DMUs.
- Consequência: eficientes BCC 31,7 % (S), 26,0 % (T), 46,2 % (ST); a média do BCC_S sobe de 0,59 (2013) para 0,75 (2021, n = 16) — o escore acompanha o tamanho da amostra, não a eficiência. Escores de anos diferentes não são comparáveis e, ainda assim, são empilhados na regressão com dummies de ano.
- Fronteira agrupada (208 DMUs, espec. da v2): eficientes 5,3 % (S), 2,9 % (T), 6,7 % (ST); CCR_S 1,9 %; Spearman com os escores anuais 0,79 (S) e 0,82 (T). A média agrupada de T sobe de 0,12 (2013) para 0,20 (2021): a fronteira de patentes se desloca (China-2021 e Luxemburgo-2021 a definem). Isso é argumento para Malmquist e dummies de ano no segundo estágio, não para fronteiras anuais.
- Recomendação: agrupada como principal (template), anual ou janela móvel como robustez.

### 3.2 FDH, outliers e *self-identifiers*

- FDH: 52,9 % das DMUs eficientes por ano — inútil como estimador aqui (a v1 sabia; a v2 silencia). Entra no deck porque o template pede, com essa leitura.
- Supereficiência CRS (Andersen-Petersen, anual): Luxemburgo 12,2 (2019), 11,4 (2021), 9,7 (2018), 5,5 (2016) — poderia perder 90 % das patentes per capita e continuar eficiente; China-2021 4,5 no ST; Austrália-2013 3,1. A etapa de outliers da v1 (Etapa 2) foi cortada na v2 e precisa voltar; Order-m/α, que a v2 mandou para o apêndice, é justamente o estimador robusto a esse quadro.
- Peru-2018 (investimento zero) está na fronteira agrupada de S **e** de T. Uma dummy `zero_inv` no segundo estágio não corrige um artefato de fronteira.
- Luxemburgo, Singapura e Eslovênia como benchmarks de T: risco de artefato de endereço do depositante (holdings de propriedade intelectual) e de escritório (EPO/PCT × escritório nacional). No modelo de conversão per capita (§4.3) os piores são Holanda, Bélgica, Suíça e Irlanda — países que patenteiam via EPO. Confirmar na fonte se a contagem é por inventor ou depositante e qual escritório.

### 3.3 Truncamento à direita das patentes

| Ano | Patentes/mi: razão mediana t/t−1 | % países em queda | Publicações: razão mediana | % em queda |
|---|---|---|---|---|
| 2018 | 1,51 | 26 | 1,20 | 0 |
| 2019 | 0,98 | 59 | 1,18 | 5 |
| 2020 | 1,08 | 35 | 1,14 | 0 |
| 2021 | 0,84 | 64 | 1,14 | 7 |

Quedas em 2021: EUA 0,56, Japão 0,70, Espanha 0,64, Polônia 0,75, Argentina 0,60, México e Peru 0,08. Publicações não caem. Compatível com a defasagem de 18 meses entre depósito e publicação de pedidos (OECD Patent Statistics Manual): os anos finais da série estão incompletos. Consequência: o modelo T em 2020–2021 (e qualquer Malmquist sobre patentes) não é confiável; reportar T até 2019 como sensibilidade. A amostra de 2021 (n = 16) é ao mesmo tempo a menor e a mais truncada — e é onde a v2 encontra mais DMUs eficientes.

### 3.4 Defasagens e deflação

- Investimento em t produz publicações em t+1/t+2 e patentes em t+2/t+3. Nenhuma proposta considera. Na base, cor(log inv_t, log pubs_t) = 0,63 e cor(log inv_{t−1}, log pubs_t) = 0,60; as variações dentro do país são descorrelacionadas (0,04): a informação é quase toda entre países. A defasagem muda pouco o ranking, mas precisa estar justificada; 154 pares de anos consecutivos permitem robustez com t−1.
- `AI.Investment` está em US\$ correntes: deflacionar para fronteira agrupada e Malmquist (a v1 apontou; a v2 abandonou).

### 3.5 Malmquist não exige painel balanceado

Com fronteiras de período estimadas em todos os países observados em cada ano, obtêm-se 154 índices país-período (CRS, modelo S): média geométrica M = 0,967, catch-up 1,118, deslocamento 0,865. O deslocamento negativo diz que a fronteira de publicações por dólar recuou enquanto o investimento mediano subiu de US\$ 9 mi (2013) para US\$ 243 mi (2021). Os valores anuais são ruidosos (TC de 0,53 a 1,35) e servem para o deck, não como resultado central. A v2 rebaixou o Malmquist "por causa do painel"; o motivo não se sustenta.

---

## 4. Segundo estágio

### 4.1 O `gap` como variável dependente

- É a diferença de dois escores limitados, viesados e serialmente dependentes (o argumento da própria v1 contra o Tobit vale em dobro), de fronteiras com unidades distintas e fortemente ligada a população e renda.
- Regressão da v2 replicada (sem `manuf_pib`, que ainda não existe): n = 207, 20 parâmetros para 37 países, R² = 0,50. Com erros-padrão agrupados por país, nada é significativo a 5 % exceto `anos_desde_1o_inv` (−0,102, p = 0,011) — a variável que mede "anos na amostra". VIF: `Government_Effectiveness` 20,7, `Corruption_Estimate` 20,1, log PIB pc 13,7 (`IncomeLevel` é redundante com PIB pc). Entre 96 % e 99 % da variância de todas as contextuais é entre países: efeitos fixos de país são inviáveis, como o professor antecipou, e com 37 clusters o poder é baixo.

### 4.2 O que o template faz (Lecture 04)

- `censReg` Tobit em (0, 1) sobre CCR, BCC e SE; KS e Kruskal-Wallis entre grupos; `rDEA::dea.env.robust(X, Y, Z, model = "output", RTS = "constant"/"variable")`, que é o Algoritmo 2 de Simar-Wilson com intervalos bootstrap dos coeficientes.
- O código da v1 e da v2 (`rDEA::dea.robust` + `truncreg` à mão) **não** é o Algoritmo 2: falta o segundo laço de bootstrap e as contextuais não entram no bootstrap. Usar `dea.env.robust`.
- `AER::tobit(left = 0)` é inócuo (não há escore 0). `truncreg(point = 1, direction = "left")` só faz sentido para escores de Farrell ≥ 1, mas as tabelas da v2 reportam escores em (0, 1]. O template inverte com `1/eff`; escolher uma convenção e mantê-la no código e no texto.

### 4.3 Testar a hipótese do professor diretamente

"Você precisa de uma base industrial para que a tua pesquisa vire patente" é um enunciado sobre conversão de pesquisa em patente, não sobre a diferença entre dois escores. O teste direto é um **modelo de conversão**: insumos = publicações, investimento e P&D (em US\$); produto = patentes (contagem). Replicado (BCC anual): China 1,00, Japão 0,82, Austrália 0,72, EUA 0,69, México 0,67, …, Brasil 0,33 (16º de 37), Índia 0,25, Espanha 0,11, Polônia 0,11, Itália 0,05, Holanda 0,01. É sobre esse escore que `manuf_pib` deve ser testado. Na base, `High_Tech_Export_Percentage` tem correlação −0,17 com ele: o proxy externo é mesmo necessário. Extensão natural: DEA em rede de dois estágios (produção de conhecimento → comercialização; Guan & Chen 2012; paper de network DEA da sessão 1–2).

### 4.4 Contextuais recomendadas

| Variável | Fonte | Papel | Observação |
|---|---|---|---|
| Manufatura, % do PIB | WDI `NV.IND.MANF.ZS` | H1 (base industrial) | Pedida pelo professor. |
| Manufaturados, % das exportações | WDI `TX.VAL.MANF.ZS.UN` | Robustez de H1 | É a "corrente de comércio" que o professor citou. |
| Voice & Accountability | WGI `VA.EST` | Institucional | Pedida pelo professor; não está na base. |
| Índice de governança | média ou 1º componente de `Corruption_Estimate` e `Government_Effectiveness` | Institucional | As duas juntas dão VIF 20. |
| log PIB per capita **ou** faixa de renda | base | Estrutural | Não as duas. |
| `High_Tech_Export_Percentage` | base | Sofisticação | Já está na base; **não** buscar `TX.VAL.TECH.MF.ZS`. |
| Pesquisadores por milhão | WDI `SP.POP.SCI.RD.P6` | Capacidade de absorção | Checar cobertura: há lacunas em vários países-ano. |
| BERD (P&D empresarial, % PIB) | OCDE MSTI / UIS | Proxy de "indústria absorve pesquisa" | Opcional; mais próximo da hipótese do que manufatura % PIB. |
| `zero_inv`, ano | base | Controles de desenho | Redefinir ou retirar `anos_desde_1o_inv`. |

Separabilidade (Daraio, Simar & Wilson 2018): está no Syllabus, não há código na aula — discutir como limitação; order-m condicional como extensão. Testes KS/Kruskal do template: por renda, região, `zero_inv` e por corte de participação industrial.

---

## 5. Aderência ao Syllabus e ao template da aula

O Syllabus pede que o aluno "replique as análises desenvolvidas nas sessões anteriores" para o diagnóstico setorial. O manuscrito pode ser focado; o deck não.

| Técnica | Template (arquivo / função) | v1 | v2 | Deck de 28/09 |
|---|---|---|---|---|
| Descritivas (densidade, boxplot, histograma) | `material_disciplina/lesson1.4.r` | sim | não menciona | obrigatório |
| FDH | `material_disciplina/lesson1.4.r`, `dea(RTS = "fdh")` | sim | não | sim, com a leitura de §3.2 |
| CCR / BCC + `dea.plot` 2D | `material_disciplina/lesson1.4.r` | sim | sim | sim |
| Folgas | `material_disciplina/lesson2.3.r`, `SLACK = TRUE`, `sx/x` | sim | sim | sim |
| Fusões | `material_disciplina/lesson2.3.r`, `make.merge` / `dea.merge` | sim ("blocos regionais") | cortado | sim — a ideia da v1 encaixa direto (Mercosul, Visegrád, Benelux) |
| Malmquist | `material_disciplina/lesson2.3.r`, `nonparaeff::faremalm2` | sim | rebaixado ou cortado | sim (§3.5) |
| TOPSIS | `material_disciplina/lesson2.3.r`, `topsis` | sim | cortado | sim (meia hora) |
| Bootstrap | `material_disciplina/lesson3.7.r`, `rDEA::dea.robust` | sim | sim | sim |
| SFA / COLS | `material_disciplina/lesson3.7.r`, `Benchmarking::sfa`, `lm` | sim (`sfaR`) | sim | sim (log pubs ~ log inv + log P&D) |
| Order-m / Order-α | `material_disciplina/lesson3.7.r`, `nonparaeff::orderm`, `frontiles` | sim, função errada (`npsf::teradialbc` não é order-m) | apêndice | sim — é o estimador robusto aos outliers de §3.2 |
| Classes latentes | `material_disciplina/lesson3.7.r`, `poLCA` sobre decis de insumos/produtos | sim, técnica diferente (`sfaR::lcmcross`) | opcional | sim, com `poLCA` (1 h) |
| KS / Kruskal-Wallis | Lecture 04 | sim | sim | sim |
| Tobit | Lecture 04, `censReg` | sim (`AER`) | sim (`AER`) | sim |
| Truncada bootstrap | Lecture 04, `rDEA::dea.env.robust` | código incorreto | código incorreto | sim, com `dea.env.robust` |
| Separabilidade | Syllabus; sem código na aula | sim | não | discutir |

Outros pontos de aderência:
- Escores: o template inverte com `1/eff`. O `roda_dea` da v2 calcula `se = ccr / bcc` sobre valores de Farrell ≥ 1 enquanto as tabelas reportam (0, 1].
- Ambiente desta máquina: nenhum dos pacotes da aula está instalado; falta GLPK (`brew install glpk`, exigido pelo `rDEA`); `frontiles` exige `rgl` (XQuartz no macOS). Em 19/09/2026 todos estão no CRAN: `Benchmarking`, `rDEA`, `nonparaeff`, `frontiles`, `poLCA`, `arules`, `censReg`, `topsis`, `reshape2`, `WDI`, `countrycode`.
- A ausência de qualquer script no repositório é a lacuna mais urgente: o Syllabus pede "rotinas empíricas reprodutíveis".

---

## 6. Erros pontuais e editoriais

**v1.** "Sete achados" lista oito. A mediana de anos por país é 6, não 5. A diferença entre `log_AI_Investment_per_GDP` e o nível chega a 1,3e-4 (6,5e-15 é a de `log_Patents_per_GDP`; a conclusão não muda). Tabela (8): a replicação dá 5–12 eficientes CCR por ano (v1: 3–6) e 8–13 BCC (v1: 10–16; o 75 % de 2021 confere). O achado (7) confere: fronteira ingênua de 2018 = Luxemburgo, Filipinas, Romênia, Eslovênia, Ucrânia; EUA 0,050, Japão 0,053, Israel 0,080. `npsf::teradialbc` não é order-m.

**v2.** "42 %" é do modelo ST (46,2 % no total; 42,4 % nos não-zeros). §5 diz "amostra completa (n = 208)" mas o pipeline é anual. S e T têm os mesmos insumos: T ignora publicações. §2 não diz que os números são do ST. `roda_dea` não inverte os escores. A regra n ≥ 3(m + s) é satisfeita e não discrimina nada. `TX.VAL.TECH.MF.ZS` duplica variável da base. A regressão do gap tem 20 parâmetros para 37 países. `anos_desde_1o_inv` mede "anos na amostra".

---

## 7. Posicionamento e periódico

- **Fukuyama, Tan & Wanke (2025)**, *Socio-Economic Planning Sciences* 100:102248, "Global inefficiencies in labour, patents, energy, capital, environment, and economics: the role of corruption, democracy, and income distribution" — 44 países, 2013–2021, DEA, ineficiência de patentes mais prevalente na América Latina e em países de renda média. É o trabalho mais próximo do grupo do professor; precisa ser citado e a contribuição (IA especificamente; ciência × tecnologia; solidez financeira como contextual) posicionada contra ele. Perguntar ao professor pelo trabalho "do Aaron" com mediação/moderação.
- Eficiência de sistemas nacionais de inovação: Wang & Huang (2007, *Research Policy* 36:260–273) usam exatamente patentes e publicações como produtos, com Tobit no segundo estágio; Guan & Chen (2012, *Research Policy* 41:102–115) formalizam os dois estágios (produção de conhecimento → comercialização) em DEA em rede; Kontolaimou, Giotopoulos & Tsakanikas (2016, *Economic Modelling* 52:477–484) constroem uma tipologia de países por eficiência e *gaps* tecnológicos; Carayannis, Goletsis & Grigoroudis (2015, *Operational Research* 15:253–274) tratam a medição multiestágio.
- Métodos: Ali & Seiford (1990) e Pastor (1996) para invariância à translação; Simar & Wilson (2007) para o segundo estágio; Daraio, Simar & Wilson (2018) para separabilidade; Wilson (1993) e Andersen & Petersen (1993) para outliers; Olesen, Petersen & Podinovski (2015, 2017) para razões no DEA.
- Periódicos a discutir com o professor antes de escrever: *Socio-Economic Planning Sciences*, *Technological Forecasting & Social Change*, *Journal of the Knowledge Economy*; nacionais: BAR, RAUSP, BJOPM. Em qualquer caso, redigir o parágrafo "por que fronteira e não mediação/moderação".

---

## 8. Melhorias priorizadas

| # | Melhoria | Esforço | Até 28/09? |
|---|---|---|---|
| 1 | Unidades consistentes: espec. extensiva principal (contagem de patentes recuperada, P&D em US\$) + intensiva como robustez; refazer S, T, ST | 4–6 h | sim |
| 2 | Fronteira agrupada como principal (template); anual como robustez; FDH/CCR/BCC/SE/folgas como na aula | 2–3 h | sim |
| 3 | Pipeline R reproduzível cobrindo o template inteiro, com `set.seed`, escores em CSV e README; instalar pacotes e GLPK | 8–12 h | sim — pré-requisito do deck |
| 4 | Segundo estágio do template (`censReg` + `dea.env.robust`) em S, T, SE e no modelo de conversão; ≤ 7 regressores (índice de governança; PIB pc ou renda); cluster por país no OLS; retirar ou redefinir `anos_desde_1o_inv` | 4 h | sim |
| 5 | Merge WDI/WGI: manufatura % PIB, manufaturados % exportações, voice & accountability; conferir os 37 nomes de país | 2–3 h | sim |
| 6 | Outliers: supereficiência, resultados com e sem Luxemburgo/Singapura, Order-m/α como robustez principal | 2–3 h | sim |
| 7 | Truncamento de patentes (sensibilidade até 2019) e defasagem t−1 | 2 h | sim |
| 8 | Zeros: shift US\$ 0,5 mi + amostra restrita; apresentar 100 mi como distorção, não como cenário | 1 h | sim |
| 9 | Restaurar técnicas do template para o deck: TOPSIS, Malmquist adjacente, fusões como consórcios regionais, `poLCA`, SFA/COLS, bootstrap | ≈ 8 h | sim — é o que garante a apresentação |
| 10 | Deck de 20 min organizado como diagnóstico setorial | 6 h | sim |
| 11 | Confirmar na fonte: definição de patentes (inventor × depositante, escritório), moeda corrente × constante, origem dos zeros; deflacionar | 2 h | sim |
| 12 | Manuscrito: citar Fukuyama–Tan–Wanke (2025), escolher periódico, parágrafo "por que fronteira" | 3 h | depois |
| 13 | Extensões: DEA em rede, order-m condicional, SFA de classes latentes com manufatura como determinante de classe | — | depois |

Total ≈ 45 h. Mínimo viável para 28/09: itens 1, 2, 3, 4 (parcial), 9 e 10 (≈ 30 h); o restante entra na versão de submissão.

---

## Apêndice A — Números de replicação

Todos gerados por `scripts/replica_analise_critica.R`. Sanidade: BCC ≤ FDH e CCR ≤ BCC em todas as DMUs; invariância do BCC-produto a translações do insumo (diferença máxima 4e-15); 0 NAs.

**A1. Especificação da v2, por ano (BCC/CCR anual, shift US\$ 10 mi)**

| Ano | n | FDH_S | BCC_S | CCR_S | BCC_T | CCR_T | média BCC_S |
|---|---|---|---|---|---|---|---|
| 2013 | 22 | 14 | 6 | 2 | 6 | 3 | 0,59 |
| 2014 | 23 | 14 | 8 | 3 | 5 | 1 | 0,62 |
| 2015 | 23 | 12 | 7 | 3 | 9 | 2 | 0,61 |
| 2016 | 26 | 9 | 7 | 3 | 6 | 3 | 0,57 |
| 2017 | 26 | 13 | 8 | 4 | 7 | 3 | 0,60 |
| 2018 | 30 | 14 | 9 | 4 | 5 | 2 | 0,57 |
| 2019 | 24 | 13 | 5 | 3 | 7 | 2 | 0,60 |
| 2020 | 18 | 10 | 7 | 4 | 5 | 2 | 0,68 |
| 2021 | 16 | 11 | 9 | 4 | 4 | 1 | 0,75 |

**A2. Gap médio por país (BCC_T − BCC_S, espec. da v2)**

| País | n | S | T | gap | | País | n | S | T | gap |
|---|---|---|---|---|---|---|---|---|---|---|
| Índia | 8 | 0,95 | 0,03 | −0,93 | | Argentina | 7 | 0,29 | 0,05 | −0,24 |
| Itália | 2 | 0,91 | 0,05 | −0,86 | | Bulgária | 3 | 0,63 | 0,40 | −0,23 |
| Polônia | 9 | 0,82 | 0,09 | −0,73 | | Reino Unido | 3 | 0,39 | 0,19 | −0,20 |
| Espanha | 9 | 0,81 | 0,12 | −0,68 | | Hungria | 9 | 0,39 | 0,21 | −0,18 |
| Malásia | 5 | 0,98 | 0,36 | −0,62 | | Noruega | 6 | 0,22 | 0,08 | −0,14 |
| Brasil | 8 | 0,64 | 0,07 | −0,57 | | Chile | 5 | 0,50 | 0,42 | −0,08 |
| Grécia | 8 | 0,74 | 0,22 | −0,53 | | Irlanda | 2 | 0,13 | 0,06 | −0,07 |
| Romênia | 6 | 1,00 | 0,48 | −0,52 | | Suíça | 1 | 0,08 | 0,06 | −0,03 |
| França | 6 | 0,49 | 0,09 | −0,40 | | Indonésia | 2 | 1,00 | 1,00 | 0,00 |
| Filipinas | 1 | 0,40 | 0,01 | −0,40 | | Peru | 4 | 1,00 | 1,00 | 0,00 |
| China | 9 | 1,00 | 0,62 | −0,38 | | Croácia | 3 | 0,32 | 0,33 | 0,01 |
| Bélgica | 4 | 0,34 | 0,03 | −0,32 | | Ucrânia | 6 | 0,82 | 0,84 | 0,02 |
| Colômbia | 3 | 0,98 | 0,67 | −0,31 | | Israel | 9 | 0,10 | 0,13 | 0,03 |
| México | 9 | 0,91 | 0,62 | −0,30 | | Japão | 9 | 0,79 | 0,83 | 0,05 |
| África do Sul | 6 | 0,31 | 0,03 | −0,29 | | Austrália | 4 | 0,92 | 1,00 | 0,08 |
| Holanda | 5 | 0,31 | 0,03 | −0,28 | | EUA | 9 | 0,74 | 0,91 | 0,16 |
| Áustria | 9 | 0,52 | 0,24 | −0,28 | | Eslovênia | 1 | 0,28 | 1,00 | 0,72 |
| Portugal | 5 | 0,42 | 0,15 | −0,27 | | Singapura | 7 | 0,23 | 1,00 | 0,77 |
| | | | | | | Luxemburgo | 6 | 0,17 | 1,00 | 0,83 |

**A3. Fronteira agrupada (208 DMUs, espec. da v2, BCC)** — eficientes em S: Austrália-2013, China-2013/2019/2020/2021, Índia-2019, Indonésia-2013/2016, Malásia-2014, Peru-2018, Romênia-2018. Em T: China-2021, Indonésia-2013, Luxemburgo-2016/2019/2021, Peru-2018. Média por ano — S: 0,46 0,30 0,30 0,31 0,24 0,27 0,27 0,32 0,31; T: 0,12 0,05 0,07 0,09 0,13 0,19 0,17 0,16 0,20.

**A4. Modelo de conversão (pubs, inv US\$, P&D US\$ → patentes contagem; BCC anual), média por país** — China 1,00; Luxemburgo, Peru, Eslovênia 1,00; Ucrânia 0,90; Japão 0,82; Austrália 0,72; EUA 0,69; México 0,67; Indonésia 0,56; Bulgária 0,53; Romênia 0,48; Croácia 0,39; Argentina 0,34; Malásia 0,34; Brasil 0,33; Singapura 0,33; Índia 0,25; Colômbia 0,18; Hungria 0,15; Reino Unido 0,12; Espanha 0,11; Grécia 0,11; Polônia 0,11; Chile 0,10; Portugal 0,09; Áustria 0,09; Filipinas 0,08; França 0,06; Israel 0,06; Itália 0,05; África do Sul 0,04; Noruega 0,03; Bélgica 0,02; Suíça 0,01; Irlanda 0,01; Holanda 0,01. (Luxemburgo, Peru, Eslovênia e Ucrânia eficientes por denominador minúsculo.)

**A5. Patentes por milhão de habitantes, países selecionados**

| País | 2013 | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 |
|---|---|---|---|---|---|---|---|---|---|
| China | 1,4 | 1,8 | 2,8 | 5,7 | 10,5 | 19,4 | 30,8 | 46,3 | 59,9 |
| EUA | 7,0 | 8,5 | 12,1 | 18,7 | 29,7 | 39,6 | 41,1 | 37,3 | 20,9 |
| Japão | 2,8 | 4,0 | 5,8 | 10,7 | 18,7 | 28,2 | 33,5 | 33,7 | 23,6 |
| Luxemburgo | — | — | — | 3,4 | 5,0 | 14,8 | 16,1 | 20,6 | 59,3 |
| Singapura | 4,8 | 6,6 | 6,0 | 9,1 | 19,8 | 35,7 | 26,6 | — | — |
| Brasil | 0,2 | 0,2 | 0,3 | 0,4 | 0,4 | 0,7 | 0,7 | 0,7 | — |

**A6. Tendências (medianas por ano)** — publicações: 1.264 (2013) → 1.787 (2021); patentes/mi: 0,25 → 0,64; investimento: US\$ 9,3 mi → 242,5 mi; P&D % PIB: 1,63 → 1,45; zeros: 2, 3, 5, 2, 2, 3, 0, 0, 0.

---

## Apêndice B — Revisão independente

Uma segunda leitura foi feita por um revisor independente, com os mesmos materiais e uma implementação própria do DEA (via `quadprog`/`nloptr`). Concordância integral nos pontos centrais (unidades, fronteira agrupada, `gap`, técnicas cortadas, `dea.env.robust`, reprodutibilidade). O que essa leitura acrescentou e foi incorporado acima:

- Teste de inteiros para confirmar que `AI.Patent.Applications` é per capita (§2.1).
- `anos_desde_1o_inv` mede "anos na amostra" em 28 de 36 países (§1, §4.1).
- Colinearidade corrupção × efetividade (0,95; VIF ≈ 20) e 96–99 % de variância entre países nas contextuais (§4.1).
- Defasagens: a informação é entre países; variações dentro do país são descorrelacionadas (§3.4).
- Min-max recriaria zeros (§1).
- Malmquist adjacente não exige painel balanceado (§3.5).
- Os piores no modelo de conversão per capita são países que patenteiam via EPO (§3.2).
- Supereficiência VRS anual no ST, na implementação do revisor: Luxemburgo 39 (2016), 21 (2019), 12 (2021); China 2–5 em todos os anos; as 17 DMUs com zero são infactíveis (extremas). Este documento reporta a versão CRS (§3.2), sempre factível.

Onde as leituras divergem:
- O revisor afirma que os zeros são de não-cobertura (Ucrânia 2013–2017 e depois US\$ 1 mi em 2018). Aqui o ponto fica em aberto (§1): o arredondamento a milhões torna as duas leituras compatíveis; decide a fonte.
- O revisor obteve Spearman(S, T) = 0,20 e Brasil 0,25 no modelo de conversão per capita; aqui 0,246 (idêntico à v2) e 0,29 — diferenças de tolerância do solver e de shift, sem efeito nas conclusões.
- Estimativa de esforço total: 30 h (revisor) contra 45 h (aqui, incluindo deck e confirmações na fonte).
