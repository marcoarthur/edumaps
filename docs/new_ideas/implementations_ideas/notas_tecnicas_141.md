# Nota técnica 141 — #137 bloco D (saúde): fix do CNES na acessibilidade escolar

Esta nota documenta a **correção da fonte de saúde** do bloco **D** do IVET
(#137) — o primeiro passo da extração territorial escolhida pelo developer
("fix do CNES primeiro, depois D"). PR **#271** (merge `bf0e4c4`). A extração R
do bloco D propriamente dita **não** entrou neste ciclo.

## Contexto

O bloco **D (saúde)** do IVET tem duas fontes candidatas: a documentada
(**PeNSE**, #127) e a já carregada (`analytics.acessibilidade_saude`, cruzamento
CNES + SISAB + Censo Escolar). A PeNSE **não está no banco** (e é quinquenal,
com LGPD a resolver), então a via prática é a acessibilidade escolar à atenção
básica.

Ao investigar a fonte antes de fixar a fórmula (regra do ciclo: dado primeiro),
apareceu que a view de acessibilidade estava **vazia de conteúdo real** apesar
de ter 145.734 linhas: 100% das escolas sem distância e classificadas "Sem UBS
no município".

## O que foi feito

Change Sqitch **nova** `analytics_acessibilidade_saude_ubs`
(`data_pipeline/{deploy,revert,verify}/analytics_acessibilidade_saude_ubs.sql`),
com **três correções** na definição da view:

1. **Filtro CNES** `codigo_tipo_unidade IN (11, 12)` → `IN (1, 2)`. Os códigos
   11/12 **não existem** no dicionário oficial (`/cnes/tipounidades`, verificado
   ao vivo): a atenção básica está em `1` (Posto de Saúde) e `2` (Centro de
   Saúde / Unidade Básica de Saúde). Com o filtro errado, nenhuma UBS casava.
2. **Distância** `ST_Distance(geom, geom) / 1000` → `ST_DistanceSphere(...) / 1000`.
   `ST_Distance` sobre geometria SRID 4674 devolve **graus**, não metros; a
   divisão por 1000 produzia micro-quilómetros. `ST_DistanceSphere` mede em
   metros (esférica).
3. **Ausência ≠ zero (#154)**: município sem UBS virava `NULL` em
   `n_ubs_municipio` (o `LEFT JOIN` do pré-agregado não produz linha), quando a
   própria #154 pede `0` (zero real). Passa a `COALESCE(..., 0)` no ramo em que
   a fonte CNES tem dado.

Como a view é **materializada** (#158), a change reconstrói a MV
`analytics.mv_acessibilidade_saude` e repõe a fachada — mesmo desenho da change
`analytics_views_materializadas` (a lógica não é duplicada: `pg_get_viewdef`).

### Docs

- `docs/analises/fontes/saude.md`: nota da correção (códigos 1/2, distância
  esférica) e aviso de que **`cobertura_aps` não é cobertura APS** — é a
  população coberta estimada do **PMMB (Programa Mais Médicos)**, em pessoas,
  não em % (ver `EduMaps::Ingestion::Job::SISAB`). Para cobertura APS, usar
  `(Σ ativas_ff + equipe_esf) ÷ população × 10.000`.

## Evidência (dev `database.edumaps`, 2026-10-17)

| | antes | depois |
|---|---|---|
| escolas com `dist_min_km_ubs` | 0 / 145.734 | **145.723 / 145.734** |
| `n_ubs_municipio` NULL | 100% | **0** |
| classificação | 100% "Sem UBS no município" | excelente 102.972 · bom 17.454 · regular 5.797 · difícil 19.500 · sem UBS 11 |

Distância após o fix: p50 **0,54 km** · p90 **7,25 km**. UBS de atenção básica:
50.715 estabelecimentos ativos com coordenada, cobrindo 5.567/5.573 municípios.

## Decisões de desenho

- **Change nova, nunca editar a deployada**: mexer no `requires`/ordem de uma
  change já aplicada muda o `change_id` em cascata (regra do squad).
- **UBS = tipos 1 + 2** (dicionário oficial), não 11/12. Decisão confirmada com
  o developer.
- **A correção do zero-real fica na view** (`COALESCE`), não na camada R: o
  contrato "#154" já era o da view, e o verify da `analytics_ausencia_visivel`
  (#16) exige `n_ubs_municipio` não-NULL com o CNES carregado.
- **`cobertura_aps` mantém o nome** (renomear quebraria o contrato de colunas),
  mas o significado real fica no `COMMENT` e na doc da fonte.

## Validação

| Checagem | Resultado |
|---|---|
| `sqitch` local: deploy + verify + revert | ok (imagem `sqitch` reconstruída) |
| **Gate de CI** `db/fixtures/ci_db.sh up && verify` (banco novo, plano completo) | **Verify successful** |
| GitHub Actions "Perl contra o banco de fixtures" (PR #271) | **pass** (10m18s) |
| Deploy `rex prepare` + `deploy_db_dev` + medição no dev | ok |

## Pendências

- **Extração R do bloco D** (IVET) sobre a fonte agora sã — PR à parte.
- **Extrações E+G+F** num PR único (segurança, recursos, meio ambiente).
- **C (mobilidade)** segue bloqueado (Tier 2 / isócrona, `influencia.md` §146):
  o IVET agregado continua **`NA`** enquanto C não existir.
- Backlog: #137 → #255 → #168 → **#138** → **#139** (#268 adiada).
