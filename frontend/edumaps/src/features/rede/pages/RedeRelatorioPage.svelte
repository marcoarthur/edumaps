<!-- src/features/rede/pages/RedeRelatorioPage.svelte -->
<script>
  // Relatório de acompanhamento de uma escola, aberto pela rede (#396): o
  // mesmo que a escola imprime (PlanoRelatorio), só leitura, com o cargo da
  // conta de rede em "por". Escola fora da rede: o servidor responde 403.
  import { onMount } from "svelte";
  import { getRedeRelatorio } from "../api/redeApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import PlanoRelatorio from "@/features/gestor/components/planos/PlanoRelatorio.svelte";

  const [, inep, planoId] = new URL(location.href).pathname.match(/\/rede\/escolas\/(\d{8})\/planos\/(\d+)\/relatorio/) ?? [];

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let error = $state(null);
  let relatorio = $state(null);
  let exercicio = $state(null);

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      relatorio = await getRedeRelatorio(inep, planoId, exercicio);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else error = err instanceof ApiError ? err.message : "Não foi possível abrir o relatório.";
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  async function recarregar() {
    relatorio = await getRedeRelatorio(inep, planoId, exercicio);
  }

  // Troca o exercício dos custos (#404) sem esconder o relatório.
  async function trocarExercicio(ano) {
    exercicio = ano;
    try {
      await recarregar();
    } catch {
      error = "Não foi possível filtrar os custos pelo exercício.";
    }
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-4 max-w-4xl mx-auto">
  <div class="flex flex-wrap items-center justify-between gap-2 print:hidden">
    <a href="/rede" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">← Rede</a>
    {#if relatorio}
      <button type="button" onclick={() => window.print()} class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">Imprimir / salvar PDF</button>
    {/if}
  </div>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Gerando o relatório…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre com a conta da rede." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if relatorio}
    <p class="text-xs text-gray-500 print:hidden">Visão da rede: só leitura. O plano é editado pela escola.</p>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-6 print:border-0 print:shadow-none print:p-0">
      <PlanoRelatorio {relatorio} onExercicio={trocarExercicio} />
    </div>
  {/if}
</div>
