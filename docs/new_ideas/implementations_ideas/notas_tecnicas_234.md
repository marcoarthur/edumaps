# Nota técnica 234: perfil da rede contra a mesma rede e grupos pelo INSE (#497)

Achados RG-01 e RG-02 da vigésima segunda avaliação da P4
(`docs/personas/publicos/avaliacoes/2026-11-19-p4-perfil-rede.md`).
Um PR: #498 (merge `414389f`).

## O problema

- **RG-01 (atrapalha).** O perfil da rede (`/municipio/perfil`) comparava a
  rede com a referência `brasil`, a média de **todas as redes**, mesmo com a
  dependência filtrada; o IDEB e o SAEB por etapa também. A tela dizia só
  "Brasil".
  - **Medido** (Salvador, rede municipal): docentes efetivos +17,6 p.p. contra
    o Brasil de todas as redes e +3,9 p.p. contra as redes municipais; IDEB
    dos anos finais −0,50 contra −0,34. As privadas (41.657 escolas, 0% de
    efetivos) puxavam a média para baixo.
  - `n_brasil` vinha `null` sempre que a referência pré-computada não
    existia (caso do Docker local).
- **RG-02 (atrapalha).** A seção "Distribuição por grupo", que a ajuda
  chamava de "grupos de contexto parecido", lia o `cluster_id` de
  `clean.school_indicators`: o último agrupamento gravado. Hoje 3.046 de
  214.192 escolas, todas de 78 municípios do ES, de um k-means de
  infraestrutura. Salvador inteira em "Sem cluster".

## Decisões

- **A mesma rede no Brasil, com o mesmo código do perfil da escola.** Com
  `tp_dependencia`, a referência é o escopo `rede` (chave = dependência),
  pela `.profile_reference_rows` (pré-computada) ou pela
  `.profile_scope_live` (ao vivo), as mesmas da coluna "Rede" do perfil da
  escola. O IDEB e o SAEB por etapa usam `.profile_ideb_etapa_stats(...,
  "rede", tp)`. Sem filtro, segue o Brasil de todas as redes.
  - **Por que não mostrar as duas colunas:** a pergunta do leitor é "a rede
    está acima ou abaixo de redes como ela?"; o Brasil de todas as redes
    continua a um clique (o perfil sem filtro).
  - **O rótulo vai no payload** (`referencia_rotulo`: "Brasil, redes
    municipais"), com `referencia_escopo` e `n_brasil`, e a tela o usa no
    cabeçalho da coluna e na linha "Comparada com".
- **Os grupos são os níveis do INSE do INEP.** A coluna
  `inse_classificacao` ("Nível I" a "Nível VIII") vira `inse_nivel` (1 a 8)
  na população do perfil (`.inse_nivel_sql`, `INSE_NIVEIS`), e a seção agrupa
  por ela; sem INSE, "Sem INSE".
  - **Por que o INSE e não um agrupamento por contexto como o da #494:** o
    grupo do perfil da escola é centrado numa escola; numa rede não há
    centro. Os níveis do INEP são públicos, fixos, iguais em todo o país e
    citáveis, e respondem "como a rede se divide pelo contexto dos alunos".
  - **O que fica visível:** "Sem INSE" junta as privadas e a maior parte da
    educação infantil (131 das 414 escolas municipais de Salvador).
  - O payload mantém a tabela `clusters` (o frontend não muda de contrato);
    o critério vai em `grupo_criterio`.
- **Sai o último agrupamento gravado dos perfis:** a leitura do
  `cluster_id` no perfil da rede, o helper
  `.school_indicators_has_cluster_id` e o escopo `cluster` de
  `.profile_ideb_etapa_stats`.
- **Cache:** a chave do perfil da rede sobe para `versao = 4`.

## Validação

- Docker local:

  | Salvador | Referência | Docentes efetivos | IDEB anos finais |
  |---|---|---|---|
  | municipal, antes | Brasil, todas as redes | +17,6 p.p. | −0,50 |
  | municipal, agora | Brasil, redes municipais (107.372) | +3,9 p.p. | −0,34 |
  | estadual, agora | Brasil, redes estaduais (29.998) | +52,5 p.p. | −1,02 |

  - Grupos da rede municipal de Salvador: Nível III 104, IV 177, V 2, Sem
    INSE 131 (soma 414). Vitória: III 1, IV 31, V 24, VI 7, Sem INSE 117.
- **Testes:**
  - R: rótulos dos níveis e do Brasil, o SQL dos oito níveis, e um teste
    contra o banco (referência `brasil` e `rede`, grupos somando a rede);
    suíte inteira passando com e sem o banco de fixtures (2.347);
  - Perl: 199 arquivos e 1.758 testes (chave de cache versão 4);
  - vitest: 1.360 testes;
  - CI do PR verde, depois de rodar de novo os jobs Perl e R, que caíram no
    `apt` (security.ubuntu.com fora do ar), antes de qualquer teste.

## Pendências

- O batch `apply_school_profile` no modo `cluster`
  (`analytics.school_cluster_profile`) ainda lê o `cluster_id`, e ninguém lê
  a saída dele desde a #494. Vale uma issue de limpeza.
