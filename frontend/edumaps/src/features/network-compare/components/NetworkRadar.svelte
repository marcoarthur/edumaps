<script>
  // src/features/network-compare/components/NetworkRadar.svelte
  import RadarChart from "@/shared/ui/components/charts/RadarChart.svelte";
  import { NETWORK_COLORS, NETWORK_ORDER, RADAR_MODES } from "../constants/indicators.js";
  import { buildShareRadarData, buildVolumeRadarData } from "../utils/transformNetworkData.js";

  let { networks = [] } = $props();

  let mode = $state("share");

  const colorScale = $derived(
    Object.fromEntries(
      NETWORK_ORDER.map((key) => [
        key.charAt(0).toUpperCase() + key.slice(1),
        NETWORK_COLORS[key],
      ]),
    ),
  );

  const rows = $derived(
    mode === "share"
      ? buildShareRadarData(networks)
      : buildVolumeRadarData(networks),
  );

  const options = $derived({
    title:
      mode === "share"
        ? "Perfil das matrículas por etapa (% da própria rede)"
        : "Matrículas por etapa (normalizadas pelo maior valor)",
    radar: {
      axes: { angle: "stage", value: "value" },
    },
    data: { groupMapsTo: "group" },
    color: { scale: colorScale },
    legend: { position: "bottom" },
    tooltip: {
      customHTML: (data) => {
        const { group, stage, value, matricula } = data[0]?.datum ?? data?.[0] ?? {};
        if (stage === undefined) return "";
        return `<div class="cds--tooltip-text">${group} · ${stage}<br/>` +
          `<strong>${Number(value).toLocaleString("pt-BR")}</strong>${mode === "share" ? "%" : ""}` +
          (matricula !== undefined ? ` (${Number(matricula).toLocaleString("pt-BR")})` : "") +
          `</div>`;
      },
    },
  });
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-4">
  <div class="flex items-center justify-between flex-wrap gap-3">
    <h2 class="text-lg font-bold text-gray-900">Matrículas por etapa e rede</h2>
    <div class="flex rounded-md bg-gray-100 p-1 text-sm" role="group" aria-label="Modo do radar">
      {#each RADAR_MODES as m}
        <button
          type="button"
          role="radio"
          aria-checked={mode === m.key}
          title={m.description}
          onclick={() => (mode = m.key)}
          class="px-3 py-1 rounded-md transition-colors {mode === m.key
            ? 'bg-brand-600 text-white'
            : 'text-gray-600 hover:text-gray-900'}"
        >
          {m.label}
        </button>
      {/each}
    </div>
  </div>

  <p class="text-xs text-gray-500">
    {RADAR_MODES.find((m) => m.key === mode)?.description}
  </p>

  <RadarChart data={rows} {options} height="340px" />
</section>