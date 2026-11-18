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
| [2026-11-16 (destaque)](2026-11-16-destaque-municipio.md) | 2026-11-16 | Ranking de redes: destacar um município (#449) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RG-03 resolvido, nenhum achado da P4 aberto |
| [2026-11-16 (infraestrutura)](2026-11-16-infra-inexistente.md) | 2026-11-16 | Base de análise: itens inexistentes de infraestrutura e coordenadas (#452) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; VJ-01 e VJ-04 resolvidos |
| [2026-11-16 (variação)](2026-11-16-variacao-csv.md) | 2026-11-16 | Ranking de redes: posição pela variação no CSV e motivo da variação vazia (#453) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; VJ-02 e VJ-03 resolvidos |
| [2026-11-16 (infraestrutura básica)](2026-11-16-infraestrutura-basica.md) | 2026-11-16 | Ranking de escolas: infraestrutura básica e método dos índices (#457) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; VK-01 resolvido; #459 aberta (diversidade) |
| [2026-11-16 (diversidade)](2026-11-16-diversidade-especial.md) | 2026-11-16 | Índice de diversidade discente com a educação especial em classe comum; IVET ivet-v1.4 (#459) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; índice corrigido |
| [2026-11-16 (etapas)](2026-11-16-etapas-cobertura.md) | 2026-11-16 | Base de análise: etapas oferecidas e aviso de cobertura do IDEB (#461) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RX-02 resolvido |
| [2026-11-16 (versão dos índices)](2026-11-16-versao-indices.md) | 2026-11-16 | Versão citável dos índices do EduMaps (indices-v2) em /fontes, no ranking de escolas e no CSV (#462) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RX-01 resolvido |
| [2026-11-16 (índices na base)](2026-11-16-indices-na-base.md) | 2026-11-16 | Base de análise: bloco "Índices do EduMaps" com a versão; versão no nome do CSV do ranking de escolas (#465) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RY-01 e RY-02 resolvidos |
| [2026-11-17 (índices sem registro)](2026-11-17-indices-sem-registro.md) | 2026-11-17 | Índice vazio, não 0, para escola sem registro de matrículas, docentes ou gestores (indices-v3, ivet-v1.5) (#467) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RZ-01 e RZ-02 resolvidos |
| [2026-11-17 (partes da capacitação)](2026-11-17-partes-capacitacao.md) | 2026-11-17 | Base de análise: as quatro partes do índice de capacitação docente e os pesos ditos normativos (#469) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RW-01 e RW-02 resolvidos |
| [2026-11-17 (cor/raça declarada)](2026-11-17-diversidade-cor-declarada.md) | 2026-11-17 | Índice de diversidade: cor/raça sobre as matrículas com cor declarada e partes na base (indices-v4, ivet-v1.6) (#471) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RT-01 a RT-03 resolvidos |
| [2026-11-17 (lotação por turno)](2026-11-17-atendimento-por-turno.md) | 2026-11-17 | Índice de atendimento: alunos por sala e por turno e partes na base (indices-v5, ivet-v1.7) (#473) | ➡️ adotaria (impacto direto) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RS-01 e RS-02 resolvidos |
| [2026-11-17 (capacidade gestora)](2026-11-17-gestora-partes.md) | 2026-11-17 | Índice de capacidade gestora: partes vazias sem matrícula e nas privadas, peso redistribuído, partes na base (indices-v6, ivet-v1.8) (#475) | ➡️ adotaria (sem impacto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RR-01 e RR-02 resolvidos |
| [2026-11-17 (ajuda refaz os índices)](2026-11-17-ajuda-refaz-indices.md) | 2026-11-17 | Base de análise: bloco R testado que refaz os seis índices; partes da infraestrutura e da sustentabilidade (#477) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RQ-01 e RQ-02 resolvidos |
| [2026-11-17 (comparação de redes)](2026-11-17-comparacao-redes-ativas.md) | 2026-11-17 | Comparação de redes só com escolas em funcionamento; escolas com dado no perfil e na linha do IDEB; ajuda nova (#479) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RP-01 a RP-04 resolvidos |
| [2026-11-17 (agrupamento por etapa)](2026-11-17-agrupamento-etapa.md) | 2026-11-17 | Agrupamento por desempenho numa etapa; infraestrutura sem contar fossa como falta (#481) | ➡️ adotaria (impacto pequeno) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RO-01 e RO-02 resolvidos |
| [2026-11-17 (IDEB do perfil por etapa)](2026-11-17-perfil-ideb-etapa.md) | 2026-11-17 | Perfil da escola e da rede: IDEB e SAEB comparados na mesma etapa; IDEB de cada etapa da escola (#483) | ➡️ adotaria (impacto direto) | ➡️ adotaria em piloto (impacto direto) | vereditos mantidos; RN-01 e RN-02 resolvidos |
| [2026-11-17 (evolução do SAEB)](2026-11-17-evolucao-saeb-etapa.md) | 2026-11-17 | Evolução da escola: SAEB por etapa; sem variação com uma edição (#485) | ➡️ adotaria (impacto direto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RM-01 e RM-02 resolvidos |
| [2026-11-18 (escolas semelhantes)](2026-11-18-semelhantes-distancia-notas.md) | 2026-11-18 | Escolas semelhantes do painel pela distância entre as notas; distância e notas no cartão; ajuda com os três critérios (#487) | ➡️ adotaria (impacto direto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RL-01 e RL-02 resolvidos |
| [2026-11-18 (IVET: motivo e versão)](2026-11-18-ivet-motivo-versao.md) | 2026-11-18 | IVET sem número diz os blocos que faltam e mostra os medidos; rótulos D–G corrigidos; IVET em `/fontes` com versão e histórico; ajuda na `ivet-v1.8` (#489) | ➡️ adotaria (impacto direto) | ➡️ adotaria em piloto (impacto pequeno) | vereditos mantidos; RK-01 e RK-02 resolvidos |
