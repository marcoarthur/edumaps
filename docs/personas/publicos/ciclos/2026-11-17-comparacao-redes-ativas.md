# Ciclo 2026-11-17: comparação de redes só com escolas em funcionamento

- **Período:** 2026-11-17.
- **História:** #479 (PR #480), achados RP-01 a RP-04 da
  [décima terceira avaliação da P4](../avaliacoes/2026-11-17-p4-comparar-redes.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 225.

## Resumo

- A comparação das redes do município deixa de contar escolas paralisadas e
  extintas. No Brasil, o total cai de 214.192 para 180.540, igual ao resto
  do produto.
- O perfil analítico diz em quantas escolas cada média se apoia, e de que
  edição e etapa é o IDEB.
- A linha do IDEB mostra, em cada ponto, quantas escolas têm nota.
- A ajuda da tela foi reescrita.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a rede do município
dela aparece com o número de escolas que ela conhece, e não com as que
fecharam há anos.

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto direto:**
"alunos por escola" da rede municipal deixa de ser dividido por escolas
fechadas. Em municípios que nuclearam escolas rurais, o número mudava a
leitura (Formoso, MG: 56 escolas na tela, 4 funcionando).

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).
A rede privada também perde as escolas fechadas da contagem.

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido), agora também com a comparação de redes.
**Resolvido:** RP-01 a RP-04. Os números da comparação batem com a base, e
o perfil diz em quantas escolas cada média se apoia. **Ficam** da décima
terceira avaliação: nenhum achado aberto. O IDEB por etapa no perfil é uma
melhoria possível, não um achado.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto direto:** um
parecer sobre a rede física do município não conta mais escolas extintas.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a matéria "a rede tem
X escolas" sai com o número das que funcionam.

## O que este ciclo ensinou

- A mesma pergunta ("quantas escolas?") tinha três respostas no produto. A
  regra "só em funcionamento" estava em cada tela, escrita à mão, e uma MV
  antiga ficou de fora.
- Ler o código de um número muda o achado: o IDEB do perfil não era a
  "média entre etapas" que o comentário da coluna dizia.
