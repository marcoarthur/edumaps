<script>
  // src/features/network-compare/components/NetworkStageBars.svelte
  import BarChartGrouped from "@/shared/ui/components/charts/BarChartGrouped.svelte";
  import { NETWORK_COLORS, NETWORK_ORDER } from "../constants/indicators.js";
  import { buildStageBars } from "../utils/transformNetworkData.js";

  let { networks = [] } = $props();

  const colorScale = $derived(
    Object.fromEntries(
      NETWORK_ORDER.map((key) => [
        key.charAt(0).toUpperCase() + key.slice(1),
        NETWORK_COLORS[key],
      ]),
    ),
  );

  const rows = $derived(buildStageBars(networks));

  const options = $derived({
    title: "Matrículas por etapa",
    axes: {
      left: { mapsTo: "value", title: "Matrículas" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Etapa" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: colorScale },
    legend: { position: "bottom" },
  });
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <BarChartGrouped data={rows} {options} height="340px" />
</section>