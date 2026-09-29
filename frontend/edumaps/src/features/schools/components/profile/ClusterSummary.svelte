<script>
  // src/features/schools/components/profile/ClusterSummary.svelte
  //
  // Distribuição do indicador dentro do cluster da escola (média, p25,
  // p50, p75 e tamanho). Dá contexto ao "quartil inferior".
  import { formatIndicator } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let { resumo = [] } = $props();
</script>

<section class="flex flex-col gap-2" aria-label="Resumo do cluster">
  <div class="flex items-center gap-2">
    <h2 class="text-base font-bold text-gray-900">Distribuição no cluster</h2>
    <InfoHint
      title="Como o cluster é formado"
      text="Agrupamos escolas de contexto parecido por similaridade (Gower/k-means) para comparar a escola com pares justos."
      items={[
        'Se a escola ainda não tem cluster persistido, estimamos o grupo no próprio município.',
        'p25/p50/p75 = percentis do indicador entre as escolas do cluster; N = nº de escolas.',
        'A mediana (p50) é a referência do cluster usada nas comparações.',
      ]}
    />
  </div>

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
    p25/p50/p75 = percentis do indicador entre as escolas do cluster; N = nº de escolas do cluster.
  </p>
</section>
