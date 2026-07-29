<script>
  /**
   * @typedef {Object} Props
   * @property {Array} [indicators] - saída de EduMaps::Model::Rank::School->rank(),
   *   um item por indicador:
   *   {
   *     indicador: { id, label, valor },
   *     ano,
   *     ranking: {
   *       municipio: { posicao, total, percentil } | null,
   *       estado:    { posicao, total, percentil } | null,
   *       nacional:  { posicao, total, percentil } | null,
   *     }
   *   }
   *   Mantemos os nomes de campo em português aqui de propósito: são o
   *   contrato JSON exato retornado pela API, não um objeto que criamos.
   * @property {'municipio'|'estado'|'nacional'} [primaryScope] - escopo em destaque no selo
   */

  /** @type {Props} */
  let { indicators = [], primaryScope = "municipio" } = $props();

  const scopeLabel = { municipio: "no município", estado: "no estado", nacional: "no Brasil" };
</script>

<section class="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-4" aria-label="Indicadores e ranking">
  {#each indicators as item (item.indicador.id)}
    {@const rank = item.ranking?.[primaryScope]}
    <article class="flex gap-3.5 items-center bg-white border border-gray-200 rounded-md p-3.5">
      <!-- Selo circular estilo carimbo — elemento de assinatura do painel -->
      <div
        class="flex-none w-14 h-14 rounded-full border-2 flex flex-col items-center justify-center font-display text-amber-500"
        class:border-gray-300={!rank}
        class:text-gray-400={!rank}
        class:border-amber-500={!!rank}
      >
        {#if rank}
          <span class="text-lg font-bold leading-none">{rank.posicao}</span>
          <span class="text-[9px] font-mono">de {rank.total}</span>
        {:else}
          <span class="text-lg font-bold leading-none">—</span>
        {/if}
      </div>

      <div class="flex flex-col">
        <h4 class="m-0 font-sans text-sm font-semibold text-gray-900">{item.indicador.label}</h4>
        <p class="m-0 font-mono text-base text-gray-900">
          {item.indicador.valor}
          <span class="text-[11px] text-gray-500">({item.ano})</span>
        </p>
        {#if rank}
          <p class="mt-0.5 text-xs text-green-600">
            Acima de {rank.percentil}% {scopeLabel[primaryScope]}
          </p>
        {/if}
      </div>
    </article>
  {/each}
</section>
