<!-- src/features/rede/pages/RedePage.svelte -->
<script>
  // Painel da rede (#394, #396): as redes da conta e, por escola, o plano de
  // gestão vigente com o andamento ("N de M metas medidas"; sem medida é texto,
  // nunca 0%), as ações atrasadas, as que vencem em 7 dias e as evidências.
  // Filtro e ordenação para achar quem precisa de apoio. Do painel, abre-se o
  // relatório de cada escola, só leitura. Embaixo, o custo por fonte de
  // recurso, consolidado e por escola (#398). Exige sessão com papel `rede`.
  import { onMount } from "svelte";
  import { getRedeMe, getRedePainel, getRedeCustos } from "../api/redeApi.js";
  import { logoutGestor } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import { pct, fmtData } from "@/features/gestor/constants/planos.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import RedeCustos from "../components/RedeCustos.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);
  let conta = $state(null);
  let painel = $state(null);
  let custos = $state(null);
  let erroCustos = $state(false);
  let filtro = $state("todas");
  let ordem = $state("nome");

  const FILTROS = [
    { valor: "todas", rotulo: "Todas as escolas" },
    { valor: "sem_plano", rotulo: "Sem plano vigente" },
    { valor: "atrasadas", rotulo: "Com ações atrasadas" },
    { valor: "sem_andamento", rotulo: "Plano sem metas medidas" },
  ];
  const ORDENS = [
    { valor: "nome", rotulo: "Nome da escola" },
    { valor: "atrasadas", rotulo: "Mais ações atrasadas" },
    { valor: "andamento", rotulo: "Menor andamento" },
  ];

  const andamento = (p) => p?.progresso?.valor;
  const semAndamento = (e) => e.plano && (andamento(e.plano) === null || andamento(e.plano) === undefined);

  let linhas = $derived.by(() => {
    if (!painel) return [];
    let l = painel.escolas.filter((e) =>
      filtro === "sem_plano" ? !e.plano
      : filtro === "atrasadas" ? (e.plano?.n_atrasadas ?? 0) > 0
      : filtro === "sem_andamento" ? semAndamento(e)
      : true);
    const porNome = (a, b) => a.nome.localeCompare(b.nome, "pt-BR");
    if (ordem === "atrasadas") {
      l = [...l].sort((a, b) => (b.plano?.n_atrasadas ?? -1) - (a.plano?.n_atrasadas ?? -1) || porNome(a, b));
    } else if (ordem === "andamento") {
      // sem plano e sem medida vêm primeiro (é quem mais precisa de olhar), depois o menor andamento
      const chave = (e) => (!e.plano ? -2 : semAndamento(e) ? -1 : andamento(e.plano));
      l = [...l].sort((a, b) => chave(a) - chave(b) || porNome(a, b));
    } else {
      l = [...l].sort(porNome);
    }
    return l;
  });

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    semPermissao = false;
    try {
      conta = await getRedeMe();
      painel = await getRedePainel();
      // os custos não seguram o painel: se falharem, só a seção avisa
      erroCustos = false;
      custos = await getRedeCustos().catch(() => {
        erroCustos = true;
        return null;
      });
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else if (err instanceof ApiError && err.status === 403) semPermissao = true;
      else error = "Não foi possível carregar a rede.";
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  async function sair() {
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      conta = null;
      precisaLogin = true;
    }
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6 max-w-5xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Rede</h1>
      <p class="text-sm text-gray-600 mt-1">Os planos de gestão das escolas da sua rede, para acompanhar e apoiar.</p>
    </div>
    {#if conta}
      <div class="flex items-center gap-2">
      {#if conta.vinculos.length}
        <a href="/rede/indicadores" class="px-3 py-1.5 rounded-md bg-indigo-50 text-indigo-800 text-xs font-medium hover:bg-indigo-100">Metas comparáveis por indicador</a>
      {/if}
      <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Sair</button>
      </div>
    {/if}
  </header>

  {#if carregando}
    <p class="text-gray-500">Carregando…</p>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre com a conta da rede." />
  {:else if semPermissao}
    <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4">
      Esta página é das contas de rede (secretarias). A sua conta é de escola: use o menu <strong>Gestor</strong>.
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if conta}
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-2" aria-label="Sua conta">
      <p class="text-base font-semibold text-gray-900">{conta.nome}</p>
      <p class="text-xs text-gray-500">{conta.cargo ?? "Conta de rede"} · {conta.email}</p>
      {#if conta.vinculos.length}
        <ul class="flex flex-wrap gap-2 pt-1">
          {#each conta.vinculos as v (v.id)}
            <li class="px-2 py-0.5 rounded-full bg-blue-50 text-blue-800 text-xs">Rede {v.dependencia.toLowerCase()} · {v.municipio}/{v.uf}</li>
          {/each}
        </ul>
      {:else}
        <p class="text-sm text-amber-800">Nenhuma rede ligada a esta conta ainda. Fale com o administrador da plataforma.</p>
      {/if}
    </section>

    {#if conta.vinculos.length && painel}
      <section class="grid gap-3 grid-cols-2 sm:grid-cols-4" aria-label="Totais da rede">
        {#each [
          ["Escolas em atividade", painel.totais.escolas],
          ["Com plano vigente", painel.totais.com_plano_vigente],
          ["Sem plano vigente", painel.totais.sem_plano_vigente],
          ["Ações atrasadas", painel.totais.acoes_atrasadas],
        ] as [rotulo, valor] (rotulo)}
          <div class="rounded-card bg-white border border-gray-200 shadow-card p-3">
            <p class="text-xs text-gray-500">{rotulo}</p>
            <p class="text-2xl font-bold text-gray-900">{valor}</p>
          </div>
        {/each}
      </section>

      <section class="space-y-2" aria-label="Escolas da rede">
        <div class="flex flex-wrap items-end gap-3">
          <label class="text-xs text-gray-600"><span class="block">Mostrar</span>
            <select bind:value={filtro} class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              {#each FILTROS as f (f.valor)}<option value={f.valor}>{f.rotulo}</option>{/each}
            </select></label>
          <label class="text-xs text-gray-600"><span class="block">Ordenar por</span>
            <select bind:value={ordem} class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              {#each ORDENS as o (o.valor)}<option value={o.valor}>{o.rotulo}</option>{/each}
            </select></label>
          <p class="text-xs text-gray-500 ml-auto">{linhas.length} de {painel.escolas.length} escola(s)</p>
        </div>
        <div class="overflow-x-auto rounded-card border border-gray-200 bg-white">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 text-xs text-gray-600">
              <tr>
                <th class="text-left px-3 py-2" scope="col">Escola</th>
                <th class="text-left px-3 py-2" scope="col">Plano vigente</th>
                <th class="text-left px-3 py-2" scope="col">Andamento</th>
                <th class="text-right px-3 py-2" scope="col">Atrasadas</th>
                <th class="text-right px-3 py-2" scope="col">Vencem em 7 dias</th>
                <th class="text-right px-3 py-2" scope="col">Evidências</th>
                <th class="text-left px-3 py-2" scope="col">Atualizado</th>
                <th class="px-3 py-2" scope="col"><span class="sr-only">Relatório</span></th>
              </tr>
            </thead>
            <tbody>
              {#each linhas as e (e.cod_inep)}
                <tr class="border-t border-gray-100 align-top">
                  <td class="px-3 py-2">
                    <p class="font-medium text-gray-900">{e.nome}</p>
                    <p class="text-xs text-gray-500">INEP {e.cod_inep} · {e.municipio}/{e.uf}</p>
                  </td>
                  {#if e.plano}
                    <td class="px-3 py-2">
                      {e.plano.titulo}
                      {#if e.plano.n_vigentes > 1}<span class="block text-xs text-amber-800">{e.plano.n_vigentes} planos vigentes; mostra o mais recente</span>{/if}
                    </td>
                    <td class="px-3 py-2">
                      {#if andamento(e.plano) !== null && andamento(e.plano) !== undefined}
                        <span class="font-semibold">{pct(andamento(e.plano))}</span>
                      {:else}
                        <span class="text-amber-800">Sem metas medidas</span>
                      {/if}
                      <span class="block text-xs text-gray-500">{e.plano.progresso.n_medidas} de {e.plano.progresso.n_metas} meta(s) medida(s)</span>
                    </td>
                    <td class="px-3 py-2 text-right {e.plano.n_atrasadas ? 'text-red-700 font-semibold' : ''}">{e.plano.n_atrasadas}</td>
                    <td class="px-3 py-2 text-right">{e.plano.n_vencem_7d}</td>
                    <td class="px-3 py-2 text-right">{e.plano.n_evidencias}</td>
                    <td class="px-3 py-2 text-xs text-gray-600">{fmtData(e.plano.atualizado_em)}</td>
                    <td class="px-3 py-2"><a href={`/rede/escolas/${e.cod_inep}/planos/${e.plano.id}/relatorio`} class="text-blue-700 hover:underline text-xs" aria-label={`Relatório de ${e.nome}`}>Relatório</a></td>
                  {:else}
                    <td class="px-3 py-2 text-amber-800" colspan="7">
                      Sem plano vigente{#if e.n_planos}{` (${e.n_planos} plano(s) em rascunho ou encerrado)`}{/if}
                    </td>
                  {/if}
                </tr>
              {:else}
                <tr><td colspan="8" class="px-3 py-4 text-center text-gray-500">Nenhuma escola neste filtro.</td></tr>
              {/each}
            </tbody>
          </table>
        </div>
        <p class="text-xs text-gray-500">
          Escolas em atividade pelo Censo Escolar mais recente. O andamento é a média das metas já medidas; os
          valores oficiais novos entram quando a escola abre o plano.
        </p>
      </section>

      {#if custos}
        <RedeCustos {custos} />
      {:else if erroCustos}
        <p class="text-sm text-red-700">Não foi possível carregar os custos da rede.</p>
      {/if}
    {/if}
  {/if}
</div>
