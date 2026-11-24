# Reavaliação: P6 compara a folha das prefeituras (2026-11-24)

Quarta rodada da P6 (terceiro setor e jornalismo de dados), feita no modo
autônomo autorizado pelo developer (até 25/11, 9h). A anterior
(2026-11-24, o piso do magistério) teve o veredito **adotaria**, e os
achados viraram a #563 (salário base e piso) e a #564 (registro da carga),
entregues. Desde então: o salário da rede inteira (#571), a carga que não
parece em horas (#572), o piso na rede inteira (#575) e o aviso do mês
incompleto com a carga (#576).

- **Avaliou:** só a P6.
- **Material:** a tela da base de análise das quatro redes com folha
  (Alta Floresta, Cuiabá, Taubaté e Ubatuba), o painel financeiro da
  Secretaria de Taubaté e de uma escola de Ubatuba, `/fontes` e as ajudas.
- **A pauta:** o jornalista de dados de um observatório monta uma tabela
  comparando as prefeituras com folha carregada: quanto pagam no ano,
  quanto sai do Fundeb, o salário típico do professor, quantos ficam abaixo
  do piso e de quando são os dados. A tabela vai para a matéria e para o
  repositório do observatório.
- ⚠️ Simulação: não substitui um jornalista de verdade.

## O que ele fez

1. **De quando são os dados:** `/fontes` diz "carga em 24/11/2026" para os
   quatro municípios, com o arquivo e o SHA-256. Resolvido desde a #564.
2. **Os números por município:** a tela da base dá, para cada município do
   recorte, frases com o total declarado e de onde vem (escolas,
   Secretaria, fora da lista), o salário da rede (mediana do total e do
   base, carga mais comum) e o piso na rede inteira. É tudo o que ele quer,
   mas em frases, uma UF de cada vez (RO, MT e SP).
   - Para a tabela, ele copia à mão cerca de 25 números de três telas.
   - O CSV da base é por escola: não traz o total declarado, nem a folha da
     Secretaria, nem o salário e o piso da rede inteira.
3. **Quanto sai do Fundeb, por prefeitura:** aqui ele trava.
   - O painel da Secretaria de Taubaté diz 84,2% pela parcela de 70%.
   - Em Ubatuba e em Cuiabá, a divisão por fonte está em cada escola (no
     painel e na base), mas a parte da Secretaria não aparece em lugar
     nenhum. Somar as escolas deixa de fora R$ 11,8 mi em Ubatuba (R$ 8,1
     mi da parcela de 70%).
   - Conferido no banco, a folha inteira: Alta Floresta 2024, 100% pela
     parcela de 70%; Cuiabá 2025, 93,4% (6,6% outras fontes); Cuiabá 2026,
     100%; Taubaté 2026, 84,2% (15,8% pela de 30%); Ubatuba 2026, 94,5%.
     Nenhuma tela dá esses números para Cuiabá, Ubatuba e Alta Floresta.
4. **O resto da tabela:** salário típico, piso e carga saem das frases.
   Taubaté vem sem a contagem do piso, com o motivo dito (carga em aulas,
   #572). Ele publica a nota.

## O que funciona para ele

- A data da carga e o arquivo, para citar.
- O salário e o piso da rede inteira, com os avisos, em todos os
  municípios.
- O fechamento da folha (escolas, Secretaria, fora da lista).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QG-01 | atrapalha | **A parte do Fundeb da folha inteira do município não aparece.** A divisão por fonte está por escola, e no painel só quando a folha é toda da Secretaria. Onde há escolas e Secretaria, a folha da Secretaria fica fora de qualquer divisão por fonte. Pedido: a divisão por fonte (Fundeb 70%, 30%, outras) da folha inteira do município, com a Secretaria, junto do fechamento da folha na tela da base. | Ubatuba 2026: 94,5% da folha inteira pela parcela de 70%, sem aparecer; a soma das escolas deixa fora R$ 11,8 mi da Secretaria. Cuiabá 2025: 93,4%, idem | P6, P5, P2 |
| QG-02 | incomoda | **Os números por município só existem em frases na tela.** O total declarado, o fechamento, a divisão por fonte, o salário e o piso da rede e a data da carga não se baixam: o CSV da base é por escola. Para comparar prefeituras, ele copia à mão de várias telas. Pedido: um CSV "folha por município" (uma linha por município e ano, com essas colunas e o dicionário). A #554 escolheu não ter esse arquivo quando havia um número por município; agora são mais de dez. | quatro municípios, três UFs, cerca de 25 números copiados à mão | P6, P4, P5 |

Continua pendente: #454 (a carga do IDEB registrada).

## Veredito

**Adotaria** (mantido). A tabela das prefeituras sai, mas copiada à mão
(QG-02) e sem a parte do Fundeb de três dos quatro municípios (QG-01).

## Encaminhamento

Issues **#579** (QG-01) e **#580** (QG-02), abertas no modo autônomo autorizado pelo developer (até 25/11, 9h).
