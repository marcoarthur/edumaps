<script>
  // src/features/schools/components/panel/SimilarSchools.svelte
  import Icon from '../icons/Icon.svelte';
  import { ETAPAS_ORDER, NETWORK_LABELS } from '../icons/icon-data.js';

  /**
   * schools: array de escolas semelhantes, já ordenadas pelo backend
   * cada item:
   * { id_escola, nome, rede, matriculas, etapas: {...},
   *   distancia: pontos (euclidiana entre as seis notas) ou null,
   *   notas: [{ id, rotulo, valor, escola }] }  (#487)
   * motivo: por que a lista veio vazia — "sem_dado" quando falta alguma nota
   * da escola (#413); null quando simplesmente não há semelhantes.
   */
  let { schools = [], motivo = null, onSelect = (schoolId) => {} } = $props();

  const fmt = (v) =>
    v === null || v === undefined
      ? '—'
      : Number(v).toLocaleString('pt-BR', { minimumFractionDigits: 1, maximumFractionDigits: 1 });

  const pontos = (v) => `${fmt(v)} ${Number(v) < 2 ? 'ponto' : 'pontos'}`;
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
        {#if school.distancia !== null && school.distancia !== undefined}
          <span>a {pontos(school.distancia)}</span>
        {/if}
      </div>

      {#if school.notas?.length}
        <dl class="grid grid-cols-[1fr_auto_auto] gap-x-2 text-xs text-gray-600 font-sans">
          <dt class="text-gray-400"></dt>
          <dd class="text-gray-400 text-right">ela</dd>
          <dd class="text-gray-400 text-right">esta</dd>
          {#each school.notas as nota (nota.id)}
            <dt>{nota.rotulo}</dt>
            <dd class="text-right font-mono">{fmt(nota.valor)}</dd>
            <dd class="text-right font-mono text-gray-400">{fmt(nota.escola)}</dd>
          {/each}
        </dl>
      {/if}
    </button>
  {/each}

  {#if schools.length > 0}
    <p class="col-span-full text-xs text-gray-500 font-sans">
      Escolas da mesma cidade, com ao menos uma etapa de ensino em comum e as
      notas do painel (atendimento, infraestrutura, docência, diversidade,
      gestão e sustentabilidade, de 0 a 10) mais próximas das desta escola.
      A distância soma as diferenças nota a nota (distância euclidiana, em
      pontos): uma escola com o mesmo perfil de notas, mas num patamar mais
      alto ou mais baixo, não conta como parecida. Ordem: da mais próxima para
      a mais distante.
    </p>
  {/if}

  {#if schools.length === 0 && motivo === 'sem_dado'}
    <p class="col-span-full text-gray-500 font-sans">
      Sem dado para comparar: falta alguma das notas desta escola no Censo
      Escolar. Sem a nota, a escola fica fora da comparação, em vez de ser
      comparada como se tivesse nota zero.
    </p>
  {:else if schools.length === 0}
    <p class="col-span-full text-gray-500 font-sans">
      Nenhuma escola semelhante encontrada para os critérios atuais.
    </p>
  {/if}
</section>
