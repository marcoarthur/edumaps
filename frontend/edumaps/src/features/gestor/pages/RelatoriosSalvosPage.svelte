<!-- src/features/gestor/pages/RelatoriosSalvosPage.svelte -->
<script>
  // Meus relatórios (#219, fase 3): a lista paginada dos relatórios que o
  // gestor salvou (mais recentes primeiro), com título, tema, recorte, a data
  // em que foi gerado e a data em que foi salvo. "Abrir" leva à fotografia;
  // "Excluir" pede confirmação. Só os salvos do próprio gestor.
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao login.
  import { onMount } from "svelte";
  import { listarSalvos, excluirSalvo } from "../api/gestorRelatoriosApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";
  import { formatarDataHora, textoRecorteSalvo } from "../utils/relatorioSalvos.js";

  const POR_PAGINA = 20;

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let carregandoLista = $state(false);
  let error = $state(null);
  let precisaLogin = $state(false);

  let items = $state([]);
  let total = $state(0);
  let pagina = $state(1);

  let aExcluir = $state(null);
  let excluindo = $state(false);
  let erroExcluir = $state(null);

  const totalPaginas = $derived(Math.max(1, Math.ceil(total / POR_PAGINA)));

  const onApiError = (err, padraoMsg) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padraoMsg;
  };

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      await carregarPagina(1);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os relatórios salvos.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function carregarPagina(p) {
    carregandoLista = true;
    try {
      const r = await listarSalvos(inep, { page: p, per_page: POR_PAGINA });
      // a página ficou vazia (ex.: excluiu o último item dela): volta uma
      if (!r.items.length && p > 1 && r.total > 0) {
        await carregarPagina(p - 1);
        return;
      }
      items = r.items;
      total = r.total;
      pagina = r.page;
    } finally {
      carregandoLista = false;
    }
  }

  async function irPara(p) {
    try {
      await carregarPagina(p);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os relatórios salvos.");
      if (msg) error = msg;
    }
  }

  function pedirExclusao(item) {
    erroExcluir = null;
    aExcluir = item;
  }

  async function confirmarExclusao() {
    if (!aExcluir) return;
    excluindo = true;
    erroExcluir = null;
    try {
      await excluirSalvo(inep, aExcluir.id);
      aExcluir = null;
      addToast("Relatório excluído.", "success");
      await carregarPagina(pagina);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o relatório.");
      if (precisaLogin) aExcluir = null;
      else erroExcluir = msg;
    } finally {
      excluindo = false;
    }
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      gestor = null;
      precisaLogin = true;
    }
  }

  function onLogin(sessao) {
    setSessaoToken(sessao?.token);
    restaurarSessao();
    carregarTudo();
  }

  onMount(() => {
    restaurarSessao();
    carregarTudo();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Meus relatórios</h1>
      <p class="text-sm text-gray-600 mt-1">
        Relatórios que você salvou. Cada um é a fotografia do dia em que foi gerado.
      </p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      {/if}
      <a
        href="/gestor/relatorios"
        class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
      >Novo relatório</a>
      <a
        href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando os relatórios salvos…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver os seus relatórios." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{error}</div>
  {:else if total === 0}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-8 text-center space-y-3" data-testid="salvos-vazio">
      <p class="text-gray-700">Você ainda não salvou nenhum relatório.</p>
      <p class="text-sm text-gray-500">
        Gere um relatório e use "Salvar relatório" para guardá-lo aqui.
      </p>
      <a href="/gestor/relatorios" class="inline-block text-sm text-blue-700 hover:underline">Gerar um relatório</a>
    </div>
  {:else}
    <div class="bg-white border border-gray-200 rounded-card shadow-card overflow-x-auto" aria-busy={carregandoLista}>
      <table class="min-w-full text-sm" data-testid="salvos-tabela">
        <caption class="sr-only">Relatórios salvos</caption>
        <thead class="bg-gray-50 text-gray-600">
          <tr>
            <th scope="col" class="text-left font-medium px-4 py-2">Relatório</th>
            <th scope="col" class="text-left font-medium px-4 py-2">Recorte</th>
            <th scope="col" class="text-left font-medium px-4 py-2">Gerado em</th>
            <th scope="col" class="text-left font-medium px-4 py-2">Salvo em</th>
            <th scope="col" class="px-4 py-2"><span class="sr-only">Ações</span></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          {#each items as item (item.id)}
            <tr data-testid="salvo-item">
              <th scope="row" class="text-left font-medium text-gray-900 px-4 py-2">
                {item.titulo}
                {#if item.tema?.titulo}
                  <span class="block text-xs font-normal text-gray-500">{item.tema.titulo}</span>
                {/if}
              </th>
              <td class="px-4 py-2 text-gray-700">{textoRecorteSalvo(item.recorte)}</td>
              <td class="px-4 py-2 text-gray-700 whitespace-nowrap">{formatarDataHora(item.gerado_em)}</td>
              <td class="px-4 py-2 text-gray-700 whitespace-nowrap">{formatarDataHora(item.salvo_em)}</td>
              <td class="px-4 py-2 text-right whitespace-nowrap space-x-2">
                <a
                  href="/gestor/relatorios/salvos/{item.id}"
                  class="text-blue-700 hover:underline"
                  aria-label="Abrir {item.titulo}"
                >Abrir</a>
                <button
                  type="button"
                  onclick={() => pedirExclusao(item)}
                  class="text-red-700 hover:underline"
                  aria-label="Excluir {item.titulo}"
                >Excluir</button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    {#if totalPaginas > 1}
      <nav class="flex items-center justify-between text-sm" aria-label="Paginação dos relatórios salvos">
        <button
          type="button"
          onclick={() => irPara(pagina - 1)}
          disabled={pagina <= 1 || carregandoLista}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 font-medium hover:bg-gray-300 disabled:opacity-50"
        >← Anterior</button>
        <span class="text-gray-600" data-testid="salvos-pagina">Página {pagina} de {totalPaginas} · {total} relatórios</span>
        <button
          type="button"
          onclick={() => irPara(pagina + 1)}
          disabled={pagina >= totalPaginas || carregandoLista}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 font-medium hover:bg-gray-300 disabled:opacity-50"
        >Próxima →</button>
      </nav>
    {/if}
  {/if}

  {#if aExcluir}
    <ConfirmDialog
      titulo="Excluir relatório salvo?"
      descricao={`"${aExcluir.titulo}" sai da sua lista. Essa ação não pode ser desfeita.`}
      confirmarRotulo="Excluir"
      perigo
      ocupado={excluindo}
      erro={erroExcluir}
      onConfirmar={confirmarExclusao}
      onCancelar={() => (aExcluir = null)}
      testid="confirmar-excluir-salvo"
    />
  {/if}
</div>
