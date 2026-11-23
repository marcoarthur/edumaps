# Reavaliação: P2 prepara a prestação de contas ao conselho (2026-11-23)

Rodada da P2 (secretaria municipal), feita sozinha a pedido do developer
(ausente, com autorização para abrir issues). A última foi em 2026-11-13
(visão da rede, #375), com o veredito **adotaria, em piloto numa rede**.
Desde então, nas telas públicas:

| Entrega | O quê |
|---|---|
| #430 a #453 | ranking de redes municipais (porte, região, destaque) e de escolas por município, com a variação |
| #516, #518, #520 | comparação de redes com creche e pré-escola separadas e as conveniadas (teto da oferta pública) |
| #439 a #531 | base de análise do município (etapas, matrículas, docência, índices, endereço) |
| #524, #527 | índices e perfil sem zero imposto à rede privada |

- **Avaliou:** só a P2.
- **Material:**
  - o ranking de redes municipais de SP com 100 a 500 mil habitantes, com
    Franca em destaque;
  - o ranking das escolas municipais de Franca (IDEB dos anos iniciais,
    infraestrutura, capacitação docente);
  - a comparação de redes de Franca (creche e pré-escola, conveniadas) e a
    ajuda da base;
  - para conferir, `clean.populacao_municipal` e
    `data_pipeline/deploy/raw_populacao_faixas_etarias.sql`.
- **O trabalho que ele faria:** a quarta pergunta do perfil dele, "como
  mostro ao conselho e ao tribunal de contas que a rede avança?", num
  relatório de Franca: a posição da rede entre municípios parecidos, as
  escolas que precisam de apoio e a cobertura da educação infantil, que é
  a meta do PNE (creche para 50% das crianças de 0 a 3 anos, e pré-escola
  universal de 4 a 5).
- ⚠️ Simulação: não substitui um secretário de verdade.

## O que ele fez

1. **Posição da rede:** no ranking de redes municipais de SP com 100 a 500
   mil habitantes, pelo IDEB dos anos iniciais, Franca é a 11ª de 70, com
   28 escolas avaliadas. O ranking diz a edição, o mínimo de escolas e a
   variação.
2. **Escolas que precisam de apoio:** o ranking das escolas municipais de
   Franca lista as 28 com IDEB e as 51 com os índices, com o INSE ao lado.
   No fim das listas estão as EMEIs (sem IDEB e sem INSE), o que ele lê
   como "educação infantil com infraestrutura e formação mais baixas".
3. **Cobertura da educação infantil:** a comparação de redes dá as
   matrículas em creche e pré-escola da rede municipal e das conveniadas
   (como teto). A ajuda da base calcula 21,2 matrículas em creche por mil
   habitantes em Franca. O conselho, porém, cobra a **taxa de
   atendimento** (matrículas ÷ crianças da idade), não matrículas por
   habitante, e a ajuda diz que a população por idade "não está
   carregada".
4. **Foi ver se não estava.** O banco tem a população municipal por faixa
   de 5 anos (`faixa_0_4_anos`, `faixa_5_9_anos`…) para todos os
   municípios, numa carga de um CSV sem fonte nem ano registrados
   (`raw_populacao_faixas_etarias`). Os números não servem para a meta:
   - as faixas de 5 anos não separam a creche (0 a 3) da pré-escola (4 e
     5);
   - faltam as faixas de 25 a 29 e de 90 a 94 anos: em Franca, a soma das
     faixas dá 325.006, contra 365.494 da população estimada;
   - a fonte e o ano não estão em `/fontes`, então nada disso se cita
     numa prestação de contas.

## Veredito

| Persona | Antes | Agora | Motivo |
|---|---|---|---|
| P2 | adotaria, em piloto numa rede | **adotaria, em piloto** (mantido) | a posição da rede entre municípios parecidos e a lista de escolas por indicador saem prontas e citáveis; a cobertura da educação infantil, que o conselho e o PNE cobram, não sai (QP-01) |

## O que funciona

- **Ranking de redes com destaque:** a posição do município entre os do
  mesmo porte, com a edição e o mínimo de escolas.
- **Escolas da rede por indicador,** com o INSE ao lado e o método.
- **Oferta da educação infantil** com as conveniadas, dita como teto.

## Achados novos

| Id | Gravidade | O quê | Evidência | Para quem |
|---|---|---|---|---|
| QP-01 | atrapalha | **Sem taxa de atendimento da educação infantil.** A meta do PNE e o conselho pedem matrículas ÷ crianças de 0 a 3 anos (creche) e de 4 a 5 (pré-escola). A plataforma só dá matrículas por habitante. O banco tem faixas de 5 anos de uma carga sem fonte nem ano, que não separam creche de pré-escola e têm faixas faltando. Pedido: carregar a população por idade do IBGE (Censo 2022, por idade simples ou nas faixas 0 a 3 e 4 a 5), com fonte e ano em `/fontes`; a taxa de atendimento em creche e pré-escola na comparação de redes (rede municipal e rede municipal mais conveniadas, como teto) e na base (bloco Porte); e decidir o que fazer com as faixas atuais sem fonte. | Franca: 21,2 matrículas em creche por mil habitantes, e não a taxa; faixas de 5 anos, sem 25 a 29 e 90 a 94 (soma 325.006 contra 365.494); ajuda da base: "a população por idade não está carregada" | P2, P5, P6 |

## Encaminhamento

Issue **#533** (QP-01), aberta sem esperar a aprovação, por autorização
do developer (ausente). A carga da população por idade exige baixar dados do IBGE, o que
depende da permissão do developer.

## Andamento

- 2026-11-23: #533 (PR #534) mergeado: QP-01 resolvido.
  - A população por idade do Censo 2022 (SIDRA 9514) está em `/fontes` e
    na base (`populacao_0_3` e `populacao_4_5`, bloco Porte).
  - A comparação de redes mostra a taxa de atendimento da creche e da
    pré-escola em todas as redes, na municipal e com as conveniadas (teto).
    Em Franca, a creche fica em 58,0%, 0,0% e 48,9%.
  - As faixas antigas, sem fonte, ficam com o comentário dizendo a origem.
