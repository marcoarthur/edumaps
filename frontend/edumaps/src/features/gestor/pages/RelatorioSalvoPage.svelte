<!-- src/features/gestor/pages/RelatorioSalvoPage.svelte -->
<script>
  // Relatório salvo (#219, fase 3): reabre a fotografia gravada, sem custo de
  // LLM, com o aviso "Fotografia de <data>", as ações de imprimir e baixar
  // Markdown, "Excluir" (com confirmação) e "Gerar de novo com os dados
  // atuais" (leva à RelatoriosPage com recorte, tema e opções por query).
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao
  // login; 404 → "Relatório não encontrado".
  // Fase 4: mostra o assistente quando não é o padrão; o "gerar de novo" o leva.
  import { onMount } from "svelte";
  import { getSalvo, excluirSalvo } from "../api/gestorRelatoriosApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { router } from "@/app/router.svelte.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import { formatarDataHora, urlGerarDeNovo, assistenteNaoPadrao } from "../utils/relatorioSalvos.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import RelatorioView from "../components/relatorios/RelatorioView.svelte";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";

  /** @type {{id?: string|number}} */
  let { id = undefined } = $props();

  const LISTA = "/gestor/relatorios/salvos";

  // a rota passa o :id; sem ele (render direto), lê da URL
  const salvoId = $derived(
    String(id ?? window.location.pathname.match(/\/relatorios\/salvos\/([^/]+)\/?$/)?.[1] ?? ""),
  );

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let naoEncontrado = $state(false);
  let precisaLogin = $state(false);
  let salvo = $state(null);

  let confirmando = $state(false);
  let excluindo = $state(false);
  let erroExcluir = $state(null);

  const relatorio = $derived(salvo?.relatorio ?? null);
  const assistente = $derived(assistenteNaoPadrao(salvo));
  const dataFoto = $derived(formatarDataHora(salvo?.gerado_em ?? relatorio?.gerado_em));

  const onApiError = (err, padraoMsg) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padraoMsg;
  };

  async function carregar() {
    carregando = true;
    error = null;
    naoEncontrado = false;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      if (!/^\d+$/.test(salvoId)) {
        naoEncontrado = true;
        return;
      }
      salvo = await getSalvo(inep, salvoId);
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        naoEncontrado = true;
        return;
      }
      const msg = onApiError(err, "Não foi possível abrir o relatório salvo.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function confirmarExclusao() {
    excluindo = true;
    erroExcluir = null;
    try {
      await excluirSalvo(inep, salvoId);
      confirmando = false;
      addToast("Relatório excluído.", "success");
      router.navigate(LISTA);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o relatório.");
      if (precisaLogin) confirmando = false;
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
    carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3 print:hidden">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Relatório salvo</h1>
      <p class="text-sm text-gray-600 mt-1">Fotografia guardada em "Meus relatórios".</p>
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
        href={LISTA}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Meus relatórios</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando o relatório…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver os seus relatórios." />
  {:else if naoEncontrado}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-8 text-center space-y-3" data-testid="salvo-nao-encontrado">
      <p class="text-gray-800 font-semibold" role="alert">Relatório não encontrado.</p>
      <p class="text-sm text-gray-500">Ele pode ter sido excluído.</p>
      <a href={LISTA} class="inline-block text-sm text-blue-700 hover:underline">Ver meus relatórios</a>
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{error}</div>
  {:else if salvo && relatorio}
    <div
      class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-3"
      role="note"
      data-testid="aviso-fotografia"
    >
      Fotografia de {dataFoto}: os números são os daquela data.
    </div>

    {#if assistente}
      <p class="text-sm text-gray-700" data-testid="salvo-assistente">
        Assistente: <strong>{assistente.titulo}</strong>
      </p>
    {/if}

    <div class="flex flex-wrap items-center gap-2 print:hidden">
      <a
        href={urlGerarDeNovo(salvo)}
        class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
        data-testid="gerar-de-novo"
      >Gerar de novo com os dados atuais</a>
      <button
        type="button"
        onclick={() => {
          erroExcluir = null;
          confirmando = true;
        }}
        class="px-3 py-1.5 rounded-md bg-red-50 text-red-700 border border-red-200 text-sm font-medium hover:bg-red-100 transition-colors"
      >Excluir</button>
    </div>

    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5 print:border-0 print:shadow-none print:p-0">
      <RelatorioView {relatorio} acoes salvo />
    </div>
  {/if}

  {#if confirmando}
    <ConfirmDialog
      titulo="Excluir relatório salvo?"
      descricao={`"${salvo?.titulo ?? relatorio?.titulo ?? "Relatório"}" sai da sua lista. Essa ação não pode ser desfeita.`}
      confirmarRotulo="Excluir"
      perigo
      ocupado={excluindo}
      erro={erroExcluir}
      onConfirmar={confirmarExclusao}
      onCancelar={() => (confirmando = false)}
      testid="confirmar-excluir-salvo"
    />
  {/if}
</div>
