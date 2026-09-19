# EduMaps — O setor educacional brasileiro como mercado de dados

> Documento de apresentação para investidores e gestores de redes escolares
> privadas interessados em **data analytics aplicado à educação**.
> O objetivo é apresentar o setor, o ativo de dados da plataforma e as
> possibilidades de monetização. Valores de receita são **exemplos
> ilustrativos** para orientação de discussão, não projeções formais.

---

## Resumo executivo

O Brasil concentra **46 milhões de matrículas** na educação básica e movimenta
cerca de **R$ 370 bilhões/ano** em financiamento público (Fundeb 2026). O dado
educacional brasileiro é **abundante, público e de alta frequência** (Censo
Escolar anual, IDEB, Siope/FNDE, INSE, IBGE) — mas quase **não existe oferta
de analytics que transforme esse capital em decisão** para gestores públicos e
redes privadas.

O **EduMaps** é uma plataforma que:
1. **Consolida** as fontes públicas em uma base integrada (escolas, rede,
   indicadores, geografia, financiamento);
2. **Analisa** com modelos de dados (indicadores, clusters, similaridade,
   séries históricas);
3. **Entrega** painéis comparativos por escola/município/estado e ferramenta de
   escuta da comunidade (pesquisas).

Proposta para o investidor: **capital de dados público → produtos de análise
com margem de SaaS**, servindo prefeituras, redes privadas e órgãos de
educação estadual e federal.

---

## 1. O setor em contexto

| Número | Valor | Fonte |
|--------|-------|-------|
| Matrículas na educação básica (2025) | **46,0 milhões** | Censo Escolar 2025 (INEP) |
| Escolas de educação básica (2024) | **179,3 mil** | Censo Escolar 2024 (INEP) |
| Matrículas da rede privada (2024) | **~20%** (~9,5 milhões) | Censo Escolar 2024 (INEP) |
| Crescimento da rede privada (2023→2024) | **+1%** (rede pública caiu) | Censo Escolar 2024 (INEP) |
| Fundeb — financiamento público (2026) | **~R$ 370 bilhões** | FNDE, Portaria Interministerial MEC/MF 14/2025 |
| Complementação da União (2026) | **~R$ 69 bilhões** | FNDE |
| Queda de matrículas em 1 ano (2024→2025) | **~1 milhão** | Censo Escolar 2025 (INEP) |

Leituras de mercado:

- **Mercado público gigante e subgerido.** R$ 370 bilhões/ano com regra de
  aplicação (70% folha / 30% manutenção) e pressão crescente por resultado
  (VAAR, metas). Quem demonstra evidência ganha orçamento — o analytics é o
  instrumento da discussão.
- **Rede privada cresce enquanto a pública encolhe.** Em tempos de queda
  demográfica de matrículas, cada escola privada compete por aluno. Dados de
  mercado e benchmark de oferta são insumo direto de **captação, retenção e
  precificação**.
- **O dado é público e subutilizado.** Não há custo de aquisição de dados; o
  ativo está em **cruzar, tratar e modelar**. Barreira de entrada é
  técnica (dados federados + modelos), não de licenciamento (diferente de
  países onde o dado educacional é proprietário).
- **Ansiedade de compliance cria orçamento B2G.** Ciclo eleitoral + exigência
  de metas (IDEB, VAAR) + fiscalização de órgãos de controle pressionam
  prefeituras a comprar "sistemas de evidência". É janela recorrente e
  previsível.

---

## 2. O capital de dados da plataforma

O ativo é o **mapeamento integrado da educação básica brasileira**:

| Camada | Conteúdo | Fonte |
|--------|----------|-------|
| Escolas | cadastro, rede, etapas, localização (geocoding) | Censo Escolar |
| Alunos e matrículas | série histórica por escola/etapa/rede | Censo Escolar |
| Docentes | capacidade, formação, vínculo | Censo Escolar |
| Qualidade | nota e histórico do IDEB, metas | INEP/SAEB |
| Socioeconômico | INSE (perfil do alunado) | INEP |
| Financiamento | Fundeb, transferências, despesas | FNDE/Siope |
| Território | municípios, PIB, população | IBGE |
| Entorno | serviços, transporte, uso do solo | OpenStreetMap |

**Dados transacionais próprios**: gestões criadas por gestores, pesquisas
públicas de escuta da comunidade e respostas anônimas — uma camada de
**engajamento em tempo real** que as fontes públicas não oferecem.

**Modelos proprietários** (`analysis/edumapsr`): indicadores consolidados,
agrupamento de escolas (clusters), similaridade escola-escola e
município-município, e séries de desempenho. Parte do diferencial está em
**medir entre pares similares**, não contra a média nacional.

---

## 3. O produto

- **Mapa interativo**: navegação territorial da rede (escola → município →
  estado).
- **Painel da escola**: indicadores, IDEB + histórico, comparativo
  município/estado.
- **Benchmark por similaridade**: encontrar escolas/municípios pares.
- **Pesquisas do gestor**: criação de questionários com link público
  (`/p/<id>`) e agregação de respostas em gráficos.
- **Acesso por papel**: gestor da escola, rede/secretaria, e gestão de
  administradores.

---

## 4. Segmentos-alvo e caso de valor

| Segmento | Caso de valor | Oferta |
|----------|---------------|--------|
| **Prefeituras / secretarias municipais** | Governar com evidência: priorizar escolas, justificar investimentos, acompanhar metas e o uso do Fundeb; **prestar contas a conselhos e órgãos de controle** | Licenciamento anual + implantação + capacitação |
| **Redes escolares privadas** | Análise de mercado local (oferta, demanda, concorrentes), benchmark de captação/retenção, apoio a precificação e expansão | SaaS de analytics por escola/ano |
| **Órgãos estaduais e federais (MEC, INEP, FNDE)** | Painéis de política pública, avaliação de programas, estudos e relatórios | Projetos e licenciamento institucional |
| **Terceiro setor e academia** | Pesquisa aplicada (economia da educação), monitoramento de redes | Assinatura de dados + API |

---

## 5. Modelos de receita

> Faixas **ilustrativas** para orientar discussão de preço, sujeitas a escopo,
> porte e implantação. Não são projeções da empresa.

| Produto | Unidade | Faixa ilustrativa | Observação |
|---------|---------|-------------------|------------|
| SaaS p/ redes privadas | R$/escola/ano | **1.200 – 4.800** | meia-dúzia de painéis: mercado, benchmark, retenção |
| Licença rede municipal | R$/município/ano | **30.000 – 120.000** | conforme porte da rede + número de acessos |
| Projeto estadual/federal | R$/projeto | **200.000 – 500.000** | painéis customizados + capacitação |
| Assinatura de dados (API) | R$/ano | **20.000 – 80.000** | pesquisa e terceiro setor |
| Implantação / capacitação | % do contrato | **15 – 30%** no 1º ano | B2G: treinamento, suporte, coleta de requisitos |

Dois desenhos naturais de contrato recorrente:

1. **B2G (prefeituras/estados)**: licença anual com renovação atrelada a
   metas/uso — gera receita recorrente e base instalada para expansão.
2. **B2B (redes privadas)**: SaaS anual por escola, com auto-serviço —
   escalabilidade de margem alta, tempo curto de contrato, renovação por
   valor percebido trimestral.

---

## 6. Economia da unidade

- **Custo de dados**: ≈ zero (fontes públicas abertas; há custo de
  processamento e armazenamento).
- **Margem bruta SaaS**: típica de **70–80%** (borda: produtos B2G com
  implantação caem para **50–65%**, compensados por ticket e recorrência).
- **Principais custos**: engenharia de dados, modelagem, suporte/implantação,
  vendas B2G (ciclo de 6–18 meses).
- **Driver de margem**: padronizar o onboarding de municípios
  (dados + implantação) para que o custo marginal por ente caia a cada
  contrato.

---

## 7. Riscos e mitigação

| Risco | Mitigação |
|-------|-----------|
| **LGPD / privacidade** | Uso exclusivo de dados públicos agregados; pesquisas anônimas; DPO e política de dados desde o início |
| **Dependência da cadência dos dados públicos** (INEP/FNDE) | Buffer de modelagem própria (cluster, similaridade) que agrega valor independente da atualização anual |
| **Ciclo eleitoral / orçamento** | Venda B2G é cíclica → compensar com receita B2B (SaaS privado) atemporal e assinaturas de pesquisa |
| **Concorrência** (QEdu, plataformas de SME, dados.gov.br) | Diferencial em **analytics de pares + dados transacionais + financiamento**, não em re-exibir o Censo |
| **Prazo de venda B2G** | Pilotos curtos por edital de inovação/lab de governo; entrada por prefeituras de médio porte (decisão rápida) |
| **Demografia declinante** | É o próprio driver de demanda: retenção de matrícula vira o problema que as redes privadas pagam para resolver |

---

## 8. Go-to-market

**Fase 1 — Prova (6 meses).** 2–3 prefeituras-piloto em co-design (valor:
governança + prestação de contas). Custo baixo, aprendizado de produto e
histórico de caso de uso.

**Fase 2 — Receita B2B (meses 6–18).** SaaS para redes privadas (churn baixo,
caso de valor imediato de captação/mercado) e disponibilização da camada de
pesquisas do gestor como produto pago de escuta.

**Fase 3 — Escala (anos 2–3).** Pacote B2G padronizado (licença + implantação)
para prefeituras; projetos estaduais/federais como vitrine; API de dados como
segundo produto.

**Fase 4 — Plataforma.** Academia + terceiro setor + desenvolvedores; dados
como serviço com faturamento predizível.

---

## 9. O que o aporte habilita

1. **Time de engenharia de dados e modelagem** (análise R + rotinas de
   atualização e qualidade).
2. **Time de implementação/sucesso do cliente** para o ciclo B2G.
3. **Compliance e LGPD** (política, DPO, acordos de ente).
4. **Produto para não-técnicos**: simplificar painéis e pesquisa para o
   gestor de escola (a persona que hoje não consome dados).
5. **Comercial B2B**: vendas diretas às redes privadas e parcerias com
   associações de escolas.

---

## Fontes

- INEP — Censo Escolar da Educação Básica 2024 (Resumo Técnico): <https://download.inep.gov.br/publicacoes/institucionais/estatisticas_e_indicadores/resumo_tecnico_censo_escolar_2024.pdf>
- INEP/MEC — Contextualização dos resultados do Censo Escolar 2024: <https://www.gov.br/inep/pt-br/centrais-de-conteudo/noticias/censo-escolar/mec-e-inep-contextualizam-resultados-do-censo-escolar-2024>
- INEP — Censo Escolar 2025 (46,0 milhões de matrículas): <https://censobasico.inep.gov.br/>
- FNDE — Fundeb 2026 (estimativas, Portaria Interministerial MEC/MF nº 14/2025): <https://www.gov.br/fnde/pt-br/acesso-a-informacao/acoes-e-programas/financiamento/fundeb/legislacao/2025>
- Senado Federal — Novo Fundeb (regras e percentuais da União): <https://www12.senado.leg.br/noticias/materias/2020/08/25/novo-fundeb-sera-maior-e-tera-carater-permanente>