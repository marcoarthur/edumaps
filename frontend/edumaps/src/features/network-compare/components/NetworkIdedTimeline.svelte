<script>
  // src/features/network-compare/components/NetworkIdedTimeline.svelte
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";
  import { NETWORK_COLORS } from "../constants/indicators.js";
  import { buildIdedTimeline } from "../utils/transformNetworkData.js";

  let { performance = [] } = $props();

  const rows = $derived(buildIdedTimeline(performance));

  const colorScale = $derived(
    Object.fromEntries(
      [...new Set(rows.map((r) => r.group))].map((group) => [
        group,
        NETWORK_COLORS[group.split(" · ")[0].toLowerCase()] ?? "#64748b",
      ]),
    ),
  );

  const options = $derived({
    title: "IDEB observado (média das escolas por rede e etapa)",
    axes: {
      left: { mapsTo: "value", title: "IDEB" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Ano" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: colorScale },
    legend: { position: "bottom" },
    curve: "curveMonotoneX",
  });
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  {#if rows.length > 0}
    <LineChart data={rows} {options} height="340px" />
  {:else}
    <h2 class="text-lg font-bold text-gray-900">IDEB observado</h2>
    <p class="text-sm text-gray-500 mt-2">
      Sem resultados de IDEB disponíveis para este município.
    </p>
  {/if}
</section>