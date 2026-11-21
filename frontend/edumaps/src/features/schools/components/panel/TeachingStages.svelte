<script>
  // src/features/school/panel/TeachingStages.svelte
  import Icon from '../icons/Icon.svelte';
  import { ETAPAS_ORDER } from '../icons/icon-data.js';

  /**
   * stages: { creche: bool|null, pre_escola: bool|null, ... } — mesmas chaves
   * de ETAPAS_ORDER. null ou ausente = sem dado (n/d, #510); false = não
   * oferece.
   */
  let { stages = {} } = $props();
</script>

<section class="flex flex-wrap gap-4 py-4" aria-label="Etapas de ensino oferecidas">
  {#each ETAPAS_ORDER as stageId}
    <Icon name={stageId} size={50} active={stages[stageId] ?? null} showLabel />
  {/each}
</section>
