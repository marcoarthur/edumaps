# Ciclo 2026-11-22: concursados vazios nas privadas

- **Período:** 2026-11-22.
- **História:** #524 (PR #525), achados QT-01 e QT-02 da
  [trigésima quinta avaliação da P4](../avaliacoes/2026-11-22-p4-agrupamento-docencia.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 247.

## Resumo

- **Sem 0 imposto:** o Censo só pergunta o vínculo do docente na escola
  pública. Na privada, os concursados ficam vazios: na base, no
  agrupamento, nos perfis e no relatório por rede.
- **Índice:** a capacitação docente da privada redistribui o peso dos
  concursados (`indices-v7`; IVET `ivet-v1.9`). A média das privadas no
  Brasil foi de 3,88 a 4,85, e o teto voltou a 10.
- **Agrupamento:** o CSV usa o nome da base (`prop_sem_formacao_continuada`)
  e a tela mostra rótulos curtos.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Sem impacto relevante:** na escola
pública, os concursados e o índice não mudam.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
no ranking do município, as escolas da rede deixam de subir por causa de um
0 das privadas.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Impacto direto:** a escola privada
deixa de perder até 2 pontos na capacitação docente e de cair nos grupos de
baixa qualidade da docência por um dado que o Censo não pede a ela. Pesa a
favor numa próxima rodada.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), sem a ressalva na comparação entre
pública e privada. **Resolvido:** QT-01 e QT-02. Nenhum achado aberto da
trigésima quinta avaliação.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** o
ranking que mistura as redes deixa de favorecer a pública por construção.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** some a comparação "a
privada tem docência pior" que vinha só do 0 dos concursados.

## O que este ciclo ensinou

- Antes de usar uma variável do Censo em todas as redes, conferir no
  dicionário do INEP se ela é perguntada a todas. "Apenas para escola
  pública" vira 0 na privada sem nenhum aviso.
- Comentário de coluna que a tela usa como rótulo é texto de tela: a nota
  para quem lê o banco vai entre parênteses.
