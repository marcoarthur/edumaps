<!-- src/features/schools/pages/MunicipioFinanceiroPage.svelte -->
<script>
  // #614 (QF-01 da P2): o painel financeiro da rede municipal aberto pelo
  // município (/municipio/financeiro?codigo_ibge=XXXXXXX&ano=AAAA), o mesmo
  // painel da rede de uma escola sem folha própria, sem depender dela. O ano
  // fica no endereço: o link enviado ao conselho abre no ano escolhido.
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { onMount } from "svelte";
  import { getCityFinance } from "../api/schoolApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import SchoolFinance from "../components/panel/SchoolFinance.svelte";

  let ibge = $state(null);
  let data = $state(null);
  let loading = $state(true);
  let error = $state(null);
  let aviso = $state(null);

  const titulo = $derived(data?.municipio?.nome
    ? `${data.municipio.nome}${data.municipio.uf ? ` (${data.municipio.uf})` : ""}` : "");

  function poeAnoNoEndereco(a) {
    const u = new URL(window.location.href);
    if (a) u.searchParams.set("ano", String(a)); else u.searchParams.delete("ano");
    window.history.replaceState(window.history.state, "", u.pathname + u.search);
  }

  async function carregar(anoPedido = null) {
    loading = true;
    error = null;
    try {
      data = await getCityFinance(ibge, anoPedido);
      poeAnoNoEndereco(data.ano);
    } catch (err) {
      // ano sem folha no endereço: abre o mais recente e diz por quê
      if (anoPedido && err instanceof ApiError && err.status === 400) {
        aviso = `Não há folha da rede municipal em ${anoPedido}; abrimos o ano mais recente.`;
        return carregar(null);
      }
      data = null;
      error = err instanceof ApiError ? err.message : "Erro ao carregar o painel da rede.";
    } finally {
      loading = false;
    }
  }

  onMount(() => {
    const p = new URLSearchParams(window.location.search);
    ibge = p.get("codigo_ibge") ?? p.get("ibge");
    if (!ibge || !/^\d{7}$/.test(ibge)) {
      loading = false;
      error = "Código IBGE do município não informado (?codigo_ibge=XXXXXXX).";
      return;
    }
    const a = p.get("ano");
    carregar(a && /^\d{4}$/.test(a) ? Number(a) : null);
  });
</script>

<div class="space-y-6">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Folha e Fundeb da rede municipal</h1>
      {#if titulo}
        <p class="text-sm text-gray-600 mt-1" data-testid="municipio-titulo">{titulo} · IBGE {ibge}</p>
      {/if}
    </div>
    {#if ibge}
      <a href={`/municipio/perfil?codigo_ibge=${ibge}`}
        class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300 transition-colors">
        ← Perfil da rede
      </a>
    {/if}
  </header>

  {#if aviso}
    <p class="text-sm text-amber-900 bg-amber-50 border border-amber-200 rounded-md p-3" role="note" data-testid="aviso-ano">{aviso}</p>
  {/if}

  {#if loading}
    <div class="text-center py-12"><p class="text-gray-500">Carregando dados financeiros…</p></div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4" role="alert">{error}</div>
  {:else if data}
    {#if (data.anos ?? []).length > 0}
      <div class="flex items-center gap-2">
        <label for="ano-folha-rede" class="text-sm text-gray-600">Ano da folha</label>
        <select id="ano-folha-rede" value={data.ano}
          onchange={(e) => { aviso = null; carregar(Number(e.currentTarget.value)); }}
          class="h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
          {#each data.anos as a (a)}<option value={a}>{a}</option>{/each}
        </select>
        <span class="text-xs text-gray-500">Os totais, as categorias e os gráficos são deste ano.</span>
      </div>
    {/if}
    <SchoolFinance inep={null} porMunicipio={true} municipioIbge={ibge}
      series={data.series ?? []} categorias={data.categorias ?? []} porFonte={data.por_fonte ?? null}
      mesesIncompletos={data.meses_incompletos ?? []} salarioRede={data.salario_rede ?? null}
      cargaFolha={data.carga_folha ?? null} totalProfissionais={data.total_profissionais ?? 0}
      origem="rede" rede={data.rede ?? null} fundeb={data.fundeb ?? null} ano={data.ano ?? null} periodo={data.periodo ?? null} />
  {/if}
  <FonteDado tela="financeiro" class="pt-2" />
</div>
