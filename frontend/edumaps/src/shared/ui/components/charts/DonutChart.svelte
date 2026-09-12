<script>
  // src/shared/ui/components/charts/DonutChart.svelte
  import { onMount, onDestroy } from "svelte";
  import { DonutChart as CarbonDonutChart } from "@carbon/charts-svelte";

  let { data = [], options = {}, height = "320px", class: className = "" } = $props();

  const fallbackHeight = parseInt(height, 10) || 320;

  let holder = $state(null);
  let dims = { height: fallbackHeight, width: undefined };
  let chartOptions = $state({ ...options });

  let resizeObserver;

  function syncSize() {
    if (!holder) return;
    const w = holder.clientWidth > 10 ? holder.clientWidth : undefined;
    const h = holder.clientHeight > 10 ? holder.clientHeight : fallbackHeight;
    dims = { width: w, height: h };
    chartOptions = { ...options, ...dims };
  }

  $effect(() => {
    chartOptions = { ...options, ...dims };
  });

  onMount(() => {
    syncSize();
    if (typeof ResizeObserver !== "undefined" && holder) {
      resizeObserver = new ResizeObserver(syncSize);
      resizeObserver.observe(holder);
    }
  });

  onDestroy(() => resizeObserver?.disconnect());
</script>

<div bind:this={holder} class="relative w-full overflow-hidden {className}" style:height>
  <CarbonDonutChart data={data} options={chartOptions} />
</div>