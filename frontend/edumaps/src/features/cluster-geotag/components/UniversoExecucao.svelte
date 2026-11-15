<script>
  // src/features/cluster-geotag/components/UniversoExecucao.svelte
  //
  // Universo de uma execução do agrupamento (#427, AN-05): quantas escolas o
  // recorte tinha, quantas entraram e por que as outras ficaram de fora; e o
  // link e a exportação da execução (AN-09).
  import { resumoUniverso, dataBR } from "../utils/execucao.js";
  import { execucaoCsvUrl } from "../api/clusterApi.js";

  let { execucao, columns = [] } = $props();

  const r = $derived(resumoUniverso(execucao, columns));
  // Versão dos dados guardada na execução (#428): ano do Censo e do IDEB.
  const versaoDados = $derived.by(() => {
    const d = execucao?.parametros?.dados ?? {};
    const partes = [];
    if (d.censo?.ano) partes.push(`Censo Escolar ${d.censo.ano}${d.censo.carga ? ` (carga em ${dataBR(d.censo.carga)})` : ""}`);
    if (d.ideb?.ano) partes.push(`IDEB ${d.ideb.ano}`);
    return partes.join(" · ");
  });
  const fmt = (n) => (n == null ? "–" : Number(n).toLocaleString("pt-BR"));
  let copiado = $state(false);
  // Sem acesso à área de transferência (http, permissão negada): mostra o
  // link num campo para copiar à mão.
  let linkManual = $state("");

  async function copiarLink() {
    const url = `${window.location.origin}/cluster/geotag?execucao=${encodeURIComponent(execucao.run_id)}`;
    try {
      await navigator.clipboard.writeText(url);
      copiado = true;
      setTimeout(() => (copiado = false), 2500);
    } catch {
      linkManual = url;
    }
  }
</script>

<section class="bg-white border border-gray-200 rounded-card shadow-card p-4 space-y-3" aria-label="Universo do agrupamento" data-testid="universo-execucao">
  <div class="flex flex-wrap items-start justify-between gap-3">
    <div>
      <p class="font-semibold text-gray-800 text-sm">Universo</p>
      <p class="text-sm text-gray-700 mt-1">
        <strong>{fmt(r.total)}</strong> escolas no recorte, <strong>{fmt(r.agrupadas)}</strong> agrupadas{#if r.fora > 0}, <strong>{fmt(r.fora)}</strong> fora{/if}.
      </p>
      {#if r.motivos.length > 0}
        <ul class="text-xs text-gray-600 mt-1 list-disc pl-5">
          {#each r.motivos as m (m.texto)}
            <li>{fmt(m.n)} {m.texto}</li>
          {/each}
        </ul>
        {#if r.motivos.filter((m) => m.texto.startsWith("sem dado")).length > 1}
          <p class="text-xs text-gray-500 mt-1">Uma escola sem dado em mais de um indicador conta em cada um deles.</p>
        {/if}
      {/if}
      {#if r.foraDoMapa > 0}
        <p class="text-xs text-gray-600 mt-1">{fmt(r.foraDoMapa)} escolas agrupadas sem coordenada não aparecem no mapa (estão na exportação).</p>
      {/if}
    </div>
    <div class="flex flex-wrap gap-2">
      <button
        type="button"
        onclick={copiarLink}
        class="px-3 py-1.5 text-sm rounded-md border border-blue-700 text-blue-700 hover:bg-blue-50"
      >
        {copiado ? "Link copiado" : "Copiar link"}
      </button>
      <a
        href={execucaoCsvUrl(execucao.run_id)}
        download
        class="px-3 py-1.5 text-sm rounded-md bg-blue-700 text-white hover:bg-blue-800"
      >
        Baixar CSV
      </a>
    </div>
  </div>
  {#if linkManual}
    <label class="block text-xs text-gray-600">
      Copie o link:
      <input readonly value={linkManual} class="mt-1 w-full border border-gray-300 rounded-md px-2 py-1 text-xs" onfocus={(e) => e.currentTarget.select()} />
    </label>
  {/if}
  {#if versaoDados}
    <p class="text-xs text-gray-600" data-testid="versao-dados">Dados: {versaoDados}.</p>
  {/if}
  {#if execucao.expira_em}
    <p class="text-xs text-gray-500">O link reabre este mesmo resultado até {dataBR(execucao.expira_em)}.</p>
  {/if}
</section>
