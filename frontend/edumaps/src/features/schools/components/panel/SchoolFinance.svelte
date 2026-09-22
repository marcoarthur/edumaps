<script>
  // src/features/schools/components/panel/SchoolFinance.svelte
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";
  import DonutChart from "@/shared/ui/components/charts/DonutChart.svelte";
  import Icon from "../icons/Icon.svelte";
  import { router } from "@/app/router.svelte.js";
  import {
    buildCostRows,
    buildProfessionalsRows,
    buildCategoryBuckets,
    buildCategoryRows,
    buildPeriodOptions,
    summarize,
    formatBRL,
    formatBRLCompact,
    formatInt,
  } from "../../utils/transformFinanceData.js";

  /**
   * @typedef {Object} Props
   * @property {string|number} inep
   * @property {{ nome?: string }|null} [escola]
   * @property {number} [totalProfissionais] total de profissionais distintos (todos os meses)
   * @property {Array<{ ano, mes, mes_num, total_salario, total_profissionais }>} [series]
   * @property {Array<{ categoria, tipo, total_salario, total_profissionais }>} [categorias]
   */

  /** @type {Props} */
  let { inep, escola = null, totalProfissionais = 0, origem = "escola", series = [], categorias = [] } = $props();

  // Quando o SIOPE não detalha a folha por escola (origem='secretaria'), todo o
  // painel é escopado como REDE MUNICIPAL — nunca como se fosse da unidade.
  const ehRede = $derived(origem === "secretaria");
  const escopo = $derived(ehRede ? "rede municipal" : "escola");
  const escopoTitulo = $derived(ehRede ? "Rede municipal (Secretaria)" : "");

  const costRows = $derived(buildCostRows(series));
  const professionalRows = $derived(buildProfessionalsRows(series));
  const buckets = $derived(buildCategoryBuckets(categorias));
  const categoryRows = $derived(buildCategoryRows(buckets));
  const periodOptions = $derived(buildPeriodOptions(series));
  const stats = $derived(summarize(series));

  let selectedPeriod = $state("");
  $effect(() => {
    // Mantém a competência mais recente como padrão do dropdown.
    if (!selectedPeriod && periodOptions.length > 0) {
      selectedPeriod = periodOptions[0].value;
    }
  });

  const costOptions = $derived({
    title: `Custo total mensal${ehRede ? " — rede municipal" : ""}`,
    axes: {
      left: { mapsTo: "value", title: "R$" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Mês" },
    },
    data: { groupMapsTo: "group" },
    legend: { enabled: false },
    curve: "curveMonotoneX",
    points: { enabled: true },
  });

  const professionalOptions = $derived({
    title: `Profissionais por mês${ehRede ? " — rede municipal" : ""}`,
    axes: {
      left: { mapsTo: "value", title: "Profissionais" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Mês" },
    },
    data: { groupMapsTo: "group" },
    legend: { enabled: false },
    curve: "curveMonotoneX",
    points: { enabled: true },
  });

  const categoryColorScale = $derived(
    Object.fromEntries(buckets.map((b) => [b.bucket.label, b.bucket.color])),
  );

  const categoryOptions = $derived({
    title: `Custo por categoria${ehRede ? " — rede municipal" : ""}`,
    donut: { center: { label: "Total", number: formatBRLCompact(stats.totalCusto) } },
    data: { groupMapsTo: "group" },
    color: { scale: categoryColorScale },
    legend: { position: "bottom" },
  });

  function verFolhaCompleta() {
    if (!selectedPeriod) return;
    router.navigate(`/escola/payroll?inep=${inep}&date=${selectedPeriod}`);
  }
</script>

<div class="space-y-6">
  {#if ehRede}
    <div class="rounded-md bg-amber-50 border border-amber-300 text-amber-900 text-sm p-4">
      <p class="font-semibold">Painel da rede municipal — não desta escola</p>
      <p class="mt-1">
        O SIOPE não detalha a folha por escola neste município; os dados vêm
        agregados na Secretaria municipal. Os números abaixo são o
        <strong>total da rede</strong> e <strong>não permitem identificar</strong>
        quem atua nesta unidade.
      </p>
    </div>
  {/if}

  <!-- Totais -->
  <section class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">
        Custo total (período){#if ehRede} · {escopoTitulo}{/if}
      </p>
      <p class="text-xl font-bold text-gray-900 mt-1">
        {formatBRL(stats.totalCusto)}
      </p>
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">
        Profissionais (total){#if ehRede} · {escopoTitulo}{/if}
      </p>
      <p class="text-xl font-bold text-gray-900 mt-1">
        {formatInt(totalProfissionais)}
      </p>
      <p class="text-xs text-gray-400 mt-0.5">
        Competência mais recente ({stats.lastPeriod ?? "—"}): {formatInt(stats.lastProfessionals)}
      </p>
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
      <p class="text-xs text-gray-500">Competências com dados</p>
      <p class="text-xl font-bold text-gray-900 mt-1">{stats.mesCount}</p>
    </div>
  </section>

  <!-- Séries temporais -->
  <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if costRows.length > 0}
        <LineChart data={costRows} options={costOptions} height="300px" />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de custo.</p>
      {/if}
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      {#if professionalRows.length > 0}
        <LineChart
          data={professionalRows}
          options={professionalOptions}
          height="300px"
        />
      {:else}
        <p class="text-sm text-gray-500">Sem dados de profissionais.</p>
      {/if}
    </div>
  </section>

  <!-- Custo por categoria -->
  {#if buckets.length > 0}
    <section class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <DonutChart data={categoryRows} options={categoryOptions} height="300px" />
      </div>

      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <h2 class="text-base font-bold text-gray-900 mb-3">
          Categorias profissionais{#if ehRede} — rede municipal{/if}
        </h2>
        <ul class="flex flex-col gap-3">
          {#each buckets as b (b.bucket.id)}
            {@const share = stats.totalCusto > 0
              ? Math.round((b.total_salario / stats.totalCusto) * 100)
              : 0}
            <li class="flex items-center gap-3">
              <Icon name={b.bucket.icon} size={26} active />
              <div class="grow">
                <p class="text-sm text-gray-800">{b.bucket.label}</p>
                <p class="text-xs text-gray-500">
                  {formatInt(b.total_profissionais)} profissional(is) · {share}%
                </p>
              </div>
              <span class="text-sm font-medium text-gray-900 whitespace-nowrap">
                {formatBRL(b.total_salario)}
              </span>
            </li>
          {/each}
        </ul>
      </div>
    </section>
  {/if}

  <!-- Folha completa (detalhes por competência) -->
  <section
    class="bg-white border border-gray-200 rounded-card shadow-card p-5 flex flex-wrap items-end gap-3"
  >
    <div>
      <label for="competencia" class="block text-sm text-gray-600 mb-1">
        Ver folha completa (detalhes){#if ehRede} — rede municipal{/if}
      </label>
      <select
        id="competencia"
        bind:value={selectedPeriod}
        class="border border-gray-300 rounded-md px-3 py-2 text-sm"
      >
        {#each periodOptions as p}
          <option value={p.value}>{p.label}</option>
        {/each}
      </select>
    </div>
    <button
      type="button"
      onclick={verFolhaCompleta}
      disabled={!selectedPeriod || ehRede}
      title={ehRede ? "A folha detalhada (nomes) só existe quando o SIOPE detalha por escola" : ""}
      class="px-4 py-2 bg-blue-700 text-white text-sm font-medium rounded-md hover:bg-blue-800 transition-colors disabled:opacity-50"
    >
      Ver folha completa →
    </button>
    <p class="text-xs text-gray-400 basis-full">
      {#if ehRede}
        A folha detalhada (nomes dos profissionais) não está disponível: neste
        município o SIOPE não detalha por escola.
      {:else}
        {escola?.nome ?? ""} — a folha lista os profissionais (nomes) apenas na
        página de detalhes.
      {/if}
    </p>
  </section>
</div>
