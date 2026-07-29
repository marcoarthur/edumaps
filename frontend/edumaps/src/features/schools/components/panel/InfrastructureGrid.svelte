<script>
  // src/features/school/components/panel/InfrastructureGrid.svelte
  import Icon from '../icons/Icon.svelte';
  import { INFRA_ORDER } from '../icons/icon-data.js';

  /**
   * infrastructure: { potable_water: bool, power: bool, ... }
   */
  let { infrastructure = {} } = $props();
</script>

<section
  class="grid grid-cols-[repeat(auto-fill,minmax(64px,1fr))] gap-3.5 bg-white border border-gray-200 rounded-lg p-4"
  aria-label="Infraestrutura da escola"
>
  {#each INFRA_ORDER as itemId}
    <div class="flex justify-center">
      <Icon name={itemId} size={30} active={!!infrastructure[itemId]} showLabel />
    </div>
  {/each}
</section>
