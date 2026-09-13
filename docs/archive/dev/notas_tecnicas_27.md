Ótimo! Vamos estruturar um **Role `Paginable`** que fornece um mecanismo de paginação reutilizável para qualquer classe que possua um método `search` (como um `ResultSet` do DBIC) ou mesmo para coleções em memória (como no seu `TestResultSet`). A ideia é que esse role se integre naturalmente com o `Observable` que você já criou, permitindo que você **encadeie** paginação com observables e operadores do RxPerl.

---

## 🧩 Design do Role `Paginable`

### Objetivos
- Adicionar atributos `page` (página atual) e `per_page` (itens por página).
- Fornecer métodos para navegar entre páginas (`first_page`, `last_page`, `next_page`, `previous_page`).
- Calcular `total_entries` (total de registros) e retornar um objeto `Data::Page` para metadados.
- Aplicar a paginação **no nível da consulta** (server‑side) quando possível (usando `page` e `rows` do DBIC).
- Ser **imutável**: cada chamada que altera a página ou o tamanho retorna uma **nova instância** com os novos parâmetros.
- Ser combinável com o `Observable` já existente, para que você possa obter um observable que emita os itens da página atual.

---

## 📦 Implementação do Role `EduMaps::Model::Role::Paginable`

```perl
package EduMaps::Model::Role::Paginable;
use Mojo::Base -role, -signatures;
use Data::Page;

# Atributos – valores padrão
has page     => 1;
has per_page => 10;

# Este método é o coração: retorna a consulta paginada.
# A classe que consome o role deve ter um método 'search' que aceite
# condições e atributos (como no DBIC). Se não, você pode sobrescrever
# este método na classe concreta.
sub paginated_search ($self, $cond = {}, $attrs = {}) {
    # Mescla os atributos de paginação com os fornecidos
    my %pagination_attrs = (
        page => $self->page,
        rows => $self->per_page,
    );
    # Se a classe tiver um método 'search', usamos ele
    # Senão, assumimos que a classe implementa uma busca própria
    if ($self->can('search')) {
        return $self->search($cond, { %$attrs, %pagination_attrs });
    }
    else {
        # Fallback para coleções em memória – você pode especializar
        croak "A classe que consome Paginable precisa implementar 'search'";
    }
}

# Retorna o total de registros (sem paginação)
sub total_entries ($self) {
    # Se a classe tem 'search', fazemos uma contagem
    if ($self->can('search')) {
        return $self->search({}, { select => [ { count => '*' } ], as => ['count'] })->single->get_column('count');
    }
    # Fallback para coleções em memória: supor que a classe tem um método 'count'
    elsif ($self->can('count')) {
        return $self->count;
    }
    else {
        croak "A classe que consome Paginable precisa implementar 'count' ou 'search'";
    }
}

# Retorna um objeto Data::Page com os metadados da página atual
sub pager ($self) {
    my $total = $self->total_entries;
    my $pager = Data::Page->new;
    $pager->total_entries($total);
    $pager->entries_per_page($self->per_page);
    $pager->current_page($self->page);
    return $pager;
}

# Métodos de navegação – todos retornam uma NOVA instância com a página alterada
sub first_page ($self) {
    return $self->new( page => 1, per_page => $self->per_page );
}
sub last_page ($self) {
    my $pager = $self->pager;
    return $self->new( page => $pager->last_page, per_page => $self->per_page );
}
sub next_page ($self) {
    my $pager = $self->pager;
    return $self->new( page => $pager->next_page || $pager->current_page, per_page => $self->per_page );
}
sub previous_page ($self) {
    my $pager = $self->pager;
    return $self->new( page => $pager->previous_page || 1, per_page => $self->per_page );
}

# Ajusta o tamanho da página – retorna nova instância com per_page alterado
sub with_per_page ($self, $new_per_page) {
    return $self->new( page => $self->page, per_page => $new_per_page );
}

# Combinação com Observable: retorna um observable que emite os itens da página atual
sub to_observable_paginated ($self) {
    # Usa o role Observable se estiver disponível
    if ($self->can('to_observable')) {
        # Obtém os itens da página atual e os transforma em observable
        my $items = $self->paginated_search->all;  # assume que retorna uma lista de objetos
        # Cria um observable a partir do arrayref
        return rx_from($items);
    }
    else {
        croak "O role Observable deve ser consumido para usar to_observable_paginated";
    }
}

1;
```

---

## 🔄 Como usar com `Observable` e DBIC

Suponha que você tenha uma classe `MyApp::Schema::ResultSet::User` que já consome `Observable` (ou que tenha `next`/`reset`). Agora vamos adicionar `Paginable`:

```perl
package MyApp::Schema::ResultSet::User;
use Mojo::Base -base;
use Role::Tiny::With;

# Consome os dois roles
with 'EduMaps::Model::Role::Observable';
with 'EduMaps::Model::Role::Paginable';

# ... (a classe já tem o método 'search' herdado do DBIC)
```

Agora você pode:

```perl
my $users_rs = $schema->resultset('User');

# Define página e itens por página
my $paginated = $users_rs->with_per_page(20)->page(3);

# Obtém os registros da página 3
my @users = $paginated->paginated_search->all;

# Ou, se quiser um observable que emita esses registros um a um:
my $obs = $paginated->to_observable;  # do role Observable, emitirá cada usuário
$obs->subscribe( sub { say $_[0]->name } );

# Ou, se quiser um observable que emita a página inteira como um arrayref:
my $page_obs = $paginated->to_observable_paginated;  # usa rx_from para emitir cada item
# (ou você pode modificar para emitir o arrayref inteiro)
```

---

## 🧪 Teste para o `Paginable` (usando a mesma estrutura de `Imports`)

Crie `t/02-models/role/paginable.t`:

```perl
use strict;
use warnings;
use lib qw(t/lib lib);
use Imports;

# Classe de teste que consome ambos os roles
package TestResultSet {
    use Mojo::Base -base;
    use Role::Tiny::With;

    has data => sub { [ 1 .. 100 ] };
    has index => 0;

    # Métodos exigidos pelo Observable
    sub next {
        my $self = shift;
        return $self->data->[ $self->{index}++ ];
    }
    sub reset {
        my $self = shift;
        $self->index(0);
    }

    # Método de busca simulada para o Paginable
    sub search {
        my ($self, $cond, $attrs) = @_;
        # Simples: retorna uma nova instância com os atributos de paginação
        my $page = $attrs->{page} // $self->page;
        my $rows = $attrs->{rows} // $self->per_page;
        # Cria uma nova instância com os dados filtrados (apenas para teste)
        my $start = ($page - 1) * $rows;
        my $end   = $start + $rows - 1;
        my @slice = @{ $self->data }[ $start .. $end ];
        return TestResultSet->new( data => \@slice, index => 0 );
    }

    # Método de contagem para o Paginable
    sub count {
        my $self = shift;
        return scalar @{ $self->data };
    }

    # Consome os roles
    with 'EduMaps::Model::Role::Observable';
    with 'EduMaps::Model::Role::Paginable';
}

# Testes
my $rs = TestResultSet->new( data => [ 1 .. 100 ] );

subtest 'paginação básica' => sub {
    my $paginated = $rs->with_per_page(10)->page(3);
    my $result = $paginated->paginated_search;
    is( $result->count, 10, 'retornou 10 itens' );
    is_deeply( $result->data, [ 21 .. 30 ], 'itens corretos (página 3)' );
};

subtest 'metadados do pager' => sub {
    my $paginated = $rs->with_per_page(15)->page(2);
    my $pager = $paginated->pager;
    is( $pager->total_entries, 100, 'total correto' );
    is( $pager->entries_per_page, 15, 'itens por página' );
    is( $pager->current_page, 2, 'página atual' );
    is( $pager->last_page, 7, 'última página' );  # ceil(100/15) = 7
};

subtest 'navegação entre páginas' => sub {
    my $paginated = $rs->with_per_page(20)->page(4);
    my $next = $paginated->next_page;
    is( $next->page, 5, 'próxima página' );
    my $prev = $paginated->previous_page;
    is( $prev->page, 3, 'página anterior' );
    my $first = $paginated->first_page;
    is( $first->page, 1, 'primeira página' );
    my $last = $paginated->last_page;
    is( $last->page, 5, 'última página (100/20=5)' );
};

subtest 'integração com Observable' => sub {
    my $paginated = $rs->with_per_page(5)->page(2);
    my @received;
    $paginated->to_observable->subscribe(
        sub { push @received, $_[0] },
        sub { fail("Erro") },
        sub { pass("Completou") }
    );
    # O Observable usa o método next que itera sobre data, que já está paginado
    is_deeply( \@received, [ 6 .. 10 ], 'observable emitiu os itens da página 2' );
};

done_testing;
```

---

## 🧠 Explicação do "pipe" com RxPerl

Você perguntou sobre "estruturar um pipe para as buscas". Com o role `Paginable`, você pode facilmente combinar com operadores RxPerl para, por exemplo:

- Transformar a saída paginada com `op_map`.
- Filtrar itens com `op_filter`.
- Combinar várias páginas com `op_merge_map`.

Exemplo:

```perl
my $obs = $rs->with_per_page(20)->page(1)->to_observable;
$obs->pipe(
    op_filter(sub { $_[0]->age > 18 }),
    op_map(sub { $_[0]->name }),
)->subscribe(sub { say "Adulto: $_[0]" });
```

Se quiser **páginas como fluxo** (cada página é um arrayref), você pode criar um observable que emite uma página por vez usando `rx_generate` ou `rx_defer`:

```perl
sub pages_observable ($self) {
    my $pager = $self->pager;
    rx_generate(
        1, # página inicial
        sub ($page) { $page <= $pager->last_page },
        sub ($page) { $page + 1 },
        sub ($page) { $self->with_per_page($self->per_page)->page($page)->paginated_search->all },
    );
}
```

Assim, você tem um fluxo reativo de páginas.

---

## ✅ Conclusão

O **Role `Paginable`** que propus:
- É **independente de banco** – pode ser usado com DBIC ou coleções em memória.
- Oferece **imutabilidade** e **fluência**.
- **Integra-se perfeitamente** com o `Observable` que você já tem.
- Permite construir **pipes reativos** com paginação server‑side.

Você pode adaptar a implementação do `search` e `count` conforme a sua classe base. No DBIC, eles já existem, então o role funciona sem modificações.

Caso prefira uma abordagem mais "pura" de RxPerl (client‑side pagination), você poderia usar `op_skip` e `op_take` diretamente no observable – mas isso traz todos os registros para o cliente, o que não é recomendado para grandes conjuntos. O server‑side com `page`/`rows` é muito mais eficiente.

Se precisar de ajustes ou tiver dúvidas sobre a implementação, é só falar! 🚀
Perfeito! Vamos então montar o mecanismo completo de paginação server-side com **DBIx::Class + Role::Paginable** no backend Perl, e no frontend **Svelte + RxJS** para gerenciar o fluxo de busca com paginação.

---

## 🧩 Backend: Servidor Mojolicious com Paginable

Assumindo que você já tem o role `EduMaps::Model::Role::Paginable` (como definido anteriormente) e que seu `ResultSet` de `School` o consome, vamos criar o endpoint da API.

### 1. Controller da API

```perl
# lib/EduMaps/Controller/API/School.pm
package EduMaps::Controller::API::School;
use Mojo::Base 'Mojolicious::Controller';

sub search {
    my $c = shift;

    # Parâmetros da requisição
    my $q        = $c->param('q')        // '';
    my $page     = $c->param('page')     // 1;
    my $per_page = $c->param('per_page') // 10;

    # Inicia o resultset
    my $rs = $c->schema->resultset('School');

    # Aplica filtro de busca (exemplo: nome ou município)
    if ($q) {
        $rs = $rs->search({
            -or => [
                name      => { -like => "%$q%" },
                municipio => { -like => "%$q%" },
            ]
        });
    }

    # Aplica paginação (usando o role Paginable)
    $rs = $rs->with_per_page($per_page)->page($page);

    # Obtém os dados (como hashrefs para JSON)
    my @data = map { $_->TO_JSON } $rs->all;

    # Metadados via Data::Page
    my $pager = $rs->pager;

    $c->render(json => {
        data => \@data,
        meta => {
            current_page => $pager->current_page,
            per_page     => $pager->entries_per_page,
            total_entries => $pager->total_entries,
            last_page    => $pager->last_page,
        }
    });
}

1;
```

### 2. Rota no Mojolicious

```perl
# lib/EduMaps/Plugin/Routes.pm (ou no startup)
$r->get('/api/schools')->to('API::School#search');
```

---

## 🧩 Frontend: Svelte + RxJS

### 1. Instalação
```bash
npm install rxjs
```

### 2. API Client (`src/features/schools/api/schoolApi.js`)

```javascript
import { from } from 'rxjs';
import { switchMap, map, catchError } from 'rxjs/operators';

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Função que retorna uma Promise
export async function searchSchools(params) {
  const url = new URL('/api/schools', window.location.origin);
  Object.entries(params).forEach(([key, val]) => {
    if (val != null && val !== '') url.searchParams.append(key, val);
  });

  const res = await fetch(url);
  if (!res.ok) {
    const errData = await res.json().catch(() => ({}));
    throw new ApiError(res.status, errData.message || res.statusText);
  }
  return res.json();
}

// Versão RxJS (retorna Observable)
export function searchSchoolsRx(params) {
  const url = new URL('/api/schools', window.location.origin);
  Object.entries(params).forEach(([key, val]) => {
    if (val != null && val !== '') url.searchParams.append(key, val);
  });

  return from(fetch(url)).pipe(
    switchMap(async (res) => {
      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        throw new ApiError(res.status, errData.message || res.statusText);
      }
      return res.json();
    }),
    catchError((err) => {
      if (err instanceof ApiError) throw err;
      throw new ApiError(500, 'Erro inesperado');
    })
  );
}
```

### 3. Store Reativa (`src/features/schools/stores/schoolSearchStore.js`)

```javascript
import { BehaviorSubject, combineLatest, of } from 'rxjs';
import {
  debounceTime,
  distinctUntilChanged,
  switchMap,
  catchError,
  map,
  shareReplay,
  startWith
} from 'rxjs/operators';
import { searchSchoolsRx } from '../api/schoolApi';

// Estado inicial dos parâmetros
const DEFAULT_PARAMS = { q: '', page: 1, per_page: 10 };

// Subject para os parâmetros de busca
const params$ = new BehaviorSubject({ ...DEFAULT_PARAMS });

// Subject para forçar recarga (ex: após erro)
const reloadTrigger$ = new BehaviorSubject(null);

// Observable do resultado da busca
export const searchResult$ = combineLatest([
  params$.pipe(
    debounceTime(300),
    distinctUntilChanged((a, b) =>
      a.q === b.q && a.page === b.page && a.per_page === b.per_page
    )
  ),
  reloadTrigger$
]).pipe(
  map(([params]) => params),
  switchMap((params) =>
    searchSchoolsRx(params).pipe(
      map((response) => ({
        data: response.data || [],
        meta: response.meta || null,
        error: null,
        loading: false
      })),
      catchError((err) =>
        of({
          data: [],
          meta: null,
          error: err.message || 'Erro desconhecido',
          loading: false
        })
      ),
      startWith({ data: [], meta: null, error: null, loading: true })
    )
  ),
  shareReplay(1)
);

// Ações para atualizar parâmetros
export function setSearchQuery(q) {
  const current = params$.value;
  params$.next({ ...current, q, page: 1 }); // reset para página 1
}

export function goToPage(page) {
  const current = params$.value;
  params$.next({ ...current, page });
}

export function setPerPage(per_page) {
  const current = params$.value;
  params$.next({ ...current, per_page, page: 1 });
}

export function reload() {
  reloadTrigger$.next(null);
}

// Para obter o valor atual dos parâmetros (síncrono)
export function getCurrentParams() {
  return params$.value;
}
```

### 4. Componente Svelte (`SchoolSearchPage.svelte`)

```svelte
<script>
  import { onDestroy } from 'svelte';
  import SchoolSearchForm from '../components/SchoolSearchForm.svelte';
  import SchoolList from '../components/SchoolList.svelte';
  import {
    searchResult$,
    setSearchQuery,
    goToPage,
    setPerPage,
    reload
  } from '../stores/schoolSearchStore.js';

  // Estado local reativo (Svelte 5 runes)
  let result = $state({ data: [], meta: null, loading: false, error: null });
  let subscription;

  // Inscreve-se no observable
  onDestroy(() => {
    if (subscription) subscription.unsubscribe();
  });

  subscription = searchResult$.subscribe((value) => {
    result = value;
  });

  // Handlers
  function handleSearch({ escola, municipio }) {
    // Aqui você pode combinar escola e municipio em um único termo 'q'
    // ou tratar separadamente. Exemplo:
    const query = escola || municipio || '';
    setSearchQuery(query);
  }

  function handleClear() {
    setSearchQuery('');
    // Opcional: resetar para página 1 (já feito no setSearchQuery)
  }

  function onPageChange(newPage) {
    goToPage(newPage);
  }

  function onPerPageChange(newPerPage) {
    setPerPage(newPerPage);
  }
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Busca de Escolas</h1>
    <p class="text-gray-600 text-sm mt-1">Encontre escolas pelo nome ou município.</p>
  </header>

  <SchoolSearchForm
    loading={result.loading}
    onSearch={handleSearch}
    onClear={handleClear}
  />

  <SchoolList
    schools={result.data}
    meta={result.meta}
    loading={result.loading}
    error={result.error}
    hasSearched={true}
    onPageChange={onPageChange}
    onPerPageChange={onPerPageChange}
  />
</div>
```

### 5. Componente `SchoolList.svelte` com paginação

```svelte
<script>
  export let schools = [];
  export let meta = null; // { current_page, per_page, total_entries, last_page }
  export let loading = false;
  export let error = null;
  export let hasSearched = false;

  export let onPageChange = () => {};
  export let onPerPageChange = () => {};

  const perPageOptions = [5, 10, 20, 50];
</script>

{#if loading}
  <div class="text-center py-8">
    <span class="text-gray-500">Carregando...</span>
  </div>
{:else if error}
  <div class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
    {error}
  </div>
{:else if !hasSearched}
  <p class="text-gray-400 text-center py-8">
    Realize uma busca para encontrar escolas.
  </p>
{:else if schools.length === 0}
  <p class="text-gray-500 text-center py-8">
    Nenhuma escola encontrada para essa busca.
  </p>
{:else}
  <ul class="divide-y divide-gray-200">
    {#each schools as school (school.id)}
      <li class="py-4">
        <h3 class="font-medium text-gray-900">{school.name}</h3>
        <p class="text-sm text-gray-600">{school.municipio}</p>
        <!-- mais campos -->
      </li>
    {/each}
  </ul>

  <!-- Controles de paginação -->
  {#if meta && meta.last_page > 1}
    <div class="flex flex-col sm:flex-row items-center justify-between gap-4 mt-6 pt-4 border-t border-gray-200">
      <div class="flex items-center gap-2">
        <button
          class="px-3 py-1 border rounded disabled:opacity-50"
          disabled={meta.current_page <= 1}
          on:click={() => onPageChange(meta.current_page - 1)}
        >
          Anterior
        </button>
        <span class="text-sm text-gray-700">
          Página {meta.current_page} de {meta.last_page}
        </span>
        <button
          class="px-3 py-1 border rounded disabled:opacity-50"
          disabled={meta.current_page >= meta.last_page}
          on:click={() => onPageChange(meta.current_page + 1)}
        >
          Próxima
        </button>
      </div>

      <div class="flex items-center gap-2 text-sm">
        <label for="per_page" class="text-gray-600">Itens por página:</label>
        <select
          id="per_page"
          class="border rounded px-2 py-1"
          value={meta.per_page}
          on:change={(e) => onPerPageChange(Number(e.target.value))}
        >
          {#each perPageOptions as opt}
            <option value={opt}>{opt}</option>
          {/each}
        </select>
      </div>
    </div>
  {/if}
{/if}
```

---

## 🧠 Como tudo se conecta

1. **Usuário interage** com o formulário de busca → dispara `handleSearch`.
2. `setSearchQuery` atualiza o `params$` com novo termo e reseta para página 1.
3. O `params$` passa por `debounceTime(300)` e `distinctUntilChanged` – só emite quando os parâmetros mudarem de fato.
4. `switchMap` cancela requisições anteriores e chama `searchSchoolsRx`.
5. O observable resultante emite estados: `{ loading: true }`, depois `{ data, meta, error: null, loading: false }` ou `{ data: [], error, loading: false }`.
6. O componente Svelte está inscrito e atualiza o estado reativo `result` com o último valor.
7. A UI exibe os dados e os controles de paginação. Ao clicar em "Próxima", chama `goToPage`, atualiza os parâmetros e o fluxo se repete.

---

## 🔁 Comunicação servidor ↔ cliente

- **Requisição**: `GET /api/schools?q=escola&page=2&per_page=20`
- **Resposta**:
```json
{
  "data": [ ... ],
  "meta": {
    "current_page": 2,
    "per_page": 20,
    "total_entries": 100,
    "last_page": 5
  }
}
```
- O servidor usa o **Role Paginable** para aplicar `page` e `rows` no DBIC e retorna os metadados via `pager`.

---

## ✅ Vantagens dessa abordagem

- **Server‑side pagination** – eficiente e escalável.
- **Reatividade** – com RxJS gerenciamos debounce, concorrência e estados de loading/erro de forma declarativa.
- **Desacoplamento** – o store é independente do componente; fácil de testar.
- **Flexibilidade** – permite alterar tamanho de página e navegação com poucas linhas de código.
- **Integração com Svelte 5** – usando `$state` e inscrição manual, mantendo a reatividade.

---

## 🧪 Extras

- **Cache**: você pode adicionar um operador `shareReplay` com buffer para evitar chamadas repetidas para mesma página.
- **Validação**: no servidor, valide `page` e `per_page` para evitar valores inválidos.
- **Ordenação**: adicione parâmetros `sort_by` e `order` na API e aplique no resultset antes da paginação.

Se precisar de mais detalhes em qualquer parte, é só avisar! 🚀

# Lições
Excelente notícia! Que bom que a suíte de testes passou e os componentes reativos estão redondos.

A transição de componentes clássicos para as **Runes e Snippets do Svelte 5** traz um ganho enorme em performance e previsibilidade, mas exige uma mudança de mentalidade na sintaxe.

Abaixo está um resumo executivo dos problemas enfrentados, como preveni-los e boas práticas para componentes genéricos.

---

## 📌 Guia de Sobrevivência: Svelte 5 (Runes & Snippets)

### 1. Colisão de Nomes (*Snippet Shadowing*)

* **O Erro:** `This snippet is shadowing the prop with the same name`
* **Por que acontece?** No Svelte 5, o analisador estático declara as props desestruturadas em `$props()` no escopo superior do componente. Tentar declarar um `{#snippet loading()}` quando a chave `loading` já existe na interface do componente faz o compilador travar.
* **Como evitar:**
* Nomeie props de snippets de forma explícita com sufixos, como `loadingSnippet`, `emptySnippet`, `itemSnippet`.
* Garanta que o contrato da interface (`$props()`) diferencie o **estado** (booleano `loading`) da **renderização** (função/snippet `loadingSnippet`).



---

### 2. Execução Segura de Snippets Opcionais

* **O Erro:** `TypeError: snippet is not a function`
* **Por que acontece?** Ao contrário dos slots legados (`<slot />`), snippets no Svelte 5 são tratados como funções de primeira classe. Se um snippet for opcional e o componente pai não o fornecer, a propriedade será `undefined`. Tentar renderizá-lo com `{@render mySnippet()}` lança uma exceção fatal de runtime.
* **Como evitar:**
* Sempre utilize o operador de navegação segura (*optional chaining*) na chamada de renderização:
```svelte
{@render loadingSnippet?.()}
{@render errorSnippet?.({ error })}

```





---

### 3. Palavras Reservadas no Parser JS

* **O Erro:** `'default' is a reserved word in JavaScript and cannot be used here`
* **Por que acontece?** Como os snippets usam a sintaxe de desestruturação e parâmetros do JavaScript, usar `{#snippet default}` entra em conflito com o parser do JS.
* **Como evitar:**
* Em substituição ao slot `default` do Svelte 4, o Svelte 5 adota por padrão a prop/snippet chamada **`children`**.
* Use `{#snippet children({ item })}` ou injete o conteúdo diretamente no corpo do componente pai para que ele seja interpretado implicitamente como `children`.



---

### 4. RxJS / Observables e Limpeza de Memória

* **O Erro:** `TypeError: unsubscribe is not a function`
* **Por que acontece?** O método `.subscribe()` do RxJS retorna um objeto **`Subscription`**, e não uma função callback. Tentar executar `unsubscribe()` como se fosse uma função estoura no `onDestroy`.
* **Como evitar:**
* Invoque o método dentro do objeto: `subscription.unsubscribe()`.
* Em componentes Svelte, considere converter o Observable para uma Svelte Store (com `readable` / `derived`) ou usar a sintaxe auto-subscription (`$stream`), deixando a gestão do ciclo de vida a cargo do Svelte.



---

## 🏗️ Conclusão: Arquitetura de Componentes Genéricos

A refatoração do `PageableList.svelte` (shared) para o `SchoolReactiveList.svelte` (feature) é um excelente exemplo da aplicação do **Princípio da Responsabilidade Única (SRP)** na UI:

1. **Separação de Preocupações (SoC):**
* **`PageableList` (Genérico/Agnóstico):** Deve gerenciar puramente a *estrutura*, o *layout de estados* (loading, error, empty) e os *controles de paginação*. Ele não conhece a regra de negócio da aplicação nem o tipo de dado exibido.
* **`SchoolReactiveList` (Específico de Domínio):** Conecta o componente genérico ao contexto de negócio (Escolas), fornecendo as regras de validação visual e delegando a apresentação das entidades para componentes atômicos como o `SchoolCard`.


2. **Adoção do Svelte 5 em Componentes da UI:**
* Usar Snippets como props transforma a composição de UI em uma troca clara de funções de renderização parametrizadas, tornando testes unitários muito mais previsíveis.
* Manter a biblioteca de componentes genéricos padronizada com a nova API garante consistência em toda a aplicação (EduMaps) à medida que novas listagens e tabelas forem introduzidas.
