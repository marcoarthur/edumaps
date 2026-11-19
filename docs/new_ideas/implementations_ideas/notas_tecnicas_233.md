# Nota técnica 233: escolas similares do perfil pelo contexto (#495)

Achados RH-01 e RH-02 da vigésima primeira avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-18-p4-similares-perfil.md`).
Um PR: #496 (merge `f218c94`).

## O problema

- **RH-01 (atrapalha).** As "Escolas similares" do perfil saíam de dois
  caminhos, e nenhum era o critério do grupo de referência da mesma tela
  (#493):
  - **pares salvos** em `analytics.similarity_pairs`, gravados pelo último
    job de similaridade com os indicadores que ele escolheu (19 escolas no
    banco local);
  - **Gower no município** (`.school_profile_fallback_peers`) sobre os
    `PROFILE_INDICATORS` que a escola tinha, inclusive `ideb_observado` e
    `nota_media`.
  - **Medido:** em 37 escolas de Salvador, correlação de 0,97 entre o IDEB
    da escola e a mediana do IDEB das dez similares, a 0,23 ponto em média.
    As similares eram escolas de resultado igual.
- **RH-02 (atrapalha).** O pool era `head(others, max_schools - 1L)`, com
  `max_schools = 300` e sem `ORDER BY` no SQL. Em São Paulo, as 110
  similares de 11 escolas caíam todas entre os INEPs 35000243 e 35044428.

## Decisões

- **As similares são as primeiras da ordem do grupo.**
  `.school_profile_context_group` já ordena o município inteiro pela
  distância de contexto (`.profile_gower_um`: rede, localização, porte,
  etapas, INSE). Agora devolve também essa ordem (`vizinhas`, com a
  distância e o IDEB da etapa da escola), e
  `.school_profile_context_peers` pega as `PROFILE_SIMILARES_N = 10`
  primeiras dentro do limiar de 0,3. Similaridade = 1 − distância.
  - **Por que o mesmo critério do grupo:** as duas listas estão na mesma
    tela. Com critérios diferentes, uma escola pode ser "similar" sem estar
    no grupo, e o leitor não tem como saber qual régua vale.
  - **O IDEB fora da escolha** é o que deixa achar "contexto parecido,
    resultado diferente". O IDEB volta na tela, ao lado de cada similar,
    com a diferença para o da escola ("IDEB 5,8 (+1,1)").
- **O município inteiro, sem pool.** A conta de uma escola contra todas já
  existia; não há custo novo. Em São Paulo o perfil continua em ~2 s.
- **O perfil deixa de ler `analytics.similarity_pairs`.** Pelo mesmo motivo
  do `cluster_id` na #494: um job rodado por alguém, com qualquer conjunto
  de indicadores, não é critério citável. A tabela e o job seguem existindo
  para quem os usa.
- **Código morto removido:** `.school_profile_fallback_peers`,
  `.profile_target_features`, `.profile_drop_constant_features` e o
  parâmetro `fallback_peer_max` (o backend não o mandava).
- **Payload:** `peers_source = "contexto_municipio"`, `peers_criterio` (o
  mesmo texto de `PROFILE_GRUPO_CRITERIO`) e `peers_n`. O frontend mantém
  os rótulos antigos para perfis de cache antigo.
- **A regra sobe para 6** (`PROFILE_REGRA_SINAIS` e `$PERFIL_REGRA_SINAIS`):
  o cache de perfis da regra 5 deixa de ser servido.

## Validação

- Nas mesmas escolas da avaliação, Docker local:
  - **Salvador (37 com IDEB):** correlação entre o IDEB da escola e a
    mediana das similares de 0,97 para **0,10**; diferença média absoluta
    de 0,23 para 0,62 ponto. As 38 escolas têm 10 similares, com
    similaridade de 95% a 100% (mediana 99%). 166 escolas distintas nas 380
    vagas.
  - **São Paulo (11):** 52 das 110 similares fora da faixa de INEPs de
    antes (eram 0). A correlação ainda é 0,8, mas com 10 escolas, e o
    contexto (rede, INSE) anda junto com o IDEB; não é o IDEB que escolhe.
- **Testes:**
  - R: três testes novos em `test-school-profile-grupo-contexto.R`
    (similares = primeiras do grupo e iguais com o IDEB trocado; limiar e
    máximo; município de 1.000 escolas com as gêmeas no fim da lista),
    suíte inteira passando com e sem o banco de fixtures (2.325);
  - Perl: 199 arquivos e 1.757 testes, todos passando;
  - vitest: 1.358 testes, todos passando;
  - CI do PR verde.

## Pendências

- O perfil da rede ainda lê o `cluster_id` do último agrupamento.
- A similaridade do Painel do Gestor é a do contexto em escopo maior
  (município, estado, região); o Painel da Escola compara as seis notas. Os
  três lugares seguem com critérios diferentes, agora ditos na ajuda.
