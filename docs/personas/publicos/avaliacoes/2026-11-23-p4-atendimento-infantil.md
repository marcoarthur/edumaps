# Reavaliação: P4 compara a oferta de educação infantil por porte e região (2026-11-23)

Trigésima sétima rodada da P4 (academia), a pedido do developer. A
anterior foi em 2026-11-22 (IDEB e docência, QS-01 → #529), com o veredito
**adotaria**. Desde então:

| Entrega | O quê |
|---|---|
| #529 | docentes por etapa na base |
| #531 | CEP, bairro e endereço na base |
| #533 | população por idade do Censo 2022 na base e em `/fontes`; taxa de atendimento na comparação de redes |
| #535, #539 | taxa de atendimento da creche e da pré-escola no ranking de redes, com o CSV e as fontes certas |

- **Avaliou:** só a P4.
- **Material:**
  - o ranking de redes com a creche e a pré-escola no recorte nacional
    (5.570 municípios);
  - a base de análise de PE e de SC (blocos Matrículas e Porte), para
    refazer a conta;
  - a comparação de redes e a base de análise do Distrito Federal (bloco
    Parceria).
- **O trabalho que ela faria:** a pergunta típica do perfil dela,
  "municípios de porte e região semelhantes têm oferta parecida?", para a
  educação infantil, num artigo sobre desigualdade regional na meta 1 do
  PNE. Antes de usar o número, ela confere se ele se reproduz a partir dos
  microdados por escola.
- ⚠️ Simulação: não substitui uma pesquisadora de verdade.

## O que ela fez

1. **A tabela do artigo:** com o CSV nacional do ranking, calcula a
   mediana da taxa de atendimento da creche (todas as redes) por região e
   porte. O padrão é claro:

   | Região | Até 5 mil | 10 a 20 mil | 100 a 500 mil |
   |---|---|---|---|
   | Norte | 35% | 25% | 24% |
   | Nordeste | 50% | 41% | 29% |
   | Sudeste | 50% | 42% | 48% |
   | Sul | 53% | 47% | 45% |
   | Centro-Oeste | 35% | 34% | 33% |

   - O Norte e o Centro-Oeste ficam abaixo em todos os portes.
   - No Nordeste a taxa cai com o porte.
   - 3.733 dos 5.570 municípios estão abaixo dos 50%.
   - Na pré-escola, a mediana fica perto de 100% em quase todos os grupos
     (2.542 municípios passam de 100%), e a meta só aparece como
     problema nas cidades grandes (84% no Nordeste com mais de 500 mil
     habitantes).
2. **Refazer a conta:** soma as matrículas em creche das escolas da base
   de análise de PE e de SC por município e divide por `populacao_0_3`.
   Os **185 municípios de PE e os 295 de SC batem com o ranking**, sem
   nenhuma diferença. A base traz o ano da população e o do Censo Escolar
   em toda linha.
3. **Os casos de borda:**
   - 244 municípios têm menos de 100 crianças de 0 a 3 anos. A coluna de
     crianças no CSV permite ponderar ou cortar, e ela pondera.
   - **O Distrito Federal** aparece com 32,7% em todas as redes, **0,0% na
     "rede municipal" e sem teto**. Ela estranha, porque a creche pública
     do DF é feita sobretudo por convênio.
     - Na base de análise (bloco Parceria), das 42.433 matrículas em
       creche das escolas privadas do DF, **24.570 estão em escolas
       conveniadas com a esfera "Estadual"**, que no DF é o governo
       distrital.
     - A rede distrital (a "estadual" do Censo) tem 149.
     - O teto conta só o convênio com a prefeitura (esfera municipal, ou
       estadual e municipal). No DF não há prefeitura, e a oferta pública
       desaparece das duas contas.
     - Com a rede distrital e as conveniadas com o governo distrital, o
       teto do DF seria cerca de 19%.

## O que funciona para ela

- A taxa se reproduz exatamente a partir dos dados por escola, com o ano
  de cada base em toda linha.
- O recorte nacional com porte e região num CSV só, sem rodar R para a
  tabela descritiva.
- As crianças por município no CSV, para ponderar os municípios pequenos.
- A fonte e o ano da população no rodapé e em `/fontes`.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QL-01 | atrapalha | **No Distrito Federal, a oferta pública de creche some da taxa da rede e do teto.** O DF não tem prefeitura: a rede pública é a distrital (`tp_dependencia` 2, "estadual" no Censo), e as escolas privadas conveniadas têm a parceria com a esfera "estadual" (o governo distrital). O ranking e a comparação de redes contam como "rede municipal" só a dependência 3, e como conveniadas só a parceria municipal (ou estadual e municipal). O DF aparece com 0,0% na rede municipal e sem teto, embora 24.570 matrículas em creche estejam em conveniadas com o governo distrital. Pedido: no DF, tratar a rede distrital como a rede "do ente local" e as conveniadas com o governo distrital como as da prefeitura, nas três contas e na nota das conveniadas da comparação de redes; ou, no mínimo, avisar na tela e no CSV que no DF a conta da rede municipal não se aplica. | `/api/ranking/redes?indicador=atendimento_creche&nacional=1`, linha 5300108; `/base-analise?uf=DF&rede=privada&blocos=matriculas,parceria`; filtro `tp_poder_publico_parceria IN (1, 3)` em `rede_escolas_conveniadas` | P4, P2, P5 |

Observação, sem pedido: a população é do Censo 2022 e as matrículas, de
2025. Com a queda dos nascimentos, a taxa tende a sair um pouco acima da
real, e a nota da tela já avisa que a população mudou desde o Censo. Uma
estimativa por idade e município para o ano das matrículas não existe nos
dados abertos do IBGE.

## Veredito

**Adotaria** (mantido). A pergunta do perfil tem resposta reproduzível e
citável. Ressalva: no DF, a conta da rede local e do teto não vale
(QL-01).

## Encaminhamento

Issue **#545** (QL-01), aberta com a aprovação do developer.
