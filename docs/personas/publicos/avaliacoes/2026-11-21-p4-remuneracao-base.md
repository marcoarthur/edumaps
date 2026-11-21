# Reavaliação: P4 e a remuneração do magistério na base de análise (2026-11-21)

Vigésima nona rodada da P4 (academia), a pedido do developer, depois da
entrega da vigésima oitava rodada:

| Entrega | O quê |
|---|---|
| #511 | painel público da escola como a base de análise: etapas e infraestrutura com o estado de cada item, matrículas do Censo com o ano, empate nos cartões (RA-01 a RA-03) |

- **Avaliou:** só a P4.
- **Material:**
  - a base de análise com o bloco "Remuneração (SIOPE)" (criado na #491,
    depois da décima nona rodada), MT e SP, rede municipal, com "Docência",
    "IDEB e SAEB" e "Etapas"
    (`base-analise-MT-municipal-censo2025-ideb2023-siope2025.csv`);
  - o catálogo da base (`/api/base-analise`) e a tela;
  - o painel financeiro das escolas (`/api/school/:inep/finance`);
  - `/fontes` e as ajudas da base de análise e de fontes;
  - o banco local, só leitura (folha do SIOPE de Cuiabá/MT 2025 e 2026,
    Ubatuba/SP 2026, Alta Floresta d'Oeste/RO 2024 e o total da Secretaria de
    Taubaté/SP 2026).
- **O trabalho que ela faria:** relacionar o salário do magistério com o
  IDEB e com os docentes do Censo, escola a escola, nos municípios com a
  folha carregada.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **Conferiu a base com a folha.** Em Cuiabá (2025, 12 meses), as 167
   escolas com folha estão todas em funcionamento na rede municipal do Censo.
   O total da Secretaria (816 pessoas, R$ 17 milhões) fica de fora, como a
   ajuda diz. Nas três maiores escolas, o número de profissionais, o gasto do
   ano e o salário batem com o painel financeiro (EMEB Prof. Ranulpho Paes de
   Barros: 89 do magistério, R$ 7.955.641).
2. **Conferiu o salário.** A média por mês fica estável de janeiro a
   novembro; só dezembro sobe (13º), e a base o deixa de fora. O salário
   para 40 horas tem mediana de R$ 9.600 por pessoa e mês, e a jornada mais
   comum é de 20 a 23 horas.
3. **Fez a conta.** Em Cuiabá, 50 escolas têm o salário e o IDEB dos anos
   iniciais de 2023; a correlação é 0,19. Até aqui, a base serviu.
4. **Tentou repetir em SP e em RO.** A tela vem com o **Ano da folha
   (SIOPE)** em 2025, o "último ano completo". Mas esse ano é um só para o
   Brasil:
   - Ubatuba (único município de SP com folha) só tem 2026; a base de SP
     sai com a remuneração vazia nas 51 escolas municipais de Ubatuba;
   - Alta Floresta d'Oeste (RO) só tem 2024; o mesmo vazio.

   A tela não diz que municípios da UF têm folha, nem em que anos. A ajuda
   manda ver a lista em **Fontes e metodologia**; lá, o SIOPE diz só
   "cobertura parcial: só os municípios já carregados", sem a lista. A
   lista existe, mas só dentro do painel financeiro de cada escola.
5. **Olhou a educação infantil.** Em Cuiabá, 53 das 167 escolas com folha
   são só de creche e pré-escola e não têm **ninguém** no magistério:
   - quem trabalha com as crianças está como "Auxiliar/Assistente
     Educacional" (2.476 pessoas, salário médio de R$ 3.932 por 30 horas);
   - na base, `prof_magisterio` é 0 e o salário fica vazio;
   - o Censo também dá 0 docentes a 44 delas (Cuiabá é o município com mais
     escolas assim no Brasil: 47).

   A ajuda explica o vazio do salário por três motivos (fora da rede
   municipal, município sem folha, só o total da Secretaria); este não está
   entre eles.
6. **Comparou os profissionais com os docentes.** `prof_magisterio` conta
   as pessoas pagas no ano. A razão com `qt_docentes` tem mediana 1,59
   (de 0,67 a 2,41). Na EMEB Ranulpho: 89 pagos no ano, 75 por mês em média,
   37 docentes no Censo. Quem dividir alunos por `prof_magisterio`, achando
   que são os professores, erra por um fator de 1,6 a 2.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), com a remuneração só para Cuiabá | o ano da folha é um só para o Brasil e a tela não diz quais municípios têm folha em cada ano: SP e RO saem vazios no padrão, e a lista prometida em `/fontes` não existe (QZ-01); a educação infantil fica sem magistério e o motivo não é dito (QZ-02); `prof_magisterio` não é o número de professores (QZ-03) |

## O que funciona

- **A folha da base bate** com o painel financeiro, escola a escola.
- **O 13º fica de fora** do salário médio e entra no gasto do ano, como dito.
- **O total da Secretaria** e as escolas fora do Censo não entram.
- **O nome do arquivo** diz o ano da folha (`-siope2025`).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QZ-01 | atrapalha | **O ano da folha é um só para o Brasil, e a tela não diz quem tem folha.** O padrão é o último ano completo de qualquer município (2025, Cuiabá); na UF escolhida, pode não haver escola nenhuma com folha nesse ano, e a base sai vazia sem aviso. A ajuda manda ver a lista em `/fontes`, que não a tem. Pedido: na tela, com o bloco marcado, os municípios da UF com folha, os anos e os meses de cada um, e quantas escolas da base têm folha no ano escolhido; o padrão pelo último ano completo **da UF**; a lista em `/fontes`, como a ajuda promete. | SP: Ubatuba só tem 2026, as 51 escolas vazias no padrão. RO: Alta Floresta d'Oeste só tem 2024. `/fontes`: "cobertura parcial", sem lista | P4, P2, P6 |
| QZ-02 | detalhe | **A educação infantil fica sem magistério, e a ajuda não diz.** Em Cuiabá, as escolas só de creche e pré-escola não têm profissional do magistério no SIOPE (os auxiliares e assistentes educacionais estão com as crianças); `prof_magisterio` = 0 e o salário fica vazio. Pedido: o motivo na ajuda e no dicionário; e, para a educação infantil, as colunas dos auxiliares/assistentes educacionais (pessoas e salário médio). | 53 das 167 escolas com folha; 2.476 auxiliares, R$ 3.932 por 30 h; o Censo dá 0 docentes a 44 delas | P4, P2 |
| QZ-03 | detalhe | **`prof_magisterio` não é o número de professores.** Conta todas as pessoas pagas no ano, inclusive quem esteve na escola só parte dele; mesmo por mês fica bem acima dos docentes do Censo. A ajuda não compara com o Censo. Pedido: dizer na ajuda e no dicionário que não é o número de docentes; e uma coluna com a média mensal de profissionais do magistério. | Razão com `qt_docentes`: mediana 1,59. EMEB Ranulpho: 89 no ano, 75 por mês, 37 docentes no Censo | P4 |

## Encaminhamento

Issue **#512** (QZ-01 a QZ-03 juntas), aberta com a aprovação do
developer.
