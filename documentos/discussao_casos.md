# Casos que quebram o padrão

Documento de apoio à discussão do manuscrito. A segunda sessão de orientação
pediu que os países do topo e da cauda do ranking de conversão de pesquisa em
patente virassem casos discutidos, com construção contrafactual na discussão e
não na revisão de literatura. Cada seção reúne o que o trabalho mede
(`resultados/t26_casos_discussao.csv`), a especialização do país segundo o
OpenAlex (`dados/openalex_nichos.csv` e `resultados/t28_conferencia_publicacoes.csv`),
a hipótese levantada e o que a confirmaria. As hipóteses sobre a economia de cada
país estão marcadas como tais: elas precisam de fonte antes de entrar no
manuscrito.

Os números são médias dos anos observados. O investimento está em milhões de
dólares de 2015, o gasto em pesquisa e desenvolvimento também; a eficiência de
conversão é o escore BCC do modelo C, e a lacuna tecnológica é a razão entre a
eficiência contra a fronteira do ano e a eficiência contra a fronteira global.

| País | Anos | Anos sem investimento | Investimento | P&D | Publicações | Patentes | Conversão | Lacuna | Manufatura % PIB |
|---|---|---|---|---|---|---|---|---|---|
| China | 9 | 0 | 6.835 | 276.838 | 40.071 | 27.930 | 0,63 | 0,63 | 27,7 |
| Peru | 4 | 1 | 1 | 309 | 236 | 5 | 0,53 | 0,53 | 12,6 |
| Ucrânia | 6 | 5 | 0,2 | 564 | 268 | 9 | 0,49 | 0,54 | 11,8 |
| Japão | 9 | 0 | 899 | 144.796 | 7.044 | 2.264 | 0,46 | 0,60 | 19,9 |
| México | 9 | 0 | 47 | 4.305 | 1.063 | 60 | 0,45 | 0,71 | 19,7 |
| Luxemburgo | 6 | 1 | 116 | 765 | 172 | 13 | 0,35 | 0,35 | 5,0 |
| Eslovênia | 1 | 1 | 0 | 940 | 244 | 4 | 0,19 | 0,19 | 20,4 |
| Brasil | 8 | 0 | 207 | 22.001 | 2.138 | 92 | 0,19 | 0,61 | 10,5 |
| Reino Unido | 3 | 0 | 2.307 | 66.483 | 8.239 | 190 | 0,03 | 0,44 | 9,3 |
| França | 6 | 0 | 865 | 54.854 | 5.026 | 76 | 0,02 | 0,37 | 10,1 |
| Israel | 9 | 0 | 1.400 | 15.777 | 1.182 | 17 | 0,02 | 0,48 | 12,2 |
| Holanda | 5 | 0 | 320 | 16.831 | 1.646 | 4 | 0,01 | 0,40 | 10,1 |
| Irlanda | 2 | 0 | 175 | 3.913 | 549 | 2 | 0,00 | 0,41 | 32,7 |
| Suíça | 1 | 0 | 926 | 21.367 | 1.349 | 3 | 0,00 | 0,15 | 17,9 |

---

## Topo do ranking

### Três posições que não são desempenho

Antes de qualquer interpretação econômica, três posições do topo se explicam
pela geometria da fronteira. Sob retornos variáveis de escala e orientação a
produto, uma observação sem investimento privado em inteligência artificial só
pode ser comparada a outras observações sem investimento, porque qualquer
combinação de referência que a domine precisa ter insumo menor ou igual. Entre
as dezessete observações nessa condição, a de menor gasto em pesquisa é
eficiente por construção.

- **Peru** aparece em terceiro com investimento médio de um milhão de dólares e
  o menor gasto em pesquisa entre as observações sem investimento. Peru-2018 é
  eficiente nos quatro modelos por essa razão. Nos demais anos o escore de
  conversão cai para 0,37 em média.
- **Eslovênia** aparece em nono com uma única observação, de um ano sem
  investimento. Não há série para avaliar.
- **Ucrânia** tem cinco anos sem investimento em seis observados e investimento
  médio de duzentos mil dólares, o menor da amostra.

A consequência prática é que o ranking por país passou a marcar o número de anos
observados e os anos sem investimento, e a reportar a média calculada apenas
sobre os anos com investimento positivo. A correlação de postos entre as duas
médias é 0,96, mas Peru e Ucrânia caem várias posições na segunda.

Nada disso desqualifica as observações. Elas são a informação de que houve
produção científica e tecnológica em inteligência artificial financiada apenas
por pesquisa pública, e servem de referência a países com investimento positivo:
Malásia-2014, por exemplo, é par de cinquenta observações no modelo de síntese.

### México

Com nove anos observados, eficiência média de conversão de 0,45 e participação
da manufatura de 19,7 % do produto, o México é o caso substantivo do topo. O
investimento privado é modesto para o tamanho da economia, 47 milhões de dólares
em média, contra 207 milhões do Brasil, mas a produção de patentes por dólar é
alta. A lacuna tecnológica de 0,71 é a maior entre os casos, o que significa que
a fronteira do próprio ano está relativamente perto da fronteira de todo o
período: o México é eficiente contra os seus contemporâneos.

Segundo o OpenAlex, a pesquisa mexicana em inteligência artificial concentra-se
em análise geológica e geoquímica, informação quântica, algoritmos
meta-heurísticos e redes neurais, e está concentrada na Universidad Nacional
Autónoma de México, no Instituto Politécnico Nacional e no seu centro de
pesquisa avançada. A participação das ciências exatas e da vida na produção
total é de 48 %.

*Hipótese levantada na orientação, a verificar:* a recepção de indústria de
transformação estrangeira exigiu uma base de formação técnica e de engenharia
que, sem produzir grande investimento privado em inteligência artificial,
sustenta a conversão de pesquisa em patente. Fontes a consultar: séries de
investimento estrangeiro direto em manufatura, dados de emprego industrial por
qualificação e estatísticas de depósito de patentes do instituto mexicano.

### Japão

O Japão confirma a hipótese central pelo lado esperado: manufatura de 19,9 % do
produto, eficiência de conversão de 0,46 e o segundo maior volume de patentes da
amostra. A produção científica em inteligência artificial é a menos concentrada
em ciências sociais entre os casos, com 6,9 %, e se organiza em robótica
educacional e computação quântica, em torno da Universidade de Tóquio e de
Quioto. É o contraponto que sustenta a leitura: base industrial e conversão
andam juntas quando o país efetivamente deposita patentes no escritório
nacional.

### Luxemburgo

Investimento alto para o tamanho do país, produção científica pequena e
concentrada em criptografia e segurança de dados, na Universidade de Luxemburgo
e no seu centro de segurança e confiabilidade. A participação da inteligência
artificial na produção total é de 3,95 %, a segunda maior da amostra, e a das
ciências sociais é de 37 %. É o exemplo mais claro de especialização estreita:
um sistema pequeno que concentra esforço em duas ou três áreas.

---

## Cauda do ranking

### O bloco que deposita patente fora do escritório nacional

Suíça, Irlanda, Holanda, Bélgica, Noruega e Israel ocupam as últimas posições
com patentes de inteligência artificial próximas de zero: a Holanda registra
quatro por ano, a Irlanda duas, a Suíça três, contra 92 do Brasil e 2.264 do
Japão. São exatamente os países cujas empresas depositam pela via europeia ou
pelo tratado de cooperação em patentes, e não no escritório nacional.

A conferência interna da base sustenta a leitura. As patentes de inteligência
artificial acompanham os depósitos de residentes, com correlação de 0,88 em
logaritmo, e menos os de não residentes, com 0,71. E a razão entre patentes de
inteligência artificial e depósitos de residentes é de 5,3 por mil nesses treze
países, contra 8,3 por mil nos demais. A diferença existe mas é modesta, de modo
que a evidência interna é sugestiva, não conclusiva: a pendência de obter uma
série de patentes atribuídas ao país do inventor continua sendo a mais
importante do trabalho.

### França e Reino Unido

São os dois casos em que a posição na cauda não se explica só pelo escritório de
depósito, porque ambos têm volume de patentes muito acima do bloco anterior, 76
e 190 por ano. O que eles têm em comum é a composição da produção científica: as
ciências sociais respondem por 25,6 % da produção francesa e 22,8 % da britânica,
contra 6,9 % da chinesa e da japonesa; a participação das ciências exatas e da
vida é de 49 % e 43 %, contra 75 % na China. A pesquisa em inteligência
artificial dos dois países é forte em informação quântica, processamento de
linguagem natural e lógica, áreas de menor densidade de patentes, e está
ancorada em instituições de pesquisa pública, o centro nacional de pesquisa
científica na França e as universidades de Londres, Oxford e Cambridge no Reino
Unido.

*Hipótese levantada na orientação, a verificar:* a desindustrialização reduziu a
base capaz de absorver pesquisa aplicada, e o que restou de indústria está
concentrado em defesa e aeroespacial, setores cujo depósito de patentes é
atípico. Fontes a consultar: participação da manufatura no valor adicionado ao
longo do período, composição setorial do depósito de patentes e estatísticas de
pesquisa e desenvolvimento empresarial por setor.

### Israel

É o caso mais difícil. O investimento privado em inteligência artificial é o
maior por habitante da amostra, 1,4 bilhão de dólares por ano numa população de
nove milhões, e a produção científica é substancial. A participação das ciências
exatas e da vida é de 49 %, acima da francesa, e a da inteligência artificial é
de 3,15 %, entre as maiores. A pesquisa se concentra em criptografia, informação
quântica e algoritmos, nas universidades de Tel Aviv, no Technion e em
Ben-Gurion. Ainda assim, a base registra dezessete patentes de inteligência
artificial por ano.

*Hipótese a verificar:* as empresas israelenses depositam diretamente no
escritório americano, porque o mercado alvo é americano e boa parte delas é
adquirida por empresas americanas. Fonte a consultar: estatísticas de depósito
por país de origem do inventor no escritório americano.

O modelo mede publicações e patentes por dólar de capital de risco e de pesquisa.
Onde há muito capital de risco, essa razão é naturalmente baixa, e Israel é o
caso extremo. Isso está registrado no manuscrito como limitação da medida, não
como resultado sobre o desempenho do país.

---

## Brasil: o diagnóstico setorial

O Brasil fica em décimo lugar entre os 37 países na conversão de pesquisa em
patente, com 0,19, e em 0,36 na síntese. A lacuna tecnológica de 0,61 mostra que
a distância à fronteira do próprio ano é bem menor que a distância à melhor
prática de todo o período. Não se confirma a leitura da segunda proposta, de que
o país publicaria sem patentear: na especificação com unidades consistentes, o
Brasil está no meio da tabela nos dois produtos.

A composição da produção científica ajuda a situar o resultado. As ciências
sociais respondem por 38,4 % dos artigos brasileiros e as exatas e da vida por
38,7 %, uma das repartições mais equilibradas da amostra; a inteligência
artificial responde por 1,36 % do total, contra 3,58 % na China. A pesquisa em
inteligência artificial se concentra em análise geológica e geoquímica e em
estudos de linguagem, nas universidades de São Paulo, Minas Gerais, Campinas e
Rio de Janeiro.

*Hipóteses levantadas na orientação, a verificar:* a conversão brasileira de
pesquisa em patente estaria concentrada em nichos com base industrial própria, o
petróleo em águas profundas, o complexo aeroespacial de São José dos Campos, os
biocombustíveis e a pesquisa agropecuária, esta última com a particularidade de
patentear sem finalidade comercial direta. Fontes a consultar: depósitos por
depositante no instituto nacional de propriedade industrial, séries de patentes
das empresas e institutos citados e a classificação setorial desses depósitos.

---

## O que os casos sugerem para o modelo

1. **Falta uma medida de destino do depósito.** A diferença entre países que
   depositam no escritório nacional e países que depositam pela via regional é a
   principal fonte de ruído do modelo tecnológico, e nenhuma variável do trabalho
   a captura.
2. **A composição da produção científica importa.** A participação das ciências
   exatas e da vida varia de 33 % a 75 % entre os países da amostra, e o produto
   do modelo científico é um recorte que representa parcela muito diferente do
   esforço de cada sistema.
3. **A escala do capital de risco distorce a razão.** Países onde o investimento
   privado em inteligência artificial é grande em relação ao sistema científico
   aparecem como ineficientes por construção da medida.
4. **Observações sem investimento precisam de tratamento explícito.** Elas são
   informação legítima, mas formam um subconjunto que só se compara consigo
   mesmo, e isso precisa estar dito onde o ranking é apresentado.
