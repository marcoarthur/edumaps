<script>
  // src/features/gestor/components/TeachersSection.svelte
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import BarChartGrouped from "@/shared/ui/components/charts/BarChartGrouped.svelte";
  import BreakdownList from "./BreakdownList.svelte";
  import { CHART_COLORS } from "../constants/gestor.js";
  import {
    buildDisciplinaRows,
    toBreakdownItems,
    formatInt,
  } from "../utils/transformGestorData.js";

  let { docentes = {} } = $props();

  const vinculoItems = $derived(toBreakdownItems(docentes.por_vinculo));
  const formacaoItems = $derived(toBreakdownItems(docentes.por_formacao));
  const disciplinaRows = $derived(buildDisciplinaRows(docentes.por_disciplina, 8));

  const vinculoRows = $derived(
    vinculoItems.map((i) => ({ group: i.label, value: i.value })),
  );

  const vinculoOptions = $derived({
    title: "Docentes por vínculo",
    donut: { center: { label: "Docentes", number: formatInt(docentes.total) } },
    data: { groupMapsTo: "group" },
    legend: { position: "bottom" },
  });

  const disciplinaOptions = $derived({
    title: "Docentes por disciplina",
    axes: {
      left: { mapsTo: "value", title: "Docentes" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Disciplina" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: { Docentes: CHART_COLORS.disciplina } },
    legend: { enabled: false },
  });
</script>

<section class="space-y-4">
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if vinculoRows.length > 0}
        <DonutChart data={vinculoRows} options={vinculoOptions} height="300px" />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de vínculo docente.</p>
      {/if}
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <h3 class="text-base font-bold text-gray-900 mb-4">Docentes por formação</h3>
      {#if formacaoItems.length > 0}
        <BreakdownList items={formacaoItems} color={CHART_COLORS.vinculo} />
        <p class="text-[11px] text-gray-400 mt-3">{docentes.nota_formacao}</p>
      {:else}
        <p class="text-sm text-gray-500">Sem dados de formação.</p>
      {/if}
    </div>
  </div>

  {#if disciplinaRows.length > 0}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <BarChartGrouped data={disciplinaRows} options={disciplinaOptions} height="320px" />
    </div>
  {/if}
</section>
