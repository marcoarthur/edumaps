<!-- src/features/rede/pages/RedePage.svelte -->
<script>
  // Página da conta de rede (#394): as redes ligadas à conta e as escolas em
  // atividade de cada uma. O acompanhamento dos planos (painel da rede) entra
  // aqui na issue seguinte. Exige sessão com papel `rede`.
  import { onMount } from "svelte";
  import { getRedeMe, getRedeEscolas } from "../api/redeApi.js";
  import { logoutGestor } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);
  let conta = $state(null);
  let escolas = $state([]);

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    semPermissao = false;
    try {
      conta = await getRedeMe();
      escolas = (await getRedeEscolas()).escolas ?? [];
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else if (err instanceof ApiError && err.status === 403) semPermissao = true;
      else error = "Não foi possível carregar a rede.";
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      conta = null;
      precisaLogin = true;
    }
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6 max-w-4xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rede</h1>
      <p class="text-sm text-gray-600 mt-1">As escolas das redes ligadas à sua conta.</p>
    </div>
    {#if conta}
      <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Sair</button>
    {/if}
  </header>

  {#if carregando}
    <p class="text-gray-500">Carregando…</p>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre com a conta da rede." />
  {:else if semPermissao}
    <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4">
      Esta página é das contas de rede (secretarias). A sua conta é de escola: use o menu <strong>Gestor</strong>.
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if conta}
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-2" aria-label="Sua conta">
      <p class="text-base font-semibold text-gray-900">{conta.nome}</p>
      <p class="text-xs text-gray-500">{conta.cargo ?? "Conta de rede"} · {conta.email}</p>
      {#if conta.vinculos.length}
        <ul class="flex flex-wrap gap-2 pt-1">
          {#each conta.vinculos as v (v.id)}
            <li class="px-2 py-0.5 rounded-full bg-blue-50 text-blue-800 text-xs">Rede {v.dependencia.toLowerCase()} · {v.municipio}/{v.uf}</li>
          {/each}
        </ul>
      {:else}
        <p class="text-sm text-amber-800">Nenhuma rede ligada a esta conta ainda. Fale com o administrador da plataforma.</p>
      {/if}
    </section>

    {#if conta.vinculos.length}
      <section class="space-y-2" aria-label="Escolas da rede">
        <h2 class="text-sm font-semibold text-gray-900">Escolas em atividade ({escolas.length})</h2>
        <p class="text-xs text-gray-500">
          Pelo Censo Escolar mais recente de cada escola. Em breve, o acompanhamento dos planos de cada uma aparece aqui.
        </p>
        <div class="overflow-x-auto rounded-card border border-gray-200 bg-white">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 text-xs text-gray-600">
              <tr><th class="text-left px-3 py-2" scope="col">Escola</th><th class="text-left px-3 py-2" scope="col">INEP</th><th class="text-left px-3 py-2" scope="col">Município</th><th class="text-left px-3 py-2" scope="col">Rede</th></tr>
            </thead>
            <tbody>
              {#each escolas as e (e.cod_inep)}
                <tr class="border-t border-gray-100">
                  <td class="px-3 py-2">{e.nome}</td>
                  <td class="px-3 py-2 text-gray-600">{e.cod_inep}</td>
                  <td class="px-3 py-2 text-gray-600">{e.municipio}/{e.uf}</td>
                  <td class="px-3 py-2 text-gray-600">{e.dependencia}</td>
                </tr>
              {:else}
                <tr><td colspan="4" class="px-3 py-4 text-center text-gray-500">Nenhuma escola em atividade nestas redes.</td></tr>
              {/each}
            </tbody>
          </table>
        </div>
      </section>
    {/if}
  {/if}
</div>
