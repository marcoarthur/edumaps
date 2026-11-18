# Ciclo 2026-11-18: IVET com o motivo certo e a versão citável

- **Período:** 2026-11-18.
- **História:** #489 (PR #490), achados RK-01 e RK-02 da
  [décima oitava avaliação da P4](../avaliacoes/2026-11-18-p4-ivet.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 230.

## Resumo

- Quando o IVET fica sem número, o painel da escola diz **quais blocos de
  território faltam** (acesso, saúde ou segurança) e mostra os blocos já
  medidos. Antes, dizia "não é publicável (amostra insuficiente ou dado
  sensível)" e escondia tudo; não havia regra de privacidade no cálculo.
- Os rótulos dos blocos D a G no painel estavam trocados (D aparecia como
  "Segurança", mas é saúde). Agora seguem o cálculo.
- A página **Fontes e metodologia** traz o "IVET do EduMaps", com a versão
  `ivet-v1.8` e o histórico das nove versões.
- A ajuda do IVET passa à versão atual. A régua de leitura (0,30 a 0,42) saiu,
  porque era de antes da escala logarítmica do bloco C; volta depois da
  medição da versão vigente no LXC.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** a escola sem o IVET
entende por que, e não lê "dado sensível" como problema da escola; os
blocos têm o nome certo.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:**
nas redes sem isócrona, o painel diz que falta o acesso, e não sigilo.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o IVET como variável de
contexto citável. **Resolvido:** RK-01 e RK-02. **Fica:** a régua da
`ivet-v1.8`, que depende da medição no LXC.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Sem impacto:** não usa o
IVET.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto pequeno:** a versão citável em
`/fontes` e o motivo certo evitam a leitura "o governo esconde o dado".

## O que este ciclo ensinou

- O aviso de privacidade veio com o primeiro card do IVET (#296), mas o
  cálculo nunca teve regra de privacidade. O texto da tela precisa sair da
  regra do código.
- Os rótulos trocados passaram por testes que só conferiam valores. Um teste
  agora amarra os nomes à ordem do cálculo.
