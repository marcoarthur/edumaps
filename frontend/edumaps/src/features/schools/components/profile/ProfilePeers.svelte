<script>
  // src/features/schools/components/profile/ProfilePeers.svelte
  //
  // Escolas similares do perfil. O payload traz
  // { co_entidade, no_entidade, similarity, ideb_observado }.
  // Desde a #495 são as escolas mais próximas do grupo de referência: o
  // mesmo contexto (rede, localização, porte, etapas, INSE), no município
  // inteiro, sem o IDEB e a nota. Cada cartão mostra a diferença de IDEB
  // para a escola, para achar "contexto parecido, resultado diferente".
  import { formatSimilarity, idebDiferencaTexto } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let {
    peers = [],
    sourceLabel = '',
    criterio = null,
    escolaIdeb = null,
    onSelect = () => {},
  } = $props();

  const itens = $derived(
    criterio
      ? [
          criterio,
          'O mesmo critério do grupo de referência: as similares são as escolas mais próximas dele, comparadas com o município inteiro.',
          'Similaridade = 1 − distância de Gower (0 a 100%); ordenadas da mais parecida.',
          'Exibimos até 10 escolas dentro do limiar de distância, com o IDEB de cada uma e a diferença para esta escola.',
        ]
      : [
          'Gower mede a proximidade considerando indicadores numéricos e categóricos.',
          'Similaridade = 1 − distância (0 a 100%); ordenadas da mais parecida.',
          'Exibimos até 10 escolas dentro do limiar de distância.',
        ]
  );
</script>

<section class="flex flex-col gap-2" aria-label="Escolas similares">
  <div class="flex items-center justify-between gap-3 flex-wrap">
    <div class="flex items-center gap-2">
      <h2 class="text-base font-bold text-gray-900">Escolas similares</h2>
      <InfoHint
        title="Como escolhemos as similares"
        text={criterio
          ? 'Escolas de contexto parecido no município, sem o IDEB e a nota: o resultado pode ser bem diferente.'
          : 'Comparação por similaridade de Gower.'}
        items={itens}
      />
    </div>
    {#if sourceLabel}
      <span class="text-xs text-gray-500" data-testid="peers-fonte">fonte: {sourceLabel}</span>
    {/if}
  </div>

  {#if peers.length === 0}
    <p class="text-sm text-gray-500">
      Nenhuma escola similar encontrada dentro do limiar de distância.
    </p>
  {:else}
    <div class="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-4">
      {#each peers as peer (peer.co_entidade)}
        {@const diff = idebDiferencaTexto(peer.ideb_observado, escolaIdeb)}
        <button
          class="text-left bg-white border border-gray-200 rounded-md p-3 flex flex-col gap-1 hover:border-amber-500 transition-colors"
          onclick={() => onSelect(peer.co_entidade)}
        >
          <strong class="text-sm text-gray-900">{peer.no_entidade}</strong>
          <span class="text-xs text-gray-500 font-mono">INEP {peer.co_entidade}</span>
          <span class="text-xs text-gray-600">
            Similaridade {formatSimilarity(peer.similarity)}
            {#if peer.ideb_observado !== null && peer.ideb_observado !== undefined}
              · IDEB {Number(peer.ideb_observado).toFixed(1).replace('.', ',')}
              {#if diff}
                <span data-testid="peer-ideb-diferenca">({diff})</span>
              {/if}
            {/if}
          </span>
        </button>
      {/each}
    </div>

    <p class="text-xs text-gray-500">
      Similaridade 0–100% (1 − distância de Gower), da mais parecida para a menos.
      {#if escolaIdeb !== null && escolaIdeb !== undefined}
        Entre parênteses, a diferença de IDEB para esta escola ({Number(escolaIdeb).toFixed(1).replace('.', ',')}).
      {/if}
    </p>
  {/if}
</section>
