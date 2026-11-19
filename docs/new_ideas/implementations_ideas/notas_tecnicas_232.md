# Nota técnica 232: grupo de referência do perfil pelo contexto (#493)

Achados RI-01, RI-02 e RI-03 da vigésima avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-18-p4-grupo-referencia.md`).
Um PR: #494 (merge `dbaee89`).

## O problema

- **RI-01 (atrapalha).** O grupo de referência do perfil, a régua dos sinais
  de atenção, vinha de dois caminhos, e os dois usavam o resultado:
  - **k-means de fallback** (4 grupos, município) sobre os nove
    `PROFILE_INDICATORS`, os mesmos que o perfil compara, inclusive
    `ideb_observado`, `nota_media` e `inse`, e só os que a escola tinha;
  - **grupo salvo**: o `cluster_id` de `clean.school_indicators`, do último
    agrupamento rodado na plataforma com qualquer preset (3.046 escolas).
  - **Medido:** em 37 escolas de Salvador, correlação de 0,83 entre o IDEB da
    escola e a mediana do grupo, com grupos de 7 a 276 escolas.
  - A ajuda prometia porte, etapas, nível socioeconômico e localização.
- **RI-02 (atrapalha).** O INSE gerava sinal "pior que o grupo" (13 de 38
  escolas).
- **RI-03 (detalhe).** `cluster_resumo$n` era o tamanho do grupo para todos
  os indicadores. O CEIFAR tinha "IDEB, N = 436" num município com 417
  escolas com IDEB.

## Decisões

- **K vizinhos por contexto, e não k-means.**
  `.school_profile_context_group` pega as `PROFILE_GRUPO_K = 30` escolas do
  município mais próximas pela distância de Gower.
  - **Por que vizinhos:** a regra se explica em uma frase, o tamanho é
    estável, ela não depende dos indicadores que a escola tem, e cada escola
    tem o seu grupo, centrado nela. No k-means, a escola na borda de um
    grupo é comparada com o centro dele.
  - **As variáveis**, em cinco dimensões com o mesmo peso:
    - `tp_dependencia` e `tp_localizacao` (categóricas);
    - `log1p(qt_mat_bas)` (numérica);
    - as etapas oferecidas: infantil, anos iniciais, anos finais, médio e
      EJA, binárias, que dividem o peso de uma dimensão;
    - `inse` (numérica).
  - **O que faltar** sai da conta daquele par, e o peso é redistribuído (é
    o Gower).
  - **Etapa ausente no Censo** (`in_comum_*` nulo) conta como não oferecida.
  - **Município com até 30 outras escolas:** todas.
- **A distância de uma escola contra todas** (`.profile_gower_um`) é
  calculada sem montar a matriz inteira. São Paulo tem 7.310 escolas, e
  o `daisy` montaria 26 milhões de pares. Medido: o perfil de São Paulo
  responde em 1,8 s.
- **O grupo salvo deixa de valer para o perfil.** Um agrupamento rodado
  por alguém, com qualquer preset, não é critério citável.
  - `.school_profile_persisted_cluster` e o fallback k-means foram
    removidos.
  - O perfil da rede (`network-profile`) ainda lê o `cluster_id` e não
    mudou.
- **O IDEB do grupo é o da etapa da escola** (#483). O frame do município
  já vem filtrado pela etapa, e o N do IDEB conta só as escolas do grupo com
  nota nela.
- **INSE sem sinal:** a constante `PROFILE_SEM_SINAL`. A análise zera o
  `atencao` do INSE, e a linha sai dos modelos dos sinais. O INSE continua
  na comparação e no critério do grupo.
- **A regra sobe para 5** (`PROFILE_REGRA_SINAIS` e
  `$PERFIL_REGRA_SINAIS`): o cache de perfis da regra 4 deixa de ser
  servido.
- **O critério vai no payload** (`metadata.grupo_criterio`, `grupo_k`), e a
  tela o mostra. O texto vive num lugar só, no R.

## Validação

- Nas mesmas 38 escolas de Salvador da avaliação:
  - a correlação entre o IDEB da escola e a mediana do grupo caiu de 0,83
    para 0,30, e a distância média à mediana do grupo foi de 0,26 para 0,45
    (a média do município dá 0,47);
  - todos os grupos têm 30 escolas;
  - os sinais de INSE caíram de 13 para 0;
  - o N do IDEB fica entre 16 e 29 por grupo.
- O CEIFAR (privada) tem um grupo de 30 escolas, com IDEB N = 0.
- **Testes:**
  - R com e sem o banco de fixtures, com o arquivo novo
    `test-school-profile-grupo-contexto.R` (Gower, o grupo sem o IDEB, N,
    município pequeno, INSE e cache), todos passando;
  - Perl: 199 arquivos e 1.757 testes, todos passando;
  - vitest: 1.355 testes, todos passando;
  - CI do PR verde.

## Pendências

- As **escolas similares do Perfil** ainda usam os indicadores do perfil,
  inclusive o IDEB, e um pool das primeiras 300 escolas do município, sem
  critério. A ajuda de escolas semelhantes diz isso. Vale uma issue
  própria.
- O perfil da rede ainda lê o `cluster_id` do último agrupamento.
