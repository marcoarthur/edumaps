<script>
  // src/features/schools/components/profile/IdebPorEtapa.svelte
  //
  // IDEB da escola em cada etapa em que ela tem nota (#483, RN-02), ao lado
  // do município, da rede e do Brasil NA MESMA ETAPA. A escala do SAEB cresce
  // com a série e o IDEB cai: comparar etapas diferentes engana.
  import { formatIndicator } from '../../utils/transformProfileData.js';
  import InfoHint from '@/shared/ui/components/InfoHint.svelte';

  let { etapas = [] } = $props();
  const fmt = (v) => formatIndicator('ideb_observado', v);
  const maiuscula = (t) => (t ? t.charAt(0).toUpperCase() + t.slice(1) : '');
</script>

{#if etapas.length > 0}
  <section class="flex flex-col gap-2" aria-label="IDEB em cada etapa">
    <div class="flex items-center gap-2">
      <h2 class="text-base font-bold text-gray-900">IDEB em cada etapa</h2>
      <InfoHint
        title="Por que por etapa"
        text="O IDEB de uma etapa só se compara com o da mesma etapa: no Brasil, em 2023, a média foi 5,7 nos anos iniciais, 4,7 nos anos finais e 4,3 no ensino médio."
        items={[
          'Município, rede e Brasil: média simples das escolas com nota naquela etapa, na mesma edição.',
          'Rede = a mesma dependência (federal, estadual, municipal ou privada) no Brasil todo.',
          'Na Posição relativa, o IDEB e a nota SAEB usam a etapa destacada aqui.',
        ]}
      />
    </div>
    <div class="overflow-x-auto border border-gray-200 rounded-md">
      <table class="min-w-full text-sm">
        <thead class="bg-gray-50 text-gray-600">
          <tr>
            <th class="text-left font-semibold px-3 py-2">Etapa</th>
            <th class="text-right font-semibold px-3 py-2">Escola</th>
            <th class="text-right font-semibold px-3 py-2">Município</th>
            <th class="text-right font-semibold px-3 py-2">Rede</th>
            <th class="text-right font-semibold px-3 py-2">Brasil</th>
          </tr>
        </thead>
        <tbody>
          {#each etapas as e (e.etapa)}
            <tr class={e.principal ? 'bg-brand-50' : 'bg-white'}>
              <td class="text-left px-3 py-2 text-gray-800">
                {maiuscula(e.etapaTexto)} {e.ano ?? ''}
                {#if e.principal}<span class="block text-xs text-gray-500">usada na posição relativa</span>{/if}
              </td>
              <td class="text-right px-3 py-2 font-mono font-semibold text-gray-900">{fmt(e.escola)}</td>
              <td class="text-right px-3 py-2 font-mono text-gray-700" title={e.nMunicipio != null ? `${e.nMunicipio} escolas` : ''}>{fmt(e.municipio)}</td>
              <td class="text-right px-3 py-2 font-mono text-gray-700" title={e.nRede != null ? `${e.nRede} escolas` : ''}>{fmt(e.rede)}</td>
              <td class="text-right px-3 py-2 font-mono text-gray-500" title={e.nBrasil != null ? `${e.nBrasil} escolas` : ''}>{fmt(e.brasil)}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </section>
{/if}
