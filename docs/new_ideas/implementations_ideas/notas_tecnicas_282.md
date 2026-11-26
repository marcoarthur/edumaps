# Nota técnica 282: os abaixo do piso por situação (#597)

Um PR: #599. Achado QB-01 da quinta avaliação da P2
(`docs/personas/publicos/avaliacoes/2026-11-25-p2-piso-por-vinculo.md`).

## O problema

- A contagem abaixo do piso da rede inteira (#575) dizia quantos e quantos
  só na Secretaria, mas não quem: temporários ou efetivos, com que carga e
  salário. A situação estava na folha carregada e na lista (#585); a
  contagem não a usava. Em Cuiabá a resposta ao tribunal ("quase todos
  temporários de 30 h") só saía da planilha do SIOPE.

## Decisões (developer: as recomendadas do plano)

- **Change nova `analytics_salario_rede_situacao`**, não edição da
  `analytics_salario_rede` (já deployada): refaz `mv_salario_rede_md` com
  três campos por pessoa e ano, ainda agregados (sem CPF nem nome; o verify
  confere):
  - **situação**: efetivo, temporario ou outros (Outros, Cedido, vazio). A
    dos **mais meses** no ano; empate: a do **último mês**. Cada pessoa
    conta uma vez e as partes somam o total (~2% das pessoas-ano têm duas
    situações);
  - **carga** mais comum dos meses da pessoa;
  - **base**: mediana do salário base mensal, sem conversão para 40 h.
  O revert recria a forma da #595. A função de refresh não mudou.
- **Perfil pela mediana do base**, não pelo valor mais comum: quando a
  tabela muda no ano (Cuiabá: R$ 3.212,71 até abril, ~R$ 3.322 depois), o
  "mais comum" depende de qual mês tem mais gente. A mediana entre pessoas
  é ponderada pelo `n` (expansão com `generate_series`); a carga mais
  comum, também pelo `n`, empate na menor.
- **Piso proporcional** = piso do ano × carga / 40, calculado no Perl
  (o piso segue só em `%PISO_MAGISTERIO`). A frase só o mostra fora das
  40 h.
- **Escopo: a rede** (painel da Secretaria, base de análise, folha por
  município). A coluna por escola da base ficou como estava.
- Sem contagem (sem piso, ou carga fora de horas, #572): situação e perfil
  vêm vazios, como a contagem.

## Resultado

- Cuiabá 2026: 1.559 abaixo, **1.417 temporários e 142 efetivos**; 30 h,
  base mediana R$ 3.212,71, piso proporcional R$ 3.847,97. A avaliação
  falava em 1.422/137 com outra regra; os textos usam a da contagem.
- Folha por município: 5 colunas novas com dicionário. Base de MT: 2,3 s
  local (a MV cresceu de 1.668 para 2.268 linhas).

## Testes

- `t/04-api/base_analise.t`: maioria dos meses, empate pelo último mês
  (cedido → outros), perfil, colunas do CSV e o caso sem contagem.
- Vitest: `textoPisoPerfil` (plural, 40 h sem proporcional, vazio) e o
  painel da Secretaria.

## Pendente

- QB-02 (#598): filtro por situação e a marca "abaixo do piso no ano" na
  lista da folha. Precisa da marca por pessoa (hoje a MV é agregada, de
  propósito): será outra consulta, sobre a folha, com a mesma regra.
- LXC: `deploy_db_dev`, depois backend, minion e frontend (roteiro).
