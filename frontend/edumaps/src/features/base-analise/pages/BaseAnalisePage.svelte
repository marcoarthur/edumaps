<script>
  // src/features/base-analise/pages/BaseAnalisePage.svelte
  //
  // Base de análise (#439, RV-02): uma linha por escola em funcionamento, com
  // os blocos de indicadores escolhidos, a versão dos dados e um dicionário
  // das colunas. Pública, uma UF por vez. A URL guarda o recorte e os blocos.
  import { onMount } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import InputAutocomplete from "@/shared/ui/components/InputAutocomplete.svelte";
  import { fetchMunicipioSuggestions } from "@/features/network-compare/api/networkCompareApi.js";
  import { ufDoMunicipio } from "@/features/ranking-recorte/constants.js";
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { getBaseAnalise, baseCsvUrl, dicionarioUrl } from "../api/baseAnaliseApi.js";

  const inicial = new URLSearchParams(window.location.search);

  let catalogo = $state(null);
  let uf = $state(/^[A-Z]{2}$/.test(inicial.get("uf") ?? "") ? inicial.get("uf") : "");
  let codigoIbge = $state(/^\d{7}$/.test(inicial.get("codigo_ibge") ?? "") ? inicial.get("codigo_ibge") : "");
  let municipioTexto = $state("");
  let rede = $state(inicial.get("rede") ?? "");
  let blocos = $state((inicial.get("blocos") ?? "").split(",").filter(Boolean));
  let anoIdeb = $state(Number(inicial.get("ano_ideb")) || null);
  let total = $state(null);
  let contando = $state(false);
  let error = $state(null);

  const filtros = $derived({ uf, codigoIbge, rede, blocos, anoIdeb });
  const escolhidos = $derived(catalogo ? catalogo.blocos.filter((b) => b.fixo || blocos.includes(b.id)) : []);
  const nColunas = $derived(escolhidos.reduce((n, b) => n + b.colunas.length, 0));
  // #444 (BA-01): edição antiga do IDEB cruzada com o Censo mais recente.
  const idebAntigo = $derived(
    !!catalogo && blocos.includes("desempenho") && anoIdeb != null && anoIdeb !== catalogo.anos.ideb[0],
  );

  function definirUrl() {
    const p = new URLSearchParams();
    if (uf) p.set("uf", uf);
    if (codigoIbge) p.set("codigo_ibge", codigoIbge);
    if (rede) p.set("rede", rede);
    if (blocos.length) p.set("blocos", blocos.join(","));
    if (anoIdeb && blocos.includes("desempenho")) p.set("ano_ideb", String(anoIdeb));
    window.history.replaceState({}, "", `/base-analise${p.size ? `?${p}` : ""}`);
  }

  async function contar() {
    definirUrl();
    if (!uf) {
      total = null;
      return;
    }
    contando = true;
    try {
      const r = await getBaseAnalise({ uf, codigoIbge, rede });
      total = r.total;
    } catch (err) {
      total = null;
      error = err instanceof ApiError ? err.message : "Não foi possível contar as escolas do recorte.";
    } finally {
      contando = false;
    }
  }

  function trocarUf() {
    // Município de outra UF sai do recorte.
    if (codigoIbge && ufDoMunicipio(codigoIbge) !== uf) {
      codigoIbge = "";
      municipioTexto = "";
    }
    contar();
  }

  function escolherMunicipio(city) {
    codigoIbge = city?.codigo_ibge ? String(city.codigo_ibge) : "";
    const u = ufDoMunicipio(codigoIbge);
    if (u) uf = u;
    contar();
  }

  function limparMunicipio() {
    codigoIbge = "";
    municipioTexto = "";
    contar();
  }

  function alternarBloco(id) {
    blocos = blocos.includes(id) ? blocos.filter((b) => b !== id) : [...blocos, id];
    definirUrl();
  }

  onMount(async () => {
    try {
      catalogo = await getBaseAnalise({ uf, codigoIbge, rede });
      total = catalogo.total;
      const ok = new Set(catalogo.blocos.filter((b) => !b.fixo).map((b) => b.id));
      blocos = blocos.filter((b) => ok.has(b));
      if (!catalogo.redes.some((r) => r.id === rede)) rede = "";
      if (!catalogo.anos.ideb.includes(anoIdeb)) anoIdeb = catalogo.anos.ideb[0] ?? null;
    } catch (err) {
      error = err instanceof ApiError ? err.message : "Não foi possível carregar a base de análise.";
    }
  });
</script>

{#snippet avisoAnos(testid)}
  <p class="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-md px-3 py-2" role="note" data-testid={testid}>
    A lista de escolas, a infraestrutura e a docência são do Censo {catalogo.anos.censo}; o IDEB é de {anoIdeb}.
    Escolas fechadas depois de {anoIdeb} não entram, e o cruzamento é entre anos diferentes.
  </p>
{/snippet}

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Base de análise</h1>
    <p class="mt-1 text-sm text-gray-600 max-w-3xl">
      Baixe uma planilha com uma linha por escola e os indicadores que escolher (infraestrutura, docência,
      IDEB e SAEB por etapa, nível socioeconômico e porte do município), para cruzar no Excel, no R ou no Python.
      Cada arquivo diz de que ano são os dados, e o dicionário explica cada coluna e a fonte dela.
    </p>
  </header>

  {#if error}
    <p class="text-sm text-red-700" role="alert">{error}</p>
  {/if}

  {#if catalogo}
    <section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-4" aria-labelledby="recorte">
      <h2 id="recorte" class="font-semibold text-gray-900">1. Recorte</h2>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
        <div>
          <label for="uf" class="block text-sm text-gray-600 mb-1">UF</label>
          <select id="uf" bind:value={uf} onchange={trocarUf}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            <option value="">Escolha a UF</option>
            {#each catalogo.ufs as u}<option value={u}>{u}</option>{/each}
          </select>
        </div>
        <div>
          <InputAutocomplete
            id="municipio-base"
            label="Município (opcional)"
            placeholder="Todos os da UF"
            bind:value={municipioTexto}
            fetchSuggestions={fetchMunicipioSuggestions}
            getOptionLabel={(city) => city.nome}
            getOptionKey={(city) => city.codigo_ibge}
            noResultsText="Nenhum município encontrado"
            onSelect={escolherMunicipio}
          >
            {#snippet option(city)}
              <span>{city.nome}</span>
              <span class="text-gray-400">{" · "}{city.uf}</span>
            {/snippet}
          </InputAutocomplete>
          {#if codigoIbge}
            <button type="button" onclick={limparMunicipio} class="mt-1 text-xs text-blue-700 hover:underline">
              Todos os municípios da UF
            </button>
          {/if}
        </div>
        <div>
          <label for="rede" class="block text-sm text-gray-600 mb-1">Rede</label>
          <select id="rede" bind:value={rede} onchange={contar}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            <option value="">Todas</option>
            {#each catalogo.redes as r}<option value={r.id}>{r.label}</option>{/each}
          </select>
        </div>
      </div>
      <p class="text-sm text-gray-700" data-testid="total-recorte">
        {#if !uf}
          Escolha a UF: a base sai uma UF por vez.
        {:else if contando}
          Contando as escolas…
        {:else if total != null}
          <strong>{total.toLocaleString("pt-BR")}</strong> {total === 1 ? "escola em funcionamento" : "escolas em funcionamento"} no recorte.
        {/if}
      </p>
    </section>

    <section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-3" aria-labelledby="blocos">
      <h2 id="blocos" class="font-semibold text-gray-900">2. Indicadores</h2>
      <ul class="space-y-3">
        {#each catalogo.blocos as b (b.id)}
          <li>
            <label class="flex items-start gap-2 text-sm">
              <input type="checkbox" class="mt-1"
                checked={b.fixo || blocos.includes(b.id)} disabled={b.fixo}
                onchange={() => alternarBloco(b.id)} />
              <span>
                <span class="font-medium text-gray-900">{b.label}</span>
                <span class="text-gray-500">{" · "}{b.colunas.length} {b.colunas.length === 1 ? "coluna" : "colunas"}</span>
                <span class="block text-gray-600">{b.descricao}</span>
              </span>
            </label>
            {#if b.id === "desempenho" && blocos.includes("desempenho")}
              <div class="ml-6 mt-2">
                <label for="ano-ideb" class="text-sm text-gray-600 mr-2">Edição do IDEB</label>
                <select id="ano-ideb" bind:value={anoIdeb} onchange={definirUrl}
                  class="border border-gray-300 rounded-md px-2 py-1 text-sm">
                  {#each catalogo.anos.ideb as a}<option value={a}>{a}</option>{/each}
                </select>
                {#if idebAntigo}<div class="mt-2">{@render avisoAnos("aviso-anos")}</div>{/if}
              </div>
            {/if}
          </li>
        {/each}
      </ul>
    </section>

    <section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-3" aria-labelledby="baixar">
      <h2 id="baixar" class="font-semibold text-gray-900">3. Baixar</h2>
      <p class="text-xs text-gray-600" data-testid="versao-dados">
        {nColunas} colunas, mais a versão dos dados no fim de cada linha:
        Censo Escolar {catalogo.anos.censo}{#if blocos.includes("desempenho")}{" · "}IDEB {anoIdeb}{/if}{#if blocos.includes("inse")}{" · "}INSE {catalogo.anos.inse}{/if}{#if blocos.includes("porte") && catalogo.anos.populacao}{" · "}população {catalogo.anos.populacao}{/if}.
        Separador ";" e vírgula decimal (abre direto no Excel). Ausência é célula vazia, nunca zero.
      </p>
      {#if idebAntigo}{@render avisoAnos("aviso-anos-baixar")}{/if}
      <div class="flex flex-wrap gap-2">
        {#if uf}
          <a href={baseCsvUrl(filtros)} download data-testid="baixar-base"
            class="px-3 py-1.5 text-sm rounded-md bg-blue-700 text-white hover:bg-blue-800">Baixar base (CSV)</a>
        {:else}
          <span class="px-3 py-1.5 text-sm rounded-md bg-gray-200 text-gray-500" aria-disabled="true">Baixar base (CSV)</span>
        {/if}
        <a href={dicionarioUrl(filtros)} download data-testid="baixar-dicionario"
          class="px-3 py-1.5 text-sm rounded-md border border-blue-700 text-blue-700 hover:bg-blue-50">Baixar dicionário das colunas</a>
      </div>
      <p class="text-xs text-gray-500">
        <span data-testid="aviso-link">O link desta página traz sempre a carga mais recente. Para citar, guarde o arquivo: os anos estão no nome e nas últimas colunas.</span>
        Os indicadores são os publicados pelo INEP e pelo IBGE, sem correção. Veja <a href="/fontes" class="text-blue-700 hover:underline">Fontes e metodologia</a>.
      </p>
    </section>
  {:else if !error}
    <p class="text-sm text-gray-500">Carregando…</p>
  {/if}

  <FonteDado tela="base_analise" class="pt-2" />
</div>
