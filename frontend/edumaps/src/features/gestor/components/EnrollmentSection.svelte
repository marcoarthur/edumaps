<script>
  // src/features/gestor/components/EnrollmentSection.svelte
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import BarChartGrouped from "@/shared/ui/components/charts/BarChartGrouped.svelte";
  import BreakdownList from "./BreakdownList.svelte";
  import Icon from "./icons/Icon.svelte";
  import { CHART_COLORS, etapaColorScale } from "../constants/gestor.js";
  import {
    buildEtapaRows,
    buildFaixaRows,
    toBreakdownItems,
    formatInt,
  } from "../utils/transformGestorData.js";

  let { matriculas = {}, resumo = {} } = $props();

  const total = $derived(matriculas.total ?? resumo.matriculas ?? 0);
  const etapaRows = $derived(buildEtapaRows(matriculas.por_etapa));
  const faixaRows = $derived(buildFaixaRows(matriculas.por_faixa_etaria));
  const turnoItems = $derived(toBreakdownItems(matriculas.por_turno).map((i) => ({ ...i, key: i.key })));
  const modalidadeItems = $derived(
    toBreakdownItems(matriculas.por_modalidade).map((i) => ({ ...i, key: i.key })),
  );
  const inclusao = $derived(matriculas.inclusao ?? {});

  const etapaOptions = $derived({
    title: "Matrículas por etapa",
    donut: { center: { label: "Total", number: formatInt(total) } },
    data: { groupMapsTo: "group" },
    color: { scale: etapaColorScale(matriculas.por_etapa ?? []) },
    legend: { position: "bottom" },
  });

  const faixaOptions = $derived({
    title: "Matrículas por faixa etária",
    axes: {
      left: { mapsTo: "value", title: "Alunos" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Faixa" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: { Alunos: CHART_COLORS.faixa } },
    legend: { enabled: false },
  });
</script>

<section class="space-y-4">
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if etapaRows.length > 0}
        <DonutChart data={etapaRows} options={etapaOptions} height="300px" />
      {:else}
        <p class="text-sm text-gray-500">Sem matrículas registradas.</p>
      {/if}
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if faixaRows.some((r) => r.value > 0)}
        <BarChartGrouped data={faixaRows} options={faixaOptions} height="300px" />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de faixa etária.</p>
      {/if}
    </div>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <h3 class="text-base font-bold text-gray-900 mb-4">Matrículas por turno</h3>
      <BreakdownList items={turnoItems} color={CHART_COLORS.turno} />
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <h3 class="text-base font-bold text-gray-900 mb-4">Matrículas por modalidade</h3>
      <BreakdownList items={modalidadeItems} color={CHART_COLORS.modalidade} />
    </div>
  </div>

  {#if inclusao.educacao_especial}
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5 flex flex-wrap gap-6">
      <div class="flex items-center gap-2">
        <Icon name="inclusao" size={28} />
        <div>
          <p class="text-xs text-gray-500">Educação especial</p>
          <p class="text-lg font-bold text-gray-900">{formatInt(inclusao.educacao_especial)}</p>
        </div>
      </div>
      <div>
        <p class="text-xs text-gray-500">Em classes comuns</p>
        <p class="text-lg font-bold text-gray-900">{formatInt(inclusao.classes_comuns)}</p>
      </div>
      <div>
        <p class="text-xs text-gray-500">Em classes exclusivas</p>
        <p class="text-lg font-bold text-gray-900">{formatInt(inclusao.classes_exclusivas)}</p>
      </div>
      {#if resumo.regime_integral}
        <div>
          <p class="text-xs text-gray-500">Tempo integral</p>
          <p class="text-lg font-bold text-gray-900">{formatInt(resumo.regime_integral)}</p>
        </div>
      {/if}
    </div>
  {/if}
</section>
