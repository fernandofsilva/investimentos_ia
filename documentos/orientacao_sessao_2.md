# Orientação da segunda sessão (21/09/2026)

Registro da segunda sessão de apresentação de resultados ao professor, com o que
cada orientação muda no trabalho, o que ela responde das perguntas que estavam em
aberto e o que permanece pendente. A transcrição está em
`material_disciplina/comments_sessao_2.txt`.

A sessão partiu da terceira proposta: unidades consistentes, fronteira agrupada,
quatro modelos, deslocamento nos zeros, bootstrap e segundo estágio com Voice &
Accountability. O desenho geral foi validado. As orientações novas estão abaixo,
na ordem em que apareceram.

---

## 1. A fronteira agrupada é uma metafronteira

> "teu painel é desbalanceado sim, isso já justifica você tratar como meta
> fronteira."

O painel vai de um a nove anos por país e de dezesseis a trinta países por ano. A
escolha da fronteira única com as 208 observações estava justificada apenas pelo
template da disciplina. A orientação dá a ela um estatuto teórico: a fronteira
agrupada é a **fronteira global ou intertemporal** (Tulkens & Vanden Eeckaut,
1995; Pastor & Lovell, 2005), que envolve as fronteiras contemporâneas de cada
ano, e corresponde à metafronteira de O'Donnell, Rao & Battese (2008) na sua
forma convexificada.

**Melhoria incorporada.** As fronteiras anuais deixam de ser um cenário de
robustez e passam a ser as fronteiras de grupo do desenho. A razão entre a
eficiência contra a fronteira do ano e a eficiência contra a fronteira global é a
razão de lacuna tecnológica (*technology gap ratio*), que mede o quanto a
tecnologia disponível em cada ano fica aquém da melhor prática de todo o período.
Duas consequências práticas: a diferença entre 36 % e 9 % de observações
eficientes deixa de ser um problema de especificação e passa a ser um resultado;
e o índice de Malmquist pode ser calculado na forma global, que não exige painel
balanceado e cobre todos os países com pelo menos dois anos, em lugar dos treze
do subpainel 2016–2021.

Duas cautelas foram incorporadas junto. A primeira é que o envelope convexo das
208 observações admite combinações de anos diferentes, o que a metafronteira como
união das tecnologias de grupo não admite; por isso as duas versões são
calculadas e comparadas. A segunda é que anos com menos observações têm
eficiência contemporânea inflada, de modo que a lacuna tecnológica por ano é
recalculada com o número de observações igualado ao do menor ano.

## 2. Zero é zero; célula em branco é que é ausência de informação

> "quando a gente pega uma base, se tem zero e na falta de informação, zero quer
> dizer zero. E a célula em branco é um missing value, não é zero, pode ser
> qualquer coisa."

O trabalho tratava os 17 zeros de investimento como possivelmente inferiores a
meio milhão de dólares, porque o menor valor positivo da base é exatamente um
milhão. A orientação recusa essa leitura e a classifica como análise de ponto de
corte: zero é a informação de que não houve investimento privado registrado.

**Melhoria incorporada.** A leitura passa a ser literal. O deslocamento de meio
milhão continua no código, mas apenas como artifício computacional das técnicas
que tomam o logaritmo do insumo, porque o modelo BCC orientado a produto é
invariante a translações do insumo (Ali & Seiford, 1990) e os escores principais
são, portanto, exatamente os de "zero é zero". O que muda é a interpretação: sob
retornos variáveis, uma observação sem investimento só pode ser comparada a
outras sem investimento, de modo que a de menor gasto em pesquisa e
desenvolvimento entre elas é eficiente por construção. É o caso de Peru-2018 e de
Eslovênia-2018. Esses casos passam a ser identificados como tais nas tabelas, em
vez de figurarem no topo do ranking sem ressalva. Ao mesmo tempo, as observações
sem investimento servem de referência a observações com investimento positivo, e
essa é a leitura substantiva: houve produção científica e tecnológica financiada
apenas por pesquisa pública.

## 3. Trabalho de cirurgião na base

> "a gente tem que fazer um trabalho antes, tentar encontrar a maior quantidade
> de observações possível e o máximo número de variáveis... a base mais compacta
> possível com o menor número de missing."

**Melhoria incorporada.** Uma auditoria explícita da cobertura passa a abrir o
trabalho: a grade de 37 países por 9 anos, com as observações sem investimento
destacadas; a contagem de ausências por variável contextual, antes de qualquer
preenchimento; e a informação de quantos anos cada país tem. O ranking por país
passa a exigir pelo menos três anos observados, e um cenário de robustez repete
as fronteiras sem os seis países com um ou dois anos. A consequência mais direta
é sobre a leitura do ranking: a Eslovênia aparecia em nono lugar na conversão de
pesquisa em patente com uma única observação, de um ano sem investimento.

## 4. Tabela de regressões e discussão das nuances

> "normalmente no paper você mostra o resultado da tabela das regressões... Você
> tem três modelos que você testou à luz das mesmas variáveis contextuais... e
> aí a tua discussão tem que se basear nisso, nas nuances."

A apresentação usou uma figura de coeficientes com intervalos, e o professor
observou que a figura serve como síntese, mas o manuscrito precisa da tabela.

**Melhoria incorporada.** Uma tabela no formato de periódico, com as contextuais
nas linhas e os modelos científico, tecnológico e de conversão nas colunas, em
três painéis: Tobit, mínimos quadrados com erros agrupados por país e o
algoritmo 2 de Simar-Wilson em logaritmo da distância. A discussão passa a
comentar as diferenças entre modelos, que já estão nos resultados: o produto por
habitante é significativo apenas no modelo científico; a solidez bancária, apenas
nos modelos de patente; a participação da manufatura, apenas nos de patente.

## 5. Casos que quebram o padrão

> "quando a gente chega nesses exemplos que quebram os paradigmas, é o momento de
> discutir os resultados... pega os três casos estranhos lá em cima e três lá
> embaixo e tenta construir um case."

A hipótese oferecida foi a das potências regionais de nicho: países que
concentram esforço em duas ou três áreas e por isso convertem bem, mesmo sem a
musculatura industrial da China ou dos Estados Unidos. Os exemplos citados foram
o México (maquiladoras e formação técnica), o Brasil (Petrobras, o complexo
aeroespacial de São José dos Campos, a Embrapa, os biocombustíveis) e a Irlanda
do Norte (ciência de dados).

**Melhoria incorporada.** Uma tabela dos casos com os dados do trabalho e um
documento de discussão com uma seção por país. A verificação feita depois da
sessão qualifica a lista: Peru e Eslovênia estão no topo por serem âncoras da
fronteira sob retornos variáveis, não por especialização, e isso precisa ser dito
antes de qualquer construção contrafactual sobre eles. O México é o caso
substantivo do topo, com nove anos observados e eficiência média de conversão de
0,44, e o Japão o confirma pelo lado da manufatura. Na cauda, Israel, França,
Reino Unido, Suíça, Irlanda e Holanda têm em comum a rota de depósito de patentes
por escritórios regionais, o que remete à pendência de dados mais importante do
trabalho.

## 6. A base de publicações é um subconjunto

> "isso que a gente está falando não são todos os artigos, são os artigos de
> STEM... talvez seja interessante verificar qual é a proporção deles naquilo que
> o país produz."

**Melhoria incorporada.** Duas medidas externas de especialização. A primeira
confere a variável de publicações da base contra uma fonte independente. A
segunda mede a participação das ciências exatas e da vida na produção total de
cada país, e a participação da inteligência artificial nessa produção. Elas
entram no segundo estágio apenas como análise de sensibilidade, porque a
participação medida no mesmo ano é simultânea ao produto do modelo, e sua
principal serventia é a discussão: a França, o Reino Unido e Israel produzem
proporcionalmente muito mais fora das áreas que geram patente do que a China ou o
México.

## 7. Capital humano

A colega Jéssica ofereceu literatura de economia da educação sobre capital
humano, formandos em áreas de ciência e tecnologia e patentes. A série de
formandos dessas áreas cobre menos da metade das observações e falta inteira para
China, Japão, Israel e Argentina, de modo que não entra no painel. A contribuição
fica na revisão de literatura e na discussão.

## 8. Trabalho correlato do grupo

O professor confirmou que a base foi explorada pelo grupo com econometria, em
trabalho submetido com um coautor, e que verificará a situação da submissão para
disponibilizar o texto. A referência já identificada é Fukuyama, Tan & Wanke
(2025).

---

## O que a sessão respondeu

| Pergunta que estava em aberto | Resposta |
|---|---|
| A fronteira agrupada de nove anos é adequada quando a tecnologia se move tanto? | Sim, e com estatuto de metafronteira, justificada pelo painel desbalanceado |
| Como tratar os zeros de investimento | Zero é informação verdadeira; nada de ponto de corte |
| O que fazer com as observações de insumo mínimo que definem a fronteira | Interpretar e discutir como caso, não excluir |
| Como apresentar o segundo estágio no manuscrito | Tabela de regressões com os três modelos e discussão das nuances |
| O que fazer com o resultado que contraria a hipótese | Construção contrafactual na discussão, com casos de nicho |

## O que continua em aberto

1. A definição da variável de patentes (país do inventor ou do depositante,
   escritório de depósito) e o tratamento dos países com patente quase nula.
2. O modelo de conversão como estágio único ou como rede de dois estágios.
3. O estimador do segundo estágio no manuscrito.
4. A hipótese de separabilidade entre as contextuais e a forma da fronteira.
5. O periódico e o posicionamento em relação ao trabalho do grupo.
