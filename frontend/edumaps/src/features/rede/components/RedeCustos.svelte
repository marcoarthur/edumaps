<!-- src/features/rede/components/RedeCustos.svelte -->
<script>
  // Custo por fonte de recurso na rede (#398, RF-109): previsto × executado,
  // consolidado e por escola. Por escola, os mesmos números do relatório do
  // plano vigente. Sem valor não é R$ 0: a fonte sem valor mostra "—" e as
  // ações sem valor são contadas à parte. Os planos encerrados ficam numa
  // linha separada, fora do consolidado.
  import { fmtMoeda, FONTE_RECURSO_LABEL } from "@/features/gestor/constants/planos.js";

  let { custos } = $props();
  let porEscola = $state(false);

  const TH = "px-3 py-2 text-left";
  const fonteRotulo = (f) => (f === "nao_informada" ? "Fonte não informada" : (FONTE_RECURSO_LABEL[f] ?? f));
  const nAcoes = (c) => c.por_fonte.reduce((s, f) => s + f.n_acoes, 0);
  const temValor = (c) => c.por_fonte.length > 0;
  const fontes = (c) => c.por_fonte.map((f) => fonteRotulo(f.fonte)).join(", ");
</script>

<section class="space-y-3" aria-labelledby="rede-custos">
  <div>
    <h2 id="rede-custos" class="text-lg font-semibold text-gray-900">Custo por fonte de recurso</h2>
    <p class="text-sm text-gray-600">Previsto × executado nos planos vigentes das escolas da rede. Ações canceladas ficam fora.</p>
  </div>

  {#if temValor(custos.consolidado)}
    <div class="overflow-x-auto rounded-card border border-gray-200 bg-white">
      <table class="w-full text-sm" aria-label="Custo consolidado da rede">
        <thead class="bg-gray-50 text-xs text-gray-600">
          <tr>
            <th class={TH} scope="col">Fonte</th>
            <th class={`${TH} text-right`} scope="col">Ações com custo</th>
            <th class={`${TH} text-right`} scope="col">Previsto</th>
            <th class={`${TH} text-right`} scope="col">Executado</th>
          </tr>
        </thead>
        <tbody>
          {#each custos.consolidado.por_fonte as f (f.fonte)}
            <tr class="border-t border-gray-100">
              <td class="px-3 py-2">{fonteRotulo(f.fonte)}</td>
              <td class="px-3 py-2 text-right">{f.n_acoes}</td>
              <td class="px-3 py-2 text-right">{fmtMoeda(f.total)}</td>
              <td class="px-3 py-2 text-right">{fmtMoeda(f.executado)}</td>
            </tr>
          {/each}
          <tr class="border-t border-gray-300 font-semibold">
            <td class="px-3 py-2">Total da rede</td>
            <td class="px-3 py-2 text-right">{nAcoes(custos.consolidado)}</td>
            <td class="px-3 py-2 text-right">{fmtMoeda(custos.consolidado.total)}</td>
            <td class="px-3 py-2 text-right">{fmtMoeda(custos.consolidado.total_executado)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  {:else}
    <p class="text-sm text-gray-500">Nenhuma ação dos planos vigentes tem custo informado.</p>
  {/if}

  <p class="text-xs text-gray-600">
    {custos.consolidado.n_escolas_com_custo} de {custos.escolas.length} escola(s) com plano vigente informaram custo.
    {#if custos.consolidado.n_acoes_sem_custo}{" "}{custos.consolidado.n_acoes_sem_custo} ação(ões) sem custo previsto.{/if}
    {#if custos.consolidado.n_acoes_sem_executado}{" "}{custos.consolidado.n_acoes_sem_executado} ação(ões) sem valor executado.{/if}
  </p>

  {#if custos.encerrados.n_planos}
    <p class="text-sm text-gray-700" aria-label="Planos encerrados">
      Planos encerrados ({custos.encerrados.n_planos} em {custos.encerrados.n_escolas} escola(s)), fora do total:
      previsto <strong>{temValor(custos.encerrados) ? fmtMoeda(custos.encerrados.total) : "—"}</strong>,
      executado <strong>{fmtMoeda(custos.encerrados.total_executado)}</strong>.
    </p>
  {/if}

  {#if custos.escolas.length}
    <button type="button" onclick={() => (porEscola = !porEscola)} aria-expanded={porEscola}
      class="px-3 py-1 rounded-md bg-gray-100 text-gray-800 text-xs hover:bg-gray-200">
      {porEscola ? "Ocultar por escola" : "Ver por escola"}
    </button>
  {/if}

  {#if porEscola}
    <div class="overflow-x-auto rounded-card border border-gray-200 bg-white">
      <table class="w-full text-sm" aria-label="Custo por escola">
        <thead class="bg-gray-50 text-xs text-gray-600">
          <tr>
            <th class={TH} scope="col">Escola</th>
            <th class={`${TH} text-right`} scope="col">Previsto</th>
            <th class={`${TH} text-right`} scope="col">Executado</th>
            <th class={`${TH} text-right`} scope="col">Sem custo previsto</th>
            <th class="px-3 py-2" scope="col"><span class="sr-only">Relatório</span></th>
          </tr>
        </thead>
        <tbody>
          {#each custos.escolas as e (e.cod_inep)}
            <tr class="border-t border-gray-100 align-top">
              <td class="px-3 py-2">
                <p class="font-medium text-gray-900">{e.nome}</p>
                <p class="text-xs text-gray-500">{temValor(e.custos) ? fontes(e.custos) : "Nenhuma ação com custo informado"}</p>
              </td>
              <td class="px-3 py-2 text-right">{temValor(e.custos) ? fmtMoeda(e.custos.total) : "—"}</td>
              <td class="px-3 py-2 text-right">{fmtMoeda(e.custos.total_executado)}</td>
              <td class="px-3 py-2 text-right">{e.custos.n_acoes_sem_custo}</td>
              <td class="px-3 py-2"><a href={`/rede/escolas/${e.cod_inep}/planos/${e.plano_id}/relatorio`} class="text-blue-700 hover:underline text-xs" aria-label={`Custos no relatório de ${e.nome}`}>Relatório</a></td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</section>
