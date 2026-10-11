<!-- src/features/admin/components/TelemetryTimeseries.svelte -->
<script>
  // Série temporal de eventos e sessões. Os rótulos do eixo X são derivados do
  // bucket do backend (sem fuso): "YYYY-MM-DD" (dia) ou "YYYY-MM-DDTHH:MM" (hora).
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";

  let { series = [], granularity = "hour" } = $props();

  function label(bucket) {
    if (granularity === "day") return `${bucket.slice(8, 10)}/${bucket.slice(5, 7)}`;
    return bucket.slice(11, 16);
  }

  const rows = $derived(
    (series ?? []).flatMap((p) => [
      { group: "Eventos", key: label(p.bucket), value: p.events },
      { group: "Sessões", key: label(p.bucket), value: p.sessions },
    ]),
  );

  const options = $derived({
    axes: {
      left: { mapsTo: "value", title: "Contagem" },
      bottom: { mapsTo: "key", scaleType: "labels" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: { Eventos: "#0f62fe", Sessões: "#08bdba" } },
    legend: { position: "bottom" },
    curve: "curveMonotoneX",
    points: { enabled: series.length <= 24 },
  });
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5">
  <h2 class="text-lg font-bold text-gray-900">Atividade ao longo do tempo</h2>
  {#if rows.length > 0}
    <div class="mt-3">
      <LineChart data={rows} {options} height="320px" />
    </div>
  {:else}
    <p class="text-sm text-gray-500 mt-3">Sem eventos registrados nesta janela.</p>
  {/if}
</section>
