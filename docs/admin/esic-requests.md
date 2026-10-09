# Registro de Pedidos e-SIC — Lei 12.527/2011

> **Issue #132** — Três e-SICs de maior retorno (INEP, MEC/NIC.br, FNDE) + Secretarias municipais (transporte escolar)

---

## 1. INEP — Licença e Dicionário do Censo Escolar/IDEB/ENEM

**Protocolo**: `________________`  
**Data de envio**: `________________`  
**Órgão**: INEP (Instituto Nacional de Estudos e Pesquisas Educacionais Anísio Teixeira)  
**Canal**: e-SIC federal (https://falabr.cgu.gov.br)

### Perguntas protocoladas

1. **Licença dos microdados**: Qual a licença de uso aplicável aos microdados do **Censo Escolar** (1995–2025), do **IDEB** e do **ENEM**? Solicita-se a fonte jurídica da licença (ato normativo, portaria, etc.), não apenas o rodapé do portal.

2. **Dicionário de dados do Censo Escolar**: Solicita-se o dicionário completo das tabelas do Censo Escolar (variáveis, códigos de classificação, significados), incluindo o **histórico de mudanças de códigos entre edições** (ex.: código 3 em 2010 vs código 5 em 2023 para mesma categoria).

3. **Chave de identificação da escola**: Existe chave estável de identificação da escola entre edições do Censo (além de CO_ENTIDADE)? Se sim, qual?

4. **Tabela de URLs dos microdados**: O microdado do Censo Escolar 2025 tem URL com underscore extra (`microdados_censo_escolar_2025_**.zip`). Solicita-se a tabela oficial de URLs dos microdados por ano, ou o dicionário de arquivos oficial, para evitar 404 por interpolação de ano.

**Desbloqueia**: 4 fichas de `[média]` → `[alta]` no catálogo (educação). Critério nº 9 (licença verificada) deixa de bloquear.

---

## 2. MEC / NIC.br — Medidor Educação Conectada (CSV + Dicionário + Licença)

**Protocolo**: `________________`  
**Data de envio**: `________________`  
**Órgão**: MEC (Ministério da Educação) / NIC.br (Núcleo de Informação e Coordenação do Ponto BR)  
**Canal**: e-SIC federal (https://falabr.cgu.gov.br) — endereçar ao MEC com cópia ao NIC.br

### Perguntas protocoladas

1. **Formato CSV**: O Medidor Educação Conectada disponibiliza os dados em **formato CSV** (não apenas app Shiny)? Solicita-se periodicidade mensal ou trimestral, agregados por município e por escola.

2. **Dicionário de dados**: Solicita-se o dicionário completo (variáveis, códigos, unidade de medida, metodologia de agregação).

3. **Licença de uso**: Qual a licença de uso declarada para os dados do Medidor?

4. **Metodologia de medição e cobertura**: Registro das metodologias de medição e da cobertura temporal (já publicado na aba "Dados" do portal — confirmar e solicitar versão oficial).

**Desbloqueia**: Lacuna 3 (conectividade) — a única das 6 lacunas sem solução verificada. O portal é a **única medição real de banda por escola** no país, mas não tem API nem licença pública.

---

## 3. FNDE — PNATE, Novo PAC/Proinfância, PDDE

**Protocolo**: `________________`  
**Data de envio**: `________________`  
**Órgão**: FNDE (Fundo Nacional de Desenvolvimento da Educação)  
**Canal**: e-SIC federal (https://falabr.cgu.gov.br)

### Perguntas protocoladas

1. **URLs de download estáveis**: URLs de download estáveis e dicionário de dados do **PNATE**, do **Novo PAC/Proinfância** e do **PDDE**, com periodicidade mensal.

2. **Licença declarada**: Qual a licença de uso declarada para cada base?

3. **Chave de identificação**: Chave de identificação do município/obra (código IBGE, código FNDE, etc.).

**Desbloqueia**: 3 fontes rebaixadas por **acesso** (não por valor) — PNATE (melhor especificação do lote: mensal, conteúdo declarado), Novo PAC/Proinfância, PDDE. O portal FNDE é SPA sem SSR e CKAN federal exige credencial (401).

---

## 4. Secretarias Municipais de Educação — Transporte Escolar por Unidade/Turno

**Protocolo(s)**: `________________` (um por secretaria)  
**Data de envio**: `________________`  
**Órgãos**: Secretarias Municipais de Educação (prioridade: capitais e municípios > 100k hab.)  
**Canal**: e-SIC municipal / SIC físico / portal transparência municipal

### Perguntas protocoladas

1. **Dados de transporte escolar**: A secretaria possui dados de **vagas de transporte escolar por unidade escolar e por turno** (manhã/tarde/integral)?

2. **Formato e periodicidade**: Em que formato (CSV, planilha) e periodicidade (mensal, semestral) podem ser disponibilizados?

3. **Chave de escola**: O dado possui **código INEP (CO_ENTIDADE)** da escola ou código próprio mapeável?

**Contexto**: O catálogo verificou que **transporte escolar com chave de escola existe em apenas um município verificado** (Recife). O gargalo da lacuna 5 **não é coleta**, é **publicação** — o dado está nos DETRANs e nas secretarias e quase nunca é aberto.

---

## Vínculo com os jobs de ingestão (#172)

Cada e-SIC pendente bloqueia um job que hoje **falha explicitamente** (não
devolve sucesso silencioso): `run()` morre com o motivo + este tracker. O
comentário das tabelas-fonte correspondentes também declara "NÃO CARREGADA" e
o porquê.

| e-SIC | Job (`backend/lib/EduMaps/Ingestion/Job/`) | Tabelas alvo | Estado do job |
|-------|--------------------------------------------|--------------|---------------|
| INEP (Censo/IDEB/ENEM) | `INEP.pm` | `censo2022_setor`, `malha_setor_censitario`, microdados Censo/IDEB/ENEM | ⛔ falha explícita (aguardando e-SIC) |
| MEC/NIC.br (Medidor) | `MedidorConectada.pm` | Medidor Educação Conectada | ⛔ falha explícita |
| FNDE (PNATE/PAC/PDDE) | `FNDE.pm` | obras/programas FNDE | ⛔ falha explícita |
| Secretarias (transporte) | `SecretariasMunicipais.pm` | transporte escolar por unidade/turno | ⛔ falha explícita |

> **CensoEscolar removido em 2026-10-09 (#172)**: era caminho morto —
> `clean.censo_escolas` (214k) e `clean.censo_docentes` (178k) já vêm de um
> caminho próprio. O job `INEP` é o único dono da carga quando o e-SIC
> responder.
>
> `inventario_fornecedores`/`inventario_anexos` **não** são alvos do FNDE:
> são tabelas de aplicação do módulo gestor (a associação na #172 estava
> errada — corrigida nesta passada).

### Decisões registradas fora do e-SIC (2026-10-09)

> **INMET — decisão C (#171)**: a API do INMET foi **retirada** (não é URL
> errada nem licença). `dados.inmet.gov.br` não resolve, e
> `apitempo.inmet.gov.br/bdmep/estacao` / `/alertas/cap12` → **404**; o
> restante host é interface web/feed RSS, que não alimenta as tabelas
> pretendidas (séries por estação + alertas CAP). Decisão **C**: sem loader
> para endpoints mortos — `inmet_bdmep`/`inmet_alerta` declaradas **NÃO
> CONSTRUÍDAS** no schema (change `comments_inmet_mapbiomas_pendente`) e fora
> do objetivo da #156. O job `INMET.pm` falha alto com o motivo. Revisitar se
> o INMET publicar API/feed oficial.
>
> **MapBiomas — loader real aguarda e-SIC (#170)**: o job antigo baixava
> `BR_Municipios_2024.gpkg` (malha municipal do **IBGE**) para uma tabela de
> uso do solo e descarregava uma **página web** do MapBiomas como se fosse
> GPKG — geometria administrativa não é cobertura de uso do solo (defeito da
> #154). O job agora falha alto e `mapbiomas_cobertura` declara **NÃO
> CONSTRUÍDA**; o loader real (URL verificado + scripts R + areolização)
> aguarda o e-SIC para o **token** da API do MapBiomas. Issue #170 segue
> aberta.

---

## Registro de Respostas

| e-SIC | Protocolo | Data Resposta | Status | Licença Confirmada | Ficha Atualizada |
|-------|-----------|---------------|--------|-------------------|------------------|
| INEP | | | ⏳ Pendente | | |
| MEC/NIC.br | | | ⏳ Pendente | | |
| FNDE | | | ⏳ Pendente | | |
| Secretarias (transporte) | | | ⏳ Pendente | | |

---

## Atualização de Fichas (após resposta)

| Fonte | Arquivo Ficha | Status | Prioridade Reavaliada |
|-------|---------------|--------|----------------------|
| INEP (Censo/IDEB/ENEM) | `docs/analises/fontes/educacao.md` | ⏳ | `[alta]` se licença confirmada |
| MEC/NIC.br (Medidor) | `docs/analises/fontes/conectividade-obras.md` | ⏳ | `[alta]` se licença + CSV |
| FNDE (PNATE/PAC/PDDE) | `docs/analises/fontes/educacao.md` / `conectividade-obras.md` | ⏳ | `[alta]` se licença + acesso |
| Secretarias (transporte) | `docs/analises/fontes/mobilidade.md` | ⏳ | `[alta]` se dados existem |

---

## Próximos Passos

1. [ ] Protocolar os 4 e-SICs (INEP, MEC/NIC.br, FNDE, Secretarias)
2. [ ] Registrar números de protocolo neste documento
3. [ ] Acompanhar prazos (20 dias + 10 dias prorrogáveis)
4. [ ] Ao receber resposta: atualizar fichas, reavaliar prioridade, registrar em `memory.md`
5. [ ] Resposta negativa também registrada: "não é dado aberto" fecha a ficha