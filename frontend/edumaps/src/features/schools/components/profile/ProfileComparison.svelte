<script>
  // src/features/schools/components/profile/ProfileComparison.svelte
  //
  // Posição relativa da escola: cada indicador comparado com o município,
  // a rede, o Brasil e o grupo de referência (mediana). Linhas com sinal de atenção
  // (pior que o grupo no sentido do indicador, #421) ficam destacadas.
  import { formatIndicator, formatQuartil } from '../../utils/transformProfileData.js';
  import { sentidoIndicador } from '@/shared/utils/sentidoIndicador.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let { indicadores = [] } = $props();

  const COLS = ['Escola', 'Município', 'Rede', 'Brasil', 'Grupo'];
  const KEYS = ['escola', 'municipio', 'rede', 'brasil', 'cluster'];
</script>

<section class="flex flex-col gap-2" aria-label="Posição relativa">
  <div class="flex items-center gap-2">
    <h2 class="text-base font-bold text-gray-900">Posição relativa</h2>
    <InfoHint
      title="Como calculamos a posição relativa"
      text="Cada indicador da escola ao lado da média do município, da rede (dependência) e do Brasil, e da mediana do grupo de referência (escolas do município de contexto parecido)."
      items={[
        'Fonte: Censo Escolar (docentes e matrículas), IDEB/SAEB e INSE — edição mais recente.',
        'Os comparativos vêm de referências pré-computadas quando disponíveis; senão são calculados na hora.',
        'Quartil = posição do valor da escola dentro do grupo (Q1 = menores valores … Q4 = maiores).',
        'Sinal de atenção: a escola está pior que a mediana do grupo no quartil do lado ruim (Q1 quando maior é melhor; Q4 quando menor é melhor). O INSE é contexto e não gera sinal.',
        'Grupo = mediana do indicador entre as escolas do grupo de referência.',
        'IDEB e nota SAEB: a etapa de maior nota da escola na edição mais recente (indicada no nome da linha), e município, rede, Brasil e grupo na mesma etapa, só com as escolas que têm nota nela. As outras etapas da escola estão em "IDEB em cada etapa".',
      ]}
    />
  </div>

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
              {#if sentidoIndicador(ind.indicador, ind.direcao) === 'menor'}
                <span class="block text-xs text-gray-500">menor é melhor</span>
              {/if}
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
    Grupo = mediana do indicador no grupo de referência da escola. Sinal de atenção
    (⚠) quando a escola está pior que o grupo: no Q1 se maior é melhor, no
    Q4 se menor é melhor.
  </p>
</section>
