<script>
  // src/features/network-compare/components/NetworkShareDonut.svelte
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import { NETWORK_COLORS, NETWORK_ORDER } from "../constants/indicators.js";
  import { buildShareDonut, formatInt } from "../utils/transformNetworkData.js";

  let { networks = [], field = "total_escolas", title = "Participação por rede" } = $props();

  const colorScale = $derived(
    Object.fromEntries(
      NETWORK_ORDER.map((key) => [
        key.charAt(0).toUpperCase() + key.slice(1),
        NETWORK_COLORS[key],
      ]),
    ),
  );

  const rows = $derived(buildShareDonut(networks, field));

  const total = $derived(rows.reduce((acc, r) => acc + r.value, 0));

  const options = $derived({
    title,
    donut: { center: { label: "Total", number: formatInt(total) } },
    data: { groupMapsTo: "group" },
    color: { scale: colorScale },
    legend: { position: "bottom" },
  });
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <DonutChart data={rows} {options} height="300px" />
</section>