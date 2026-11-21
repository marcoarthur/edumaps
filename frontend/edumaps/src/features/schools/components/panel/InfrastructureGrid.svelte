<script>
  // src/features/school/components/panel/InfrastructureGrid.svelte
  import Icon from '../icons/Icon.svelte';
  import { INFRA_ORDER } from '../icons/icon-data.js';

  /**
   * infrastructure: { agua_potavel: bool|null, energia: bool|null, ... } —
   * mesmas chaves de INFRA_ORDER; null/ausente = sem dado (n/d, #510).
   * detail: { esgoto?: 'rede_publica'|'outra_solucao', energia?: ... }.
   */
  let { infrastructure = {}, detail = {} } = $props();

  const DETALHE = { rede_publica: 'rede pública', outra_solucao: 'outra solução' };
</script>

<section
  class="grid grid-cols-[repeat(auto-fill,minmax(64px,1fr))] gap-3.5 bg-white border border-gray-200 rounded-lg p-4"
  aria-label="Infraestrutura da escola"
>
  {#each INFRA_ORDER as itemId}
    <div class="flex justify-center">
      <Icon name={itemId} size={30} active={infrastructure[itemId] ?? null}
        detail={DETALHE[detail?.[itemId]] ?? null} showLabel />
    </div>
  {/each}
</section>
