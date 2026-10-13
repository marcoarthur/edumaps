# Nota técnica 121 — Ingestão real, P1: carga no produto e o que as cargas reais revelaram (#234; PRs #235, #236, #237)

## Resumo

A fase **P1** do plano da #156 (`docs/specs/2026-10-13-ingestao-real-plano.md`)
carregou no banco do produto (`database.edumaps`/`edumaps_dev`) as fontes que
já tinham loader: SICONFI, BrazilCrime, Transportes (RENAEST + RENAVAM) e
IBGE. Todas terminaram com `ultimo_status = ok`.

A parte mais valiosa do ciclo foram **seis defeitos que só a carga real
mostrou**. O dry-run e os testes passavam em todos eles. As correções
entraram em três PRs.

## Decisões do developer

1. **SICONFI:** último exercício completo (**2025**), todas as UFs, RREO do
   6º bimestre + DCA.
2. **IBGE:** snapshot de `clean.dados_ibge` antes da carga. A carga só fica
   se bater com o snapshot; senão, restaura-se.
3. **Uma issue P1.** PR só quando houver código; as cargas são operação.
4. **IBGE (decidido no meio da carga):** o loader segue o **contrato** da
   tabela, e não o percentual oficial do SIDRA.

## Resultado (antes → depois)

| Tabela | Antes | Depois |
|---|---|---|
| `siconfi_receita` | 88 (só SP) | 192.998 (5.538 municípios; FUNDEB 5.468) |
| `siconfi_despesa` | 0 | 83.508 (5.497 municípios) |
| `brazilcrime_municipio` | 0 | 61.192 (5.570) |
| `renaest_sinistro` | 0 | 2.268.496 (5.378) |
| `renaest_localidade_municipio` | 5.573 `auto_seed` | 5.570 de-para real |
| `renavam_frota_municipio` | 0 | 5.538 |
| `dados_ibge` | 27.850 (2019–2023) | 55.715 (2014–2023) |
| `ibge_agregados` | 0 | 2.563.120 |

O relatório completo está na #234.

## O que as cargas reais revelaram

1. **RREO Simplificado** (#235). Municípios com menos de 50 mil habitantes
   podem publicar o RREO Simplificado (LRF art. 63), e com
   `co_tipo_demonstrativo=RREO` eles devolvem 0 itens.
   - **2.295 municípios (41%)** só têm o simplificado.
   - O loader os pulava com um aviso de "ainda não publicado", que é
     plausível o bastante para passar despercebido.
   - O Anexo 01 do simplificado tem as mesmas colunas e `cod_conta`; o
     loader agora cai para ele.
2. **Custo da malha** (#235). O RREO trazia ~4 mil itens em ~5 páginas,
   mas só o Anexo 01 é usado.
   - Com `no_anexo` e páginas de 5000, o custo cai para 1 GET por
     município.
   - A estimativa da malha nacional caiu de ~10 h para ~4 h; a medição
     final foi RREO 3,9 h e DCA 3,6 h, em paralelo.
3. **Brutos que não existiam** (#235). BrazilCrime (via pacote R) e IBGE
   (via API) não deixavam arquivo baixado.
   - Agora o CSV extraído é o bruto, com sha256 no manifesto.
   - O ganho apareceu na mesma tarde: duas recargas do IBGE saíram **do
     bruto**, em 12 s e 473 s, contra ~2 h de SIDRA.
4. **Órfão falso** (#235). O extractor R lia o `municipios.csv` com
   `header=FALSE`, e o cabeçalho virava um "município" órfão nos dois lados
   do relatório. O comentário do código descrevia um contrato antigo, sem
   cabeçalho.
5. **PK violada pela repetição mensal** (#235). O sentinela do RENAEST
   repete-se nas linhas mensais do Localidade, e a segunda cópia violava a
   PK das não resolvidas. A carga real abortava; o dry-run não toca o
   banco.
6. **Percentual com outra grandeza** (#236).
   - O loader gravava as variáveis 516/520/528/6574 do SIDRA (% do valor
     adicionado, de 0 a 100).
   - O contrato da tabela (COMMENT + consumidores City e
     `analytics.municipios_consolidado`) é **fração do PIB**, com serviços
     como complemento.
   - Os absolutos eram idênticos e 16.707 pares tinham divergência só nos
     percentuais. **O snapshot pegou isso antes de qualquer consumidor**: a
     MV não tinha sido atualizada.
7. **NULL numa coluna da PK** (#237). `ibge_agregados.classificacao` faz
   parte da PK, e a tabela 5938 não tem quebra. A carga abortou depois de
   2 h de extração. Vazio agora vira `'Total'`, a convenção do SIDRA.

## Decisões de design

- **O bruto guarda o valor oficial; a carga aplica o contrato.** O CSV do
  SIDRA preservado mantém o % oficial, e `processar_dados_ibge` converte.
  Se o contrato mudar um dia, recarrega-se do bruto.
- **Recarga do bruto como argumento** (`--arg dados_csv`/`agregados_csv`).
  É o uso que justifica a preservação decidida na P0.
- **Snapshot + comparação com tolerância.** A comparação por igualdade de
  JSON acusa 16.707 "divergências" que são ruído de ponto flutuante
  (máx. 4e-15). O critério é `abs(a - b) > 1e-9` e nulidade igual.
- **Correção de loader durante a carga:** branch, PR e merge para cada
  defeito. A carga em curso continua com o código antigo quando não é
  afetada, e a recarga usa o novo.

## Operação (backend.edumaps)

- Scripts em `/root/p1/*.sh`, logs em `/var/log/edumaps/p1_*.log`. Rodar
  com `setsid nohup`: uma sessão ssh silenciosa por ~10 min é cortada.
- `pgrep -f`/`pkill -f` via ssh casam a própria linha de comando e
  derrubam a sessão. Usar o padrão `[p]erl …`.
- O dados.transportes.gov.br corta downloads e só às vezes aceita
  `Range`. Usar `curl -C -` em laço até o tamanho do CKAN e `unzip -t`.
- Contagem de progresso: no DCA, contar a linha-resumo `— <cod>/2025`; uma
  contagem por "linhas em clean" infla.

## Pendências

- **RENAVAM:** 33 pares (UF, município) sem casa por grafia (~0,5% das
  linhas, 32 municípios sem frota). Candidato a mapa de variantes, como o
  do BrazilCrime.
- **SICONFI** sem bruto preservado (resposta por município). Se necessário,
  gravar o JSON agregado por execução.
- **P2:** CGU pelo ZIP mensal, setores + Censo 2022, SISAB. **P3:** CNES e
  MapBiomas. **P4:** fechamento.
