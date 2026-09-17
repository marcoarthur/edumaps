<script>
  // src/features/schools/components/panel/SchoolPerformance.svelte
  import LineChart from "@/shared/ui/components/charts/LineChart.svelte";

  /**
   * Série histórica de desempenho (IDEB observado) por etapa.
   * @type {{ desempenho?: Array<{ ano: number, etapa: string, ideb_observado: number|null }> }}
   */
  let { desempenho = [] } = $props();

  // Rótulos/ordem locais (não importar de outra feature — regra de camadas).
  const ETAPA_ORDER = ["fundamental_i", "fundamental_ii", "ensino_medio"];
  const ETAPA_LABELS = {
    fundamental_i: "Fundamental I",
    fundamental_ii: "Fundamental II",
    ensino_medio: "Ensino Médio",
  };
  const ETAPA_COLORS = {
    fundamental_i: "#2563eb",
    fundamental_ii: "#16a34a",
    ensino_medio: "#f59e0b",
  };

  // Uma série (linha) por etapa; ignora anos sem IDEB observado.
  const rows = $derived.by(() => {
    const out = [];
    for (const etapa of ETAPA_ORDER) {
      const points = desempenho
        .filter((d) => d.etapa === etapa && d.ideb_observado != null)
        .sort((a, b) => a.ano - b.ano);
      for (const d of points) {
        out.push({
          group: ETAPA_LABELS[etapa] ?? etapa,
          key: String(d.ano),
          value: d.ideb_observado,
        });
      }
    }
    return out;
  });

  const options = $derived({
    title: "IDEB observado por etapa",
    axes: {
      left: { mapsTo: "value", title: "IDEB" },
      bottom: { mapsTo: "key", scaleType: "labels", title: "Ano" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: ETAPA_COLORS },
    legend: { position: "bottom" },
    curve: "curveMonotoneX",
    points: { enabled: true },
  });
</script>

{#if rows.length > 0}
  <LineChart data={rows} {options} height="340px" />
{:else}
  <p class="text-sm text-gray-500">
    Sem resultados de IDEB observado para esta escola.
  </p>
{/if}
