# Nota técnica 230: IVET com o motivo certo e a versão citável (#489)

Achados RK-01 e RK-02 da décima oitava avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-18-p4-ivet.md`).
Um PR: #490 (merge `d3753a9`).

## O problema

- **RK-01 (atrapalha).** O card do IVET dizia "não é publicável (amostra
  insuficiente ou dado sensível)" e escondia todos os blocos quando
  `publicavel` era falso.
  - No R, `publicavel` é só "os blocos C (mobilidade), D (saúde) e E
    (segurança) têm dado" (`ivet_v1`). Não há regra de amostra nem de
    privacidade.
  - Localmente, as 180.540 escolas só têm o bloco A, e todas viam o aviso.
    Na medição nacional documentada eram 34.808 (19,3%), quase todas sem
    isócrona.
  - A ajuda (§4.3, §5, perguntas frequentes e glossário) explicava o aviso
    como proteção de dados.
- **RK-02 (atrapalha).**
  - A ajuda estava na `ivet-v1.2`, com a régua 0,30 a 0,42 das medições de
    outubro, de antes da escala logarítmica do bloco C (v1.3).
  - O IVET não aparecia em `/fontes`.
  - A ficha ligada à ajuda era a do Assistente do Censo.
- **Achado no caminho.** `IVET_BLOCOS` (frontend) rotulava D "Segurança",
  E "Recursos", F "Saúde" e G "Mobilidade". No R e no card, as letras são
  D saúde, E segurança, F meio ambiente e G recursos. Os valores estavam
  certos, mas os rótulos de quatro dos sete blocos estavam errados desde a
  #296.

## Decisões

- **O motivo vem da API.** `GET /api/school/:inep/ivet` devolve
  `blocos_faltando`, com os blocos de `@BLOCOS_TERRITORIAIS` (C, D e E) sem
  valor.
  - A regra espelha `ivet_blocos_territoriais_minimos()`. O teste
    `t/02-models/ivet_versao.t` a confere contra
    `blocos_territoriais_minimos` do `inst/ivet-card.yml`, mapeado pelas
    letras do próprio card.
  - Não precisou de coluna nova nem de change: a lista sai dos blocos nulos.
- **Sem número, o painel mostra os blocos e não mostra o selo.** O aviso é
  cinza e informativo: "ainda não pode ser calculado: faltam os blocos C
  (acesso)…". Se a lista vier vazia (`publicavel` falso por outro motivo
  futuro), o texto é genérico e continua sem falar em privacidade.
- **Registro da versão no Perl** (`EduMaps::Model::Ivet::Versao`):
  `$VERSAO` e `@HISTORICO`, da v1.0 à v1.8, com as datas tiradas do git do
  `ivet.R`.
  - A fórmula continua no R; o registro é o espelho que a API publica.
  - O teste exige a mesma versão em quatro lugares: R, card, cabeçalho do
    `docs/analises/ivet.md` e registro. A regra está no `AGENTS.md`.
- **`/fontes` com mais de uma base própria.** O catálogo ganhou
  `versao_de` (`indices` ou `ivet`), e `versao_propria` escolhe o registro.
  - A entrada `ivet_edumaps` lê o período de `nu_ano_censo` e o "último
    cálculo" de `max(calculado_em)` de `analytics.ivet_escola`.
  - O frontend já tratava as bases próprias de forma genérica; só ganhou o
    rótulo da tela `painel_escola` (e o de `base_analise`, que faltava).
- **A régua sai até haver medição.** Localmente não dá para medir (só o
  bloco A), e o LXC está fora do ar.
  - A ajuda diz que a régua da versão atual está pendente, e o §4.8 do
    documento de método marca as duas medições como da v1.2.
  - O roteiro do LXC (§7) ganhou o passo `medir-ivet-nacional.R`; a régua
    volta à ajuda num commit só de documentação.
  - A alternativa de calcular a mediana na API, a partir da própria tabela,
    ficou de fora: localmente sairia vazia, e o escopo crescia.
- **Sem bump de cache:** a rota do IVET não passa pelo
  `Cache::SchoolSearch`.

## Validação

- Suíte Perl inteira com `-j4`: 198 arquivos e 1.752 testes, todos
  passando. vitest: 1.350 testes, todos passando.
- Local, depois do rebuild:
  - a escola 26193906 devolve `blocos_faltando: ["C","D","E"]`, com o bloco
    A em 0,666;
  - `/api/fontes` traz `ivet-v1.8`, com nove versões e o cálculo de
    2026-11-17;
  - o bundle traz o texto novo.
- CI do PR verde.

## Pendências

- Medir a `ivet-v1.8` no LXC depois do deploy e repor a régua (roteiro, §7).
- O painel do gestor (`InfluenciaPanel`) não usa os rótulos dos blocos; não
  mudou.
