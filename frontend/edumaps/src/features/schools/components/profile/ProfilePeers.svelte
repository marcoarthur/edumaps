<script>
  // src/features/schools/components/profile/ProfilePeers.svelte
  //
  // Escolas similares do perfil (benchmarking justo por Gower). O payload
  // traz { co_entidade, no_entidade, similarity, ideb_observado }.
  import { formatSimilarity } from '../../utils/transformProfileData.js';

  let { peers = [], sourceLabel = '', onSelect = () => {} } = $props();
</script>

<section class="flex flex-col gap-2" aria-label="Escolas similares">
  <div class="flex items-baseline justify-between gap-3">
    <h2 class="text-base font-bold text-gray-900">Escolas similares</h2>
    {#if sourceLabel}
      <span class="text-xs text-gray-500">fonte: {sourceLabel}</span>
    {/if}
  </div>

  {#if peers.length === 0}
    <p class="text-sm text-gray-500">
      Nenhuma escola similar encontrada dentro do limiar de distância.
    </p>
  {:else}
    <div class="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-4">
      {#each peers as peer (peer.co_entidade)}
        <button
          class="text-left bg-white border border-gray-200 rounded-md p-3 flex flex-col gap-1 hover:border-amber-500 transition-colors"
          onclick={() => onSelect(peer.co_entidade)}
        >
          <strong class="text-sm text-gray-900">{peer.no_entidade}</strong>
          <span class="text-xs text-gray-500 font-mono">INEP {peer.co_entidade}</span>
          <span class="text-xs text-gray-600">
            Similaridade {formatSimilarity(peer.similarity)}
            {#if peer.ideb_observado !== null && peer.ideb_observado !== undefined}
              · IDEB {Number(peer.ideb_observado).toFixed(1)}
            {/if}
          </span>
        </button>
      {/each}
    </div>
  {/if}
</section>
