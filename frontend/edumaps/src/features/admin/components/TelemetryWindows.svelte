<!-- src/features/admin/components/TelemetryWindows.svelte -->
<script>
  // Seletor de janela de tempo. Controla as métricas de atividade, a série e
  // as rotas (o cartão de logins fica fixo em 6/12/24 h).
  import { TELEMETRY_WINDOWS } from "../constants/windows.js";

  let { value, onSelect } = $props();
</script>

<div class="flex flex-wrap gap-1" role="group" aria-label="Janela de tempo">
  {#each TELEMETRY_WINDOWS as w (w.key)}
    <button
      type="button"
      onclick={() => onSelect(w.key)}
      aria-pressed={value === w.key}
      class="px-3 py-1.5 text-sm rounded-md border transition-colors {value === w.key
        ? 'bg-brand-700 text-white border-brand-700'
        : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'}"
    >
      {w.label}
    </button>
  {/each}
</div>
