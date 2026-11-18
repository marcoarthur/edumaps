# Reavaliação: P4 e o grupo de referência do perfil (2026-11-18)

Vigésima rodada da P4 (academia), a pedido do developer, depois da entrega
da décima nona rodada:

| Entrega | O quê |
|---|---|
| #492 | folha contada pela pessoa; painel financeiro um ano por vez; bloco Remuneração (SIOPE) na base de análise (RJ-01 a RJ-03) |

- **Avaliou:** só a P4.
- **Material:**
  - a ficha `analise/perfil-escola.md`;
  - a ajuda `perfil-da-escola.md`;
  - o perfil da escola (`/api/school/:inep/profile`) de 38 escolas de
    Salvador;
  - o código do grupo de referência
    (`model-datasource-postgres-school-profile-source.R`) e dos sinais
    (`analysis-school-profile.R`);
  - o banco local, só leitura.
- **O trabalho que ela faria:** o perfil promete "comparação justa com o
  grupo de referência". Ela quer usar esse grupo como controle num estudo
  de caso: comparar o IDEB de uma escola com o de escolas de contexto
  parecido, e ler os sinais de atenção como "onde esta escola fica abaixo
  das parecidas".
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A promessa.**
   - A ficha diz que o grupo evita "comparações injustas com realidades
     distantes".
   - A ajuda diz que o grupo junta escolas de **contexto parecido**: porte,
     etapas, nível socioeconômico e localização.
2. **Abriu o método.** Nenhuma das 38 escolas tem grupo persistido. Todas
   caem no grupo "estimado no próprio município" (`fallback_kmeans`), e as
   vizinhas vêm do Gower no município.
   - O grupo é um k-means com 4 grupos (semente fixa) sobre **os nove
     indicadores que o perfil compara**:
     - cinco proporções de docentes;
     - alunos por docente;
     - **IDEB**, **nota SAEB** e **INSE**.
   - Porte, etapas e localização não entram.
   - Entram só os indicadores que a própria escola tem. Duas escolas do
     mesmo município podem ser agrupadas com variáveis diferentes.
3. **O IDEB escolhe o grupo.** Nas 37 escolas com IDEB 2023 dos anos
   iniciais:
   - a correlação entre o IDEB da escola e a mediana do IDEB do grupo dela é
     **0,83**;
   - a distância média entre o IDEB da escola e a mediana do grupo é de 0,26
     ponto, contra 0,47 da média do município;
   - os rótulos dos grupos ordenam pelo resultado: "Muito baixa perfil
     escolar" (mediana 4,9, 126 escolas) e "Alta perfil escolar" (5,8, 106
     escolas);
   - a escola de IDEB 4,0 é comparada com escolas de 4,9, e a de 6,4 com
     escolas de 5,8.

   Como "contexto parecido" contra o qual se lê o IDEB, a conta é
   circular: as escolas de IDEB baixo são postas juntas, e o IDEB delas
   parece normal "para o grupo". Há grupos de 7 e 8 escolas ao lado de
   grupos de 126.
4. **Os sinais de atenção.**
   - O INSE é sinal de atenção quando a escola está abaixo do grupo: 13 das
     38 escolas têm "INSE pior que o grupo".
   - O INSE é o nível socioeconômico dos alunos, o contexto que o grupo
     deveria controlar, e não algo que a escola possa mudar.
5. **O N da distribuição.**
   - A tabela "Distribuição no cluster" repete o tamanho do grupo como N de
     todos os indicadores.
   - O grupo do CEIFAR (29445906, privada) tem "IDEB observado: N = 436".
     Salvador inteira tem 417 escolas com IDEB em 2023.
   - O N de cada indicador é o de escolas com dado, não o do grupo.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido), sem o grupo de referência do perfil | o grupo "de contexto parecido" é formado com o próprio IDEB, a nota e o INSE; o INSE vira sinal de atenção; o N da distribuição não é o de escolas com dado (RI-01, RI-02, RI-03) |

## O que funciona

- **A comparação na mesma etapa** do IDEB (#483).
- **A ausência honesta:** indicador sem dado não gera sinal.
- **O sentido de cada indicador** nos sinais (menor é melhor em alunos por
  docente).
- **A regra dos sinais versionada** (`regra_sinais = 4`).

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RI-01 | atrapalha | **O grupo de referência do perfil é formado com o próprio resultado.** O k-means usa os nove indicadores comparados, inclusive IDEB, nota SAEB e INSE, e só os que a escola tem. A ajuda promete porte, etapas, nível socioeconômico e localização. Pedido: o grupo por contexto (porte, etapas, localização, rede, INSE), sem os indicadores de resultado; o critério na ajuda e a versão da regra no perfil. | 37 escolas de Salvador: correlação 0,83 entre o IDEB da escola e a mediana do grupo; grupos "Muito baixa" (mediana 4,9) e "Alta" (5,8); grupos de 7 e 8 escolas | P4, P1, P2 |
| RI-02 | atrapalha | **O INSE vira sinal de atenção.** "Pior que o grupo" no nível socioeconômico dos alunos não é algo a agir na escola. Pedido: o INSE como contexto, sem sinal. | 13 de 38 escolas com o sinal "INSE" | P1, P4, P2 |
| RI-03 | detalhe | **O N da distribuição no grupo é o tamanho do grupo, não o de escolas com dado.** Pedido: o N de cada indicador. | CEIFAR: "IDEB observado, N = 436"; Salvador tem 417 escolas com IDEB 2023; `n = indicators$cluster_n` | P4 |

## Encaminhamento

Aguardando a aprovação do developer para abrir a issue.
