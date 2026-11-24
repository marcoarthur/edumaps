# Reavaliação: P5 confere a folha do Fundeb em Ubatuba (2026-11-24)

Quarta rodada da P5 (órgãos de controle e conselhos), a pedido do
developer. A terceira, na véspera (meta 1 do PNE em Pernambuco), teve o
veredito **não adotaria** (registro), mais perto. Os achados dela foram
entregues: QJ-01 (#549, taxa bruta) e QJ-02 (#550, fontes no CSV do
ranking).

As rodadas anteriores foram do auditor do tribunal. Esta é do **outro lado
do perfil**: o conselheiro do CACS-Fundeb, que recebe a prestação de contas
da secretaria.

- **Avaliou:** só a P5. Ela continua só como registro: não orienta produto
  até a decisão de posicionamento.
- **Material:**
  - `/fontes` (a cobertura da folha);
  - a folha pública de uma escola municipal de Ubatuba;
  - a base de análise da rede municipal de Ubatuba (blocos Etapas,
    Matrículas, Docência, INSE, Remuneração e Porte, folha de 2026);
  - as ajudas da base de análise e de financeiro e folha.
- **Por que Ubatuba (SP):** é o município com folha por escola mais recente
  (2026, 8 meses, 48 escolas). Taubaté tem 2026, mas sem as escolas.
- **O trabalho que ele faria:** o conselheiro do CACS-Fundeb de Ubatuba
  prepara o parecer sobre a aplicação do Fundeb no ano:
  - a folha declarada bate com as escolas e os professores que existem?
  - quanto da folha foi pago com o Fundeb?
  - o recurso chegou às escolas que mais precisam?
- ⚠️ Simulação: não substitui um conselheiro de verdade.

## O que ele fez

1. **A cobertura:** em `/fontes`, Ubatuba aparece com a folha de 2026 (8
   meses) e 48 escolas. A base diz o mesmo, e o `meses_folha` = 8 avisa que
   o gasto é só desses meses.
2. **A folha bate com as escolas?** Na base, 47 das 51 escolas municipais
   têm folha (R$ 55,6 milhões em 8 meses). As 4 sem folha são pequenas: uma
   EMEI com 89 matrículas e três escolas com 13 a 34 alunos. É uma pergunta
   concreta para a secretaria.
3. **E com os professores?** O `prof_magisterio_mes` (média de
   profissionais do magistério por mês) soma 616, contra 693 docentes do
   Censo nas mesmas escolas. A maior diferença é a EM Presidente Tancredo
   de Almeida Neves: 1.316 matrículas, 62 docentes no Censo e 26,5 do
   magistério na folha por mês. Outra pergunta concreta (professores de
   outra rede, contratados por outra fonte?). A ajuda explica bem a
   diferença entre as duas contagens.
4. **Quanto foi pago com o Fundeb?** Esta é a pergunta do conselho, e a
   plataforma não responde.
   - O SIOPE traz, em cada pagamento, a parte paga com os 70% do Fundeb, a
     parte dos 30% e a de outras fontes.
   - Nenhuma tela, nem a folha da escola, nem a base, mostra essa divisão.
   - Conferida no banco: de R$ 67,7 milhões pagos em 2026 (8 meses), R$ 64,0
     milhões (94,5%) vieram da parte dos 70% do Fundeb.
5. **A folha que não está em escola:** o total declarado (R$ 67,7 milhões)
   não fecha com a soma das escolas da base (R$ 55,6 milhões).
   - R$ 11,8 milhões (17,5%) estão no código da Secretaria, sem escola
     (R$ 8,1 milhões deles da parte dos 70%).
   - Cerca de R$ 0,3 milhão é de uma escola que tem folha mas não está na
     lista da rede municipal da base.
   - Nada na tela ou no CSV diz o total do município nem essa diferença. Um
     conselheiro que soma a base acha R$ 12 milhões "sumidos".
6. **O recurso chegou a quem mais precisa?** Só 23 das 47 escolas com folha
   têm INSE (as creches e pré-escolas não têm). Nelas, a metade de INSE
   mais baixo tem, na mediana:
   - R$ 3.479 de pessoal por aluno (8 meses), contra R$ 3.605 na metade
     mais alta;
   - salário do magistério de R$ 8.047, contra R$ 9.116;
   - 19,2 alunos por profissional do magistério, contra 22,2.

   Gasto por aluno parecido, mais gente e salário menor nas escolas mais
   pobres. Um começo de resposta, só para metade das escolas.

## O que funciona para ele

- A folha por escola, sem nomes nem CPF, com os meses e o ano em cada
  linha.
- O confronto da folha com o Censo (escolas sem folha, profissionais por
  mês contra docentes), com a ajuda explicando por que as contagens
  diferem.
- A cobertura da folha dita em `/fontes` e na base.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QS-01 | atrapalha | **A parte do Fundeb na folha não aparece.** O SIOPE separa, em cada pagamento, a parte paga com os 70% do Fundeb, a dos 30% e a de outras fontes, e a plataforma carrega essas três partes. Nenhuma tela nem a base as mostram, e é a pergunta central do conselho do Fundeb. Pedido: a divisão por fonte (Fundeb 70%, Fundeb 30%, outras) na folha da escola e em colunas da base, com o aviso de que não é a verificação do mínimo legal: a receita do Fundeb do município não está na plataforma. | Ubatuba, 2026 (8 meses): R$ 64,0 mi de R$ 67,7 mi (94,5%) pela parte dos 70%; a resposta da folha da escola e o bloco Remuneração da base não têm a divisão | P5, P2, P6 |
| QS-02 | incomoda | **A folha sem escola (o total da Secretaria) não aparece.** A soma das escolas da base não fecha com o total declarado pelo município, e nada diz a diferença. Pedido: o total do município e a parte que não está em nenhuma escola (Secretaria, ou escola fora da lista), na tela da base e na ajuda, para a soma fechar. | Ubatuba, 2026: R$ 67,7 mi declarados, R$ 55,6 mi nas 47 escolas da base, R$ 11,8 mi no código da Secretaria e cerca de R$ 0,3 mi numa escola fora da lista | P5, P2, P4 |

Continua aberto: AN-12 (comparação de gasto entre municípios; o SICONFI
segue vazio). Sem a receita do Fundeb, o percentual aplicado em
remuneração não sai daqui.

Observação técnica, fora da persona: a rota pública
`/api/city/3555406/payroll/overall`, que nenhuma tela usa, devolve
`nome_estado` com acento quebrado ("SÃ£o Paulo").

## Veredito

**Não adotaria** (registro; mantido). O confronto da folha com as escolas
e os professores do Censo já rende perguntas concretas para a secretaria.
Para o parecer do conselho, falta a parte paga com o Fundeb (QS-01) e a
soma que fecha com o total declarado (QS-02).

## Encaminhamento

Issues **#553** (QS-01) e **#554** (QS-02), abertas com a aprovação do developer.
