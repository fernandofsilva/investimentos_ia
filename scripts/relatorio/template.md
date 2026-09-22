# Eficiência do investimento em IA

**Autor:** Fernando Silva · **Disciplina:** Introdução à Análise de Eficiência em R

Este relatório apresenta o trabalho sobre eficiência do investimento em IA. Cada seção parte de um resultado obtido, analisa o que ele revela e registra a melhoria que foi incorporada ao trabalho a partir dessa análise.

O bloco marcado **R** é o código que rodou; o bloco **saída** é o que o console devolveu.

---

## 1. Pergunta e hipóteses

**Pergunta:** Quão eficientes são os países em converter esforço financeiro em IA — investimento privado em IA e gasto em P&D — em produção científica (publicações) e tecnológica (patentes) em IA, e a base industrial condiciona essa conversão?

O desenho adotado é o seguinte: insumos = investimento em IA e P&D; produtos = publicações e patentes de IA; CCR e BCC para ter o contrafactual de retornos de escala; um segundo estágio com contextuais, com uma proxy de base industrial; zeros mantidos com um deslocamento; painel desbalanceado.

- **H1.** Países com maior participação da manufatura no PIB são mais eficientes em produzir patentes (modelo T) e em converter pesquisa em patente (modelo C).
- **H2.** A base industrial tem menor impacto na eficiência científica (modelo S) do que para a tecnológica.
- **Exploratórias.** Qualidade institucional e solidez financeira afetam a eficiência; a fronteira se deslocou com o aumento do investimento (Malmquist).

Quatro modelos de fronteira e todos usam a mesma fronteira única com as 208 observações país-ano, orientada a produto, estimada em CCR e BCC; o que muda entre eles é só o que entra como insumo e como produto.

| Modelo | Insumos | Produto | Pergunta que responde |
|---|---|---|---|
| **S**, científico | investimento em IA, P&D | publicações | quanta ciência sai por dólar gasto |
| **T**, tecnológico | investimento em IA, P&D | patentes | quanta tecnologia sai por dólar gasto |
| **ST**, síntese | investimento em IA, P&D | publicações e patentes | os dois produtos na mesma fronteira |
| **C**, conversão | publicações, investimento em IA, P&D | patentes | quantas patentes saem dado o dinheiro e a ciência já produzida |

Tudo em dólares com base o ano 2015 (corrigida inflação) e em contagem. O modelo C é o que testa diretamente a hipótese sobre pesquisa que vira patente: ele coloca as publicações do lado dos insumos, e por isso substitui a diferença entre dois escores que a v2 propunha como variável dependente.

O que contaria como resposta: H1 respondida se o coeficiente da manufatura no segundo estágio for positivo sobre o escore de patentes e sobrevivesse a mudanças de unidades, de estimador e de amostra. H2 respondida se o mesmo coeficiente fosse fraco ou nulo sobre o escore de publicações. Os instrumentos da disciplina entram assim: FDH, CCR e BCC para as fronteiras; folgas, supereficiência e Order-m para os outliers; bootstrap para os intervalos; SFA como contraparte paramétrica; Malmquist para a dinâmica; fusões e TOPSIS como leituras complementares; Tobit e regressão truncada bootstrap para o segundo estágio.

Preparação comum a todos os trechos:

{{SETUP}}

---

## 2. Segunda proposta

A v2 usava as variáveis previstas, mas com unidades mistas, do jeito que saem da base: investimento em dólares, P&D em % do PIB, publicações em contagem e patentes por milhão de habitantes, com uma fronteira por ano. A ideia era comparar o escore científico (S) com o tecnológico (T) e explicar a diferença.

{{E02}}

O resultado: "o Brasil converte investimento em artigo, não em patente", com Índia, Itália, Polônia e Espanha na mesma lista e Luxemburgo e Singapura do outro lado.

> **Diagnóstico.** O gap entre T e S tem correlação −0,53 com o log da população, e na regressão só a população explica o gap (coeficiente −0,105, p = 0,013; PIB per capita não). O modelo S, em contagem, premia países grandes; o modelo T, per capita, premia países pequenos e ricos. A "lista dos que publicam e não patenteiam" era, em boa parte, a lista dos países populosos.

Os mesmos modelos foram reestimados com unidades consistentes, nas duas formas possíveis.

{{E03}}

> **Melhoria incorporada.** Tudo per capita ou tudo em contagem. O Brasil sai de −0,57 para 0,04 (per capita) ou −0,31 (contagem, meio da tabela); a Índia sai de −0,93 para −0,07 ou −0,75. O ranking científico da v2 não tem relação com o ranking per capita (Spearman 0,11). A forma em contagem e dólares passou a ser a principal, por ser a leitura literal da pergunta de pesquisa, isto é, o que se investe contra o quanto se gera; a forma per capita ficou como robustez.

---

## 3. Fronteira por ano ou fronteira agrupada?

Na disciplina coloca as 115 companhia-ano numa única fronteira. A v2 fazia uma fronteira por ano, com 16 a 30 países.

{{E04}}

> **Diagnóstico.** Com fronteiras anuais, 36 % das DMUs são eficientes e o escore médio sobe justamente nos anos com menos países (0,80 em 2021, com n = 16). O escore acompanhava o tamanho da amostra. Na fronteira agrupada, 9 % são eficientes e os rankings mudam de forma moderada (Spearman 0,84).

> **Melhoria incorporada.** Fronteira agrupada com as 208 observações como desenho principal, como na aula, com o ano como contextual; as fronteiras anuais viram robustez. O Malmquist cuida do deslocamento da fronteira (seção 8).

> **Leitura revisada.** A escolha deixou de ser justificada só pelo template. Com o painel desbalanceado, a fronteira agrupada é a fronteira global ou intertemporal, que envolve as fronteiras contemporâneas de cada ano, e as fronteiras anuais são as fronteiras de grupo de uma metafronteira. A seção 10 desenvolve essa leitura e extrai dela a lacuna tecnológica e um índice de Malmquist que não exige painel balanceado.

![Fronteiras FDH, CRS e VRS em um insumo e um produto, e os eficientes VRS em escala log](figuras/fig02_fronteira_2d.png)

![Distribuição dos escores por método e por modelo na fronteira agrupada](figuras/fig04_boxplot_metodos.png)

---

## 4. Os zeros e o tamanho do deslocamento

A v2 manteve os 17 zeros de investimento somando uma constante ao insumo, testou três magnitudes e concluiu que o CCR era "brutalmente sensível" ao deslocamento.

{{E05}}

> **Diagnóstico.** As constantes testadas (1, 10 e 100 milhões) eram uma, dez e cem vezes o menor valor positivo da base, e a maior delas passa da mediana da amostra. Somar 100 milhões a todos não é uma translação dos zeros, é uma distorção da variável inteira. Por outro lado, o BCC orientado a produto é invariante a translações do insumo (Ali & Seiford, 1990), e a saída confirma: diferença de 2e-15 entre os deslocamentos.

> **Melhoria incorporada.** Deslocamento de US\$ 0,5 milhão (metade do menor valor positivo), robustez com a amostra sem os zeros (Spearman 0,988 com a amostra completa) e eficiência de escala reportada só para as observações com investimento positivo, porque sob CCR ela é indefinida para os zeros. A dummy de zero entra no segundo estágio.

> **Leitura revisada.** O trabalho tratava o zero como possivelmente inferior a meio milhão de dólares, porque o menor valor positivo da base é exatamente um milhão. Essa leitura foi abandonada: o zero é a informação de que não houve investimento privado registrado, e a célula em branco é que seria ausência de informação. Como o modelo BCC orientado a produto é invariante a translações do insumo, os escores principais já são os de "zero é zero", e o deslocamento permanece apenas como artifício computacional das técnicas que tomam o logaritmo do insumo. O que muda é a interpretação, no trecho seguinte.

{{E12}}

> **Diagnóstico.** Sob retornos variáveis e orientação a produto, uma observação sem investimento só pode ser envelopada por outras sem investimento, porque qualquer combinação de referência que a domine precisa ter insumo menor ou igual. Entre as dezessete nessa condição, a de menor gasto em pesquisa é eficiente por construção: é o caso de Peru-2018, que define a fronteira nos quatro modelos. A leitura do topo do ranking muda com isso. O Peru cai de 0,53 para 0,37 quando a média é calculada só sobre os anos com investimento positivo, e a Eslovênia, que aparecia em nono lugar, tem uma única observação, de um ano sem investimento.

> **Melhoria incorporada.** As tabelas de eficientes marcam as observações sem investimento; o ranking por país informa quantos anos cada um tem e traz a média restrita aos anos com investimento positivo, cuja correlação de postos com a média completa é 0,96; e a robustez sem os zeros passou a cobrir os três modelos, não só o de síntese. Nada disso retira as observações da amostra: elas são a informação de que houve produção científica e tecnológica financiada apenas por pesquisa pública, e servem de referência a países com investimento positivo.

---

## 5. O núcleo da v3 e o que ele mostra

Com unidades consistentes e fronteira agrupada, o trabalho estima quatro modelos: **S** (investimento, P&D → publicações), **T** (→ patentes), **ST** (→ ambos) e **C** (publicações, investimento, P&D → patentes), este último o teste direto da hipótese sobre pesquisa que vira patente.

| Modelo | FDH eficientes | CCR eficientes | BCC eficientes | BCC média | Zeros eficientes (BCC) | Não-zeros eficientes |
|---|---|---|---|---|---|---|
| S | 25,0 % | 2,4 % | 7,7 % | 0,459 | 23,5 % | 6,3 % |
| T | 18,3 % | 1,9 % | 3,4 % | 0,146 | 11,8 % | 2,6 % |
| ST | 46,6 % | 4,8 % | 9,1 % | 0,486 | 29,4 % | 7,3 % |
| C | 22,6 % | 1,9 % | 3,8 % | 0,165 | 17,6 % | 2,6 % |

Três coisas saltam da leitura dos escores por país (tabela `t03_medias_pais.csv`):

- **Quem está na fronteira.** Em S: Austrália-2013, China (2013, 2019–2021), Índia (2013, 2016, 2019, 2020), Malásia-2014, Peru (2018, 2021), Romênia (2018, 2020), Ucrânia (2017, 2018). Em T: Austrália-2013, China (2013, 2020, 2021), México-2018, Peru-2018, Ucrânia-2014. Peru, Ucrânia, Malásia e Romênia entram por terem insumos minúsculos; a supereficiência CRS confirma (Ucrânia-2014 1,81; Malásia-2014 1,78). Israel, com o maior investimento por habitante, é o menos eficiente em ST (0,11). O modelo mede publicações e patentes por dólar de capital de risco e de P&D, e onde há muito capital de risco essa razão é naturalmente baixa. Isso fica registrado no artigo.
- **O Brasil** fica em 10º de 37 na conversão pesquisa → patente (0,19) e em 0,36 na síntese ST. Nada de "publica e não patenteia".
- **Os últimos da conversão** são Suíça, Irlanda, Holanda, Bélgica, Noruega e Israel, com patentes de IA quase nulas. São exatamente os países que patenteiam via EPO/PCT. Isso sugere que a variável conta pedidos em escritórios nacionais, e é a pendência de dados mais importante do trabalho, retomada nas seções 9 e 10.

![Eficiência de conversão pesquisa → patente por país, colorida pela participação da manufatura no PIB](figuras/fig11_conversao_pais.png)

Robustez do núcleo (Spearman com o escore principal): forma per capita 0,12 para S, 0,90 para T e 0,94 para C; fronteiras anuais 0,84; deslocamento de 1 milhão 1,00; sem os zeros 0,99 em ST, 0,99 em S, 0,98 em T e 0,97 em C; patentes só até 2019, pelo truncamento à direita da série nos anos finais, 0,99; sem Luxemburgo e Singapura 1,00; insumos defasados em um ano 0,89; sem os seis países com um ou dois anos observados 1,00 nos quatro modelos. T e C são estáveis; S não é.

A cobertura da base condiciona a leitura do ranking por país, e por isso passou a ser apresentada antes dele.

{{E13}}

![Cobertura da base: países por ano, com as observações sem investimento destacadas](figuras/fig12_cobertura_pais_ano.png)

> **Diagnóstico.** Nove países têm os nove anos e seis têm um ou dois; as observações caem de trinta em 2018 para dezesseis em 2021. Dos dezessete anos sem investimento privado, cinco são da Ucrânia, que tem seis observações. Entre as contextuais, só a participação da manufatura tem ausências, três, e a série de pesquisadores por milhão de habitantes, com trinta e uma, não entra em nenhuma regressão.

> **Melhoria incorporada.** O ranking por país informa o número de anos observados e destaca em tom mais claro os países com menos de três; um cenário de robustez repete as quatro fronteiras sem esses seis países, sem alterar a ordenação; e a série de pesquisadores deixou de ser interpolada, porque a interpolação repetia valores por até seis anos numa variável que o trabalho não usa.

---

## 6. Bootstrap: quando o pacote devolve escores negativos

O bootstrap de Simar-Wilson foi estimado exatamente como na Lecture 03.

{{E06}}

> **Diagnóstico.** O `rDEA` corrige o viés na escala do escore (0 a 1) e, com a cauda pesada do modelo de patentes, o viés estimado supera o próprio escore: 77 escores negativos em 208, mínimo de −76. O mesmo aparece na Lecture 03 (mínimo −0,32 na saída da aula), só que aqui a cauda é muito mais longa.

> **Melhoria incorporada.** A correção refeita na escala de Farrell (φ = 1/θ) com as réplicas que o próprio pacote devolve: nenhum negativo, escore corrigido médio 0,097 contra 0,146 original, e ranking preservado (Spearman 0,999). O `scripts/pipeline_v3.R` faz isso para S, T e C.

![Escores originais e corrigidos de viés por modelo](figuras/fig05_bootstrap.png)

---

## 7. Segundo estágio: do gap em OLS ao Algoritmo 2 em log(δ)

A v2 propunha regredir o gap T − S por OLS com vinte parâmetros para 37 países. Essa escolha foi abandonada por três razões: não é o segundo estágio da aula (Tobit e `dea.env.robust`), a diferença de dois escores limitados e dependentes herda os problemas dos dois, e a variável "anos desde o primeiro investimento" media apenas "anos na amostra" (em 28 dos 36 países o primeiro ano positivo é o primeiro ano observado).

O Algoritmo 2 foi então estimado como na Lecture 04.

{{E07}}

> **Diagnóstico.** No modelo de patentes a distância à fronteira tem mediana 21 e máximo acima de 1.400. A regressão truncada linear em δ não aguenta: σ̂ = 720 e intervalos que nem contêm a estimativa pontual. Em S, onde δ é moderado, a versão linear funciona.

> **Melhoria incorporada.** O mesmo Algoritmo 2, com a regressão truncada em **log(δ)** (`truncreg`, truncatura em zero), implementado em R com os mesmos dois laços de bootstrap. A regressão fica bem comportada (σ̂ = 1,48) e o coeficiente da manufatura sai negativo sobre a ineficiência, −0,142 com intervalo [−0,198; −0,083]: mais manufatura, menos distância à fronteira. Os avisos de `NaN` são da verossimilhança do `truncreg` em pontos extremos durante a otimização e não afetam o ajuste.

No Tobit (`censReg`, como na aula) e no OLS com erros agrupados por país, sem a variável de voice, o resultado era o mesmo: manufatura positiva e significativa em T e C (Tobit p < 1e-5; OLS agrupado p 0,02–0,03) e fraca em S. Até aqui, H1 parecia respondida e H2 também.

![Coeficientes do segundo estágio em log(δ) com intervalos bootstrap, por modelo](figuras/fig10_segundo_estagio.png)

A figura serve como síntese, mas o manuscrito precisa da tabela: os três modelos avaliados à luz das mesmas contextuais, em três estimadores. Ela está completa em `resultados/t20_regressoes_paper.md`; o trecho abaixo traz o painel do Tobit e o resumo das diferenças entre modelos.

{{E14}}

> **Diagnóstico.** Os determinantes da eficiência científica não são os da tecnológica. O produto por habitante entra com sinal negativo e significativo apenas no modelo científico, em dois estimadores, e com sinal oposto no de conversão; a governança e os empréstimos inadimplentes só aparecem no científico; a participação da manufatura, o Z-score bancário e a ausência de investimento privado só nos de patente. A participação dos manufaturados nas exportações entra com sinal negativo nos modelos de patente, o oposto da participação da manufatura no produto, o que sugere que exportar manufatura e produzir tecnologia própria são coisas distintas nesta amostra. Só a voz e responsabilização é significativa nos três, sempre no mesmo sentido implausível discutido na seção seguinte.

> **Melhoria incorporada.** A tabela em formato de periódico passou a ser gerada pelo pipeline, com os três painéis e a mesma lista de contextuais, ao lado de um resumo que registra, para cada variável, em quantos estimadores ela é significativa e em que sentido. É a partir dessa leitura, e não da comparação de um coeficiente isolado, que a discussão do manuscrito se organiza.

---

## 8. O que mais o template mostrou

{{E08}}

> **Diagnóstico.** No modelo de publicações o SFA não identifica ineficiência (λ negativo: os resíduos têm a assimetria "errada"). Não é defeito de código, é heterogeneidade entre países dominando o termo de ineficiência, o que combina com o resultado das classes latentes (duas classes que separam sistemas grandes de pequenos, não renda). No modelo de patentes o SFA funciona: 22 % da variância é ineficiência, elasticidade de quase 1 em P&D, correlação 0,62 com o BCC.

{{E10}}

> **Diagnóstico.** A v2 tinha rebaixado o Malmquist "por causa do painel desbalanceado". Ele roda como na aula no subpainel 2016–2021 (13 países) e diz algo substantivo: a fronteira de publicações por dólar recuou (deslocamento 0,891) enquanto o investimento mediano subiu de 9 para 243 milhões de dólares, com catch-up de 1,089. O FDH continua pouco informativo (25 % eficientes na fronteira agrupada, 53 % nas anuais) e o Order-m coloca a mediana dos países a seis vezes o produto esperado dos 25 melhores pares.

Fusões como blocos regionais (Mercosul, Aliança do Pacífico, Benelux, Ibéria, Visegrád, Leste da UE) mostram ganho de harmonia em todos os blocos (4 a 21 %) e perda de escala em todos (o bloco fundido cai na região de retornos decrescentes); o TOPSIS com pesos iguais premia volume e coloca a China no topo em todos os anos.

![Índice de Malmquist e componentes no subpainel 2016–2021](figuras/fig08_malmquist.png)

---

## 9. A reviravolta: Voice & Accountability

O desenho previa três variáveis institucionais: controle de corrupção, efetividade do governo e voz e responsabilização. As duas primeiras já estavam na base e têm correlação 0,95 entre si, por isso foram combinadas num índice único; Voice & Accountability foi acrescentada em 20/09, a partir de arquivo do WGI.

{{E09}}

> **Diagnóstico.** Manufatura e voice têm correlação −0,60: nesta amostra, base industrial e democracia são quase o mesmo eixo, com economias manufatureiras asiáticas e emergentes de um lado e democracias ocidentais de outro. Quando voice entra, o coeficiente da manufatura cai pela metade e perde a significância com erros agrupados. Sem os 13 países de patente quase zero, a manufatura continua forte se voice fica fora e some quando voice entra. E voice tem sinal implausível: mais democracia, menos eficiência em patentes, com magnitude que corresponderia a 55 % mais distância à fronteira a cada dez pontos.

> **Leitura revisada.** A leitura honesta é que, com a variável de patentes atual, não dá para separar "base industrial" de "regime político ou escritório de patentes": voice separa a China (31, que define a fronteira) das democracias europeias que aparecem com patente zero por construção da variável. H1 passa de "respondida" a "plausível, com evidência frágil". Isso está registrado na tabela `t19_sensibilidade_2o_estagio.csv` e é assim que o resultado será apresentado em 28/09.

---

## 10. A fronteira agrupada é uma metafronteira

A segunda sessão de orientação observou que o painel desbalanceado justifica tratar a fronteira agrupada como metafronteira. A observação dá estatuto teórico ao que era uma escolha de template e produz três resultados que o desenho anterior não extraía.

A fronteira agrupada é a fronteira global ou intertemporal: ela envolve as fronteiras contemporâneas de cada ano, porque o conjunto das 208 observações contém o de cada ano. A razão entre a eficiência medida contra a fronteira do próprio ano e a medida contra a fronteira global é a lacuna tecnológica, que diz quanto a melhor prática de um ano fica aquém da melhor prática de todo o período.

{{E11}}

> **Diagnóstico.** No modelo de patentes, 17,8 % das observações são eficientes contra o próprio ano e 3,4 % contra a fronteira global: a diferença entre os dois números, que antes parecia um problema de especificação, é a lacuna tecnológica. Ela vale 0,49 em média e tem trajetória clara: cai de 0,63 em 2013 para 0,27 em 2016 e volta a 0,83 em 2020. A tecnologia de conversão de dinheiro em patente de inteligência artificial piorou na segunda metade da década passada e recuperou terreno no fim do período. A lacuna calculada com o número de observações igualado ao do menor ano preserva esse desenho, de modo que ele não é efeito do tamanho da amostra de cada ano.

> **Melhoria incorporada.** A metafronteira entrou no pipeline para os quatro modelos, com três referências: a fronteira contemporânea, a sequencial (que usa os anos até t) e a união não convexa das fronteiras anuais. Dessa última vem uma ressalva metodológica: a fronteira agrupada convexifica a união, isto é, admite combinações de observações de anos diferentes, e o efeito não é desprezível, entre 10 % e 27 % conforme o modelo. Só cerca de um oitavo das observações está na metatecnologia não convexa. As duas versões são reportadas lado a lado.

> **Melhoria incorporada.** O índice de Malmquist ganhou uma versão global. Com a fronteira intertemporal como referência única, ele não exige painel balanceado e cobre 34 países, contra os 13 do subpainel de 2016 a 2021, e se decompõe exatamente em aproximação à fronteira do próprio ano e deslocamento dessa fronteira em relação à global. No modelo de publicações, o índice global indica ganho de 4,9 % no período; no de patentes, queda, com avanço da fronteira e afastamento dos países em relação a ela. A comparação com o índice adjacente do subpainel, no mesmo período e nos mesmos países, tem correlação de postos de 0,70 mas níveis diferentes, o que é o comportamento esperado: o índice adjacente atribui a regresso técnico o que o global lê como distância à melhor prática do período.

Uma decomposição exploratória por faixa de renda mostra que a fronteira global é essencialmente a dos países de renda média: a lacuna desse grupo é de 0,95 no modelo científico e 0,99 no tecnológico, contra 0,65 e 0,31 no grupo de renda alta. É a mesma heterogeneidade que o SFA não consegue identificar no modelo científico e que as classes latentes separam por tamanho.

![Lacuna tecnológica média por ano e por modelo, com o número de observações de cada ano](figuras/fig13_tgr_por_ano.png)

---

## 11. O que a base de publicações mede e os casos que quebram o padrão

A orientação observou que a variável de publicações cobre um recorte da produção científica de cada país, e que a participação desse recorte no total varia muito. Uma fonte externa permite medir isso e, de passagem, conferir a própria variável.

{{E15}}

> **Diagnóstico.** A variável da base e a contagem de artigos de inteligência artificial do OpenAlex ordenam os países quase da mesma forma, com correlação de postos de 0,96, mas em níveis diferentes, com razão mediana de 1,45 e variação sistemática por país. São bases de indexação distintas, e a conferência sustenta o uso da variável para comparar países, não para ler volumes absolutos. A composição da produção total confirma o argumento da orientação: as ciências exatas e da vida respondem por 75 % dos artigos chineses e 60 % dos japoneses, contra 39 % dos brasileiros e 33 % dos peruanos, e as ciências sociais fazem o caminho inverso, de 7 % na China e no Japão a 42 % no Peru.

> **Melhoria incorporada.** A participação das ciências exatas e da vida e a participação da inteligência artificial no período anterior ao analisado entraram como contextuais de sensibilidade no segundo estágio. Não entram na especificação principal porque a participação medida no mesmo ano é simultânea aos produtos do modelo; a versão anterior ao período é predeterminada e não tem esse problema.

![Composição da produção científica de cada país: participação das ciências exatas e da vida e das ciências sociais](figuras/fig14_especializacao.png)

O mesmo material sustenta a discussão dos casos, pedida na orientação, que está em `documentos/discussao_casos.md`. Três posições do topo do ranking não são desempenho, e sim geometria da fronteira: Peru, Ucrânia e Eslovênia aparecem à frente porque suas observações sem investimento só podem ser comparadas entre si. México e Japão são os casos substantivos do topo, com nove anos observados, participação da manufatura perto de 20 % do produto e conversão alta. Na cauda, Suíça, Irlanda, Holanda, Bélgica, Noruega e Israel formam um bloco explicado pela rota de depósito da patente, e França e Reino Unido, que têm volume de patentes muito acima desse bloco, se distinguem pela composição da produção científica, com um quarto dos artigos em ciências sociais.

A conferência interna apoia a leitura sobre o escritório de depósito: as patentes de inteligência artificial acompanham os depósitos de residentes, com correlação de 0,88 em logaritmo, contra 0,71 com os de não residentes, e a razão entre patentes de inteligência artificial e depósitos de residentes é de 5,3 por mil nos treze países que depositam pela via europeia, contra 8,3 por mil nos demais. A diferença é modesta, de modo que a evidência é sugestiva e não substitui a série por país do inventor.

---

## 12. Situação atual

| Pergunta ou hipótese | Situação | Evidência |
|---|---|---|
| Quem é eficiente em converter esforço financeiro em ciência e tecnologia | Respondida com ressalvas | Fronteira agrupada, quatro modelos, robustez em nove cenários; ranking tecnológico estável, científico instável entre unidades |
| H1: base industrial → mais eficiência em patentes | Plausível, evidência frágil | Positiva e significativa em Tobit, OLS agrupado e Simar-Wilson sem voice; cai pela metade com voice; some sem os países de patente ≈ 0 |
| H2: base industrial importa menos para ciência | Compatível | Coeficiente fraco e instável em S em todos os estimadores; S não é robusto entre unidades |
| Instituições e solidez financeira | Inconclusivo | Voice com sinal implausível; Z-score negativo sobre a ineficiência em T e C; governança perde significância com voice |
| Dinâmica | Respondida | Malmquist global em 34 países: a tecnologia de patentes avançou e os países se afastaram dela; a lacuna tecnológica cai até 2016 e se recupera até 2020 |
| O que a variável de publicações mede | Respondida | Mesma ordenação do OpenAlex (0,96) em níveis diferentes; a participação das exatas e da vida vai de 33 % a 75 % entre os países |
| Por que países improváveis lideram | Respondida | Peru, Ucrânia e Eslovênia são âncoras das observações sem investimento; México e Japão são os casos substantivos do topo |

Pendências de dados, em ordem de importância: (1) definição de `AI.Patent.Applications` (inventor ou depositante, escritório) e uma série alternativa por país do inventor (OECD.AI, WIPO), agora com evidência interna de que a variável acompanha depósitos de residentes; (2) escala e fonte do arquivo de Voice & Accountability (0–100, não é o percentil do WGI); (3) unidade do investimento (corrente ou constante) e cobertura por país do rastreador. A origem dos zeros deixou de ser pendência: eles são tratados como ausência de investimento, não como valor abaixo de um limiar.

---

## 13. Decisões em aberto

As melhorias das seções anteriores já estão incorporadas ao trabalho. Restam seis decisões, que dependem de discussão antes da apresentação e da submissão.

1. **Unidades.** A forma em contagem e dólares é a principal e a per capita entra como robustez. O escore científico muda de ranking entre as duas formas, e o relatório opta por registrar essa instabilidade em vez de escolher a versão de resultado mais favorável. Falta confirmar a escolha.
2. **Patentes.** Definir o tratamento dos 13 países de patente quase nula: excluí-los, marcá-los com uma variável binária ou trocar a fonte por patentes atribuídas ao país do inventor, antes de qualquer conclusão sobre H1.
3. **Algoritmo 2 em log(δ).** A versão linear do `rDEA` é instável em T e C. Definir se a reimplementação em log(δ) com `truncreg` entra no manuscrito como estimador principal ou se o Tobit assume esse papel, com a regressão truncada restrita a S.
4. **Manufatura × voice.** Definir entre reportar os dois conjuntos de contextuais lado a lado, com e sem voice, apresentando H1 como frágil, e construir um índice institucional único.
5. **Deck de 28/09.** Doze slides seguindo o template da disciplina (fronteiras, folgas, fusões, Malmquist, TOPSIS, bootstrap, SFA, Order-m, classes latentes, testes, Tobit, truncada bootstrap), com o diagnóstico setorial nos dois últimos. Falta definir se alguma técnica merece mais tempo.
6. **Periódico.** Socio-Economic Planning Sciences, Technological Forecasting & Social Change ou Journal of the Knowledge Economy. Falta escrever o parágrafo que justifica o uso de fronteira em lugar de modelos de mediação e moderação, e localizar o trabalho do grupo com esta mesma base (Fukuyama, Tan & Wanke, 2025, e o estudo econométrico correlato) para posicionar a contribuição.

---

## 14. Pontos em aberto com o professor

A segunda sessão de orientação respondeu parte das perguntas que esta seção reunia, e as respostas estão incorporadas às seções anteriores: a fronteira agrupada é adequada e tem estatuto de metafronteira; o zero é informação verdadeira e não pede análise de ponto de corte; as observações de insumo mínimo devem ser interpretadas e discutidas como casos, não excluídas; o segundo estágio vai ao manuscrito como tabela de regressões com os três modelos; e o resultado que contraria a hipótese pede construção contrafactual na discussão. O registro completo está em `documentos/orientacao_sessao_2.md`.

O que segue são as perguntas que continuam abertas: em cada uma, o que foi feito, onde está a dúvida e o que a resposta mudaria. Dentro de cada bloco, os pontos estão em ordem decrescente de impacto sobre o trabalho.

### Sobre os dados

- **A variável de patentes.** O trabalho inferiu, por testes internos, que `AI.Patent.Applications` é por milhão de habitantes e que conta depósitos em escritórios nacionais, o que zera países que patenteiam via EPO e PCT (Suíça, Holanda, Irlanda, Bélgica, Noruega, Israel e outros sete). O grupo do professor já trabalhou com esta base (Fukuyama, Tan & Wanke, 2025). A dúvida é de fonte: qual a definição exata (país do inventor ou do depositante; escritório), como esses países foram tratados nesse trabalho e se existe uma série alternativa já usada pelo grupo (OECD.AI, WIPO). A resposta decide o tratamento dos 13 países e, com ele, o veredito sobre H1; nenhuma outra pendência tem esse alcance.
- **O investimento.** A fonte arredonda a milhões, e o menor valor positivo é exatamente US\$ 1.000.000. O zero passou a ser lido como ausência de investimento privado registrado, conforme a orientação. Resta saber se a fonte é conhecida (AI Index, Quid), se os valores são correntes ou constantes e qual a cobertura do rastreador por país, o que afeta a comparabilidade entre economias pequenas e grandes.
- **Voice & Accountability.** O arquivo está numa escala 0–100 que não corresponde ao percentil do WGI (Noruega 90, China 31), e a fonte exata ainda não está documentada. Uma conclusão central depende dessa variável. A dúvida é se o grupo dispõe da série original do WGI e se a escala usada altera a leitura.

### Sobre o desenho da fronteira

- **Modelo C como estágio único ou DEA em rede.** O modelo C coloca as publicações do lado dos insumos das patentes. É uma forma de comprimir num único DEA o que seria uma rede de dois estágios (investimento e P&D → publicações → patentes). A dúvida: se o modelo C é defensível como está num manuscrito ou se a versão correta é o DEA em rede, como nos trabalhos vistos nas sessões iniciais. A resposta muda a peça central do argumento e qual escore o segundo estágio explica.
- **A convexificação da metafronteira.** A fronteira agrupada admite combinações de observações de anos diferentes, o que a união das tecnologias anuais não admite, e o efeito vai de 10 % a 27 % conforme o modelo. O trabalho reporta as duas versões. A dúvida é se a versão convexa basta como resultado principal num manuscrito, com a não convexa em nota, ou se a literatura recente exige o contrário.
- **Defasagens.** A literatura de sistemas de inovação espera investimento em t, publicações em t+1 e patentes em t+2. A especificação principal é contemporânea; a defasada de um ano entra como robustez (154 pares, Spearman 0,89). A dúvida é se a defasada deveria ser a principal, mesmo perdendo um quarto das observações, ou se contemporânea com robustez basta.
- **O escore científico que não é robusto.** O modelo S muda de ranking entre a forma em contagem e a per capita (Spearman 0,12), o SFA não identifica ineficiência nele (λ < 0) e as classes latentes separam sistemas grandes de pequenos. Três caminhos: manter S e reportar a instabilidade; tirar S do manuscrito e ficar com T, C e ST; ou tratar S por classes, com uma metafronteira. A opinião de quem publica com DEA sobre o que um parecerista aceita decide.

### Sobre o segundo estágio

- **O estimador do manuscrito.** A regressão truncada linear do `rDEA` não se sustenta nos modelos de patentes (σ̂ = 720); a versão em log(δ) é implementação própria. A dúvida: se um periódico aceita a reimplementação como estimador principal, ou se o caminho seguro é Tobit como principal com a regressão truncada restrita ao modelo S. E como tratar, no Algoritmo 2, a dependência entre os anos de um mesmo país, que o procedimento original não prevê: a orientação apontou que o segundo estágio seria de efeito aleatório, e o trabalho hoje reporta OLS com erros agrupados por país ao lado.
- **Manufatura, voice e o índice institucional.** As duas têm correlação −0,60 e não se separam nesta amostra; voice entra com sinal negativo sobre a eficiência. A orientação previa que voice poderia empurrar em qualquer direção; a dúvida é se este sinal, nesta magnitude, é ruído, artefato do escritório de patentes ou uma explicação substantiva que o trabalho não está vendo. E, na forma de reportar: os dois conjuntos de contextuais lado a lado, como está, ou um índice institucional único.
- **Separabilidade.** O segundo estágio pressupõe que as contextuais não alteram a forma da fronteira, só a distância a ela (Daraio, Simar & Wilson, 2018). A hipótese é pouco plausível para a manufatura, que pode deslocar a própria fronteira de patentes, e não há teste na disciplina. A dúvida é se basta discutir como limitação ou se o grupo usa algum teste, ou o Order-m condicional, em publicações recentes.

### Sobre o manuscrito e a apresentação

- **Escopo e periódico.** O Syllabus manda replicar todas as técnicas; no manuscrito, quais ficam. E o periódico: SEPS, Technological Forecasting & Social Change ou Journal of the Knowledge Economy. A orientação mencionou que o grupo já explorou esta base "tudo econometria" e que há periódicos que preferem mediação e moderação a DEA; a dúvida é qual é esse trabalho, como posicionar a contribuição sem sobrepor Fukuyama, Tan & Wanke (2025), e como justificar a escolha pela fronteira.
- **O diagnóstico setorial do deck.** O Syllabus pede diagnóstico setorial nos slides finais. A dúvida é de recorte: o Brasil (10º de 37 na conversão, 0,36 na síntese) ou o sistema de IA como um todo (lacuna tecnológica que se recupera no fim do período, países que depositam fora do escritório nacional ausentes do mapa de patentes); e quanto dos vinte minutos dedicar às técnicas em relação ao diagnóstico.
- **Capital humano.** A contribuição oferecida na sessão, sobre formandos em áreas de ciência e tecnologia e patentes, não pode entrar no painel: a série cobre menos da metade das observações e falta inteira para China, Japão, Israel e Argentina. A dúvida é se ela entra na revisão de literatura, na discussão, ou nas duas.

Se houver tempo para poucos pontos, os que mais mudam o trabalho são a variável de patentes, o modelo C como estágio único ou rede, e o estimador do segundo estágio; os demais podem esperar a submissão.

---

## Anexo: reprodução

- `Rscript scripts/pipeline_v3.R` (cerca de um minuto) gera `resultados/t01`–`t28` e `resultados/figuras/fig01`–`fig14`; `RAPIDO=FALSE` para os valores finais. O arquivo segue o Google R Style Guide e traz o cabeçalho com entradas, saídas e modo de uso.
- `Rscript scripts/relatorio/run_prints.R` regenera as saídas deste relatório em `resultados/prints/`; `python3 scripts/relatorio/build_report.py` remonta este documento e a versão em página.
- `Rscript scripts/replica_analise_critica.R` reproduz a análise crítica da v2 sem depender de pacotes de DEA.
- Contextuais e fontes externas: `bash dados/baixar_wdi.sh` (WDI), `dados/wgi.voice_accountability.csv` (WGI) e `bash dados/baixar_openalex.sh` (OpenAlex, para a conferência das publicações e a composição da produção científica).
- Documentos: `documentos/proposta_v3.md` (proposta atual), `documentos/orientacao_sessao_2.md` (registro da segunda sessão de orientação), `documentos/discussao_casos.md` (casos do topo e da cauda do ranking), `documentos/analise_critica.md` (crítica das versões anteriores), `documentos/anteriores/proposta_v2_revisada.md` e `documentos/anteriores/proposta_eficiencia_ia.md` (versões anteriores), `material_disciplina/comments.txt` e `material_disciplina/comments_sessao_2.txt` (orientação transcrita).
