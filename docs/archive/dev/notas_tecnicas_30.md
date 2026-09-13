Esse exemplo é ainda mais interessante do que o caso hipotético que eu tinha em mente, porque vocês **já estão usando EventEmitter de uma maneira bastante natural** no backend — e, olhando o código, eu diria que o uso está conceitualmente correto.

Na verdade, há uma distinção importante: o que vocês têm aqui não é exatamente um "EventBus global". É mais próximo de **event-driven objects / local event emitters**. E para esse caso eu gosto bastante mais.

### O desenho atual

Vocês têm:

```text
EduMaps::Task::OSM::Query
          │
          │ possui
          ▼
EduMaps::Task::OSM::Service
          │
          ├── query
          ├── progress
          ├── query_data
          ├── osm_data
          └── feature
```

E `Query` se inscreve nos eventos do `Service`:

```perl
$self->_service->on(
    query_data => sub ($evt, $data) {
        $self->_save_query($data)
    }
);

$self->_service->on(
    feature => $save_feature
);
```

Isso é uma excelente aplicação de `Mojo::EventEmitter`.

O `Service` não sabe absolutamente nada sobre:

* banco;
* `OsmQuery`;
* `OsmLanduse`;
* Minion;
* como os dados serão persistidos.

Ele simplesmente diz:

> "Obtive um resultado de query."

e

> "Produzi uma feature."

Isso é desacoplamento real.

---

## O `progress` é talvez o melhor exemplo

Aqui:

```perl
$self->emit(
    progress => {
        total     => 100,
        processed => int($size / ($len / 100)),
        phase     => 'download osm'
    }
);
```

e no `Query`:

```perl
$self->_service->on(
    progress => sub ($evt, $data) {
        $self->_minion_job->note(progress => $data)
    }
);
```

Isso é muito bom arquiteturalmente.

O `Service` não sabe que existe **Minion**.

Isso significa que amanhã você pode ter:

```text
Service
   │
   └── progress
          ├── Minion
          ├── CLI progress bar
          ├── WebSocket
          ├── log
          └── metrics
```

sem alterar `Service.pm`.

Esse é exatamente o tipo de situação onde eventos começam a pagar dividendos.

---

# Há uma diferença interessante para o EventBus do frontend

No frontend:

```text
EventBus global
```

é apropriado porque os componentes são relativamente independentes:

```text
SchoolSearchForm ──┐
                   │
SchoolList ────────┼── EventBus
                   │
Toast ─────────────┘
```

No backend, nesse caso:

```text
Query ─────── Service
                │
                ├── emit
                │
                └── listeners
```

não precisamos de um bus global.

E eu **evitaria criar um EventBus global no backend neste momento**.

O `Mojo::EventEmitter` por objeto já dá uma granularidade muito boa.

---

# Uma coisa que eu mudaria conceitualmente no futuro

Vocês têm alguns eventos que parecem estar misturando duas categorias.

Por exemplo:

```perl
$self->emit(query => $q);
$self->emit(osm_data => $data);
$self->emit(query_data => $osm_data);
$self->emit(feature => $feat);
$self->emit(progress => {...});
```

Alguns são claramente **eventos de domínio/estado**:

```text
query_data
feature
progress
```

Enquanto:

```text
query
osm_data
```

parecem mais próximos de **hooks internos do processamento**.

Não é errado. Na verdade, para uma classe como `Service`, isso pode ser perfeitamente adequado.

Mas se o sistema crescer, eu faria uma distinção mental:

```text
Eventos públicos da classe
--------------------------
progress
query_data
feature
completed
failed
```

versus:

```text
detalhes internos da implementação
-----------------------------------
osm_data
internal_x
raw_response
```

Isso ajuda a evitar que consumidores externos acabem dependendo da implementação interna do `Service`.

---

# E existe uma evolução muito interessante aqui

Hoje:

```perl
$self->emit(feature => $feat);
```

e o `Query` imediatamente salva:

```perl
$self->on(feature => $save_feature);
```

Isso é essencialmente um **pipeline de processamento**:

```text
HTTP
 │
 ▼
raw OSM
 │
 ▼
parse
 │
 ▼
Feature
 │
 ├── persistência
 ├── progress
 └── outros consumidores
```

E o seu `Service` está fazendo uma coisa particularmente boa: **streaming lógico das features**.

Em vez de esperar:

```text
OSM
 ↓
processar tudo
 ↓
retornar FeatureCollection
 ↓
salvar tudo
```

ele permite:

```text
feature 1 ──→ consumidor
feature 2 ──→ consumidor
feature 3 ──→ consumidor
...
```

Isso pode ser muito valioso se no futuro vocês processarem municípios grandes ou datasets maiores.

---

## E isso conversa diretamente com o assíncrono do Mojo

O interessante é que vocês têm duas dimensões diferentes:

### Promise

Representa:

> "Estou esperando uma operação terminar."

```perl
my $data = await $self->_get_from_osm($q);
```

### EventEmitter

Representa:

> "Enquanto isso acontece, coisas estão acontecendo."

```perl
$self->emit(progress => {...});
$self->emit(feature => $feat);
```

Essa combinação é muito poderosa:

```text
             Promise
               │
               │ resultado final
               ▼
        ┌──────────────┐
        │ run_query_p  │
        └──────────────┘
          ↑     ↑    ↑
          │     │    │
       progress feature query_data
          │     │    │
          └─────┴────┘
             eventos
```

E acho que essa é a parte que vale estudar mais.

**Promise não substitui EventEmitter, e EventEmitter não substitui Promise.**

Eles respondem perguntas diferentes.

---

# Eu manteria exatamente essa filosofia no backend

Não faria:

```text
"Vamos transformar o backend em event-driven."
```

Isso seria provavelmente overengineering.

Faria:

```text
"Quando uma classe possui múltiplos consumidores independentes
de acontecimentos durante sua execução, EventEmitter é uma
boa interface de extensão."
```

E vocês já encontraram um caso perfeito para isso.

---

## Inclusive, o seu `Query` já é quase um "adapter"

Observe:

```perl
Service
   │
   │ eventos
   ▼
Query
   │
   ├── PostgreSQL
   └── Minion
```

O `Service` é especializado em **OSM/Overpass**.

O `Query` adapta esse serviço para a aplicação EduMaps.

Isso é uma separação bastante elegante:

```text
EduMaps::Task::OSM::Service
        ↓
   conhecimento de OSM

EduMaps::Task::OSM::Query
        ↓
   conhecimento de EduMaps
   + PostgreSQL
   + Minion
```

O `Service` poderia até ser utilizado em um programa completamente diferente e não precisaria saber que EduMaps existe.

---

### Só faria uma observação sobre este trecho

```perl
$self->emit(query_data => $osm_data);
```

e:

```perl
$self->_query($query);
```

Se `query_data` for consumido por vários listeners no futuro, talvez valha estabelecer uma convenção explícita para o payload:

```perl
$self->emit(
    query_data => {
        query   => $q,
        data    => $data,
        elapsed => $elapsed,
    }
);
```

Vocês já estão fazendo isso em `_get_from_osm`, então eu manteria essa ideia como contrato.

---

## E isso abre uma possibilidade muito legal para o EduMaps

Sem implementar nada agora, imagine futuramente:

```text
                    OSM Service
                         │
                         │ events
                         ▼
              ┌─────────────────────┐
              │     OSM Query       │
              └─────────────────────┘
                 │      │       │
                 │      │       │
                 ▼      ▼       ▼
               DB     Minion   Metrics
                 │
                 ▼
             PostGIS
```

Depois:

```text
              OSM Query
                  │
          query.completed
                  │
       ┌──────────┼──────────┐
       ▼          ▼          ▼
    cache       metrics    audit
```

Sem precisar transformar tudo em uma arquitetura distribuída, Kafka, RabbitMQ etc.

**É simplesmente EventEmitter dentro do processo.**

E isso é justamente o que eu acho mais interessante no seu exemplo: vocês já têm uma forma pequena, idiomática e barata de introduzir **event-driven architecture localmente**, sem pagar o custo arquitetural de transformar o sistema inteiro em EDA.

Eu diria que o próximo estudo natural, quando houver tempo, seria justamente comparar **`Mojo::EventEmitter` → Promises → Minion → WebSocket/SSE**, porque aí dá para enxergar onde termina o *event emitter intra-processo* e onde começa um verdadeiro *event-driven system*. Essa fronteira é conceitualmente muito importante.


## Expansão para AutoComplete

Bom pedido — autocomplete é exatamente o caso onde vale a pena usar RxJS de verdade: `switchMap` cancela automaticamente uma busca anterior quando o usuário já digitou de novo (sem isso, respostas fora de ordem — "resposta da letra 'a' chegando depois da resposta de 'abc'" — são um bug clássico). A diferença pro `EventBus`: aqui o RxJS fica **isolado dentro deste componente único**, nunca exposto — a API pública continua sendo só props/callbacks, como qualquer outro componente do design system.

**Sobre "eventos específicos":** decidi que isso significa callback props dedicados (`onSelect`, `onQueryChange`, `onClear`, `onError`), não o `eventBus` global. Um input de autocomplete é um átomo de UI genérico — ele não deveria conhecer nem emitir fatos no barramento da aplicação; isso ficaria acoplando `shared/ui` a semântica de features. Quem decide se uma seleção vira um evento cross-feature é quem usa o átomo (o `SchoolSearchForm`), não o átomo em si.Bom. Agora os testes, a API de sugestões da feature, e a integração no formulário.Agora integrando no formulário:Coisas pra você confirmar/ajustar (não pude verificar por não ter esses arquivos/backend):

1. **Os endpoints em `autocompleteApi.js` são um chute** (`/api/escola/sugestoes`, `/api/municipio/sugestoes`, formato `{ id, nome, municipio }` / `{ codigo_ibge, nome, uf }`) — ajuste pro contrato real do backend. Se o backend ainda não tem essas rotas de sugestão, isso é trabalho de API novo (fora do escopo Perl que já fizemos).
2. **Não rodei os testes de verdade** (não tenho o `vitest.config`/setup de vocês pra montar o ambiente aqui) — a parte que mais vale a pena conferir localmente é `InputAutocomplete.test.js`: o `debounceTime` do RxJS com `vi.useFakeTimers()`/`vi.advanceTimersByTimeAsync()` geralmente funciona bem, mas é a combinação mais sensível a peculiaridades de versão (RxJS/Vitest) — se algum teste travar ali, normalmente é isso.
3. **`@/shared/api/client.js`** — assumi de novo uma função `get(url, { params })`; ajuste se a assinatura real for outra (mesma ressalva do `chartApi.js`).
