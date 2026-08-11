<!-- src/shared/ui/components/InputAutocomplete.svelte -->
<script>
  // Combobox de autocomplete genérico. RxJS é usado só internamente, pra
  // resolver dois problemas que texto puro não resolve bem:
  //   1) debounce — não bater na API a cada tecla;
  //   2) respostas fora de ordem — se o usuário digita rápido, uma
  //      resposta antiga (da busca por "a") pode chegar DEPOIS de uma
  //      mais nova (busca por "abc") e sobrescrever o resultado certo.
  //      switchMap cancela a busca anterior assim que uma nova começa,
  //      resolvendo isso de graça.
  //
  // A API pública é só props/callbacks — quem usa este componente nunca
  // importa RxJS nem sabe que ele existe aqui dentro.

  import { Subject, from, of } from "rxjs";
  import { debounceTime, distinctUntilChanged, switchMap, catchError, tap, map } from "rxjs/operators";

  /**
   * @typedef {Object} Props
   * @property {string} [value] - bindable: texto atual do campo
   * @property {(query: string) => Promise<any[]>} fetchSuggestions - busca as sugestões; específico de cada uso (escola, município...)
   * @property {number} [minLength] - tamanho mínimo do texto pra disparar a busca
   * @property {number} [debounceMs]
   * @property {string} id
   * @property {string} label
   * @property {string} [placeholder]
   * @property {boolean} [disabled]
   * @property {string} [noResultsText]
   * @property {(option: any) => string} [getOptionLabel] - texto de exibição de uma sugestão
   * @property {(option: any) => string|number} [getOptionKey] - chave única de cada sugestão
   * @property {(query: string) => void} [onQueryChange] - toda vez que uma busca (já debounced) é disparada
   * @property {(option: any) => void} [onSelect] - usuário escolheu uma sugestão
   * @property {() => void} [onClear]
   * @property {(error: Error) => void} [onError]
   */

  /** @type {Props} */
  let {
    value = $bindable(""),
    fetchSuggestions,
    minLength = 3,
    debounceMs = 300,
    id,
    label,
    placeholder = "",
    disabled = false,
    noResultsText = "Nenhum resultado encontrado",
    getOptionLabel = (option) => String(option),
    getOptionKey = (option) => option?.id ?? String(option),
    onQueryChange,
    onSelect,
    onClear,
    onError,
    option: optionSnippet,
  } = $props();

  let suggestions = $state([]);
  let isOpen = $state(false);
  let loading = $state(false);
  let error = $state(null);
  let activeIndex = $state(-1);

  const query$ = new Subject();
  const listboxId = `${id}-listbox`;

  $effect(() => {
    const subscription = query$
      .pipe(
        tap(() => {
          loading = true;
          error = null;
        }),
        debounceTime(debounceMs),
        distinctUntilChanged(),
        tap((query) => onQueryChange?.(query)),
        switchMap((query) => {
          if (query.trim().length < minLength) {
            return of({ results: [], searched: false });
          }
          return from(Promise.resolve(fetchSuggestions(query))).pipe(
            map((results) => ({ results, searched: true })),
            catchError((err) => {
              const normalizedError = err instanceof Error ? err : new Error(String(err));
              error = normalizedError.message;
              onError?.(normalizedError);
              return of({ results: [], searched: true });
            })
          );
        })
      )
      .subscribe(({ results, searched }) => {
        suggestions = results;
        loading = false;
        // isOpen abre tanto pra mostrar resultados quanto pra mostrar
        // "nenhum resultado encontrado" — só não abre se a busca nem
        // chegou a rodar (texto abaixo do mínimo).
        isOpen = searched;
        activeIndex = -1;
      });

    return () => subscription.unsubscribe();
  });

  function handleInput(event) {
    value = event.target.value;
    query$.next(value);
  }

  function handleClear() {
    value = "";
    suggestions = [];
    isOpen = false;
    error = null;
    onClear?.();
  }

  function selectOption(selectedOption) {
    value = getOptionLabel(selectedOption);
    suggestions = [];
    isOpen = false;
    activeIndex = -1;
    onSelect?.(selectedOption);
  }

  function handleKeydown(event) {
    if (event.key === "Escape") {
      isOpen = false;
      activeIndex = -1;
      return;
    }

    if (!isOpen || suggestions.length === 0) return;

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        activeIndex = Math.min(activeIndex + 1, suggestions.length - 1);
        break;
      case "ArrowUp":
        event.preventDefault();
        activeIndex = Math.max(activeIndex - 1, 0);
        break;
      case "Enter":
        if (activeIndex >= 0) {
          event.preventDefault();
          selectOption(suggestions[activeIndex]);
        }
        break;
    }
  }

  // mousedown (não click) registra a seleção ANTES do blur do input
  // fechar a lista — padrão clássico de combobox, sem isso o blur
  // fecharia a lista antes do clique no item ser processado.
  function handleOptionMouseDown(event, selectedOption) {
    event.preventDefault();
    selectOption(selectedOption);
  }

  function handleClearMouseDown(event) {
    event.preventDefault();
    handleClear();
  }

  function handleBlur() {
    isOpen = false;
  }

  function handleFocus() {
    if (suggestions.length > 0) isOpen = true;
  }
</script>

<div class="input-autocomplete">
  <label for={id} class="block text-sm font-medium text-gray-700 mb-1">{label}</label>

  <div class="relative">
    <input
      {id}
      type="text"
      role="combobox"
      autocomplete="off"
      aria-autocomplete="list"
      aria-expanded={isOpen}
      aria-controls={listboxId}
      aria-activedescendant={activeIndex >= 0 ? `${listboxId}-option-${activeIndex}` : undefined}
      {placeholder}
      {disabled}
      {value}
      oninput={handleInput}
      onkeydown={handleKeydown}
      onfocus={handleFocus}
      onblur={handleBlur}
      class="w-full px-3 py-2 pr-8 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
    />

    {#if value && !disabled}
      <button
        type="button"
        aria-label="Limpar {label}"
        onmousedown={handleClearMouseDown}
        class="absolute right-2 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
      >
        ✕
      </button>
    {/if}

    {#if loading}
      <p class="mt-1 text-xs text-gray-500">Buscando…</p>
    {/if}

    {#if isOpen}
      <ul
        id={listboxId}
        role="listbox"
        class="absolute z-10 mt-1 w-full bg-white border border-gray-200 rounded-md shadow-lg max-h-60 overflow-auto"
      >
        {#if suggestions.length === 0}
          <li class="px-3 py-2 text-sm text-gray-500">{noResultsText}</li>
        {:else}
          {#each suggestions as suggestion, index (getOptionKey(suggestion))}
            <li
              id="{listboxId}-option-{index}"
              role="option"
              aria-selected={index === activeIndex}
              onmousedown={(event) => handleOptionMouseDown(event, suggestion)}
              class="px-3 py-2 text-sm cursor-pointer {index === activeIndex
                ? 'bg-brand-50 text-brand-700'
                : 'hover:bg-gray-50'}"
            >
              {#if optionSnippet}
                {@render optionSnippet(suggestion, index)}
              {:else}
                {getOptionLabel(suggestion)}
              {/if}
            </li>
          {/each}
        {/if}
      </ul>
    {/if}
  </div>

  {#if error}
    <p class="mt-1 text-xs text-red-600">{error}</p>
  {/if}
</div>
