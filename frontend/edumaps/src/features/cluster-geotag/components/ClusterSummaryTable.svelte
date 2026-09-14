<script>
  // src/features/cluster-geotag/components/ClusterSummaryTable.svelte
  import { clusterColor, formatColumnName } from "../constants/cluster.js";

  let { summary = [] } = $props();

  function topIndicators(indicators, limit = 3) {
    if (!indicators || typeof indicators !== "object") return [];
    return Object.entries(indicators)
      .filter(([, v]) => typeof v === "number" && Number.isFinite(v))
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([name, value]) => ({
        name: formatColumnName(name),
        value: Number(value).toLocaleString("pt-BR", { maximumFractionDigits: 2 }),
      }));
  }
</script>

{#if summary.length > 0}
  <div class="mt-4 bg-white border border-gray-200 rounded-card shadow-card overflow-hidden">
    <p class="px-4 pt-3 pb-1 font-semibold text-gray-800 text-sm">Resumo dos clusters</p>
    <table class="w-full text-sm">
      <thead>
        <tr class="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100">
          <th class="px-4 py-2 font-medium">Cluster</th>
          <th class="px-4 py-2 font-medium">Escolas</th>
          <th class="px-4 py-2 font-medium">Indicadores principais</th>
        </tr>
      </thead>
      <tbody>
        {#each summary as row}
          <tr class="border-b border-gray-50 last:border-0">
            <td class="px-4 py-2">
              <span class="flex items-center gap-2">
                <span
                  class="w-3 h-3 rounded-full inline-block shrink-0"
                  style:background-color={clusterColor(row.cluster_id)}
                ></span>
                <span class="text-gray-800">{row.cluster_label ?? `Cluster ${row.cluster_id}`}</span>
              </span>
            </td>
            <td class="px-4 py-2 text-gray-600">{row.cluster_size ?? 0}</td>
            <td class="px-4 py-2 text-gray-600">
              {#each topIndicators(row.indicators) as ind, i}
                {#if i > 0}<span class="text-gray-300"> · </span>{/if}
                <span class="whitespace-nowrap">{ind.name} <b class="text-gray-800">{ind.value}</b></span>
              {/each}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
