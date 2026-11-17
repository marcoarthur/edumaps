# Reavaliação: P4 depois das etapas oferecidas e da versão citável dos índices (2026-11-16)

Sexta rodada da P4 (academia), depois das duas entregas da quinta rodada:

| Entrega | O quê |
|---|---|
| #463 | etapas oferecidas na base e aviso de cobertura do IDEB (RX-02) |
| #464 | versão citável dos índices (`indices-v2`) em `/fontes`, no ranking de escolas e no CSV (RX-01) |

- **Avaliou:** só a P4, a pedido do developer.
- **Material:**
  - as ajudas `base-de-analise.md`, `rankings.md` e `fontes-e-metodologia.md`;
  - `/fontes`, a API do ranking de escolas e os links da fórmula no GitHub;
  - a stack local com os dados reais, só leitura;
  - **o trabalho que ela faria:** refazer no R, com a BA e o ES, o modelo
    da pergunta dela, agora com a seleção do IDEB à vista, e citar um
    índice do EduMaps num texto.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A base com as etapas.** A BA e o ES, com todos os blocos, juntam com
   `rbind`: 19.152 escolas e 61 colunas. Os nomes dos arquivos trazem o
   Censo, o IDEB e o INSE (`base-analise-BA-censo2025-ideb2023-inse2023.csv`).
2. **A seleção do IDEB, refeita só com a base** (RX-02 resolvido).
   - O exemplo da ajuda roda como está: entre as que oferecem anos
     iniciais, 34,8% das escolas com água têm IDEB, contra 4,1% das sem
     água.
   - Com `oferece_ai` e os itens `_inexistente`, ela reproduz os números
     da ajuda: 44,3% das escolas públicas completas têm IDEB 2023, contra
     12,7% das 417 com alguma falta básica.
   - **Modela a seleção:** um probit de "tem IDEB" com a falta básica, a
     localização, o porte (docentes), a rede e a UF. A falta básica reduz a
     chance mesmo controlando pelo porte e pela localização (coef. −0,27,
     p = 0,008).
   - O modelo do IDEB (4.155 escolas, R² 0,37) segue sem associação com a
     falta básica (p = 0,48). Agora ela sabe por quê e pode dizer isso no
     texto, ou corrigir com um modelo de seleção.
3. **Citar o índice de diversidade** (RX-01 resolvido).
   - `/fontes` traz o cartão "Índices do EduMaps": `indices-v2`, de
     16/11/2026, o histórico (`indices-v1`, a fórmula original) e os links
     "O que cada índice mede" e "Fórmula completa", que abrem a seção certa
     no GitHub.
   - O ranking de escolas de Salvador por diversidade (1.432 escolas) diz
     "indices-v2" ao lado do método, e o CSV traz `versao_indice` em toda
     linha.
4. **Usar os índices na pergunta dela.** Ela quis pôr o índice de
   infraestrutura do EduMaps ao lado dos itens do Censo, para comparar.
   - **Os índices não estão na base de análise.** Só saem no ranking de
     escolas, um município por vez: a BA tem 417 municípios (16.106 escolas
     com índice) e o ES, 78.
   - E não dá para refazer o índice com a base: ele usa itens que ela não
     traz (salas, cozinha, refeitório, órgãos colegiados, formação dos
     gestores).
   - Ou seja: o índice agora é citável, mas não é usável numa análise de
     uma UF (RY-01).
5. **O arquivo do ranking de escolas.** Chama-se
   `ranking-escolas-2927408-diversidade_discente-2025.csv`. A versão está
   dentro, mas não no nome, ao contrário da base, que leva os anos no nome
   (RY-02).

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P4 | adotaria | **adotaria** (mantido) | a seleção do IDEB fica visível e modelável só com a base, e o índice próprio tem versão, data e histórico; mas os índices não saem na base de uma UF, só município a município (RY-01) |

## O que funciona

- **Seleção à vista:** a base separa "não oferece" de "não teve nota", e a
  ajuda dá o exemplo com o código.
- **Índice citável:** versão, data, histórico e links da fórmula, no lugar
  onde ela procura as fontes.
- **Reprodutível:** os números da ajuda saem iguais do arquivo baixado.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| RY-01 | atrapalha | **Os seis índices do EduMaps não estão na base de análise.** Só saem no ranking de escolas, um município por vez (417 downloads para a BA), e não dá para refazê-los com a base, que não traz todos os itens da fórmula. Pedido: um bloco "Índices do EduMaps" na base, com os seis índices (0 a 10) e a coluna `versao_indice`, e o dicionário com o método de cada um e o link para `/fontes`. | base da BA e do ES sem colunas de índice; `clean.mv_escolas_scores` com 16.106 escolas na BA | P4, P6 |
| RY-02 | detalhe | **O nome do CSV do ranking de escolas não traz a versão do índice.** A base leva os anos no nome; o ranking de escolas leva só o ano. Pedido: `ranking-escolas-<ibge>-<indicador>-<ano>-indices-v2.csv` quando o indicador tiver versão. | `ranking-escolas-2927408-diversidade_discente-2025.csv` | P4 |

## Encaminhamento

Issue aberta com a aprovação do developer (2026-11-16): **#465** (RY-01 e
RY-02 juntas).

### Proposta

1. **RY-01:** o bloco "Índices do EduMaps" na base, lido de
   `clean.mv_escolas_scores` no mesmo ano do Censo da base, com
   `versao_indice` e o método do `%METODO` no dicionário. Mexe na base, no
   dicionário, na tela (um bloco a mais) e na ajuda. A pesquisadora pediria
   junto a RY-02, que é uma linha no frontend.
2. **RY-02:** pode ir no mesmo PR da RY-01, ou numa issue à parte.

## Andamento

- 2026-11-17: #465 (PR #466) mergeado: RY-01 e RY-02 resolvidos (bloco
  "Índices do EduMaps" na base, com `versao_indice`, o método no dicionário e
  a versão no nome do arquivo; versão no nome do CSV do ranking de escolas).
  Fechamento em
  [`../ciclos/2026-11-16-indices-na-base.md`](../ciclos/2026-11-16-indices-na-base.md).
  Nenhum achado aberto.
