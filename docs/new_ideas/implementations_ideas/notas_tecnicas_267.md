# Nota técnica 267: o registro da carga da folha do SIOPE (#564)

Achado QQ-02 da terceira avaliação da P6
(`docs/personas/publicos/avaliacoes/2026-11-24-p6-piso-magisterio.md`).
Issue aberta com a aprovação do developer; plano aprovado com as opções A1
e B1. Um PR: #566 (merge `977547c`), seguido da recarga dos quatro
municípios.

## O problema

- **QQ-02 (incomoda).** A folha é carregada município a município (job
  `query_siope`), cada um numa data, e nada era registrado. O cartão do
  SIOPE em `/fontes` dizia "carga não registrada", e quem cita o dado
  ficava sem a data.

## Decisões

- **A1, em `clean.import_metadata`:** na linha de
  `clean.remuneracao_municipal`, uma entrada por município e ano em
  `raw_manifest`: `cod_municipio`, `ano`, `linhas`, `baixado_em`, `url`
  (sem o campo do captcha), `sha256` e `bytes` da planilha. Sem change no
  banco; o cartão e a lista de arquivos já liam dali.
- **Na mesma transação que troca a folha (#536):** recarregar o mesmo
  município e ano troca a entrada (o `jsonb` filtra a antiga e acrescenta a
  nova); carga que falha não registra.
- **A cobertura diz a data por município e ano** ("carga em 24/11/2026";
  as antigas, "carga não registrada", sem data inventada, regra da #428).
- **Achado durante a implementação:** o job reaproveitava a planilha de
  uma carga anterior que ficasse no `/tmp` do contêiner (`get_data unless
  -f`). Uma recarga no mesmo contêiner lia o arquivo velho. O job passou a
  apagar a planilha antes e depois de cada carga.
- **Teste sem rede:** a planilha e o arquivo são simulados; a carga que
  falha volta à fila (o Minion tenta de novo), e o teste confere só que
  ela não termina com sucesso.

## B1: a recarga dos quatro municípios

- Com a permissão do developer dada no plano, cinco planilhas baixadas do
  SIOPE no ambiente local (jobs 4105 a 4109): Cuiabá 2025 (11 MB) e 2026,
  Alta Floresta 2024, Taubaté 2026 e Ubatuba 2026. Todas com o mesmo número
  de linhas de antes.
- `/fontes` passou a "carga em 24/11/2026" nos quatro municípios.
- **A pendência da #557 respondida:** setembro e outubro de 2025 em Cuiabá
  vieram iguais (3.269 e 3.253 registros, só o magistério) na planilha
  baixada agora. A falta está na fonte, como o SIOPE publica a declaração
  do município, e não na nossa carga. Os avisos continuam dizendo "pode ser
  a declaração do município ao SIOPE ou a carga"; agora se sabe que, em
  Cuiabá 2025, é a declaração.

## Validação

- **Docker local:** `/fontes` com "carga não registrada" antes da recarga e
  "carga em 24/11/2026" depois; o registro com as cinco entradas (data,
  linhas, SHA-256, bytes).
- **Testes:** Perl, 210 arquivos (novo `t/05-tasks/siope_registro_carga.t`);
  vitest, 1.435. CI do PR verde.

## Pendências

- No LXC: `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`;
  as cargas do LXC ficam "não registrada" até a próxima recarga lá.
- #454 (a carga do IDEB registrada) segue aberta.
