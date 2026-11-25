# Nota técnica 281: o salário da rede pré-calculado (#595)

Um PR: #596 (opção C da issue, escolhida pelo developer). Sem avaliação de
persona: não muda o que nenhum público vê, só o tempo de resposta.

## O problema

- A base de análise com UF levava 3,6 s (MT). O maior pedaço era o salário
  do magistério da rede (#571/#575): três medianas e uma contagem distinta
  sobre ~73 mil pessoa-mês, mais a mediana por pessoa para o piso, em cada
  tela da base e em cada painel financeiro. 1,7 s só nessa conta.
- A folha só muda numa carga do SIOPE: recalcular a cada leitura é
  desperdício.

## Decisões

- **Duas matviews em `analytics`**, não uma: `mv_salario_rede` guarda as
  medianas por município e ano; `mv_salario_rede_md` guarda quantas pessoas
  têm cada (mediana do base por 40 h, meses pagos, se teve escola). Assim o
  **piso de cada ano e o mínimo de meses continuam no Perl** (fonte única,
  `%PISO_MAGISTERIO`, `$MESES_MIN_PISO`): mudar o piso não exige change.
- **Sem CPF nem nome** nas views (o verify falha se aparecerem): `analytics`
  tem SELECT automático para o `edumaps_leitor`.
- **Refresh `CONCURRENTLY`**, com índice único, para a leitura não travar
  durante a carga; `work_mem` de 64 MB só dentro da função (com o padrão de
  4 MB, dois sorts iam a disco).
- **A carga do SIOPE atualiza no fim**, fora da transação da folha. Se o
  refresh falhar, a carga fica e o erro vai ao log: a tela mostra a conta da
  carga anterior até a próxima.
- **Os testes que gravam a folha chamam o refresh** depois de inserir. Na
  proposta eu tinha dito que a opção C não mexia nos testes; mexe, como a B.
- A base de análise também deixou de calcular os anos duas vezes por
  requisição.

## Validação

- Consulta antiga × views, com `EXCEPT` nos dois sentidos, nos dados
  locais: nenhuma diferença. A resposta da base de MT tem o mesmo md5 antes
  e depois.
- Conta do salário: 1,7 s → 4 ms; refresh: 1,5 s por carga.
  `/api/base-analise?uf=MT`: 3,6 s → 2,7 s.
- Perl, 212 arquivos (1.897 testes); `ci_db.sh verify` ok; CI verde.

## O que ficou

- Os 2,7 s restantes são outras consultas: a cobertura por município (~0,5 s
  sem o salário), os meses incompletos (0,3 s), os anos (0,4 s), as
  contagens e o fechamento (~0,4 s cada). Nenhuma domina; fica para quando
  incomodar.
