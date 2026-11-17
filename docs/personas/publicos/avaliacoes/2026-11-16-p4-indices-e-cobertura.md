# Reavaliação: P4 depois da região na base, dos itens inexistentes, das coordenadas e da diversidade corrigida (2026-11-16)

Quinta rodada da P4 (academia), depois das entregas que mudaram o que ela
usa:

| Entrega | O quê |
|---|---|
| #450 | região na base e recorte no CSV |
| #451 | destacar um município |
| #455 | itens inexistentes e coordenadas |
| #456 | as duas posições no CSV |
| #458 | infraestrutura básica e método dos índices |
| #460 | diversidade discente corrigida, `ivet-v1.4` |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md` e `rankings.md`;
  - `/fontes` e a sua API;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** refazer no R o modelo da pergunta dela com
    as colunas novas (BA e ES juntas), e conferir como citaria um índice que
    mudou hoje.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.
- Feita a pedido do developer. Issues **#461** (RX-02) e **#462** (RX-01),
  abertas com a aprovação dele.

## O que ela fez

1. **Duas UFs de regiões diferentes numa base só.**
   - A BA e o ES, com todos os blocos, juntam com `rbind`: 19.152 escolas e
     53 colunas.
   - A coluna `regiao` já vem (Nordeste, Sudeste), sem mapa à mão (RG-01
     resolvido).
2. **"IDEB × infraestrutura, controlando por rede", agora com a
   infraestrutura básica.**
   - `lm(ideb_ai ~ basica + in_internet + in_biblioteca + rede + inse_media +
     uf)` roda direto: 4.218 escolas, R² 0,37.
   - A infraestrutura básica (itens `_inexistente` e banheiro) **não se
     associa** ao IDEB (p = 0,42).
   - **Mas só 54 das 4.218 escolas com IDEB têm alguma falta básica.**
     Entre as escolas públicas da BA e do ES que oferecem anos iniciais:

     | Escolas | Com IDEB 2023 |
     |---|---|
     | sem alguma infraestrutura básica (417) | **12,7%** |
     | completas (9.273) | **44,3%** |

     A ausência do IDEB não é aleatória: quem não tem infraestrutura quase
     nunca tem nota. O "não se associa" do modelo é, em boa parte, efeito de
     quem ficou de fora (RX-02).
   - **A base não deixa ver isso.** Ela não traz as etapas que a escola
     oferece. O IDEB vazio mistura "não oferece a etapa" com "oferece e não
     teve nota", e a ajuda diz só que a ausência é célula vazia. A medida
     acima precisou do banco.
3. **Coordenadas:** 3.335 escolas com IDEB têm coordenada. O `sf` monta os
   pontos para uma análise espacial dos resíduos.
4. **Citar o índice de diversidade, que mudou hoje (#459).**
   - A tela e a ajuda dizem a correção, com a data.
   - **Não há versão citável dos índices próprios** (RX-01):
     - `/fontes` lista só o INEP e o IBGE. Os seis índices do EduMaps, de
       onde vem o "Diversidade Discente 4,2", não aparecem lá;
     - o CSV do ranking de escolas não traz a versão do índice;
     - só o IVET tem versão (`ivet-v1.4`).
   - Um número citado ontem (6,0) e o de hoje (4,2) não se distinguem pelo
     arquivo, só pela data do download.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido) | junta UFs com a região, tem coordenadas e "sem" é "sem"; mas a ausência do IDEB, que a base não deixa separar da oferta, enviesa a pergunta central dela (RX-02), e os índices próprios mudam sem versão citável (RX-01) |

## O que funciona

- **Base:** junta regiões sem ajuste, traz as coordenadas, e
  "inexistente" é "sem".
- **Método dito:** cada índice diz como é calculado e quando mudou.
- **O erro da diversidade foi corrigido**, com o aviso de não
  comparabilidade e a versão do IVET subindo.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RX-01 | atrapalha | **Os índices próprios do EduMaps não têm versão citável.** `/fontes` lista só as fontes externas, e os seis índices (atendimento, infraestrutura, docentes, diversidade, gestão, sustentabilidade) não aparecem com método nem versão. A correção da diversidade (#459) mudou a nota média de 6,0 para 4,2, e um arquivo baixado antes e um depois não se distinguem. Pedido: uma versão dos índices (ex.: `indices-v2`, 16/11/2026, com o histórico), na página `/fontes` (com o método e o link para a fórmula) e numa coluna `versao_indice` do CSV do ranking de escolas, como o IVET já faz. | `/api/fontes`; CSV do ranking de escolas por `diversidade_discente` | P4, P6 |
| RX-02 | atrapalha | **A ausência do IDEB é seletiva, e a base não deixa separá-la da oferta.** Entre as escolas públicas da BA e do ES que oferecem anos iniciais, 12,7% das sem infraestrutura básica têm IDEB 2023, contra 44,3% das completas. A base não traz as etapas oferecidas, então o IDEB vazio mistura "não oferece" e "não teve nota", e nada avisa da seletividade. Pedido: (1) colunas de etapas oferecidas (creche, pré-escola, anos iniciais, anos finais, ensino médio, EJA, profissional) na base; (2) no dicionário e na ajuda, o aviso de que o IDEB só sai para escolas com participação suficiente no SAEB e que isso exclui sobretudo as pequenas, rurais e sem infraestrutura. | modelo no R da rodada; consulta ao `clean.censo_escolas` | P4, P6 |

## Encaminhamento

Issues abertas com a aprovação do developer (2026-11-16): **#461** (RX-02) e
**#462** (RX-01).

### Proposta original

1. **RX-02**: as etapas oferecidas entram como um bloco da base, e o aviso
   de cobertura entra no dicionário e na ajuda. Mexe só na base e nos
   textos.
2. **RX-01**: a versão dos índices em `/fontes` e no CSV. Pede decidir o
   nome e onde a versão vive. A sugestão é um registro no backend, ao lado
   do `%METODO`, com a data de cada mudança de fórmula.

## Andamento

- 2026-11-16: #461 (PR #463) mergeado: RX-02 resolvido (bloco "Etapas
  oferecidas" na base; aviso de cobertura do IDEB no dicionário, na tela e na
  ajuda). Fechamento em
  [`../ciclos/2026-11-16-etapas-cobertura.md`](../ciclos/2026-11-16-etapas-cobertura.md).
  Fica #462 (RX-01).
- 2026-11-16: #462 (PR #464) mergeado: RX-01 resolvido (versão citável
  `indices-v2` em `/fontes`, no ranking de escolas e no CSV, e no comentário
  da MV; regra e teste para a próxima mudança de fórmula). Fechamento em
  [`../ciclos/2026-11-16-versao-indices.md`](../ciclos/2026-11-16-versao-indices.md).
  Nenhum achado desta avaliação fica aberto.
