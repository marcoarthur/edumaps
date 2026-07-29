<script>
  // src/features/schools/components/panel/SimilarSchools.svelte
  import Icon from '../icons/Icon.svelte';
  import { ETAPAS_ORDER, NETWORK_LABELS } from '../icons/icon-data.js';

  /**
   * schools: array de escolas semelhantes, já ordenadas pelo backend
   * cada item:
   * { id_escola, nome, rede, matriculas, etapas: {...},
   *   indicador_principal: { label, valor } }
   */
  let { schools = [], onSelect = (schoolId) => {} } = $props();
</script>

<section class="grid grid-cols-[repeat(auto-fill,minmax(240px,1fr))] gap-4" aria-label="Escolas semelhantes">
  {#each schools as school (school.id_escola)}
    <button
      class="text-left bg-white border border-gray-200 rounded-md p-3 cursor-pointer flex flex-col gap-2 hover:border-amber-500 transition-colors"
      onclick={() => onSelect(school.id_escola)}
    >
      <div class="flex justify-between gap-2 text-sm text-gray-900">
        <strong>{school.nome}</strong>
        <span class="text-xs text-gray-500 whitespace-nowrap">
          {NETWORK_LABELS[school.rede] ?? school.rede}
        </span>
      </div>

      <div class="flex gap-1.5 flex-wrap">
        {#each ETAPAS_ORDER.filter((id) => school.etapas?.[id]) as stageId}
          <Icon name={stageId} size={30} active={true} />
        {/each}
      </div>

      <div class="flex justify-between text-xs text-gray-500 font-mono">
        <span>{school.matriculas} matrículas </span>
        {#if school.indicador_principal}
          <span>
            {school.indicador_principal.label}: {school.indicador_principal.valor}
          </span>
        {/if}
      </div>
    </button>
  {/each}

  {#if schools.length === 0}
    <p class="col-span-full text-gray-500 font-sans">
      Nenhuma escola semelhante encontrada para os critérios atuais.
    </p>
  {/if}
</section>
