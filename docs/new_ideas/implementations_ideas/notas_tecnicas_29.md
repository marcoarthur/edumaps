
# Padronizando Eventos

A ideia tem bons objetivos (padronização, redução de strings soltas e documentação dos eventos), mas eu faria algumas mudanças se o objetivo principal é **facilidade de orquestração com RxJS**.

Minha avaliação seria algo como:

| Critério                   | Avaliação |
| -------------------------- | --------- |
| Padronização               | ★★★★★     |
| Facilidade de manutenção   | ★★★★☆     |
| Flexibilidade              | ★★★☆☆     |
| Integração futura com RxJS | ★★☆☆☆     |
| Acoplamento                | ★★★☆☆     |

O principal problema é que, apesar do nome "centralização de eventos", os eventos **continuam sendo eventos locais do Svelte** (`createEventDispatcher`). O helper apenas encapsula chamadas de `dispatch()`.

Isso é diferente de uma arquitetura orientada a eventos.

---

# O que gostei

## 1. Constantes

Excelente.

```js
EVENTS.SEARCH
EVENTS.PAGE_CHANGE
```

evita

```js
dispatch("search")
dispatch("serach")
dispatch("Search")
```

e permite renomeação global.

---

## 2. Payloads documentados

Também gostei.

Em projetos JS puro (sem TS) isso ajuda bastante.

---

## 3. Componentes ficam limpos

Em vez de

```js
dispatch("search", {
   escola,
   municipio
})
```

fica

```js
dispatchSearch({
   escola,
   municipio
})
```

mais legível.

---

# O que não gostei

## O helper cria um dispatcher para cada componente

Hoje ele faz:

```js
const dispatch = createEventDispatcher();
```

Ou seja:

```
Componente A
    dispatcher A

Componente B
    dispatcher B

Componente C
    dispatcher C
```

Na prática isso continua sendo exatamente o mecanismo do Svelte.

Não existe um barramento.

---

## Não existe Event Bus

Se amanhã você quiser fazer:

```
SchoolSearchForm

↓

RxJS pipeline

↓

Analytics

↓

Cache

↓

Toast

↓

Log

↓

Store
```

não existe um ponto único para interceptar os eventos.

Eles saem direto do componente.

---

## Helper conhece todos os eventos

Hoje ele tem:

```
dispatchSearch()

dispatchPageChange()

dispatchError()

dispatchAction()

dispatchClear()
```

Imagine daqui dois anos.

Você terá

```
dispatchUserLogin()

dispatchUserLogout()

dispatchSchoolCreated()

dispatchSchoolUpdated()

dispatchSchoolDeleted()

dispatchMapZoom()

dispatchLayerChanged()

dispatchToast()

dispatchAlert()

dispatchExport()

dispatchImport()

dispatch...
dispatch...
dispatch...
```

O helper vira um arquivo de 500 linhas.

Isso normalmente é um cheiro de arquitetura.

---

# O problema principal para RxJS

RxJS gosta de trabalhar assim:

```
evento

↓

Observable

↓

pipe()

↓

map()

↓

filter()

↓

debounce()

↓

switchMap()

↓

shareReplay()
```

Já o createEventDispatcher trabalha assim:

```
dispatch()

↓

DOM Event

↓

Parent

↓

Handler
```

São modelos completamente diferentes.

---

# O que eu faria

Eu separaria completamente:

```
Eventos do DOM

≠

Eventos da aplicação
```

Hoje seu helper mistura os dois.

---

Por exemplo:

```
SchoolSearchForm

↓

dispatch(EVENTS.SEARCH)
```

não deveria saber nada de Rx.

Mas a aplicação deveria.

---

# Eu criaria um EventBus

Algo parecido com:

```js
export const EventBus = {
    emit(name, payload),

    on(name),

    off(name)
}
```

Depois faria uma implementação usando RxJS.

Exemplo:

```js
const bus = new Subject();
```

emit:

```js
bus.next({
    type,
    payload
});
```

consumo:

```js
bus.pipe(
    filter(e => e.type === EVENTS.SEARCH)
)
```

Aí amanhã você consegue fazer:

```
SEARCH

↓

debounceTime(500)

↓

distinctUntilChanged()

↓

switchMap(api)

↓

retry()

↓

catchError()

↓

toast()
```

sem alterar nenhum componente.

Essa é justamente a força do RxJS.

---

# Outra coisa que mudaria

Eu evitaria criar uma função para cada evento.

Hoje:

```js
dispatchSearch()

dispatchClear()

dispatchPageChange()
```

Isso escala mal.

Prefiro algo como

```js
dispatch(EVENTS.SEARCH, payload)
```

ou

```js
emit(EVENTS.SEARCH, payload)
```

As constantes já dão segurança suficiente.

---

# Outra melhoria

Hoje

```js
ACTION
```

é genérico demais.

```js
dispatchAction("delete", data)
```

isso vira uma string dentro de outra string.

Prefiro

```
DELETE

SAVE

EXPORT

IMPORT

ARCHIVE
```

Cada ação vira um evento.

Isso simplifica bastante os filtros no RxJS.

---

# Uma arquitetura que eu considero mais preparada

```
src/

    shared/

        events/

            events.js

            eventBus.js

            eventTypes.js

            rx/
                search.js
                pagination.js
                toast.js

        utils/
```

Fluxo:

```
SchoolSearchForm

↓

emit(EVENTS.SEARCH)

↓

EventBus

↓

RxJS Subject

↓

pipeline

↓

Store

↓

API

↓

Toast

↓

Analytics
```

Os componentes ficam completamente desacoplados da implementação do barramento.

Se amanhã você abandonar RxJS e usar outra biblioteca, os componentes continuam emitindo exatamente o mesmo evento.

## Conclusão

A proposta atual é uma boa evolução em relação a usar strings literais espalhadas pelo projeto e melhora a consistência dos componentes. No entanto, ela ainda é essencialmente uma camada de conveniência sobre `createEventDispatcher`, não uma centralização real de eventos.

Se o objetivo declarado é **preparar o sistema para orquestração com RxJS**, eu faria uma separação clara entre:

* **Eventos de interface (Svelte)**: comunicação entre componente filho e pai via `createEventDispatcher`.
* **Eventos da aplicação (Event Bus)**: barramento central baseado em `Subject`/`Observable`, onde ficam debounce, cache, logging, analytics, efeitos, sincronização entre módulos e demais pipelines.

Essa separação reduz o acoplamento, evita que um helper cresça indefinidamente com uma função por evento e deixa a migração ou adoção gradual de RxJS muito mais natural. Em uma escala de prontidão para uma arquitetura reativa, eu avaliaria a proposta atual como **7/10**; com um `EventBus` independente e uma API baseada em `emit(event, payload)` sobre um barramento observável, ela subiria para algo em torno de **9,5/10**.



Acho que essa é uma boa direção. Eu faria o `EventBus` **independente do RxJS**.

Isso pode parecer estranho, mas traz uma vantagem enorme: o barramento vira apenas uma abstração. Hoje ele pode usar RxJS internamente; amanhã pode usar Signals, EventTarget, EventEmitter ou qualquer outra implementação sem alterar os componentes.

Minha sugestão é dividir em três camadas:

```
Application

        │

 emit(EVENTS.SEARCH)

        │

     EventBus

        │

 RxJS (Subject)

        │

 Observables
```

Assim, **RxJS fica escondido**.

---

# events.js

```javascript
export const EVENTS = {
    SEARCH: "search",
    CLEAR: "clear",

    PAGE_CHANGE: "page-change",
    PER_PAGE_CHANGE: "per-page-change",

    ERROR: "error",

    TOAST_ADD: "toast-add",
    TOAST_REMOVE: "toast-remove",
};
```

---

# EventBus.js

```javascript
import { Subject } from "rxjs";
import { filter, map } from "rxjs/operators";

export class EventBus {

    #subject;

    constructor() {
        this.#subject = new Subject();
    }

    /**
     * Emite um evento.
     *
     * @param {string} type
     * @param {*} payload
     */
    emit(type, payload = undefined) {

        this.#subject.next({
            type,
            payload,
            timestamp: Date.now()
        });

    }

    /**
     * Observable contendo todos os eventos.
     */
    events() {
        return this.#subject.asObservable();
    }

    /**
     * Observable de um tipo específico.
     */
    on(type) {

        return this.#subject.pipe(

            filter(event => event.type === type),

            map(event => event.payload)

        );

    }

}
```

Uso:

```javascript
export const eventBus = new EventBus();
```

---

# Consumindo

```javascript
eventBus.on(EVENTS.SEARCH)
.subscribe(search => {

    console.log(search);

});
```

---

# Emitindo

```javascript
eventBus.emit(
    EVENTS.SEARCH,
    {
        escola,
        municipio
    }
);
```

Observe que nenhum componente conhece RxJS.

---

# O próximo passo: middlewares

Uma coisa extremamente útil é transformar o EventBus em um "middleware pipeline", semelhante ao Redux.

Exemplo:

```javascript
eventBus.use(logger);

eventBus.use(analytics);

eventBus.use(cache);

eventBus.use(permissionChecker);
```

Internamente:

```
emit()

↓

logger

↓

analytics

↓

cache

↓

subject.next()
```

Assim você consegue registrar logs de todos os eventos sem modificar nenhum componente.

---

# Outra melhoria: eventos como objetos

Em vez de emitir apenas um payload, eu padronizaria o formato:

```javascript
eventBus.emit(EVENTS.SEARCH, {

    escola,

    municipio

});
```

Internamente, o evento fica:

```javascript
{
    id: crypto.randomUUID(),

    type: EVENTS.SEARCH,

    payload: {
        escola,
        municipio
    },

    timestamp: Date.now(),

    source: "SchoolSearchForm"
}
```

Depois fica fácil fazer auditoria.

---

# Uma API ainda mais rica

Eu provavelmente faria algo assim:

```javascript
eventBus.emit(type, payload);

eventBus.on(type);

eventBus.once(type);

eventBus.off(subscription);

eventBus.events();

eventBus.use(middleware);

eventBus.destroy();
```

E ainda:

```javascript
eventBus.waitFor(EVENTS.SEARCH);
```

que retornaria uma `Promise`:

```javascript
await eventBus.waitFor(EVENTS.SEARCH);
```

Isso é muito útil em testes.

---

## Eu adicionaria também `request()` para comandos

Uma evolução interessante é separar **eventos** de **requisições**. Eventos representam algo que aconteceu ("SearchExecuted", "PageChanged"), enquanto requisições representam uma intenção ("ExecuteSearch"). Você pode refletir isso na API:

```javascript
await eventBus.request(COMMANDS.SEARCH, {
    escola,
    municipio
});
```

Internamente, o `request()` pode usar operadores como `switchMap`, aguardar uma resposta e retornar uma `Promise`. Isso aproxima o barramento de padrões como CQRS, mas sem introduzir muita complexidade.

## Minha recomendação

Eu implementaria o `EventBus` em **três fases**:

1. **Fase 1 (simples):** `emit()`, `on()`, `events()` — suficiente para começar.
2. **Fase 2:** adicionar `use()`, `once()`, `destroy()`, `waitFor()` e metadados (`id`, `timestamp`, `source`).
3. **Fase 3:** introduzir `request()`/`reply()` para operações assíncronas mais sofisticadas.

Dessa forma você começa com uma API pequena e estável, mas já prepara o terreno para que o EduMaps tenha um barramento de eventos realmente reutilizável e bem integrado ao RxJS, sem que os componentes precisem conhecer a biblioteca.
