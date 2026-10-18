# Nota técnica 148 — #268: renda do responsável no produto

Esta nota documenta a **materialização da renda do responsável** (produto
*Rendimento do Responsável* do Censo 2022) no produto, para o bloco B do IVET
passar a agregar **instrução + renda + saneamento**. PR **#279** (branch
`feat/data-renda-responsavel`, commit `2819521`).

## Contexto

O **código** da renda do bloco B estava mergeado e deployado (#266, PR #267;
`ivet-v1.2`), mas o **dado** não estava no produto: `clean.censo2022_setor.rend_media`
tinha **0** linhas e `clean.escola_entorno_socioeconomico` estava **todo em
`ivet-v1.1`** (470.448 linhas). O componente `renda` saía `NA` (correto — ausência
≠ 0, #154), mas sem valor.

## Bloqueio encontrado: o allowlist não cobria a renda

O loader `EduMaps::Ingestion::Job::SetoresCenso2022` (#266) referencia o ZIP da
renda numa **pasta irmã** dos demais temas:

```
ftp.ibge.gov.br/Censos/Censo_Demografico_2022/
  Agregados_por_Setores_Censitarios/Agregados_por_Setor_csv/*.zip        (5 temas)
  Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/*.zip     (renda)
```

O allowlist (`ibge_ftp_censo2022`) declarava só a **primeira** — a renda, sendo um
segmento diferente (`…_Rendimento_do_Responsavel`), **não casava**, e o job
morreria no `exigir_allowlist`. Entrada nova acrescentada (URL verificada: HTTP
200, `2026-05-08`). É o mesmo padrão de defeito que o #168 (ANTT): **um loader
mergeado que referencia uma URL fora do allowlist** só se revela quando o job roda.

## Materialização

### Loader (`so=censo`, 816 s)

`clean.censo2022_setor` passou a ter:

| coluna | setores |
|---|---|
| `rend_media` (V06004, rendimento nominal médio) | **449.531** |
| `rend_mediana` (V06006) | **449.531** |
| `rend_resp_count` (V06001, peso da arealização) | **449.868** |

De **468.097** setores no total — o resto é **célula suprimida** ("X" do IBGE →
`NULL`, #154). Média de `rend_media` ≈ R$ 2.860, mediana ≈ R$ 2.103.

⚠️ O ZIP da renda **não estava no raw** (só os 5 temas antigos, de 2026-10-13/16).
Para não rebaixar ~450 MB: os 5 ZIPs foram **hardlinkados** para o diretório do dia
(o `download_file` reaproveita por *mesmo nome, mesmo dia*) e **só a renda foi
baixada** (9,37 MB).

### Re-materialização do entorno

`clean.refresh_escola_entorno_socioeconomico()` já produz **`ivet-v1.2`** com a
renda (verificado no corpo da função: `ivet-v1.2`, `renda_resp*`,
`rend_resp_count`). Rodada **por UF**, em background no `database.edumaps`
(`/tmp/refresh_entorno.sh`, log `/tmp/refresh_entorno.log`), retomável.

**Tempo medido**: AC (539 escolas) → **89–100 s** → projeção **~8 h** para o país
(a issue estimava 5–6 h). ⚠️ **A rodada nacional não conclui nesta sessão** — o
script continua no servidor; a pendência é confirmar o `FIM` no log e medir
`versao='ivet-v1.2'`.

## Validação (piloto AC)

| métrica | resultado |
|---|---|
| `versao` | **`ivet-v1.2`** |
| linhas (AC, 3 raios) | 1.617 |
| `renda_resp_media` / `renda_resp_mediana` preenchidos | **1.616 / 1.617** (1 sem renda → `NULL`) |
| média `renda_resp_media` | R$ 2.226 |
| média `renda_resp_mediana` | R$ 1.523 |

**Nota sobre `cobertura_pct`**: AC deu 0,024, contra 0,058 (RR) e 0,071 (AP) em
`v1.1`. É **característica pré-existente** do Censo 2022 por setor (~88% dos
setores suprimidos) — **não é regressão** da renda.

## Testes

`backend/t/05-tasks/setores_censo_loader.t` (já cobria o tema renda: ponto
decimal, `X`→`NULL`, mapeamento) e `backend/t/02-models/allowlist_real.t` —
verdes.

## Docs

`docs/analises/fontes/socioeconomico.md` (estado da materialização) e
`docs/analises/ivet.md` (§4.3 — o bloco B passa a agregar instrução + renda +
saneamento).

## Lição

O defeito do allowlist (aqui e no #168) tem a mesma forma: **o `exigir_allowlist`
só é exercido quando o job roda**, e um loader mergeado sem execução fica com uma
URL não coberta. Um teste que valide **todas as URLs declaradas pelos jobs**
contra o allowlist real (sem rede) pegaria os dois — candidato a próximo item.
