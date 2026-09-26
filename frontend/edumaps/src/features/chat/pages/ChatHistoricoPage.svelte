<!-- src/features/chat/pages/ChatHistoricoPage.svelte -->
<script>
  import { onMount } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import {
    listConversas,
    searchConversas,
    getCalendar,
    deleteConversa,
    exportConversas,
  } from "../api/chatApi.js";
  import ChatCalendar from "../components/ChatCalendar.svelte";
  import ChatConversaList from "../components/ChatConversaList.svelte";
  import ChatExportModal from "../components/ChatExportModal.svelte";

  // ---- estado ----
  let loading = $state(false);
  let error = $state(null);
  let sessaoExpirada = $state(false);

  // lista
  let conversas = $state([]);
  let page = $state(1);
  let perPage = $state(20);
  let total = $state(0);
  let totalPages = $state(0);

  // busca
  let searchQuery = $state("");
  let searchDebounce = $state(null);
  let searchResults = $state([]);
  let searchPage = $state(1);
  let searchTotal = $state(0);
  let isSearching = $state(false);

  // calendário
  let calendarData = $state({});
  let currentMonth = $state(new Date());
  let selectedDate = $state("");

  // export
  let showExportModal = $state(false);

  // sessão
  onMount(async () => {
    if (!restaurarSessao()) {
      error = "Sessão não encontrada. Faça login novamente.";
      return;
    }
    await loadConversas();
    await loadCalendar();
  });

  async function loadConversas(resetPage = true) {
    if (resetPage) page = 1;
    loading = true;
    error = null;
    try {
      const res = await listConversas({ page, per_page: perPage });
      conversas = res.items;
      total = res.total;
      totalPages = res.total_pages;
    } catch (err) {
      error = err instanceof ApiError ? err.message : "Falha ao carregar conversas";
      if (err instanceof ApiError && err.status === 401) sessaoExpirada = true;
    } finally {
      loading = false;
    }
  }

  async function loadCalendar() {
    const year = currentMonth.getFullYear();
    const month = currentMonth.getMonth();
    const firstDay = `${year}-${String(month + 1).padStart(2, "0")}-01`;
    const lastDay = new Date(year, month + 1, 0).toISOString().split("T")[0];
    try {
      const cal = await getCalendar({ from: firstDay, to: lastDay });
      calendarData = cal;
    } catch (err) {
      console.warn("[historico] falha ao carregar calendário:", err);
    }
  }

  function debouncedSearch() {
    if (searchDebounce) clearTimeout(searchDebounce);
    searchDebounce = setTimeout(async () => {
      if (!searchQuery.trim()) {
        searchResults = [];
        isSearching = false;
        return;
      }
      isSearching = true;
      searchPage = 1;
      try {
        const res = await searchConversas({ q: searchQuery, page: 1, per_page: 20 });
        searchResults = res.items;
        searchTotal = res.total;
      } catch (err) {
        console.warn("[historico] erro na busca:", err);
        searchResults = [];
      } finally {
        isSearching = false;
      }
    }, 300);
  }

  function handleSearchInput() {
    debouncedSearch();
  }

  function onCalendarSelect(date) {
    selectedDate = date;
  }

  function handleMonthChange(m) {
    currentMonth = m;
    loadCalendar();
  }

  async function handleDelete(id) {
    if (!confirm("Tem certeza que deseja excluir esta conversa?")) return;
    try {
      await deleteConversa(id);
      await loadConversas();
      await loadCalendar();
    } catch (err) {
      error = err instanceof ApiError ? err.message : "Falha ao excluir";
    }
  }

  function openExportModal() {
  }

  function exportSelected(ids) {
    exportConversas({ ids }).then(blob => {
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `conversas-${new Date().toISOString().split("T")[0]}.md`;
      a.click();
      URL.revokeObjectURL(url);
    }).catch(err => {
      error = "Falha ao exportar: " + err.message;
    });
  }

  function exportAll() {
    exportConversas({ all: true }).then(blob => {
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `conversas-${new Date().toISOString().split("T")[0]}.md`;
      a.click();
      URL.revokeObjectURL(url);
    }).catch(err => {
      error = "Falha ao exportar: " + err.message;
    });
  }

  function goToPage(newPage) {
    if (newPage >= 1 && newPage <= totalPages) {
      page = newPage;
      loadConversas(false);
    }
  }
</script>

<div class="flex flex-col h-full">
  <header class="mb-6">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Histórico de Conversas</h1>
        <p class="text-sm text-gray-600 mt-1">
          Gerencie suas conversas salvas com o Assistente do Censo. Busque por texto,
          filtre por data no calendário e exporte em Markdown.
        </p>
      </div>
    </div>
  </header>

  {#if error}
    <div class="mb-4 bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-3 flex items-center justify-between">
      <span>{error}</span>
      <button onclick={() => (error = null)} class="text-red-500 hover:text-red-700 font-bold text-lg leading-none" aria-label="Fechar erro">×</button>
    </div>
  {/if}

  {#if sessaoExpirada}
    <div class="mb-4 bg-amber-50 border border-amber-200 text-amber-800 text-sm rounded-md p-3 flex items-center justify-between gap-3">
      <span>Sua sessão expirou. <a href="/gestor" class="underline font-medium">Entre novamente</a>.</span>
      <button onclick={() => (sessaoExpirada = false)} class="text-amber-600 hover:text-amber-800 font-bold text-lg leading-none" aria-label="Fechar aviso">×</button>
    </div>
  {/if}

  <div class="flex flex-col lg:flex-row gap-6 min-h-[500px] h-full">
    <aside class="lg:w-72 flex-shrink-0 h-full">
      <ChatCalendar
        diasComConversa={calendarData}
        selectedDate={selectedDate}
        onSelect={onCalendarSelect}
        currentMonth={currentMonth}
        onMonthChange={handleMonthChange}
      />
    </aside>

    <div class="flex-1 flex flex-col min-h-0">
      <div class="mb-4">
        <label class="block">
          <span class="sr-only">Buscar por texto</span>
          <input
            type="text"
            bind:value={searchQuery}
            placeholder="Buscar por texto nas conversas salvas..."
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            oninput={handleSearchInput}
          />
          {#if isSearching}
            <p class="text-xs text-gray-500 mt-1">Buscando...</p>
          {/if}
        </label>
      </div>

<ChatConversaList
          {conversas}
          {loading}
          {searchQuery}
          onSearch={handleSearchInput}
          {selectedDate}
          onExportSelected={ids => exportSelected(ids)}
          onExportAll={exportAll}
        />
      {#if totalPages > 1}
    <nav class="mt-4 flex items-center justify-center gap-2" aria-label="Paginação">
      <button onclick={() => goToPage(page - 1)} disabled={page === 1} class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 disabled:opacity-50">Anterior</button>
      <span class="px-3 text-sm text-gray-600">Página {page} de {totalPages} ({total} conversas)</span>
      <button onclick={() => goToPage(page + 1)} disabled={page === totalPages} class="px-3 py-1.5 bg-gray-100 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-200 disabled:opacity-50">Próxima</button>
    </nav>
  {/if}
</div>
</div>
</div>