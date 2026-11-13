<!-- src/features/rede/pages/RedeIndicadoresPage.svelte -->
<script>
  // Metas comparáveis por indicador (#397, P2-PG-03): nas escolas da rede, as
  // metas do plano vigente que seguem o mesmo indicador oficial, lado a lado.
  // Por indicador: quantas escolas têm a meta, quantas mediram, o andamento
  // médio das medidas (sem medida é texto, nunca 0%) e a lista das escolas,
  // com a base ajustada pela escola marcada. Metas manuais ficam à parte.
  import { onMount } from "svelte";
  import { getRedeIndicadores } from "../api/redeApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { setSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import { pct, fmtNum, META_ESTADO_LABEL } from "@/features/gestor/constants/planos.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);
  let dados = $state(null);
  let aberto = $state({});

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    semPermissao = false;
    try {
      dados = await getRedeIndicadores();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else if (err instanceof ApiError && err.status === 403) semPermissao = true;
      else error = "Não foi possível carregar as metas da rede.";
    } finally {
      carregando = false;
    }
  }

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregar();
  }

  const alternar = (codigo) => (aberto = { ...aberto, [codigo]: !aberto[codigo] });

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6 max-w-5xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Metas comparáveis da rede</h1>
      <p class="text-sm text-gray-600 mt-1">
        As metas que seguem o mesmo indicador oficial, escola por escola. Só os planos vigentes.
      </p>
    </div>
    <a href="/rede" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">← Rede</a>
  </header>

  {#if carregando}
    <p class="text-gray-500">Carregando…</p>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre com a conta da rede." />
  {:else if semPermissao}
    <div class="rounded-md bg-amber-50 border border-amber-200 text-amber-900 text-sm p-4">
      Esta página é das contas de rede (secretarias).
    </div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if dados}
    <p class="text-sm text-gray-700">
      {dados.n_com_plano_vigente} de {dados.n_escolas} escola(s) com plano vigente.
      {#if dados.manuais.n_metas}
        {" "}{dados.manuais.n_metas} meta(s) manual(is) em {dados.manuais.n_escolas} escola(s) não entram na comparação
        (o valor é informado pela escola, sem um indicador comum).
      {/if}
    </p>

    <ul class="space-y-3" aria-label="Indicadores">
      {#each dados.indicadores as ind (ind.codigo)}
        <li class="rounded-card bg-white border border-gray-200 shadow-card p-4 space-y-2">
          <div class="flex flex-wrap items-start justify-between gap-2">
            <div>
              <h2 class="text-base font-semibold text-gray-900">{ind.rotulo}</h2>
              <p class="text-xs text-gray-500">{ind.fonte} · {ind.unidade}</p>
            </div>
            <button type="button" onclick={() => alternar(ind.codigo)} aria-expanded={!!aberto[ind.codigo]}
              class="px-3 py-1 rounded-md bg-gray-100 text-gray-800 text-xs hover:bg-gray-200">
              {aberto[ind.codigo] ? "Ocultar escolas" : `Ver as ${ind.n_escolas} escola(s)`}
            </button>
          </div>
          <p class="text-sm text-gray-700" aria-label={`Resumo de ${ind.rotulo}`}>
            {ind.n_escolas} escola(s) com meta · {ind.n_medidas} de {ind.n_metas} meta(s) medida(s) ·
            {#if ind.andamento_medio !== null && ind.andamento_medio !== undefined}
              andamento médio <strong>{pct(ind.andamento_medio)}</strong>
            {:else}
              <span class="text-amber-800">sem metas medidas</span>
            {/if}
            {#if ind.n_base_ajustada}{" · "}<span class="text-amber-800">{ind.n_base_ajustada} com base ajustada pela escola</span>{/if}
          </p>

          {#if aberto[ind.codigo]}
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead class="text-xs text-gray-600 bg-gray-50">
                  <tr>
                    <th class="text-left px-2 py-1" scope="col">Escola</th>
                    <th class="text-left px-2 py-1" scope="col">Meta</th>
                    <th class="text-right px-2 py-1" scope="col">Base</th>
                    <th class="text-right px-2 py-1" scope="col">Alvo</th>
                    <th class="text-right px-2 py-1" scope="col">Atual</th>
                    <th class="text-left px-2 py-1" scope="col">Andamento</th>
                  </tr>
                </thead>
                <tbody>
                  {#each ind.escolas as e (e.meta.id)}
                    <tr class="border-t border-gray-100 align-top">
                      <td class="px-2 py-1">
                        <a href={`/rede/escolas/${e.cod_inep}/planos/${e.plano_id}/relatorio`} class="text-blue-700 hover:underline">{e.nome}</a>
                        <span class="block text-xs text-gray-500">{e.plano_titulo}</span>
                      </td>
                      <td class="px-2 py-1">{e.meta.descricao}</td>
                      <td class="px-2 py-1 text-right">
                        {fmtNum(e.meta.linha_base)}
                        {#if e.meta.base_ajustada}<span class="block text-[11px] text-amber-800">ajustada; oficial {fmtNum(e.meta.linha_base_oficial)}</span>{/if}
                      </td>
                      <td class="px-2 py-1 text-right">{fmtNum(e.meta.alvo)}</td>
                      <td class="px-2 py-1 text-right">{#if e.meta.atual}{fmtNum(e.meta.atual.valor)}{#if e.meta.atual.ano_ref}{" ("}{e.meta.atual.ano_ref}){/if}{:else}—{/if}</td>
                      <td class="px-2 py-1">{e.meta.progresso !== null && e.meta.progresso !== undefined ? pct(e.meta.progresso) : (META_ESTADO_LABEL[e.meta.estado] ?? "Sem medição")}</td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          {/if}
        </li>
      {:else}
        <li class="rounded-card bg-white border border-gray-200 p-6 text-center text-sm text-gray-500">
          Nenhuma escola da rede tem meta ligada a indicador oficial no plano vigente.
        </li>
      {/each}
    </ul>
    <p class="text-xs text-gray-500">
      O andamento médio considera só as metas medidas. Os valores oficiais novos entram todo dia de manhã, sem a escola precisar abrir o plano.
    </p>
  {/if}
</div>
