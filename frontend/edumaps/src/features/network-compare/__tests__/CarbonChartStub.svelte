<script>
  // src/features/network-compare/__tests__/CarbonChartStub.svelte
  //
  // Stub usado nos testes (o motor do @carbon/charts depende de APIs SVG
  // que o jsdom não implementa — getComputedTextLength/baseVal). Reproduz
  // o contrato (data/options) dos wrappers de @carbon/charts-svelte para
  // que os testes da feature validem a fiação sem renderizar o gráfico.
  let { data = [], options = {} } = $props();
</script>

<div data-testid="carbon-chart-stub" data-rows={data.length} data-height={options.height ?? 0}>
  {#if options.title}
    <p>⚛ {options.title}</p>
  {/if}
</div>