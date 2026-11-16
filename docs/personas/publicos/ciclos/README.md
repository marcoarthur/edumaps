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
| [2026-11-14 (duplo envio)](2026-11-14-duplo-envio.md) | 2026-11-14 | Botão de salvar sem réplica (PR #415) | ➡️ adotaria (sem nova avaliação) | ➡️ adotaria em piloto (sem nova avaliação) | sem impacto direto |
| [2026-11-14 (servidor)](2026-11-14-envio-sem-duplicidade.md) | 2026-11-14 | Envio sem duplicidade no servidor (#416) | ➡️ adotaria (sem nova avaliação) | ➡️ adotaria em piloto (sem nova avaliação) | sem impacto direto |
| [2026-11-14 (build)](2026-11-14-build-e-testes.md) | 2026-11-14 | Suíte em paralelo e backend sem o PDL (#418, #419) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (sem impacto) | sem impacto direto |
| [2026-11-15](2026-11-15-analises-legiveis.md) | 2026-11-14 a 2026-11-15 | Análises públicas legíveis e ausência honesta (#421, #422, #423) | ➡️ adotaria (impacto indireto) | ➡️ adotaria em piloto (impacto indireto) | vereditos mantidos (sem reavaliação); AN-01, -02, -03, -04 e -12 resolvidos |
| [2026-11-15 (busca)](2026-11-15-busca-e-linguagem.md) | 2026-11-15 | Busca por município com UF, menus em PT-BR e menos jargão (#431) | ➡️ adotaria (impacto indireto) | ➡️ adotaria em piloto (impacto indireto) | vereditos mantidos; AN-06 e AN-07 resolvidos |
| [2026-11-15 (agrupamento)](2026-11-15-agrupamento-reprodutivel.md) | 2026-11-15 | Agrupamento com universo, link e CSV (#427) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto indireto) | vereditos mantidos; AN-05 e AN-09 resolvidos; P4 a reavaliar após #428 |
| [2026-11-15 (fontes)](2026-11-15-fontes-e-metodologia.md) | 2026-11-15 | Fonte, ano e versão dos dados na tela (#428) | ➡️ adotaria (impacto indireto) | ➡️ adotaria em piloto (impacto indireto) | vereditos mantidos; AN-08 resolvido; P4 a reavaliar |
| [2026-11-15 (ranking)](2026-11-15-ranking-de-redes.md) | 2026-11-15 | Ranking de redes municipais e de escolas (#430) | ➡️ adotaria (impacto indireto) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; AN-11 resolvido; P4 e P6 a reavaliar |
| [2026-11-15 (atípico)](2026-11-15-ranking-atipico.md) | 2026-11-15 | Ranking: salto atípico, mínimo e ordem crescente (#437) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto indireto) | vereditos mantidos; RV-01 e RV-04 resolvidos |
| [2026-11-16 (CSV)](2026-11-16-csv-versao.md) | 2026-11-16 | Agrupamento: versão dos dados no CSV exportado (#438) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RV-03 resolvido |
| [2026-11-16 (base)](2026-11-16-base-analise.md) | 2026-11-16 | Porte no ranking de redes e base de análise por escola (#439) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RV-02 e RV-05 resolvidos, nenhum achado aberto |
| [2026-11-16 (avisos)](2026-11-16-avisos-base.md) | 2026-11-16 | Base de análise: avisos de anos, do link e da docência (#444) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; BA-01, BA-03 e BA-04 resolvidos |
| [2026-11-16 (região)](2026-11-16-ranking-regiao.md) | 2026-11-16 | Ranking de redes: recorte por região (#445) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; BA-02 resolvido no ranking, base por região na assinatura |
| [2026-11-16 (região na base)](2026-11-16-regiao-base-csv.md) | 2026-11-16 | Base de análise com a região e CSVs do ranking com o recorte (#448) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RG-01 e RG-02 resolvidos |
