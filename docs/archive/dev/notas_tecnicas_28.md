Excelente ideia! Vamos criar um sistema de eventos padronizado, tipado e com nomes constantes para todo o projeto. Isso elimina **strings mágicas**, facilita refatoração e melhora a manutenção.

---

## 🧩 Estrutura Proposta

1. **Arquivo de constantes** – centraliza todos os nomes de eventos.
2. **Helper `createTypedDispatcher`** – encapsula `createEventDispatcher` e retorna funções específicas para cada evento (com payload tipado via JSDoc).
3. **Uso nos componentes** – formulários, botões, listas, etc., disparam eventos usando essas funções.
4. **Consumidores** – ouvem os eventos usando `on:eventName` normalmente.

---

## 📁 1. Constantes de Eventos (`src/shared/constants/events.js`)

```javascript
// src/shared/constants/events.js
export const EVENTS = {
  // Busca
  SEARCH: 'search',
  CLEAR: 'clear',

  // Paginação
  PAGE_CHANGE: 'page-change',
  PER_PAGE_CHANGE: 'per-page-change',

  // Toasts
  TOAST_ADD: 'toast-add',
  TOAST_REMOVE: 'toast-remove',

  // Erros
  ERROR: 'error',

  // Genérico (para quando não se encaixa nos acima)
  ACTION: 'action',
} as const;

// Para TypeScript (se usar), pode exportar um tipo
export type EventName = typeof EVENTS[keyof typeof EVENTS];
```

---

## 🎯 2. Helper `createTypedDispatcher` (`src/shared/utils/eventDispatcher.js`)

```javascript
// src/shared/utils/eventDispatcher.js
import { createEventDispatcher } from 'svelte';
import { EVENTS } from '$shared/constants/events';

/**
 * Cria um dispatcher tipado para eventos comuns.
 *
 * @param {any} component - O componente Svelte (geralmente `this` ou o contexto)
 * @returns {Object} Objeto com funções de dispatch para cada evento
 */
export function createTypedDispatcher(component) {
  const dispatch = createEventDispatcher();

  return {
    /**
     * Dispara evento de busca
     * @param {Object} payload - { escola, municipio }
     */
    dispatchSearch(payload) {
      dispatch(EVENTS.SEARCH, payload);
    },

    /** Dispara evento de limpeza */
    dispatchClear() {
      dispatch(EVENTS.CLEAR);
    },

    /**
     * Dispara mudança de página
     * @param {number} page
     */
    dispatchPageChange(page) {
      dispatch(EVENTS.PAGE_CHANGE, page);
    },

    /**
     * Dispara mudança de itens por página
     * @param {number} perPage
     */
    dispatchPerPageChange(perPage) {
      dispatch(EVENTS.PER_PAGE_CHANGE, perPage);
    },

    /**
     * Dispara erro genérico
     * @param {string|Error} error
     */
    dispatchError(error) {
      dispatch(EVENTS.ERROR, error);
    },

    /**
     * Dispara ação personalizada
     * @param {string} action
     * @param {any} payload
     */
    dispatchAction(action, payload) {
      dispatch(EVENTS.ACTION, { action, payload });
    },
  };
}
```

---

## 🧩 3. Uso no `SchoolSearchForm.svelte`

```svelte
<script>
  // src/features/schools/components/SchoolSearchForm.svelte
  import { createTypedDispatcher } from '$shared/utils/eventDispatcher';
  import { EVENTS } from '$shared/constants/events';

  let { loading = false } = $props();

  let nomeEscola = $state("");
  let municipio = $state("");

  let canSubmit = $derived(nomeEscola.trim().length >= 3 || municipio.trim().length >= 3);

  // Cria o dispatcher tipado
  const { dispatchSearch, dispatchClear } = createTypedDispatcher();

  function handleSubmit(event) {
    event.preventDefault();
    if (!canSubmit) return;
    dispatchSearch({ escola: nomeEscola.trim(), municipio: municipio.trim() });
  }

  function handleClear() {
    nomeEscola = "";
    municipio = "";
    dispatchClear();
  }
</script>

<!-- ... template ... -->
```

---

## 🧩 4. Uso no `SchoolSearchPageRx.svelte` (consumidor)

```svelte
<script>
  // ... imports
  import { EVENTS } from '$shared/constants/events';

  function handleSearch(event) {
    // event.detail é o payload { escola, municipio }
    const { escola, municipio } = event.detail;
    hasSearched = true;
    schoolStore.setSearch({ escola, municipio, page: 1 });
  }

  function handleClear() {
    hasSearched = false;
    schoolStore.setSearch({ escola: "", municipio: "", page: 1 });
  }
</script>

<SchoolSearchForm
  loading={result.loading}
  on:search={handleSearch}
  on:clear={handleClear}
/>
```

---

## 🧩 5. Uso genérico em botões ou outros componentes

### Botão de paginação (`PaginationControls.svelte`)

```svelte
<script>
  import { createTypedDispatcher } from '$shared/utils/eventDispatcher';
  import { EVENTS } from '$shared/constants/events';

  let { pagination, perPageOptions = [5, 10, 20, 50] } = $props();
  const { dispatchPageChange, dispatchPerPageChange } = createTypedDispatcher();

  function goToPage(page) {
    if (page >= 1 && page <= pagination.total_pages) {
      dispatchPageChange(page);
    }
  }
</script>

<button on:click={() => goToPage(pagination.current_page - 1)}>Anterior</button>
<!-- ... -->
<select
  value={pagination.per_page}
  on:change={(e) => dispatchPerPageChange(Number(e.target.value))}
>
  {#each perPageOptions as opt}
    <option value={opt}>{opt}</option>
  {/each}
</select>
```

---

## 📝 6. Vantagens

- **Centralização**: todos os nomes de eventos em um único lugar.
- **Sem strings mágicas**: IDE autocompleta as constantes.
- **Tipagem**: com JSDoc, os parâmetros ficam documentados.
- **Facilidade de refatoração**: mudar o nome de um evento é feito uma única vez.
- **Consistência**: todos os componentes seguem o mesmo padrão.
- **Rastreabilidade**: você pode adicionar logs ou analytics interceptando os eventos.

---

## 🔌 Opcional: Monitoramento Global de Eventos

Se quiser logar todos os eventos disparados, adicione um **event listener global** no `App.svelte`:

```svelte
<script>
  import { EVENTS } from '$shared/constants/events';

  function handleGlobalEvent(event) {
    if (event.type === EVENTS.SEARCH) {
      console.log(`🔍 Busca realizada:`, event.detail);
    }
    // ... outros eventos
  }
</script>

<svelte:window
  on:search={handleGlobalEvent}
  on:clear={handleGlobalEvent}
  on:page-change={handleGlobalEvent}
  on:per-page-change={handleGlobalEvent}
/>
```

---

## 🚀 Conclusão

Com essa abordagem, seu projeto fica mais **organizado**, **manutenível** e **seguro**. Componentes de formulário, botões e listas podem disparar eventos padronizados, e os consumidores podem reagir a eles com total confiança.

Se precisar adicionar novos eventos, basta estender o arquivo `events.js` e o helper `createTypedDispatcher`. 🎯

# Relatório de Mudanças e Avanços no Projeto EduMaps

Este relatório apresenta uma análise detalhada dos **últimos 5 commits** realizados no repositório do projeto **EduMaps**. As alterações abrangem desde refatorações estruturais e correções no backend em Perl até a implementação completa de paginação no ecossistema (backend e frontend), testes automatizados e integração reativa via RxJS.

---

## 1. Resumo Histórico dos Commits Analisados

| Hash / Commit | Autor | Módulo / Tipo | Descrição Sumária |
| --- | --- | --- | --- |
| **`5b78617`** | Marco Silva | Backend / Feat | Implementação da busca paginada de escolas (`/search/pageable`), criação da Role `Pageable` e `Observable`, além de testes de integração e performance.

 |
| **`8dc2311`** | Marco Silva | Frontend / Feat | Adição de suporte a paginação server-side, inclusão da biblioteca RxJS, componentes UI reativos (`SchoolReactiveList`, `SchoolSearchPageRx`) e testes com Vitest/MSW.

 |
| **`261c6b1`** | Marco Silva | Backend / Fix | Correção na montagem de parâmetros de consulta e normalização do alias para matriculas escolares (`Profile.pm`).

 |
| **`ff48ee3`** | Marco Silva | Backend / Feat | Adição de novos *endpoints* para folha de pagamento (`payroll/last`) e gerador de colunas customizadas do Censo Escolar.

 |
| **`7150a0f`** | Marco Silva | Backend / Refactor | Refatoração arquitetural para separação das responsabilidades de negócio nas Roles `Finance`, `Searching` e `Profile`.

 |

---

## 2. Detalhamento e Escopo das Mudanças

### Commit `7150a0f`: Refatoração Arquitetural de Business Roles

* **Descrição das Mudanças:** O arquivo monolítico/centralizado `School.pm` foi faturado e modularizado em Roles especializadas (`EduMaps::Roles::Business::School::*`), dividindo a lógica em `Finance.pm`, `Searching.pm` e `Profile.pm`.


* **Importância:** Elimina acoplamento, facilita a manutenção contínua e permite que novas funcionalidades sejam desenvolvidas de forma isolada sem riscos de regressão em outras partes da regra de negócio.


* **Alcance:** Modificação estrutural que afeta a camada de domínio e a forma como o controller de escolas instancia os serviços de consulta.



---

### Commit `ff48ee3`: Expansão da API de Finanças e Modelagem do Censo

* **Descrição das Mudanças:**
1. Criação do *endpoint* `/api/school/:cod_inep/payroll/last` para retornar os dados financeiros mais recentes de uma instituição.


2. Implementação do atributo/método `censo_columns` em `Searching.pm`, construindo expressões SQL computadas (`concat_ws`, `CASE/WHEN`) para formatar endereços, links do OpenStreetMap, links diretos de WhatsApp, tipos de dependência administrativa e etapas de ensino.




* **Importância:** Reduz a complexidade do frontend ao entregar dados já formatados e higienizados vindos do banco de dados (PostgreSQL/PostGIS).


* **Alcance:** Atualização nos Controllers, Plugins de Rota (`API::School`) e no schema de mapeamento do Censo Escolar.



---

### Commit `261c6b1`: Correção no Mapeamento de Parâmetros de Matrícula

* **Descrição das Mudanças:** Correção no método `info_enrollment` (`Profile.pm`), garantindo que o prefixo de alias (`$alias.`) seja injetado corretamente na chave do parâmetro de busca quando ausente.


* **Importância:** Evita erros de SQL/ambiguidade em *joins* entre a tabela de escolas e o relacionamento de matrículas.


* **Alcance:** Correção pontual de bug no backend com impacto direto na precisão das consultas de dados do Censo.



---

### Commit `8dc2311`: Paginação Server-Side e Reatividade no Frontend

* **Descrição das Mudanças:**
1. Inclusão das dependências `@testing-library/svelte`, `rxjs` e `msw` no `package.json` / `package-lock.json`.


2. Adição da função `searchPaginatedSchools` na camada de integração da API (`schoolApi.js`).


3. Criação de novos componentes reativos no Svelte (utilizando *Runes* do Svelte 5): `PageableList.svelte`, `SchoolReactiveList.svelte` e a página reativa `SchoolSearchPageRx.svelte` baseada em *stores* RxJS.


4. Mapeamento da rota `/escola/search` no roteador da aplicação.




* **Importância:** Melhora significativamente a experiência do usuário (UX), eliminando o carregamento excessivo de dados e permitindo pesquisas paginadas em tempo real.


* **Alcance:** Camada de apresentação (UI), gerenciamento de estado e suíte de testes de integração frontend.



---

### Commit `5b78617`: Implementação de Paginação e Observables no Backend

* **Descrição das Mudanças:**
1. **Role `Pageable` (`EduMaps::Roles::DB::Pageable`):** Traz métodos auxiliares para ResultSet do `DBIx::Class` (`set_page`, `set_page_size`, `total_items`, `total_pages`, `to_api_response`).


2. **Role `Observable` (`EduMaps::Model::Role::Observable`):** Integração com `RxPerl::Mojo` para converter iteradores de banco de dados em fluxos reativos (*Observables*).


3. **Rota e Controller:** Criação do endpoint `/api/school/search/pageable` com validações para `page` e `per_page`.


4. **Suíte de Testes:** Inclusão de testes unitários para a Role `Observable` (`observable.t`) e testes funcionais/de performance para a rota de busca paginada (`search_paginated.t`).




* **Importância:** Fornece uma infraestrutura genérica de paginação para qualquer ResultSet do banco de dados, além de garantir alta eficiência e tempo de resposta aceitável na API.


* **Alcance:** Camada de banco de dados (`Schema/ResultSet/Base.pm`), Controllers, Rotas da API e testes automatizados backend.



---

## 3. Conclusão do Impacto e Alcance Geral

O conjunto das mudanças efetuadas nesses 5 commits representa um **salto qualitativo na arquitetura do EduMaps**:

1. **Desempenho e Escalabilidade:** A paginação *end-to-end* (do banco de dados até a interface do usuário) impede que requisições tragam milhares de registros desnecessários, reduzindo o consumo de memória e tráfego de rede.


2. **Qualidade de Código e Manutenibilidade:** A modularização em *Roles* e a inclusão de componentes reutilizáveis deixam a base de código pronta para novos módulos.


3. **Reatividade e DX:** A adoção de **RxJS / RxPerl** e **Svelte 5 Runes** moderniza a aplicação, trazendo uma comunicação reativa e robusta entre o cliente e o servidor.


4. **Confiabilidade:** A inclusão de testes unitários, funcionais e de performance garante o funcionamento correto dos contratos de API e previne regressões futuras.


# Memória do EduMaps

Como o EduMaps é uma SPA em Svelte, existem **dois tipos de memória** que normalmente você quer medir:

1. **Memória JavaScript (heap)** — objetos, componentes Svelte, arrays, caches, etc.
2. **Memória do navegador** — DOM, imagens, Canvas, WebGL, Leaflet, tiles, etc.

O Chrome DevTools possui ferramentas diferentes para cada caso.

---

## 1. Ver o uso atual de memória (mais simples)

Abra o DevTools (`F12`)

Vá em:

```
Performance
```

Marque:

* ✅ Memory

Depois:

1. Clique em **Record**
2. Navegue pelo EduMaps (zoom, troca de cidade, filtros...)
3. Pare a gravação.

Você verá um gráfico parecido com:

```
Heap
  ^
90MB |            /\__
80MB |          _/    \__
70MB |      ___/
60MB |_____/_________________
      tempo
```

Se o heap sobe e nunca volta a cair após GC, provavelmente existe um leak.

---

# 2. Heap Snapshot (a ferramenta mais importante)

Abra

```
Memory
```

Depois escolha

```
Heap snapshot
```

e clique

```
Take snapshot
```

Você verá algo parecido com

```
Array
Object
Map
Closure
HTMLDivElement
Detached DOM tree
...
```

Pode ordenar por

```
Retained Size
```

Esse valor mostra quem realmente está segurando memória.

É excelente para descobrir:

* componentes Svelte não destruídos
* arrays enormes
* objetos do Leaflet
* caches

---

# 3. Allocation instrumentation

Ainda na aba Memory:

```
Allocation instrumentation on timeline
```

Depois:

```
Start
```

Use a aplicação.

Depois:

```
Stop
```

Você verá exatamente:

```
loadSchools()

   Array
   Object
   GeoJSON
   Feature
```

e quantos MB cada chamada alocou.

É excelente para descobrir funções que criam muitos objetos.

---

# 4. Descobrir vazamentos (Leaks)

O método clássico:

1.

Heap Snapshot

2.

Interaja com a aplicação

3.

Volte ao estado inicial

4.

Force GC

(botão da lixeira)

5.

Novo Heap Snapshot

Depois compare:

```
Snapshot 1

↓

Snapshot 2

↓

Comparison
```

Se aparecer

```
SchoolMarker
+800

CityPopup
+120

GeoJSON
+500
```

então objetos permaneceram vivos.

---

# 5. Performance Monitor (tempo real)

No DevTools:

```
More tools

↓

Performance Monitor
```

Ele mostra em tempo real

```
JS Heap

DOM Nodes

JS Event Listeners

Documents

Frames

GPU Memory
```

É ótimo para deixar aberto enquanto usa o sistema.

---

# 6. Ver quanto cada arquivo JS ocupa

Abra

```
Sources
```

ou

```
Coverage
```

Em

```
More tools

↓

Coverage
```

Clique

```
Reload
```

Vai mostrar

```
bundle.js

3.4 MB

Used

18%
```

Isso mede o código carregado e utilizado, não a memória em execução.

---

# 7. `performance.memory`

No Console:

```javascript
performance.memory
```

Retorna algo parecido com

```javascript
{
  jsHeapSizeLimit: 4294705152,
  totalJSHeapSize: 86433792,
  usedJSHeapSize: 52345001
}
```

onde

```
usedJSHeapSize
```

é a memória atualmente usada pelo heap JavaScript.

Pode monitorar ao longo do tempo:

```javascript
setInterval(() => {
    console.log(
        (performance.memory.usedJSHeapSize / 1024 / 1024).toFixed(1) + " MB"
    );
}, 1000);
```

---

# 8. Específico para Svelte

Os problemas mais comuns em aplicações Svelte são:

* `setInterval()` não cancelado no `onDestroy`
* `window.addEventListener()` sem remoção
* stores com `subscribe()` sem `unsubscribe()`
* componentes que permanecem montados
* objetos grandes mantidos em stores globais

Exemplo correto:

```javascript
import { onMount, onDestroy } from 'svelte';

let unsubscribe;

onMount(() => {
    unsubscribe = store.subscribe(...);
});

onDestroy(() => {
    unsubscribe();
});
```

---

# 9. Leaflet costuma ser o maior consumidor

Como o EduMaps usa Leaflet, normalmente vale investigar:

* milhares de `L.Marker`
* muitos objetos `GeoJSON`
* tiles não descartados
* popups permanentes
* listeners em camadas antigas

Se cada troca de município cria novas camadas, sempre remova as anteriores:

```javascript
map.removeLayer(layer);
layer.clearLayers();
```

---

## Fluxo recomendado para o EduMaps

Para encontrar vazamentos de memória de forma eficiente:

1. Abra **Memory → Heap Snapshot** e tire um snapshot inicial.
2. Navegue pelo sistema (troque cidades, faça zoom, carregue escolas, etc.).
3. Retorne ao estado inicial, force um **Garbage Collection** e tire um segundo snapshot.
4. Compare os snapshots para identificar objetos que permaneceram vivos.
5. Em seguida, use **Performance** com a opção **Memory** habilitada para verificar se o heap cresce continuamente durante uma sessão de uso.

Essa combinação costuma localizar rapidamente leaks em aplicações Svelte com Leaflet e é a abordagem que eu usaria primeiro no seu projeto.
