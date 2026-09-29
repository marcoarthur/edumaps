<script>
  // src/features/schools/components/profile/ProfileComparison.svelte
  //
  // Posição relativa da escola: cada indicador comparado com o município,
  // a rede, o Brasil e o cluster (mediana). Linhas no quartil inferior do
  // cluster ficam destacadas.
  import { formatIndicator, formatQuartil } from '../../utils/transformProfileData.js';

  let { indicadores = [] } = $props();

  const COLS = ['Escola', 'Município', 'Rede', 'Brasil', 'Cluster'];
  const KEYS = ['escola', 'municipio', 'rede', 'brasil', 'cluster'];
</script>

<section class="flex flex-col gap-2" aria-label="Posição relativa">
  <h2 class="text-base font-bold text-gray-900">Posição relativa</h2>

  <div class="overflow-x-auto border border-gray-200 rounded-md">
    <table class="min-w-full text-sm">
      <thead class="bg-gray-50 text-gray-600">
        <tr>
          <th class="text-left font-semibold px-3 py-2 whitespace-nowrap">Indicador</th>
          {#each COLS as col}
            <th class="text-right font-semibold px-3 py-2 whitespace-nowrap">{col}</th>
          {/each}
          <th class="text-right font-semibold px-3 py-2 whitespace-nowrap">Quartil</th>
        </tr>
      </thead>
      <tbody>
        {#each indicadores as ind (ind.indicador)}
          <tr class={ind.atencao ? 'bg-amber-50' : 'bg-white'}>
            <td class="text-left px-3 py-2 text-gray-800 whitespace-nowrap">
              {ind.label ?? ind.indicador}
            </td>
            {#each KEYS as key}
              <td
                class="text-right px-3 py-2 font-mono text-gray-700 whitespace-nowrap"
              >
                {formatIndicator(ind.indicador, ind[key])}
              </td>
            {/each}
            <td class="text-right px-3 py-2 whitespace-nowrap">
              <span
                class={ind.atencao
                  ? 'text-amber-700 font-semibold'
                  : 'text-gray-500'}
              >
                {formatQuartil(ind.quartil_no_cluster)}
                {ind.atencao ? '⚠' : ''}
              </span>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <p class="text-xs text-gray-500">
    Cluster = mediana do indicador no cluster da escola. Quartil inferior
    do cluster (Q1) gera sinal de atenção.
  </p>
</section>
