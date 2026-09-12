<script>
  // src/features/network-compare/components/NetworkSummaryBanner.svelte
  import { NETWORK_ORDER, NETWORK_LABELS, NETWORK_COLORS } from "../constants/indicators.js";
  import { formatInt, municipalityHeader } from "../utils/transformNetworkData.js";

  let { networks = [] } = $props();

  let header = $derived(municipalityHeader(networks));

  const orderedNetworks = $derived(
    NETWORK_ORDER
      .map((key) => networks.find((n) => String(n.rede).toLowerCase() === key))
      .filter(Boolean),
  );
</script>

<header class="bg-white border border-gray-200 rounded-card shadow-card p-6">
  <div class="flex items-center gap-3 flex-wrap">
    <h1 class="text-2xl font-bold text-gray-900">Redes que atendem {header.no_municipio}</h1>
    {#if header.sg_uf}
      <span class="px-2 py-0.5 rounded-full bg-brand-50 text-brand-700 text-xs font-semibold">
        {header.sg_uf} · {header.no_regiao}
      </span>
    {/if}
  </div>

  <p class="text-sm text-gray-600 mt-1">
    Comparação das redes federal, estadual, municipal e privada no município
    selecionado (Censo Escolar e IDEB).
  </p>

  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mt-6">
    {#each orderedNetworks as net}
      <div class="rounded-lg border border-gray-200 p-4">
        <div class="flex items-center gap-2">
          <span
            class="inline-block w-3 h-3 rounded-full"
            style:background-color={NETWORK_COLORS[String(net.rede).toLowerCase()] ?? "#64748b"}
          ></span>
          <span class="font-semibold text-gray-800">
            {NETWORK_LABELS[String(net.rede).toLowerCase()] ?? net.rede}
          </span>
        </div>
        <dl class="mt-3 space-y-1 text-sm">
          <div class="flex justify-between">
            <dt class="text-gray-500">Escolas</dt>
            <dd class="font-medium text-gray-900">{formatInt(net.total_escolas)}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-gray-500">Matrículas</dt>
            <dd class="font-medium text-gray-900">{formatInt(net.total_matriculas)}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-gray-500">Etapas</dt>
            <dd class="font-medium text-gray-900">{formatInt(net.total_etapas)}</dd>
          </div>
        </dl>
      </div>
    {/each}
  </div>
</header>