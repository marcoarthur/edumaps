<script>
  // src/shared/ui/components/charts/RadarChart.svelte
  //
  // Wrapper genérico (Svelte 5 / runes) para o RadarChart do Carbon.
  // Cuida do dimensionamento responsivo (ResizeObserver) que a lib base
  // não faz; o consumidor passa `data` e `options` do Carbon.
  import { onMount, onDestroy } from "svelte";
  import { RadarChart as CarbonRadarChart } from "@carbon/charts-svelte";

  let { data = [], options = {}, height = "320px", class: className = "" } = $props();

  const fallbackHeight = parseInt(height, 10) || 320;

  let holder = $state(null);
  let dims = { height: fallbackHeight, width: undefined };
  let chartOptions = $state({ ...options });

  // Snapshot NÃO reativo do que foi efectivamente passado ao Carbon. Usado
  // para só re-atribuir `chartOptions` (e disparar update()/re-render no
  // Carbon) quando o conteúdo muda de facto — evita interromper as transições
  // do próprio Carbon com re-renders de conteúdo idêntico (issue #200).
  let lastChart = null;

  let resizeObserver;
  let rafId = null;
  let hasMeasured = false;
  let onUnhandledRejection = null;

  function sameOptions(a, b) {
    const ka = Object.keys(a);
    const kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    return ka.every((k) => Object.is(a[k], b[k]));
  }

  function applyChartOptions(next) {
    if (lastChart !== null && sameOptions(next, lastChart)) return;
    lastChart = next;
    chartOptions = next;
  }

  // -- Carbon 1.22.x: "Uncaught (in promise) <rótulo>" (issue #200)
  //
  // O componente Radar do Carbon anima os rótulos do eixo com
  // `transition(...).end().finally(...)`. `.end()` devolve uma promise que
  // REJEITA com o datum do elemento (uma string: o rótulo da etapa, ex.:
  // "Infantil") quando a transição é interrompida por um novo update — o que
  // acontece sempre que o chart re-renderiza (ResizeObserver no mount, troca
  // de modo, etc.). Como o `.finally()` do Carbon não trata a rejeição, cada
  // interrupção vira um "Uncaught (in promise) "Infantil"" no console.
  //
  // Não dá para corrigir o Carbon (node_modules), então neutralizamos o
  // artefato no boundary do wrapper: enquanto este radar está montado,
  // suprimimos apenas rejeições cujo reason é uma STRING (os dados reais do
  // eixo). Erros de verdade (Error/objeto) continuam a propagar.
  function syncSize() {
    if (!holder) return;
    const w = holder.clientWidth > 10 ? holder.clientWidth : undefined;
    const h = holder.clientHeight > 10 ? holder.clientHeight : fallbackHeight;
    // Sem mudança real de tamanho (a primeira medição sempre aplica).
    if (hasMeasured && w === dims.width && h === dims.height) return;
    hasMeasured = true;
    dims = { width: w, height: h };
    applyChartOptions({ ...options, ...dims });
  }

  $effect(() => {
    applyChartOptions({ ...options, ...dims });
  });

  onMount(() => {
    syncSize();
    if (typeof ResizeObserver !== "undefined" && holder) {
      resizeObserver = new ResizeObserver(() => {
        // Coalesce rajadas do RO num único flush — evita re-render (e
        // interrupção das transições do Carbon) para o mesmo tamanho.
        if (rafId != null) return;
        rafId = requestAnimationFrame(() => {
          rafId = null;
          syncSize();
        });
      });
      resizeObserver.observe(holder);
    }

    onUnhandledRejection = (event) => {
      if (typeof event.reason === "string") {
        event.preventDefault();
        console.debug(
          "[RadarChart] rejeição suprimida (transition do Carbon interrompida):",
          event.reason,
        );
      }
    };
    window.addEventListener("unhandledrejection", onUnhandledRejection);
  });

  onDestroy(() => {
    if (rafId != null) cancelAnimationFrame(rafId);
    resizeObserver?.disconnect();
    if (onUnhandledRejection) {
      window.removeEventListener("unhandledrejection", onUnhandledRejection);
    }
  });
</script>

<div bind:this={holder} class="relative w-full overflow-hidden {className}" style:height>
  <CarbonRadarChart data={data} options={chartOptions} />
</div>