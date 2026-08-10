<script>
  // src/features/schools/components/SchoolSearchForm.svelte
  import { eventBus } from "@/shared/events";
  import { SCHOOL_EVENTS } from "../constants/events.js";

  /**
   * @typedef {Object} Props
   * @property {boolean} [loading]
   * @property {(filters: { escola: string, municipio: string }) => void} [onSearch] -
   *   chamado direto pelo pai (SchoolSearchPageRx) pra orquestrar a busca de fato.
   * @property {() => void} [onClear]
   */

  /** @type {Props} */
  let { loading = false, onSearch, onClear } = $props();

  let nomeEscola = $state("");
  let municipio = $state("");

  // Espelha a validação do backend (qr/.{3,100}/) só como hint de UX —
  // o servidor continua sendo a fonte de verdade da validação real.
  let canSubmit = $derived(nomeEscola.trim().length >= 3 || municipio.trim().length >= 3);

  function handleSubmit(event) {
    event.preventDefault();
    if (!canSubmit) return;

    const filters = { escola: nomeEscola.trim(), municipio: municipio.trim() };

    // eventBus: para quem, fora desta árvore de componentes, precisa
    // saber que "uma busca de escola aconteceu" sem se acoplar a este
    // formulário — ex.: o mapa recentralizando no município buscado.
    eventBus.emit(SCHOOL_EVENTS.SEARCH, filters, { source: "SchoolSearchForm" });

    // callback prop: para o pai direto orquestrar a busca (chamar a API,
    // atualizar paginação). É uma relação 1:1 pai/filho — prop é mais
    // simples e mais fácil de testar do que ir e voltar pelo bus pra isso.
    onSearch?.(filters);
  }

  function handleClear() {
    nomeEscola = "";
    municipio = "";

    eventBus.emit(SCHOOL_EVENTS.CLEAR, undefined, { source: "SchoolSearchForm" });
    onClear?.();
  }
</script>

<form onsubmit={handleSubmit} class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
    <div>
      <label for="nome-escola" class="block text-sm font-medium text-gray-700 mb-1">
        Nome da Escola
      </label>
      <input
        id="nome-escola"
        type="text"
        bind:value={nomeEscola}
        disabled={loading}
        placeholder="Ex: Paulo Freire"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
      />
    </div>
    <div>
      <label for="municipio" class="block text-sm font-medium text-gray-700 mb-1">
        Município
      </label>
      <input
        id="municipio"
        type="text"
        bind:value={municipio}
        disabled={loading}
        placeholder="Ex: Ubatuba"
        class="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-brand-600"
      />
    </div>
  </div>
  <p class="text-xs text-gray-500 mt-2">Mínimo de 3 caracteres em pelo menos um dos campos.</p>
  <div class="flex gap-3 mt-4">
    <button
      type="submit"
      disabled={loading || !canSubmit}
      class="px-4 py-2 bg-brand-600 text-white text-sm font-medium rounded-md disabled:opacity-50 disabled:cursor-not-allowed hover:bg-brand-700 transition-colors"
    >
      {loading ? "Buscando..." : "Buscar Escolas"}
    </button>
    <button
      type="button"
      onclick={handleClear}
      disabled={loading}
      class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-50 transition-colors"
    >
      Limpar
    </button>
  </div>
</form>
