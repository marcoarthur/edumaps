# Nota técnica 204: ranking de redes municipais e de escolas por município (#430)

PR #436 (merge `2fedc87`), fecha a #430: achado AN-11 da curadoria P3–P6.
Feito durante a ausência do developer, com as decisões de produto informadas
por Telegram antes de começar.

## Decisões de produto

1. **Valor da rede** = média simples das escolas da rede com o indicador na
   edição. O IDEB oficial por rede (INEP) não está carregado, e a nota da tela
   diz isso.
2. **Só redes municipais** (a unidade de política da P2 e de quem a fiscaliza),
   com pelo menos 3 escolas com dado (`$MIN_ESCOLAS_REDE`). As outras ficam de
   fora e são contadas (`fora_por_poucas_escolas`).
3. **Recorte** padrão: os municípios de uma UF; Brasil como opção.
4. **Leitura não punitiva:**
   - `inse` é a média do INSE das escolas da rede (edição mais recente do
     SAEB);
   - `quinto_inse` é o `ntile(5)` no recorte, e `media_quinto_inse` a média
     das redes do mesmo quinto;
   - a tela diz "X acima/abaixo dos de INSE parecido" e não pinta vermelho
     nem verde.
5. **Variação** = média da edição atual menos a da anterior, cada uma sobre as
   escolas com dado na sua edição, só quando a anterior também tem ao menos 3
   escolas. É a resposta a "quais redes mais melhoraram?"; a posição pela
   variação vem à parte.

## Desenho

- Os dois métodos ficam em `Model::Rank::School`, ao lado do
  `indicator_registry` (fonte única dos indicadores):
  - `redes_municipais` só aceita indicadores do IDEB/SAEB;
  - `escolas_do_municipio` aceita todos (MV de scores do Censo ou
    `ideb_notas_escolas`) e usa `RANK()`, então empate divide a posição.
- **Desempenho:** a primeira versão buscava o INSE escola a escola com
  `LATERAL ... ORDER BY nu_ano_saeb DESC LIMIT 1`. O índice do `clean.inse` é
  `(nu_ano_saeb, id_escola)` e não serve para buscar por escola. Trocado por
  um join com a edição mais recente, a mesma regra do perfil da escola.
  - Nacional: de 15,6 s para 0,19 s.
  - Escolas de São Paulo (7.310): de 5,6 s para 0,12 s.
- **Frontend:**
  - página `/ranking` com duas abas;
  - a URL guarda aba e filtros, e o link do município preenche a busca;
  - CSV gerado no navegador (`;`, BOM, vírgula decimal) e selo de fonte;
  - atalhos na página inicial e na comparação de redes, com a UF tirada dos 2
    primeiros dígitos do código IBGE.

## Validação

- Perl:
  - `ranking_recorte.t` monta municípios fictícios da UF "XX";
  - suíte `-j4`: 192 arquivos, 1699 testes.
- vitest: 151 arquivos, 1294 testes.
- Navegador:
  - ES, IDEB anos iniciais: 67 redes, 11 fora;
  - escolas de Vitória por infraestrutura: 180.

## Deploy

No LXC: `deploy_backend_dev`, `deploy_minion_dev` e `deploy_frontend_dev`.
