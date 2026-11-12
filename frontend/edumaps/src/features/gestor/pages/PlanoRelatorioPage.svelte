<!-- src/features/gestor/pages/PlanoRelatorioPage.svelte -->
<script>
  // Relatório de acompanhamento do plano (#374): carrega os dados e mostra a
  // visão de impressão (PlanoRelatorio). "Imprimir / salvar PDF" usa o
  // window.print do navegador (A4). Exige sessão do gestor.
  import { onMount } from "svelte";
  import { getRelatorio } from "../api/gestorPlanosApi.js";
  import { fetchMe } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import PlanoRelatorio from "../components/planos/PlanoRelatorio.svelte";

  const planoId = Number(new URL(location.href).pathname.match(/\/planos\/(\d+)\/relatorio/)?.[1]);

  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);
  let relatorio = $state(null);

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      relatorio = await getRelatorio(me.cod_inep, planoId);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else error = err instanceof ApiError ? err.message : "Não foi possível gerar o relatório.";
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-4 max-w-4xl mx-auto">
  <div class="flex flex-wrap items-center justify-between gap-2 print:hidden">
    <a href={`/gestor/planos/${planoId}`} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">← Plano</a>
    {#if relatorio}
      <button type="button" onclick={() => window.print()} class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">Imprimir / salvar PDF</button>
    {/if}
  </div>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Gerando o relatório…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerar o relatório do plano." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if relatorio}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-6 print:border-0 print:shadow-none print:p-0">
      <PlanoRelatorio {relatorio} />
    </div>
  {/if}
</div>
