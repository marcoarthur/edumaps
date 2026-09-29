<script>
  // src/features/network-compare/pages/NetworkProfilePage.svelte
  //
  // Perfil analítico da rede de um município (issue #109): indicadores da
  // rede vs. Brasil e distribuição das escolas por cluster.
  // Rota: /municipio/perfil?ibge=XXXXXXX[&dependencia=N]
  import { onMount } from "svelte";
  import { getNetworkProfile } from "../api/networkCompareApi.js";
  import {
    transformNetworkProfileData,
    formatNetworkValue,
  } from "../utils/transformNetworkProfileData.js";
  import { ApiError } from "@/shared/api/client.js";

  let ibge = $state(null);
  let profile = $state(null);
  let loading = $state(true);
  let error = $state(null);

  async function load(codigoIbge, tpDependencia) {
    loading = true;
    error = null;
    try {
      const raw = await getNetworkProfile(codigoIbge, { tpDependencia });
      profile = transformNetworkProfileData(raw);
    } catch (err) {
      profile = null;
      error =
        err instanceof ApiError
          ? err.message
          : "Erro ao carregar o perfil da rede.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const params = new URLSearchParams(window.location.search);
    const code = params.get("ibge");
    const dep = params.get("dependencia");
    if (code) {
      ibge = code;
      load(code, dep ? Number(dep) : undefined);
    } else {
      loading = false;
      error = "Nenhum código IBGE informado (?ibge=XXXXXXX).";
    }
  });

  function goBack() {
    window.location.href = ibge ? `/municipio/compare?ibge=${ibge}` : "/";
  }
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Perfil da Rede</h1>
      {#if profile}
        <p class="text-sm text-gray-600 mt-1">
          {profile.metadata.municipio} · {profile.metadata.uf}
          {#if profile.metadata.dependenciaLabel}· {profile.metadata.dependenciaLabel}{/if}
          · {profile.metrics.n_escolas ?? "–"} escolas
          {#if profile.metadata.anoCenso}· Censo {profile.metadata.anoCenso}{/if}
        </p>
      {/if}
    </div>
    <button
      onclick={goBack}
      class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors"
    >
      ← Voltar
    </button>
  </header>

  {#if loading}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando o perfil da rede…</p>
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      {error}
    </div>
  {:else if profile}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <section aria-label="Rede vs. Brasil" class="flex flex-col gap-2">
        <h2 class="text-base font-bold text-gray-900">Rede vs. Brasil</h2>
        <div class="overflow-x-auto border border-gray-200 rounded-md">
          <table class="min-w-full text-sm">
            <thead class="bg-gray-50 text-gray-600">
              <tr>
                <th class="text-left font-semibold px-3 py-2">Indicador</th>
                <th class="text-right font-semibold px-3 py-2">Rede</th>
                <th class="text-right font-semibold px-3 py-2">Brasil</th>
                <th class="text-right font-semibold px-3 py-2">Variação</th>
              </tr>
            </thead>
            <tbody>
              {#each profile.indicadores as ind (ind.indicador)}
                <tr class="bg-white">
                  <td class="text-left px-3 py-2 text-gray-800">{ind.label ?? ind.indicador}</td>
                  <td class="text-right px-3 py-2 font-mono text-gray-700">{formatNetworkValue(ind.indicador, ind.rede)}</td>
                  <td class="text-right px-3 py-2 font-mono text-gray-500">{formatNetworkValue(ind.indicador, ind.brasil)}</td>
                  <td
                    class="text-right px-3 py-2 font-mono {Number(ind.variacao) >= 0 ? 'text-emerald-700' : 'text-red-700'}"
                  >
                    {Number(ind.variacao) >= 0 ? '+' : ''}{formatNetworkValue(ind.indicador, ind.variacao)}
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      </section>

      <section aria-label="Distribuição por cluster" class="flex flex-col gap-2">
        <h2 class="text-base font-bold text-gray-900">Distribuição por cluster</h2>
        <div class="flex flex-col gap-4">
          {#each profile.clusters as cluster (cluster.cluster_label + '::' + (cluster.cluster_id ?? 'sem'))}
            <article class="bg-white border border-gray-200 rounded-md p-3 flex flex-col gap-2">
              <header class="flex items-baseline justify-between gap-2">
                <strong class="text-sm text-gray-900">{cluster.cluster_label}</strong>
                <span class="text-xs text-gray-500">{cluster.n} escolas</span>
              </header>
              <ul class="grid grid-cols-2 gap-x-4 gap-y-1">
                {#each cluster.indicadores as ind (ind.indicador)}
                  <li class="flex justify-between gap-2 text-xs">
                    <span class="text-gray-600 truncate">{ind.label}</span>
                    <span class="font-mono text-gray-700 whitespace-nowrap">
                      {formatNetworkValue(ind.indicador, ind.media)}
                    </span>
                  </li>
                {/each}
              </ul>
            </article>
          {/each}
        </div>
      </section>
    </div>
  {/if}
</div>
