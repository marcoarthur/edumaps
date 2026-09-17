<script>
  // src/features/schools/components/panel/SchoolPanel.svelte
  import SchoolSummary from './SchoolSummary.svelte';
  import SchoolStages from './TeachingStages.svelte';
  import SchoolInfrastructure from './InfrastructureGrid.svelte';
  import SchoolIndicators from './SchoolIndicator.svelte';
  import SimilarSchools from './SimilarSchools.svelte';
  import SchoolPerformance from './SchoolPerformance.svelte';
  import SchoolMap from './SchoolMap.svelte';

  /**
   * @typedef {Object} Props
   * @property {Object} school - {
   *   id_escola, nome, municipio, uf,
   *   rede: 'municipal'|'estadual'|'privada',
   *   matriculas: number,
   *   etapas: { creche, pre_escola, fundamental_i, fundamental_ii,
   *             ensino_medio, eja, profissionalizante },
   *   infraestrutura: { agua_potavel, energia, esgoto, coleta_lixo,
   *             internet, biblioteca, laboratorio_ciencias,
   *             laboratorio_informatica, quadra_esportes,
   *             acessibilidade, alimentacao },
   * }
   * Campos internos de `school` mantidos em português: contrato da API.
   * @property {Array} [indicators] - saída de rank() para os indicadores exibidos
   * @property {Array} [similarSchools] - saída do endpoint de escolas semelhantes
   * @property {Array} [desempenho] - série histórica de IDEB { ano, etapa, ideb_observado }
   * @property {boolean} [loadingSimilarSchools]
   * @property {(schoolId: number) => void} [onSelectSimilarSchool]
   */

  /** @type {Props} */
  let {
    school,
    indicators = [],
    similarSchools = [],
    desempenho = [],
    loadingSimilarSchools = false,
    onSelectSimilarSchool = () => {},
  } = $props();
</script>

<div class="bg-white text-gray-900 p-6 rounded-lg flex flex-col gap-7 font-sans">
  <header class="flex flex-wrap justify-between items-end gap-4 border-b border-gray-200 pb-4">
    <div>
      <h1 class="text-2xl font-bold m-0">{school.nome}</h1>
      <p class="text-sm text-gray-600 font-mono mt-1">
        {school.municipio} · {school.uf} · INEP {school.id_escola}
      </p>
    </div>
    <div class="flex items-center gap-3">
      <SchoolSummary network={school.rede} enrollments={school.matriculas} />
      <a
        href={`/escola/financeiro?inep=${school.id_escola}`}
        class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors whitespace-nowrap"
      >
        Painel financeiro →
      </a>
    </div>
  </header>

  <section class="flex flex-col gap-2">
    <h2 class="text-base font-bold text-gray-900 mb-2">Etapas de ensino</h2>
    <SchoolStages stages={school.etapas} />
  </section>

  <section class="flex flex-col gap-2">
    <h2 class="text-base font-bold text-gray-900 mb-2">Infraestrutura</h2>
    <SchoolInfrastructure infrastructure={school.infraestrutura} />
  </section>

  {#if indicators.length > 0}
    <section class="flex flex-col gap-2">
      <h2 class="text-base font-bold text-gray-900 mb-2">Indicadores</h2>
      <SchoolIndicators {indicators} primaryScope="municipio" />
    </section>
  {/if}

  {#if school.latitude && school.longitude}
    <section class="flex flex-col gap-2">
      <h2 class="text-base font-bold text-gray-900 mb-2">Localização</h2>
      <SchoolMap
        latitude={school.latitude}
        longitude={school.longitude}
        schoolName={school.nome}
        height="300px"
        similarSchools={similarSchools}
      />
    </section>
  {/if}

  <section class="flex flex-col gap-2">
    <h2 class="text-base font-bold text-gray-900 mb-2">Escolas semelhantes</h2>
    {#if loadingSimilarSchools}
      <p class="text-sm text-gray-500">Buscando escolas semelhantes…</p>
    {:else}
      <SimilarSchools schools={similarSchools} onSelect={onSelectSimilarSchool} />
    {/if}
  </section>

  {#if desempenho.length > 0}
    <section class="flex flex-col gap-2">
      <h2 class="text-base font-bold text-gray-900 mb-2">Desempenho</h2>
      <SchoolPerformance {desempenho} />
    </section>
  {/if}
</div>
