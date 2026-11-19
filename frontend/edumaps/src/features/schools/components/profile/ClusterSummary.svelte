<script>
  // src/features/schools/components/profile/ClusterSummary.svelte
  //
  // Distribuição do indicador dentro do grupo de referência da escola
  // (média, p25, p50, p75 e quantas escolas do grupo têm o dado). Dá
  // contexto ao "quartil inferior". #493: o grupo é formado pelo contexto
  // (rede, localização, porte, etapas, INSE), nunca pelo IDEB.
  import { formatIndicator } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let { resumo = [], criterio = null } = $props();
</script>

<section class="flex flex-col gap-2" aria-label="Distribuição no grupo de referência">
  <div class="flex items-center gap-2">
    <h2 class="text-base font-bold text-gray-900">Distribuição no grupo de referência</h2>
    <InfoHint
      title="Como o grupo é formado"
      text={criterio ?? "As escolas do mesmo município de contexto mais parecido (rede, localização, porte, etapas oferecidas e INSE). O IDEB e a nota não entram: são o que se compara."}
      items={[
        'p25/p50/p75 = percentis do indicador entre as escolas do grupo que têm o dado; N = quantas são.',
        'A mediana (p50) é a referência do grupo usada nas comparações.',
      ]}
    />
  </div>
  {#if criterio}
    <p class="text-xs text-gray-600" data-testid="grupo-criterio">{criterio}</p>
  {/if}

  <div class="overflow-x-auto border border-gray-200 rounded-md">
    <table class="min-w-full text-sm">
      <thead class="bg-gray-50 text-gray-600">
        <tr>
          <th class="text-left font-semibold px-3 py-2 whitespace-nowrap">Indicador</th>
          <th class="text-right font-semibold px-3 py-2">Média</th>
          <th class="text-right font-semibold px-3 py-2">p25</th>
          <th class="text-right font-semibold px-3 py-2">p50</th>
          <th class="text-right font-semibold px-3 py-2">p75</th>
          <th class="text-right font-semibold px-3 py-2">N</th>
        </tr>
      </thead>
      <tbody>
        {#each resumo as row (row.indicador)}
          <tr class="bg-white">
            <td class="text-left px-3 py-2 text-gray-800 whitespace-nowrap">
              {row.label ?? row.indicador}
            </td>
            <td class="text-right px-3 py-2 font-mono text-gray-700">{formatIndicator(row.indicador, row.media)}</td>
            <td class="text-right px-3 py-2 font-mono text-gray-700">{formatIndicator(row.indicador, row.p25)}</td>
            <td class="text-right px-3 py-2 font-mono text-gray-700">{formatIndicator(row.indicador, row.p50)}</td>
            <td class="text-right px-3 py-2 font-mono text-gray-700">{formatIndicator(row.indicador, row.p75)}</td>
            <td class="text-right px-3 py-2 text-gray-500">{row.n ?? '–'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <p class="text-xs text-gray-500">
    p25/p50/p75 = percentis do indicador entre as escolas do grupo; N = escolas do grupo com o dado.
  </p>
</section>
