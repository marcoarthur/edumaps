<script>
  // src/features/cluster-geotag/components/ClusterSummaryTable.svelte
  //
  // Resumo dos grupos. Com `destaques` (#427), mostra os indicadores que mais
  // afastam o grupo da média das escolas agrupadas, com o nome legível e o
  // valor do grupo ao lado da média geral. Sem eles (execução antiga), cai
  // nos maiores valores do centroide, como antes.
  import { clusterColor, formatColumnName } from "../constants/cluster.js";
  import { rotuloIndicador, formatarIndicador } from "../utils/execucao.js";

  let { summary = [], columns = [] } = $props();

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
    <p class="px-4 pt-3 pb-1 font-semibold text-gray-800 text-sm">Resumo dos grupos</p>
    <p class="px-4 pb-2 text-xs text-gray-500">
      Para cada grupo, os indicadores em que ele mais se afasta da média das escolas agrupadas (valor do grupo × média geral).
    </p>
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100">
            <th class="px-4 py-2 font-medium">Grupo</th>
            <th class="px-4 py-2 font-medium">Escolas</th>
            <th class="px-4 py-2 font-medium">O que mais o distingue</th>
          </tr>
        </thead>
        <tbody>
          {#each summary as row (row.cluster_id)}
            <tr class="border-b border-gray-50 last:border-0 align-top">
              <td class="px-4 py-2">
                <span class="flex items-center gap-2">
                  <span
                    class="w-3 h-3 rounded-full inline-block shrink-0"
                    style:background-color={clusterColor(row.cluster_id)}
                  ></span>
                  <span class="text-gray-800">{row.cluster_label ?? `Grupo ${row.cluster_id}`}</span>
                </span>
              </td>
              <td class="px-4 py-2 text-gray-600">{row.cluster_size ?? 0}</td>
              <td class="px-4 py-2 text-gray-600">
                {#if row.destaques?.length}
                  <ul class="space-y-0.5" data-testid="destaques">
                    {#each row.destaques as d (d.indicador)}
                      <li>
                        <span class="{d.z >= 0 ? 'text-emerald-700' : 'text-amber-700'}" aria-hidden="true">{d.z >= 0 ? "▲" : "▼"}</span>
                        {rotuloIndicador(d.indicador, columns)}:
                        <b class="text-gray-800">{formatarIndicador(d.indicador, d.media_grupo)}</b>
                        <span class="text-gray-400">× {formatarIndicador(d.indicador, d.media_geral)}</span>
                      </li>
                    {/each}
                  </ul>
                {:else}
                  {#each topIndicators(row.indicators) as ind, i}
                    {#if i > 0}<span class="text-gray-300"> · </span>{/if}
                    <span class="whitespace-nowrap">{ind.name} <b class="text-gray-800">{ind.value}</b></span>
                  {/each}
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </div>
{/if}
