# Fechamento de ciclo por público

Ao fim de cada ciclo de desenvolvimento, um arquivo aqui registra, **para cada
público do plano de negócios (P1 a P6)**, o que mudou no produto, o impacto
para quem usa ou paga, e como evoluiu o veredito da persona. É o progresso das
mudanças contado do lado do usuário. A nota técnica do ciclo (em
`docs/new_ideas/implementations_ideas/`) conta o mesmo do lado da engenharia.

## Como fechar um ciclo

1. **Quando:** junto da nota técnica, depois do último merge do ciclo.
2. **Arquivo:** `AAAA-MM-DD-<tema>.md` nesta pasta, com:
   - o período, os PRs e as issues do ciclo;
   - **uma seção por público (P1 a P6)**:
     - o que mudou para ele;
     - o impacto em linguagem de usuário;
     - o veredito antes e depois;
     - o que ficou pendente.
   - O público sem mudança percebida também aparece, com uma linha: "sem
     impacto neste ciclo" e o motivo.
3. **Base:** as avaliações do ciclo em [`../avaliacoes/`](../avaliacoes/). Se a
   persona não avaliou, o fechamento diz isso e não inventa veredito.
4. **Memória das personas:** cada arquivo de persona ganha uma linha em
   "Progresso por ciclo", com o link para o fechamento.
5. Fechamento de ciclo é **documentação**: vai direto ao `main`, sem PR.

## Ciclos

| Ciclo | Período | Tema | P1 | P2 | P3–P6 |
|---|---|---|---|---|---|
| [2026-11-12](2026-11-12-planos-de-gestao.md) | 2026-11-11 a 2026-11-12 | Planos de gestão (épico #368) | ⬆️ com ressalvas → adotaria | ➡️ com ressalvas (aguarda #375) | sem impacto direto |
| [2026-11-13](2026-11-13-visao-da-rede.md) | 2026-11-12 a 2026-11-13 | Visão da rede (#375) | ➡️ adotaria | ⬆️ com ressalvas → adotaria em piloto | sem impacto direto |
| [2026-11-13 (fluxo)](2026-11-13-fluxo-inep.md) | 2026-11-13 | Rendimento e distorção do INEP nas metas (#376) | ➡️ adotaria (sem nova avaliação) | ➡️ piloto (sem nova avaliação) | sem impacto direto |
| [2026-11-13 (embedding)](2026-11-13-embedding-diario.md) | 2026-11-13 | Escolas semelhantes do painel em dia e sem zero falso (#413) | ➡️ adotaria (sem nova avaliação) | sem impacto direto | sem impacto direto |
