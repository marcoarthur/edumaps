# Ciclo 2026-11-17: índice vazio, não 0, para escola sem registro

- **Período:** 2026-11-17.
- **História:** #467 (PR #468), achados RZ-01 e RZ-02 da
  [sétima avaliação da P4](../avaliacoes/2026-11-17-p4-indices-na-base.md).
- **Avaliação:** sem rodada nova; os vereditos ficam.
- **Engenharia:** nota técnica 219.

## Resumo

- A escola sem matrículas, docentes ou gestores registrados no Censo deixa
  de receber 0 no índice que depende desse registro e fica sem ele: vazio na
  base, fora do ranking daquele índice. São sobretudo centros de atendimento
  especializado e escolas sem turma regular, cerca de 2 mil no Brasil.
- A versão dos índices sobe para `indices-v3`, e a do IVET para `ivet-v1.5`.
- O dicionário da base deixa de apontar para uma coluna que não existe.

## P1 — Gestor escolar (diretora de escola municipal)

**Veredito:** adotaria (mantido). **Impacto pequeno:** a escola dela deixa
de ser comparada, no ranking do município, com centros de atendimento que
apareciam com 0. Para quem dirige um desses centros, o índice some em vez
de dizer "a pior formação docente da cidade".

## P2 — Secretaria municipal (secretário de educação)

**Veredito:** adotaria, em piloto numa rede (mantido). **Impacto pequeno:** a
média da rede deixa de ser puxada para baixo pelos centros de atendimento da
própria rede (164 municipais na BA e no ES).

## P3 — Rede privada (mantenedor)

**Veredito:** não adotaria (mantido). **Sem impacto na dor central** (#429).

## P4 — Academia (pesquisadora)

**Veredito:** adotaria (mantido). **Resolvido:** RZ-01 e RZ-02. O vazio dos
índices segue a regra da base, e a média municipal sai certa sem filtro
manual (Divino de São Lourenço: 7,91, antes 5,93). **Ficam** da sétima
avaliação: nenhum achado aberto.

## P5 — Órgãos de controle e conselhos

**Veredito:** não adotaria (registro; mantido). **Impacto pequeno:** uma
média municipal citada num parecer deixa de misturar ausência de dado com
nota baixa.

## P6 — Terceiro setor e jornalismo de dados

**Veredito:** adotaria (mantido). **Impacto direto:** a lista das "piores
escolas" num índice deixa de abrir com instituições de atendimento a
crianças com deficiência que só não tinham o registro, o tipo de erro que
vira matéria injusta.

## O que este ciclo ensinou

- O zero como valor-padrão escapa das regras escritas. A base dizia "vazio,
  nunca zero" desde a #154, mas o índice herdava o 0 de uma junção antiga.
  Só apareceu quando a pesquisadora fez uma média.
- Mudar um valor exige olhar quem guarda cópia dele. O ranking pré-calculado
  só fazia upsert e teria mantido o 0 antigo para sempre.
