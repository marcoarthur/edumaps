# Nota técnica 115 — Assistente de Relatório, Fase 2: aprofundamento (PR #221)

## Resumo

Quatro temas novos no Assistente de Relatório (#219, PR #221, merge
`0184bf2`): **IDEB escola a escola** (município), **Infraestrutura e IDEB**
(regressão por UF), **Histórico da escola** e **Escolas parecidas**. O contrato
do relatório ganhou extensões retrocompatíveis. A integração revelou problemas
de ambiente (pilha do R) e de cache que valem para o pacote inteiro.
Antecedente: nota 114 (Fases 0 e 1).

## Decisões de design

- **Regressão com especificação fixa** (developer). O desfecho é o IDEB 2023
  da etapa; os preditores são `in_biblioteca`, `in_internet`,
  `in_laboratorio_informatica`, `docentes` e `matriculas`; o corte é por
  `localizacao`; o modelo é linear. O gestor escolhe só UF, etapa e rede.
  - **Só redes públicas:** com todas as redes, SP tem 30.817 escolas ativas,
    acima do teto absoluto do eduBR (30.000).
  - `max_amostra` subiu para 30.000; um recorte acima do teto dá 400 pedindo
    uma rede.
- **Leitura simplificada + técnico recolhido** (developer). A seção
  `associacoes` traz:
  - `direcao` pelo sinal da estimativa; `sem_relacao_clara` quando p ≥ 0,05;
  - `seguranca`: alta se p < 0,01, média se p < 0,05;
  - coeficientes e métricas em `tabela` com `recolhida: true`;
  - o aviso `associacao` fixo no topo.
- **Complemento B sem tocar no eduBR.** As ferramentas de escola são
  exclusivas da `gestora-escolar`. Ferramentas criadas com `persona = NULL` não
  carregam o atributo de persona, então o adapter as escolhe por nome. O
  prompt continua o da pesquisadora.
- **Posição da escola no município** calculada no R, de forma determinística
  (empates dividem a posição). A nota da seção explica que a posição não é
  julgamento. O LLM recebe a escola do gestor como `sua_escola: true` e
  **não recebe nomes de outras escolas**.
- **Catálogo com `padroes`.** As opções com valor padrão são obrigatórias na
  tela; as sem padrão viram "Todas". Isso corrigiu a etapa forçada que
  quebrava `escolas_parecidas` para escolas sem anos iniciais.

## Problemas de integração (e lições)

- **Pilha de C no Plumber.** O `escolas_similares` (dbplyr) estourava os 8 MB
  da pilha do R **só dentro do Plumber**, que soma quadros à pilha. A
  integração da trilha R, via `pkgload`, passava.
  - Correção: `LimitSTACK=64M` na unit systemd e `ulimits.stack` no compose.
  - **Lição:** a integração precisa passar pelo mesmo servidor de produção (o
    endpoint), não só pela função.
- **Cache entre versões do R.** A chave do `analytics.analysis_cache` já
  incluía `analytics_source_version`, mas ninguém a subia. Uma mudança no
  pacote (inclusive no catálogo de temas) ficava escondida por até 24 h.
  - Agora o `edumapsAnalytics` está na 0.2.0, com
    `analytics_source_version = edumapsr-0.2.0`.
  - **Regra:** subir os dois juntos (comentada no `edumaps_db.conf`).
- **Nomes internos vazando.** O prefixo `[ferramenta]` nos avisos e o
  `(ferramenta)` no rodapé de fontes foram removidos; o LLM já não os
  recebia.
- **`escolas_similares`** devolve uma linha por escola × etapa. Pedimos 20
  linhas e ficamos com as 10 escolas distintas mais próximas.
- **Driver de e2e:**
  - o Mojo limita mensagens de WebSocket a 256 KB, e capturas de páginas com
    muitos gráficos derrubavam a conexão (`max_websocket_size`);
  - a página aplica o recorte padrão de forma assíncrona: esperar
    "Da minha escola:" antes de clicar no nível;
  - rodar cada caso numa aba nova.

## Validação

- **Testes:**
  - R: 29 arquivos / 1374 asserções;
  - frontend: 101 / 795;
  - Perl: relatórios 2 / 23.
- **E2E com o Gemini real:** 13/13 pela API e 11/11 na tela.
- **Exemplos reais:**
  - Ubatuba, anos finais: "7ª de 11";
  - SP: laboratório de informática associado a IDEB maior nas escolas
    urbanas (segurança alta); número de matrículas associado a IDEB menor.

## Pendências

- **Paginação** da lista de escolas em municípios grandes (São Paulo: 1.128).
- **Achados para o eduBR** (só registro):
  - um `filtro` em `regressao_escolas` (ex.: só escolas que ofertam a
    etapa) reduziria o recorte;
  - um filtro por código de município nas ferramentas agregadas eliminaria as
    fatias.
- **Redação dos selos** de segurança: a validar com uso real.
