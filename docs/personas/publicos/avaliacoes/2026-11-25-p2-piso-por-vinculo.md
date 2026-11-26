# Reavaliação: P2 procura os 1.421 abaixo do piso na folha da Secretaria (2026-11-25)

Quinta rodada da P2 (secretaria municipal), a pedido do developer. A
anterior (2026-11-24, a resposta ao tribunal sobre o piso) teve o veredito
**adotaria, em piloto numa rede**, e o achado QE-01 virou a #585, entregue
(#586): a folha detalhada do total da Secretaria abre pelo painel. Desde
então também: o salário da escola ao lado do da rede (#589) e o painel e a
base mais rápidos (#591, #595).

- **Avaliou:** só a P2.
- **Material:** a folha do total da Secretaria de Cuiabá (abril de 2026),
  o painel financeiro da Secretaria, a base da rede e a folha por município
  de MT, as ajudas de folha de pagamento e de financeiro e folha.
- **O trabalho que ele faria:** com a lista da Secretaria agora visível,
  voltar à pergunta do tribunal ("por que 1.559 profissionais do magistério
  abaixo do piso em 2026?") e achar quem são e o que têm em comum.
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **A lista da Secretaria (#585):** abre pelo painel. Abril de 2026: 13.019
   registros, 131 páginas de 100, busca pelo nome, o aviso de que pode
   haver pagamentos parciais. A coluna **Situação** traz efetivo ou
   temporário, como o município declarou.
2. **Procurar os 1.421:** a lista é de um mês e só busca pelo nome. Não
   marca quem fica abaixo do piso no ano, não filtra por situação, carga
   ou valor, não ordena, não baixa. Folheando, ele nota um temporário de
   30 h com base de R$ 3.212,71 na segunda linha, mas não tem como contar
   quantos são assim.
3. **O que a plataforma sabe e não diz:** a mesma regra da contagem (base
   por 40 h no mês típico, 3 meses ou mais), aberta pela coluna Situação
   que a lista já mostra:

   | Situação | Abaixo do piso | No magistério da rede (2026) |
   |---|---|---|
   | Temporário | 1.422 | 3.280 (43%) |
   | Efetivo | 137 | 3.288 (4%) |

   E 1.474 dos 1.559 têm o mesmo perfil: docente habilitado em pedagogia,
   30 h, base de **R$ 3.212,71** de fevereiro a abril e ~R$ 3.322 de maio
   em diante. O piso proporcional a 30 h é R$ 3.847,97.
4. **A resposta que ele daria com isso:** "a quase totalidade são
   contratos temporários de 30 h, pagos por uma tabela própria abaixo do
   proporcional do piso; os efetivos abaixo são 137, a conferir um a um".
   É uma frase, e é o que o tribunal precisa. Hoje ele só chega a ela com
   a planilha do SIOPE e uma tabela dinâmica fora da plataforma.

## O que funciona para ele

- A folha detalhada da Secretaria existe (QE-01 resolvido), com a situação
  de cada pessoa.
- O número do tribunal continua reproduzido com a regra e os avisos.
- A tela da base e o painel respondem mais rápido (2,7 s e 0,3 a 0,7 s).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QB-01 | atrapalha | **A contagem abaixo do piso não se abre por situação.** O painel, a base e a folha por município dizem quantos ficam abaixo do piso (e quantos só na Secretaria), mas não quantos são temporários e quantos efetivos, nem o perfil mais comum (carga e salário base). A situação está na folha carregada e na lista; a contagem não a usa. Pedido: a contagem abaixo do piso por situação (efetivo, temporário, outros) no painel da Secretaria e nas colunas da folha por município, com o salário base e a carga mais comuns de quem fica abaixo. | Cuiabá 2026: 1.422 dos 1.559 são temporários (43% dos temporários; 4% dos efetivos); 1.474 com 30 h e base R$ 3.212,71 | P2, P5, P6 |
| QB-02 | atrapalha | **A lista da folha não filtra nem marca quem fica abaixo do piso.** A folha detalhada (da escola e da Secretaria) é de um mês, com busca pelo nome e 100 por página. Para conferir os casos (o tribunal pede nome a nome), não dá para filtrar pela situação nem ver quem a contagem do ano pôs abaixo do piso. Pedido: filtro por situação e a marca "abaixo do piso no ano" (a mesma regra da contagem) na lista, com o filtro por ela. | 13.019 registros em 131 páginas; só a busca pelo nome | P2, P5 |

Não é achado: a regra da contagem está certa e os números batem com a
folha (conferido com a consulta direta).

## Veredito

**Adotaria, em piloto numa rede** (mantido). A lista que faltava existe;
falta a plataforma dizer o que a própria contagem já sabe (QB-01) e deixar
conferir os casos sem sair dela (QB-02).

## Encaminhamento

Duas issues, abertas com a aprovação do developer: QB-01 → #597 e
QB-02 → #598. QB-01 vem primeiro: responde ao tribunal em uma frase. QB-02 depende da
marca por pessoa, que a contagem já calcula.

## Andamento

- 2026-11-26: #597 (PR #599) mergeado: QB-01 resolvido. Pela situação dos
  mais meses no ano (empate: a do último mês), Cuiabá 2026 tem 1.417
  temporários e 142 efetivos abaixo do piso (a tabela acima usou outra
  regra); o mais comum é 30 h, base mediana R$ 3.212,71, piso proporcional
  R$ 3.847,97. QB-02 segue na #598.
- 2026-11-26: #598 (PR #600) mergeado: QB-02 resolvido. A folha do mês
  marca quem fica abaixo do piso no ano, com a regra da contagem da rede, e
  filtra por situação e pela marca (Secretaria de Cuiabá, abril de 2026:
  1.504 pessoas marcadas). Os dois achados desta rodada estão entregues.
