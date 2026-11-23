# Reavaliação: P5 acompanha a meta 1 do PNE em Pernambuco (2026-11-23)

Terceira rodada da P5 (órgãos de controle e conselhos), a pedido do
developer. A segunda, no mesmo dia (auditoria de Cuiabá), teve o veredito
**não adotaria** (registro), mais perto. Os achados dela foram entregues:
QO-01 (#535, taxa no ranking) e QO-02 (#536, nomes da folha). Desde
então, na meta 1:

| Entrega | O quê |
|---|---|
| #539 | fontes do ranking pelo indicador |
| #545 | o DF com a rede distrital e as conveniadas com o governo distrital |
| #547 | vagas que faltam para a meta, por município e por recorte |

- **Avaliou:** só a P5. Ela continua só como registro: não orienta produto
  até a decisão de posicionamento.
- **Material:**
  - o ranking da creche e da pré-escola em PE, e o CSV;
  - as ajudas de rankings, da comparação de redes e da base de análise;
  - o rodapé de fontes.
- **O trabalho que ele faria:** o auditor do TCE-PE prepara o
  acompanhamento da meta 1 do PNE no estado:
  - quais municípios estão mais longe da meta, em vagas;
  - onde está a maior parte do déficit;
  - a planilha anexada ao relatório, que o município fiscalizado pode
    contestar.
- ⚠️ Simulação: não substitui um auditor de verdade.

## O que ele fez

1. **O quadro do estado:** no ranking da creche em PE, **174 dos 185
   municípios** estão abaixo dos 50%, e faltam **96.578 vagas**. Na
   pré-escola, 101 estão abaixo dos 100%, e faltam 25.058 vagas.
2. **Onde está o déficit:** ordenando o CSV por `vagas_faltam_meta`,
   **metade das vagas que faltam está em 15 municípios**. Jaboatão dos
   Guararapes (9.866, com 17,5% de taxa), Recife (6.370), Paulista
   (5.121), Olinda (4.323) e Caruaru (4.013) puxam a lista. Para o
   tribunal, isso define a amostra da fiscalização.
3. **O que o número é:** antes de anexar, ele confere o método.
   - A "taxa de atendimento" da plataforma soma as matrículas na etapa
     (de crianças de qualquer idade e de qualquer município) e divide
     pelas crianças da idade que moram no município. **É uma taxa bruta
     de matrícula.**
   - O indicador oficial da meta 1 é o **percentual das crianças da idade
     que frequentam** creche ou escola, medido em pesquisa domiciliar.
   - As duas contas dão números diferentes:
     - a bruta conta a criança de 4 anos matriculada na creche e a do
       município vizinho;
     - a oficial conta a criança que mora no município, pela idade.
   - A ajuda avisa que a taxa "pode passar de 100%", mas nenhuma tela,
     ajuda ou CSV diz que ela **não é o indicador oficial** da meta. O
     município fiscalizado contestaria o "abaixo da meta" com o número
     oficial.
4. **A planilha anexada:** o CSV traz o ano da população (2022) e o do
   Censo Escolar (2025) em cada linha, mas não o nome das bases, a data
   da carga nem o link oficial. Isso fica no rodapé da página
   (#539). Solta num processo, a planilha não diz de onde veio.

## O que funciona para ele

- O quadro do estado e o déficit em vagas, com a lista dos municípios que
  concentram metade dele.
- O recorte e os anos em cada linha do CSV.
- As três contas (todas as redes, rede local, teto com as conveniadas),
  agora certas também no DF.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QJ-01 | atrapalha | **A "taxa de atendimento" é uma taxa bruta de matrícula, e nada diz que não é o indicador oficial da meta 1.** A plataforma divide as matrículas na etapa (qualquer idade, qualquer município) pelas crianças da idade. O indicador oficial é o percentual das crianças da idade que frequentam creche ou escola, de pesquisa domiciliar. Os números diferem, e o "abaixo da meta" pode ser contestado. Pedido: chamar a conta pelo nome (ex.: "taxa bruta de matrícula") na tela, no CSV e nas ajudas, com o aviso de que não é o indicador oficial do PNE e de que pode diferir dele (e do monitoramento do INEP). | ajudas de rankings, da comparação de redes e da base: nenhuma menciona "bruta" nem o indicador oficial; nota da tabela e do quadro: "Taxa de atendimento = matrículas … ÷ crianças" | P5, P2, P4, P6 |
| QJ-02 | incomoda | **O CSV do ranking não traz as fontes.** O arquivo tem os anos, mas não o nome das bases (Censo Escolar, população por idade do Censo Demográfico, estimativa), a data da carga nem o link oficial, que estão só no rodapé da página. Pedido: as fontes no CSV (colunas ou linhas de cabeçalho) ou um dicionário para baixar, como na base de análise. | `ranking-atendimento-creche-PE-2022.csv`: colunas `ano_populacao_idade` e `ano_censo`, sem fonte | P5, P6, P4 |

Continua aberto: AN-12 (comparação de gasto entre municípios; o SICONFI
segue vazio).

## Veredito

**Não adotaria** (registro; mantido), mais perto. O acompanhamento da
meta 1 no estado sai da plataforma, com o déficit em vagas e a lista dos
municípios. Para anexar a um processo, falta dizer que o número é uma
taxa bruta, e não o indicador oficial (QJ-01), e a fonte dentro da
planilha (QJ-02).

## Encaminhamento

Issues **#549** (QJ-01) e **#550** (QJ-02), abertas com a aprovação do developer. QJ-01 vale para
todos os públicos que citam a taxa.

## Andamento

- 2026-11-23: #549 (PR #551) mergeado: QJ-01 resolvido.
  - A taxa é chamada de "taxa bruta de matrícula", com o aviso de que não
    é o indicador oficial da meta 1, nas telas, no CSV (coluna `metodo`)
    e nas ajudas.
  - A marca passou a "abaixo de 50%".
- QJ-02 (#550) segue aberto.
