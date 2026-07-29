<script>
  // src/features/school/panel/TeachingStages.svelte
  import Icon from '../icons/Icon.svelte';
  import { ETAPAS_ORDER } from '../icons/icon-data.js';

  /**
   * stages: { creche: bool, pre_escola: bool, fundamental_i: bool, ... }
   * — mesmas chaves de ETAPAS_ORDER. Chaves ausentes no objeto são
   * tratadas como `false` (etapa não oferecida).
   */
  let { stages = {} } = $props();
</script>

<section class="flex flex-wrap gap-4 py-4" aria-label="Etapas de ensino oferecidas">
  {#each ETAPAS_ORDER as stageId}
    <Icon name={stageId} size={50} active={!!stages[stageId]} showLabel />
  {/each}
</section>
