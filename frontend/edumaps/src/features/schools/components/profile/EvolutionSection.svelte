<script>
  // src/features/schools/components/profile/EvolutionSection.svelte
  //
  // Série histórica da escola (issue #110): uma série por (indicador,
  // etapa), com os anos e uma barra proporcional + variação total.
  import { formatEvolutionValue } from '../../utils/transformEvolutionData.js';

  /** @type {{ groups?: Array<object> }} */
  let { groups = [] } = $props();

  function barWidth(pontos, valor) {
    const vals = pontos
      .map((p) => p.valor)
      .filter((v) => v !== null && !Number.isNaN(v));
    if (vals.length === 0 || valor === null || Number.isNaN(valor)) return 0;
    const min = Math.min(...vals, 0);
    const max = Math.max(...vals);
    if (max === min) return 100;
    return Math.max(4, Math.round(((valor - min) / (max - min)) * 100));
  }
</script>

<section class="flex flex-col gap-2" aria-label="Evolução">
  <h2 class="text-base font-bold text-gray-900">Evolução</h2>

  {#if groups.length === 0}
    <p class="text-sm text-gray-500">
      Sem histórico disponível para esta escola.
    </p>
  {:else}
    <div class="grid grid-cols-[repeat(auto-fill,minmax(260px,1fr))] gap-4">
      {#each groups as g (g.indicador + '::' + (g.etapa ?? ''))}
        <article class="bg-white border border-gray-200 rounded-md p-3 flex flex-col gap-2">
          <header class="flex items-baseline justify-between gap-2">
            <div class="min-w-0">
              <strong class="text-sm text-gray-900">{g.label}</strong>
              {#if g.etapaLabel}
                <span class="text-xs text-gray-500 block">{g.etapaLabel}</span>
              {/if}
            </div>
            {#if g.variacao !== null && g.variacao !== undefined}
              <span
                class={g.variacao >= 0 ? 'text-xs font-semibold text-emerald-700' : 'text-xs font-semibold text-red-700'}
                title="Variação entre o primeiro e o último ano"
              >
                {g.variacao >= 0 ? '▲' : '▼'}
                {formatEvolutionValue(Math.abs(g.variacao))}
              </span>
            {/if}
          </header>

          <ul class="flex flex-col gap-1">
            {#each g.pontos as p (p.ano)}
              <li class="flex items-center gap-2 text-xs">
                <span class="w-9 text-gray-500 font-mono">{p.ano}</span>
                <span class="grow h-1.5 bg-gray-100 rounded overflow-hidden">
                  <span
                    class="block h-full rounded bg-blue-500"
                    style="width: {barWidth(g.pontos, p.valor)}%"
                  ></span>
                </span>
                <span class="w-10 text-right font-mono text-gray-700">
                  {formatEvolutionValue(p.valor)}
                </span>
              </li>
            {/each}
          </ul>
        </article>
      {/each}
    </div>
  {/if}
</section>
