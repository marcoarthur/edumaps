# Catálogo de fontes de dados abertas — EduMaps

> **Issue**: #123 · **Escopo**: catálogo e priorização **antes** de qualquer
> pipeline (implementação vira issue própria).
> **Método**: cada fonte recebe uma ficha em [`fontes/`](fontes/) e uma linha na
> [matriz de priorização](#matriz-de-priorização) abaixo.

## Por que este catálogo existe

O EduMaps combina **Censo Escolar + OpenStreetMap + SIOPE** para responder ao
problema central: *onde a falta de acesso, a precariedade da infraestrutura e a
insuficiência de recursos se sobrepõem, e como priorizar investimentos para
reduzir desigualdades educacionais territoriais*.

Essa combinação já sustenta o **IVET — Índice de Vulnerabilidade Educacional
Territorial**, mas ele tem seis lacunas:

| # | Lacuna | Por que importa |
|---|--------|-----------------|
| 1 | **Saúde** | Condições de saúde da população escolar afetam frequência e aprendizagem. |
| 2 | **Segurança pública** | Violência no entorno escolar impacta evasão e desempenho. |
| 3 | **Conectividade** | Qualidade da internet na escola é fator crítico pós-pandemia. |
| 4 | **Investimentos planejados** | Obras do Novo PAC e Proinfância mudam o cenário futuro. |
| 5 | **Mobilidade em escala** | Matrizes origem-destino e tráfego revelam fluxos reais de acesso. |
| 6 | **Meio ambiente e clima** | Eventos extremos afetam frequência escolar e infraestrutura. |

## Método de priorização

Cada fonte é pontuada somando o peso dos critérios que ela **atende**:

| Critério | Peso |
|---|---|
| Endereça lacuna direta do IVET (1–6) | ⭐⭐⭐ |
| API/SDK oficial estável | ⭐⭐ |
| Granularidade compatível com escola ou município | ⭐⭐⭐ |
| Licença aberta e compatível com LGPD | ⭐⭐⭐ |
| Cobertura nacional | ⭐⭐ |
| Periodicidade compatível com o ciclo de gestão escolar | ⭐⭐ |
| Já possui pacote R ou ferramenta de acesso pronta | ⭐ |
| Complementa diretamente Censo / OSM / SIOPE | ⭐⭐⭐ |

**Faixas**: `[alta]` ≥ 6 pontos · `[média]` 3–5 pontos · `[baixa]` ≤ 2 pontos.

**Rebaixes** (Levam a `[baixa]` independentemente da soma):

- exige scraping frágil (sem API/download estável);
- granularidade apenas estadual/nacional sem desagregação municipal/escolar;
- licença restritiva ou incompatível com uso público;
- risco LGPD elevado sem mitigação clara.

> Fontes de **agregadores/ferramentas de acesso** (lote H) são calibradas
> diferente: "endereça lacuna direta" pesa menos (não são indicadores), mas
> "pacote R / API estável" pesa mais. A justificativa de cada ficha registra
> essa calibragem.

## Regras de curadoria aplicadas

1. **Nenhuma fonte entra sem licença e risco LGPD verificados** em fonte
   oficial. Campo não confirmado aparece como `não verificado` e derruba a
   prioridade.
2. **Granularidade municipal é o alvo mínimo útil**; granularidade escolar
   (quando existe) é o ideal. A ordem de decisão é: escolar > municipal >
   estadual (estadual só como contexto, nunca como indicador).
3. **LGPD**: só entram dados **agregados ou desidentificados**. Dados
   individuais de saúde, segurança ou deslocamento — mesmo públicos — são
   rebaixados por-etiqueta.
4. **Rastro obrigatório**: `Z:<itemID>` quando houver item Zotero
   (`docs/personas/tech-lead.md`), ou o caminho em `docs/`, ou a URL canônica.

## Domínios catalogados

| Domínio | Fichas | Foco principal |
|---|---|---|
| [Educação](fontes/educacao.md) | Censo/IDEB/ENEM/SAEB, SDG 4, IDHM, PNE | desempenho e contexto educacional |
| [Socioeconômico](fontes/socioeconomico.md) | IBGE, BrasilAPI, BCB, Ipeadata, World Bank | demografia e economia municipal |
| [Conectividade e obras](fontes/conectividade-obras.md) | Medidor Educação Conectada, Gesac, Novo PAC, PNCT | lacunas 3 e 4 |
| [Mobilidade](fontes/mobilidade.md) | Matriz OD, DNIT, ANTT, SENATRAN, GTFS | lacuna 5 |
| [Saúde](fontes/saude.md) | DATASUS, VIGITEL/PNS, CIDACS, CNES | lacuna 1 |
| [Segurança](fontes/seguranca.md) | SINESP/Dados.MJ, Crime Brasil, BrazilCrime, SNSP | lacuna 2 |
| [Meio ambiente e clima](fontes/meio-ambiente.md) | INMET, MapBiomas, IBAMA, áreas de risco | lacuna 6 |
| [Agregadores](fontes/agregadores.md) | Base dos Dados, BrasilAPI, MCP-Brasil, pacotes R | acesso às fontes acima |

## Matriz de priorização

<!-- MATRIZ: preenchida na Fase 2 da issue #123 -->

_(a preencher)_

## Plano de integração faseado

<!-- PLANO: preenchido na Fase 3 da issue #123 -->

_(a preencher)_