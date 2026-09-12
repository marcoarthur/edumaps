<script>
  // src/features/network-compare/components/NetworkKpis.svelte
  import { NETWORK_ORDER, NETWORK_LABELS, NETWORK_COLORS } from "../constants/indicators.js";
  import { formatDecimal, formatInt } from "../utils/transformNetworkData.js";

  let { networks = [] } = $props();

  const orderedNetworks = $derived(
    NETWORK_ORDER
      .map((key) => networks.find((n) => String(n.rede).toLowerCase() === key))
      .filter(Boolean),
  );
</script>

<section class="space-y-4">
  <h2 class="text-lg font-bold text-gray-900">Indicadores por rede</h2>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    {#each orderedNetworks as net}
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <div class="flex items-center gap-2 mb-3">
          <span
            class="inline-block w-3 h-3 rounded-full"
            style:background-color={NETWORK_COLORS[String(net.rede).toLowerCase()] ?? "#64748b"}
          ></span>
          <h3 class="font-semibold text-gray-800">
            {NETWORK_LABELS[String(net.rede).toLowerCase()] ?? net.rede}
          </h3>
        </div>

        <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Escolas</dt>
            <dd class="font-semibold text-gray-900">{formatInt(net.total_escolas)}</dd>
          </div>
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Matrículas</dt>
            <dd class="font-semibold text-gray-900">{formatInt(net.total_matriculas)}</dd>
          </div>
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Docentes</dt>
            <dd class="font-semibold text-gray-900">{formatInt(net.total_docentes)}</dd>
          </div>
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Etapas oferecidas</dt>
            <dd class="font-semibold text-gray-900">{formatInt(net.total_etapas)}</dd>
          </div>
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Média de etapas/escola</dt>
            <dd class="font-semibold text-gray-900">{formatDecimal(net.media_etapas)}</dd>
          </div>
          <div class="flex flex-col">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">Alunos por docente</dt>
            <dd class="font-semibold text-gray-900">{formatDecimal(net.alunos_por_docente)}</dd>
          </div>
          <div class="flex flex-col col-span-2">
            <dt class="text-gray-500 text-xs uppercase tracking-wide">% docentes c/ superior</dt>
            <dd class="font-semibold text-gray-900">
              {formatDecimal(net.perc_docentes_superior)}%
            </dd>
          </div>
        </dl>
      </div>
    {/each}
  </div>
</section>