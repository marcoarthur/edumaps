# Nota técnica 161 — ajuda guiada, fase 3: tour do painel do gestor

Terceira fase da ajuda guiada (fase 1: [nota 159](notas_tecnicas_159.md),
PR #311; fase 2: [nota 160](notas_tecnicas_160.md), PR #312). Um PR (**#313**,
`4388f4b`), com e2e em Chrome real contra `ubatexu.lan:8080`.

## Entregas

| Commit | Escopo |
|---|---|
| `94017bb` | tour `painel-gestor` + `prontoQuando` no `TourManager` + `data-tour` no painel + docs |
| `e99d0f8` | fix: passo “Matrículas” passou a citar a faixa etária |
| `cd5e06d` | rodada e2e em `docs/e2e/cobertura.md` |

## 1. `prontoQuando`: tour de página que carrega dados

As fases 1 e 2 tinham alvos no DOM desde a montagem. O painel do gestor não:
ele busca os dados da escola e só então monta o conteúdo. Sem cuidado, o tour
automático abriria sobre “Carregando…”, cada passo esperaria o alvo e o tour
ficaria marcado como visto mesmo que a pessoa não tivesse visto nada.

Opções consideradas:

- **Só o `waitForElement` do driver.js** (já usado): resolve o atraso, mas não
  o erro. Com INEP inválido, os 8 passos cairiam no popover centralizado e o
  “visto” seria gravado.
- **A página avisar o tour** (evento “painel pronto” no `eventBus`): acopla
  cada feature ao tour e espalha a regra pelas páginas.
- **`prontoQuando: <alvo>` na definição do tour** (adotada): o
  `TourManager` só inicia o tour automático quando o alvo indicado existe,
  verificando a cada 100 ms até `esperaMs`. Se a pessoa sair da página ou o
  prazo acabar, desiste **sem gravar nada**. A página não sabe que o tour
  existe; a regra fica numa linha de dados.

O botão “?” não espera: quem pede ajuda explicitamente vê o tour na hora (e o
`waitForElement` cobre o restante do carregamento).

Testes com `vi.useFakeTimers()` fixam os quatro casos: abre quando o alvo
monta, não abre nem marca se nunca montar, desiste ao sair da página e o
início manual não espera.

## 2. Seções altas e mapas Leaflet

- Matrículas (746 px) e infraestrutura (649 px) quase ocupam a janela; o
  driver.js rola até o início da seção e põe o popover ao lado. Ficou legível
  sem ajuste.
- Com o mapa de escolas similares carregado, o mapa aparece dentro do
  destaque. z-index medido: overlay do tour 10000; Leaflet usa 400 nos panes e
  1000 nos controles. A recomendação da nota 159 se manteve: destacar a
  **seção** que contém o mapa, nunca marcadores.

## 3. Texto de tour: ficha **e** tela

A nota 160 fixou “escrever a partir da ficha”. Aqui a ficha estava
incompleta: não citava o gráfico de matrículas por faixa etária, que o painel
mostra. O e2e pegou. A regra fica: conferir o texto na ficha da
funcionalidade **e** na tela renderizada.

## 4. Limite do e2e: estado logado

A API do painel responde sem sessão, então o tour foi validado sem login.
Nesse estado, área de influência e equipamentos do entorno mostram “Entre como
gestor desta escola…”, e o passo 8 destaca essa seção nos dois estados. O
estado logado foi validado pelo developer: o agente não digita credenciais em
`ubatexu.lan`, que não é host local nem de teste.

## Pendências

- Tour das análises (última fase prevista). Ao fechá-la: nota técnica
  consolidada do ciclo inteiro (fases 1–4).
- O “?” fica visível na tela de erro do painel; aberto lá, os passos caem no
  popover centralizado. Caso raro; registrado.
- Telemetria do tour (iniciado/concluído/abandonado por passo).
- Primeira carga em branco após deploy (nota 160, §4): causa encontrada na
  fase 4 — bundle sem gzip ([nota 162](notas_tecnicas_162.md)).
