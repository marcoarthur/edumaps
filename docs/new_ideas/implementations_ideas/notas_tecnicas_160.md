# Nota técnica 160 — ajuda guiada, fase 2: tour de primeiro acesso

Segunda fase da ajuda guiada (fase 1: [nota 159](notas_tecnicas_159.md),
PR #311). Um PR (**#312**, `b8517ca`), com e2e em Chrome real contra
`ubatexu.lan:8080`.

## Entregas

| Commit | Escopo |
|---|---|
| `0eae50a` | tour `primeiro-acesso` + `data-tour` na home, no menu e no “?” + docs |
| `0ae3915` | rodada e2e em `docs/e2e/cobertura.md` |

## 1. Um tour novo custou só dados e marcações

A fase 1 deixou a infraestrutura pronta: a fase 2 não tocou no
`TourManager`. O tour é um arquivo de dados (`tours/primeiroAcesso.js`), uma
linha no `registrar(...)` e atributos `data-tour` nos alvos. É a medida de
sucesso da camada da fase 1: tours novos não exigem código novo.

- **Menu**: em vez de marcar cada `<a>` à mão, `NAV_LINKS` ganhou um campo
  opcional `tour`, renderizado como `data-tour={item.tour}` (Svelte omite o
  atributo quando é `undefined`). Item sem tour não carrega marcação.
- **O botão “?” como último passo**: termina o tour mostrando como voltar a
  ele. Como o “?” só aparece em páginas com tour, e `/` agora tem um, ele é
  sempre alvo válido aqui.
- **Escopo**: Configurações, Administração e “Sobre o Refactor” ficaram de
  fora: são áreas internas, e apresentá-las a quem chega pela primeira vez
  confunde mais do que ajuda.

## 2. Dois tours automáticos, sem conflito

Cada tour é ligado à sua `rotaInicial` e lembrado por chave própria
(`edumaps.tour.<id>.v<versao>`). Quem chega pela home vê o de primeiro acesso;
ao ir para a busca, vê o da busca (uma vez cada). Quem cai direto na busca
(link externo) vê só o da busca, e o de primeiro acesso fica para quando
passar pela home. Um teste fixa que `tourDaRota` resolve cada página para o
seu tour.

## 3. Texto de tour é documentação: tem de bater com a ficha

O rascunho do passo “Assistente do Censo” prometia resposta “com a fonte”. A
ficha (`docs/funcionalidades/analise/assistente-censo.md`) diz outra coisa:
exclusivo de gestor com login, devolve números e, quando ajuda, um gráfico. O
texto foi corrigido antes do deploy. Regra para os próximos tours: escrever
cada passo **a partir da ficha da funcionalidade**, não da memória da tela.

## 4. Observação de ambiente: primeira carga em branco após o deploy

Duas vezes (fases 1 e 2), a primeira carga logo após o `deploy_frontend_dev`
ficou em branco. O `edumaps-frontend-access.log` mostra `GET /` 200 e
**nenhum** GET do bundle `index-*.js` nessa carga; a recarga seguinte funciona.
Como nenhum JS do app chegou a rodar, não é do tour. Hipóteses a investigar à
parte: Chrome da automação com estado de cache inconsistente após o restart do
nginx (o `error.log` registra o nginx abortando com sockets abertos), ou
interação entre `index.html no-cache` e assets `immutable`. Vale verificar se
usuários reais também passam por isso logo após deploys.

## Pendências

- Tours do painel do gestor (exige sessão no e2e) e das análises (mapa
  Leaflet: destacar contêiner/controles, não marcadores).
- Telemetria do tour (iniciado/concluído/abandonado por passo).
- Investigar a primeira carga em branco (§4).
- Ao encerrar a feature: nota técnica consolidada do ciclo inteiro.
