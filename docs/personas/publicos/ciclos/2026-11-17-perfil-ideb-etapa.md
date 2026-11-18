# Ciclo 2026-11-17: IDEB do perfil comparado na mesma etapa

- **Período:** 2026-11-17.
- **História:** #483 (PR #484), achados RN-01 e RN-02 da
  [décima quinta avaliação da P4](../avaliacoes/2026-11-17-p4-perfil-ideb-etapa.md).
- **Modo:** autônomo (delegação do developer até 7h de 18/11), com aviso
  pelo Telegram.
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 227.

## Resumo

- No perfil da escola, o IDEB e a nota do SAEB passam a ser comparados com
  o município, a rede, o Brasil e o grupo **na mesma etapa**. Antes, o
  "Brasil" misturava as etapas (5,33), e uma escola de ensino médio na
  média nacional aparecia 1 ponto abaixo.
- A escola com mais de uma etapa vê o IDEB de cada uma.
- O perfil analítico da rede mostra o IDEB e o SAEB por etapa.
- Com isso, o produto inteiro compara o IDEB dentro da etapa.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto direto:** o perfil é a tela
dela. Uma escola de anos finais deixa de aparecer abaixo do Brasil só por
causa da etapa, e a de anos iniciais deixa de parecer melhor do que é. A
escola de duas etapas vê as duas.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:** o
perfil da rede compara os anos iniciais da rede com os anos iniciais do
Brasil, e os finais com os finais.

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429);
as privadas quase não têm IDEB.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com o IDEB do perfil.
**Resolvido:** RN-01 e RN-02. **Ficam** da décima quinta avaliação: nenhum
achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto direto:** um
parecer que cite "a escola está X pontos abaixo do Brasil" passa a usar a
média da mesma etapa.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a matéria "as escolas
de ensino médio de Salvador estão abaixo da média nacional" sai com a
diferença certa (0,5 ponto, não 1,1).

## O que este ciclo ensinou

- O mesmo defeito apareceu em quatro telas (comparação, agrupamento e os dois
  perfis) porque cada uma escolhia a etapa à sua maneira. A regra "compare
  dentro da etapa" precisava ser do produto, não de cada consulta.
- Um rótulo honesto (#479) é um passo, mas não corrige a comparação: só
  mudou o número quando a média do Brasil passou a ser da mesma etapa.
