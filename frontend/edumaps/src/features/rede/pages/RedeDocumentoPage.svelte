<!-- src/features/rede/pages/RedeDocumentoPage.svelte -->
<script>
  // Documento consolidado da rede para imprimir (#405, P2-RD-02): o que o
  // conselho municipal pede numa folha só. Monta-se dos MESMOS endpoints do
  // painel, das metas comparáveis e dos custos, então os números são os mesmos
  // por construção. Emissão com a data (Brasília) e o cargo da conta de rede,
  // sem o nome. Ausência em texto ("Sem metas medidas", "—"), nunca 0% nem R$ 0.
  import { onMount } from "svelte";
  import { getRedeMe, getRedePainel, getRedeIndicadores, getRedeCustos } from "../api/redeApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import { pct, fmtData } from "@/features/gestor/constants/planos.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import RedeCustos from "../components/RedeCustos.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);
  let conta = $state(null);
  let painel = $state(null);
  let indicadores = $state(null);
  let custos = $state(null);
  let emitidoEm = $state("");

  const TH = "text-left font-semibold border-b border-gray-300 px-2 py-1";
  const TD = "border-b border-gray-100 px-2 py-1 align-top";
  const andamento = (p) => p?.progresso?.valor;
  const temAndamento = (p) => andamento(p) !== null && andamento(p) !== undefined;

  let escolas = $derived(painel ? [...painel.escolas].sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR")) : []);

  // data e hora de Brasília, como o relatório da escola
  function agoraBrasilia() {
    const f = new Intl.DateTimeFormat("pt-BR", {
      timeZone: "America/Sao_Paulo", day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit",
    });
    return f.format(new Date()).replace(", ", " às ");
  }

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    semPermissao = false;
    try {
      conta = await getRedeMe();
      [painel, indicadores, custos] = await Promise.all([getRedePainel(), getRedeIndicadores(), getRedeCustos()]);
      emitidoEm = agoraBrasilia();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else if (err instanceof ApiError && err.status === 403) semPermissao = true;
      else error = "Não foi possível montar o documento da rede.";
    } finally {
      carregando = false;
    }
  }

  async function trocarExercicio(ano) {
    try {
      custos = await getRedeCustos(ano);
      emitidoEm = agoraBrasilia();
    } catch {
      error = "Não foi possível filtrar os custos pelo exercício.";
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-4 max-w-5xl mx-auto">
  <div class="flex flex-wrap items-center justify-between gap-2 print:hidden">
    <a href="/rede" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">← Rede</a>
    {#if painel}
      <button type="button" onclick={() => window.print()} class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">Imprimir / salvar PDF</button>
    {/if}
  </div>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Montando o documento…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre com a conta da rede." />
  {:else if semPermissao}
    <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4">
      Esta página é das contas de rede (secretarias).
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if conta && painel}
    <article class="bg-white border border-gray-200 rounded-card shadow-card p-6 space-y-6 text-sm text-gray-900 print:border-0 print:shadow-none print:p-0" aria-label="Documento da rede">
      <header class="space-y-1 border-b border-gray-300 pb-3">
        <h1 class="text-xl font-bold">Acompanhamento dos planos de gestão da rede</h1>
        <ul class="text-sm text-gray-700">
          {#each conta.vinculos as v (v.id)}
            <li>Rede {v.dependencia.toLowerCase()} · {v.municipio}/{v.uf}</li>
          {/each}
        </ul>
        <p class="text-xs text-gray-600">Emitido em {emitidoEm}{#if conta.cargo}{" · por: "}{conta.cargo}{/if}</p>
      </header>

      <section aria-labelledby="doc-resumo" class="space-y-2 print:break-inside-avoid">
        <h2 id="doc-resumo" class="text-base font-semibold">Resumo</h2>
        <dl class="grid grid-cols-2 sm:grid-cols-4 gap-2">
          {#each [
            ["Escolas em atividade", painel.totais.escolas],
            ["Com plano vigente", painel.totais.com_plano_vigente],
            ["Sem plano vigente", painel.totais.sem_plano_vigente],
            ["Ações atrasadas", painel.totais.acoes_atrasadas],
          ] as [rotulo, valor] (rotulo)}
            <div class="border border-gray-200 rounded p-2">
              <dt class="text-xs text-gray-500">{rotulo}</dt>
              <dd class="text-lg font-bold">{valor}</dd>
            </div>
          {/each}
        </dl>
      </section>

      <section aria-labelledby="doc-escolas" class="space-y-2">
        <h2 id="doc-escolas" class="text-base font-semibold">Escolas e planos</h2>
        <table class="w-full border-collapse text-xs" aria-label="Escolas e planos">
          <thead>
            <tr>
              <th class={TH} scope="col">Escola</th>
              <th class={TH} scope="col">Plano vigente</th>
              <th class={TH} scope="col">Andamento</th>
              <th class={`${TH} text-right`} scope="col">Atrasadas</th>
              <th class={`${TH} text-right`} scope="col">Vencem em 7 dias</th>
              <th class={`${TH} text-right`} scope="col">Evidências</th>
              <th class={TH} scope="col">Atualizado</th>
            </tr>
          </thead>
          <tbody>
            {#each escolas as e (e.cod_inep)}
              <tr class="print:break-inside-avoid">
                <td class={TD}>{e.nome}<span class="block text-gray-500">INEP {e.cod_inep}</span></td>
                {#if e.plano}
                  <td class={TD}>{e.plano.titulo}</td>
                  <td class={TD}>
                    {temAndamento(e.plano) ? pct(andamento(e.plano)) : "Sem metas medidas"}
                    <span class="block text-gray-500">{e.plano.progresso.n_medidas} de {e.plano.progresso.n_metas} meta(s) medida(s)</span>
                  </td>
                  <td class={`${TD} text-right`}>{e.plano.n_atrasadas}</td>
                  <td class={`${TD} text-right`}>{e.plano.n_vencem_7d}</td>
                  <td class={`${TD} text-right`}>{e.plano.n_evidencias}</td>
                  <td class={TD}>{fmtData(e.plano.atualizado_em)}</td>
                {:else}
                  <td class={TD} colspan="6">Sem plano vigente{#if e.n_planos}{` (${e.n_planos} plano(s) em rascunho ou encerrado)`}{/if}</td>
                {/if}
              </tr>
            {/each}
          </tbody>
        </table>
      </section>

      {#if custos}
        <div class="print:break-inside-avoid">
          <RedeCustos {custos} onExercicio={trocarExercicio} sempreAberto />
        </div>
      {/if}

      {#if indicadores}
        <section aria-labelledby="doc-metas" class="space-y-2 print:break-inside-avoid">
          <h2 id="doc-metas" class="text-base font-semibold">Metas comparáveis por indicador oficial</h2>
          {#if indicadores.indicadores.length}
            <table class="w-full border-collapse text-xs" aria-label="Metas comparáveis">
              <thead>
                <tr>
                  <th class={TH} scope="col">Indicador</th>
                  <th class={`${TH} text-right`} scope="col">Escolas com meta</th>
                  <th class={`${TH} text-right`} scope="col">Metas medidas</th>
                  <th class={TH} scope="col">Andamento médio</th>
                  <th class={`${TH} text-right`} scope="col">Base ajustada</th>
                </tr>
              </thead>
              <tbody>
                {#each indicadores.indicadores as ind (ind.codigo)}
                  <tr>
                    <td class={TD}>{ind.rotulo}<span class="block text-gray-500">{ind.fonte}</span></td>
                    <td class={`${TD} text-right`}>{ind.n_escolas}</td>
                    <td class={`${TD} text-right`}>{ind.n_medidas} de {ind.n_metas}</td>
                    <td class={TD}>{ind.andamento_medio !== null && ind.andamento_medio !== undefined ? pct(ind.andamento_medio) : "Sem metas medidas"}</td>
                    <td class={`${TD} text-right`}>{ind.n_base_ajustada}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          {:else}
            <p class="text-gray-500">Nenhuma escola da rede tem meta ligada a indicador oficial no plano vigente.</p>
          {/if}
          {#if indicadores.manuais.n_metas}
            <p class="text-xs text-gray-500">
              {indicadores.manuais.n_metas} meta(s) manual(is) em {indicadores.manuais.n_escolas} escola(s) não entram na
              comparação (o valor é informado pela escola, sem um indicador comum).
            </p>
          {/if}
        </section>
      {/if}

      <footer class="border-t border-gray-300 pt-2 text-[11px] text-gray-500 space-y-1">
        <p>
          Escolas em atividade pelo Censo Escolar mais recente. Só os planos vigentes entram no andamento, nas metas
          comparáveis e no total dos custos. O andamento é a média das metas já medidas, sempre com "N de M"; meta sem
          medição não conta como 0%.
        </p>
        <p>
          Custos: ações canceladas ficam fora; ação sem valor não conta como R$ 0. Os valores oficiais novos entram
          todo dia de manhã, nos planos vigentes. Fonte: EduMaps, com os dados cadastrados pelas escolas.
        </p>
      </footer>
    </article>
  {/if}
</div>
