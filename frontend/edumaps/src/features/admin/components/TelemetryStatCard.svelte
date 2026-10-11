<!-- src/features/admin/components/TelemetryStatCard.svelte -->
<script>
  // Cartão de KPI do painel. `tone` dá a cor do número.
  let { label, value, hint = null, tone = "default" } = $props();

  const TONES = {
    default: "text-gray-900",
    brand: "text-brand-700",
    positive: "text-emerald-700",
    muted: "text-gray-500",
  };
</script>

<div class="bg-white border border-gray-200 rounded-card shadow-card p-4">
  <p class="text-xs font-medium uppercase tracking-wide text-gray-500">{label}</p>
  <p class="mt-1 text-3xl font-bold {TONES[tone] ?? TONES.default}">{value}</p>
  {#if hint}
    <p class="mt-1 text-xs text-gray-500">{hint}</p>
  {/if}
</div>
