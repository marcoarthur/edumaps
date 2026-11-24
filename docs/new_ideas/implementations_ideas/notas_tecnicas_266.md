# Nota técnica 266: o salário base do magistério e o piso (#563)

Achado QQ-01 da terceira avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-24-p6-piso-magisterio.md`, o
piso do magistério na folha municipal). Issue aberta com a aprovação do
developer; plano aprovado com as opções A1 e B1. Um PR: #565 (merge
`c5ee46b`).

## O problema

- **QQ-01 (atrapalha).** A base trazia só o salário total por 40 horas
  (`salario_40h_magisterio`: vencimento mais gratificações e adicionais),
  bem acima do piso. O piso do magistério vale para o salário base, que o
  SIOPE traz em cada pagamento (`salario_base`) e a base não exportava.
- Lida às pressas, a base dizia "todos acima do piso". Em Alta Floresta
  (2024), a mediana do salário base para 40 horas é R$ 5,0 mil, contra
  R$ 6,6 mil do total.

## Decisões

- **Três colunas, logo depois do salário total:**
  `salario_base_40h_magisterio`, `piso_magisterio_ano` (o piso usado, em
  toda linha, para refazer) e `prof_magisterio_base_abaixo_piso`.
- **A1, o mês típico:** conta quem tem o salário base para 40 horas abaixo
  do piso na mediana dos próprios meses, sem dezembro. Medido:
  - Alta Floresta 2024: 45 pessoas em algum mês, 45 no mês típico, 43 em
    todos;
  - Cuiabá 2025: 673 em algum mês, 40 no mês típico, 20 em todos.

  "Em algum mês" chamava de abaixo do piso o mês de admissão ou de
  desconto; "em todos" perdia quem ficou abaixo até o reajuste do meio do
  ano.
- **B1, o piso numa tabela no código:** `%PISO_MAGISTERIO` em
  `EduMaps::BaseAnalise`, com o valor e o ato, a partir de 2024 (os anos com
  folha carregada): 2024 R$ 4.580,57; 2025 R$ 4.867,77; 2026 R$ 5.130,63
  (Portaria MEC nº 82, de 29/01/2026, conferida na busca). O reajuste anual
  entra no PR do ano. Ano sem piso cadastrado deixa as colunas vazias.
- **A conta numa consulta só:** `$SQL_FOLHA` passou a `WITH pm …, p (o piso
  como parâmetro), pp (a mediana por pessoa)`, sem mudar as outras colunas.
- **Contagem por escola:** quem trabalha em duas escolas conta nas duas.
  Em Cuiabá 2025, a soma das escolas dá 47, contra 40 pessoas na rede. O
  dicionário e a ajuda dizem isso (commit da validação).
- **Sem afirmar descumprimento:** o dicionário e as ajudas avisam que não é
  a verificação legal (complementos, jornada, licenças, reajuste pago com
  atraso). O número é uma pergunta para a prefeitura.

## Validação

- **Docker local:**
  - Alta Floresta 2024: piso 4.580,57, 45 abaixo, base 40 h R$ 5.042 contra
    total R$ 6.628 (medianas das escolas);
  - Cuiabá 2025: 47 na soma das escolas;
  - Ubatuba 2026: piso 5.130,63, 6 abaixo.
- **Testes:** Perl, 209 arquivos (salário base médio; só a pessoa abaixo
  nos três meses conta, a admitida com um mês pela metade não; ano sem piso
  e escola sem folha, vazio; o aviso). CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev`.
- #564 (a carga da folha registrada) segue aberta.
- Reajuste do piso de 2027: entra na tabela quando sair o ato do MEC.
