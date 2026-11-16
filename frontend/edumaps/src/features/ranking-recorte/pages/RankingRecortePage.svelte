<script>
  // src/features/ranking-recorte/pages/RankingRecortePage.svelte
  //
  // Ranking por recorte (#430, AN-11):
  //   * Redes municipais — as redes dos municípios de uma UF (ou do Brasil)
  //     por um indicador do IDEB/SAEB, com a variação entre edições e o
  //     contexto socioeconômico (INSE) ao lado;
  //   * Escolas de um município — todas as escolas por um indicador.
  // A URL guarda a aba e os filtros (link estável); cada tabela exporta CSV.
  import { onMount } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import InputAutocomplete from "@/shared/ui/components/InputAutocomplete.svelte";
  import { fetchMunicipioSuggestions } from "@/features/network-compare/api/networkCompareApi.js";
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { getRankingRedes, getRankingEscolas } from "../api/rankingRecorteApi.js";
  import { INDICADORES_IDEB, INDICADORES_ESCOLA, UFS, REDES, MINIMOS } from "../constants.js";
  import { num, variacao, contexto, csv, baixarCsv } from "../utils/formato.js";

  const inicial = new URLSearchParams(window.location.search);

  let aba = $state(inicial.get("aba") === "escolas" ? "escolas" : "redes");

  // ---- redes municipais -----------------------------------------------
  let uf = $state(UFS.includes(inicial.get("uf") ?? "") ? inicial.get("uf") : "ES");
  let nacional = $state(inicial.get("nacional") === "1");
  let indicadorRede = $state(
    INDICADORES_IDEB.some((i) => i.id === inicial.get("indicador")) ? inicial.get("indicador") : "ideb_anos_iniciais",
  );
  let ordem = $state(inicial.get("ordem") === "variacao" ? "variacao" : "media");
  // #437: mínimo de escolas por rede e sentido da ordem (as duas abas).
  let minimo = $state(MINIMOS.includes(Number(inicial.get("minimo"))) ? Number(inicial.get("minimo")) : 3);
  let sentido = $state(inicial.get("sentido") === "asc" ? "asc" : "desc");
  let redes = $state(null);

  // Ordena pelo critério; "menor primeiro" inverte, mas quem não tem valor
  // (variação "–") fica sempre no fim.
  function ordenar(lista, chave) {
    const com = lista.filter((x) => x[chave] != null);
    const sem = lista.filter((x) => x[chave] == null);
    com.sort((a, b) => (sentido === "asc" ? a[chave] - b[chave] : b[chave] - a[chave]));
    return [...com, ...sem];
  }

  const redesOrdenadas = $derived(redes ? ordenar([...redes.redes], ordem === "variacao" ? "variacao" : "media") : []);


  // ---- escolas de um município ----------------------------------------
  let codigoIbge = $state(/^\d{7}$/.test(inicial.get("codigo_ibge") ?? "") ? inicial.get("codigo_ibge") : "");
  let municipioTexto = $state("");
  let indicadorEscola = $state(
    INDICADORES_ESCOLA.some((i) => i.id === inicial.get("indicador")) ? inicial.get("indicador") : "ideb_anos_iniciais",
  );
  let rede = $state(REDES.some((r) => r.id === inicial.get("rede")) ? inicial.get("rede") : "");
  let escolas = $state(null);
  const escolasOrdenadas = $derived(escolas ? ordenar([...escolas.escolas], "valor") : []);

  let loading = $state(false);
  let error = $state(null);

  function definirUrl() {
    const p = new URLSearchParams();
    p.set("aba", aba);
    if (aba === "redes") {
      p.set("indicador", indicadorRede);
      if (nacional) p.set("nacional", "1");
      else p.set("uf", uf);
      if (ordem !== "media") p.set("ordem", ordem);
      if (minimo !== 3) p.set("minimo", String(minimo));
    } else {
      p.set("indicador", indicadorEscola);
      if (codigoIbge) p.set("codigo_ibge", codigoIbge);
      if (rede) p.set("rede", rede);
    }
    if (sentido === "asc") p.set("sentido", "asc");
    window.history.replaceState({}, "", `/ranking?${p}`);
  }

  function mensagem(err, padrao) {
    return err instanceof ApiError ? err.message : padrao;
  }

  async function carregarRedes() {
    loading = true;
    error = null;
    definirUrl();
    try {
      redes = await getRankingRedes({ indicador: indicadorRede, uf, nacional, minimo });
    } catch (err) {
      redes = null;
      error = mensagem(err, "Não foi possível carregar o ranking das redes.");
    } finally {
      loading = false;
    }
  }

  async function carregarEscolas() {
    definirUrl();
    if (!codigoIbge) {
      escolas = null;
      return;
    }
    loading = true;
    error = null;
    try {
      escolas = await getRankingEscolas({ codigoIbge, indicador: indicadorEscola, rede });
      municipioTexto = escolas?.municipio?.nome ?? municipioTexto;
    } catch (err) {
      escolas = null;
      error = mensagem(err, "Não foi possível carregar as escolas.");
    } finally {
      loading = false;
    }
  }

  function alternarSentido() {
    sentido = sentido === "asc" ? "desc" : "asc";
    definirUrl();
  }

  function trocarAba(nova) {
    aba = nova;
    error = null;
    if (nova === "redes") carregarRedes();
    else carregarEscolas();
  }

  function escolherMunicipio(city) {
    codigoIbge = city?.codigo_ibge ? String(city.codigo_ibge) : "";
    carregarEscolas();
  }

  function exportarRedes() {
    const r = redes;
    baixarCsv(
      `ranking-redes-${r.indicador.id}-${nacional ? "BR" : uf}-${r.ano}-min${r.minimo_escolas}.csv`,
      csv(
        ["posicao", "codigo_ibge", "municipio", "uf", "escolas", `media_${r.ano}`, `variacao_${r.ano_anterior ?? ""}_${r.ano}`, "salto_atipico", "inse_medio", "quinto_inse", "media_dos_municipios_do_mesmo_quinto"],
        redesOrdenadas.map((x) => [x.posicao, x.codigo_ibge, x.municipio, x.uf, x.escolas, x.media, x.variacao, x.atipico ? "sim" : "", x.inse, x.quinto_inse, x.media_quinto_inse]),
      ),
    );
  }

  function exportarEscolas() {
    const e = escolas;
    baixarCsv(
      `ranking-escolas-${e.municipio.codigo_ibge}-${e.indicador.id}-${e.ano}.csv`,
      csv(
        ["posicao", "inep", "escola", "rede", `${e.indicador.id}_${e.ano}`, "inse"],
        escolasOrdenadas.map((x) => [x.posicao, x.co_entidade, x.no_entidade, x.rede, x.valor, x.inse]),
      ),
    );
  }

  onMount(() => {
    if (aba === "redes") carregarRedes();
    else carregarEscolas();
  });
</script>

<div class="space-y-6">
  <header>
    <h1 class="text-2xl font-bold text-gray-900">Rankings</h1>
    <p class="mt-1 text-sm text-gray-600">
      Compare as redes municipais de um estado, ou as escolas de um município, por um indicador.
      O nível socioeconômico (INSE) aparece ao lado: posição sem contexto não diz quem faz mais com o que tem.
    </p>
  </header>

  <div class="flex gap-2 border-b border-gray-200" role="tablist">
    <button role="tab" aria-selected={aba === "redes"} onclick={() => trocarAba("redes")}
      class="px-4 py-2 text-sm font-medium border-b-2 {aba === 'redes' ? 'border-blue-700 text-blue-700' : 'border-transparent text-gray-600'}">
      Redes municipais
    </button>
    <button role="tab" aria-selected={aba === "escolas"} onclick={() => trocarAba("escolas")}
      class="px-4 py-2 text-sm font-medium border-b-2 {aba === 'escolas' ? 'border-blue-700 text-blue-700' : 'border-transparent text-gray-600'}">
      Escolas de um município
    </button>
  </div>

  {#if aba === "redes"}
    <section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-3 lg:grid-cols-6 gap-4 items-end">
        <div>
          <label for="uf" class="block text-sm text-gray-600 mb-1">UF</label>
          <select id="uf" bind:value={uf} disabled={nacional} onchange={carregarRedes}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            {#each UFS as u}<option value={u}>{u}</option>{/each}
          </select>
        </div>
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input type="checkbox" bind:checked={nacional} onchange={carregarRedes} />
          Brasil inteiro
        </label>
        <div>
          <label for="indicador-rede" class="block text-sm text-gray-600 mb-1">Indicador</label>
          <select id="indicador-rede" bind:value={indicadorRede} onchange={carregarRedes}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            {#each INDICADORES_IDEB as i}<option value={i.id}>{i.label}</option>{/each}
          </select>
        </div>
        <div>
          <label for="ordem" class="block text-sm text-gray-600 mb-1">Ordenar por</label>
          <select id="ordem" bind:value={ordem} onchange={definirUrl}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            <option value="media">Valor da edição mais recente</option>
            <option value="variacao">Quanto mudou desde a edição anterior</option>
          </select>
        </div>
        <div>
          <label for="minimo" class="block text-sm text-gray-600 mb-1">Mínimo de escolas por rede</label>
          <select id="minimo" bind:value={minimo} onchange={carregarRedes}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            {#each MINIMOS as m}<option value={m}>{m}</option>{/each}
          </select>
        </div>
        <button type="button" onclick={alternarSentido} data-testid="sentido-redes"
          class="px-3 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50">
          {sentido === "asc" ? "Menor primeiro ↑" : "Maior primeiro ↓"}
        </button>
      </div>

      {#if loading}
        <p class="text-sm text-gray-500">Carregando…</p>
      {:else if error}
        <p class="text-sm text-red-700" role="alert">{error}</p>
      {:else if redes}
        <div class="flex flex-wrap items-start justify-between gap-3">
          <p class="text-xs text-gray-600 max-w-3xl" data-testid="nota-redes">
            Valor da rede = <strong>média simples das escolas municipais</strong> com {redes.indicador.label} em {redes.ano}
            (não é o IDEB oficial da rede, calculado pelo INEP). Variação: diferença para {redes.ano_anterior ?? "a edição anterior"}.
            Entram as redes com pelo menos {redes.minimo_escolas} escolas com dado: {redes.total} redes;
            {redes.fora_por_poucas_escolas} ficaram de fora por terem menos escolas.
            "INSE parecido" = municípios do mesmo quinto de nível socioeconômico no recorte.
            {#if redes.atipico?.limite_superior != null}
              <strong>Salto atípico</strong>: variação a mais de {redes.atipico.desvios} desvios padrão da média do recorte
              (fora de {variacao(redes.atipico.limite_inferior)} a {variacao(redes.atipico.limite_superior)});
              {redes.atipico.marcadas} {redes.atipico.marcadas === 1 ? "rede marcada" : "redes marcadas"}. É o dado publicado; confira os dados da rede antes de citar.
            {/if}
          </p>
          <button type="button" onclick={exportarRedes}
            class="px-3 py-1.5 text-sm rounded-md bg-blue-700 text-white hover:bg-blue-800">Baixar CSV</button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" data-testid="tabela-redes">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100">
                <th class="px-2 py-2 font-medium">#</th>
                <th class="px-2 py-2 font-medium">Município</th>
                <th class="px-2 py-2 font-medium text-right">Escolas</th>
                <th class="px-2 py-2 font-medium text-right">{redes.ano}</th>
                <th class="px-2 py-2 font-medium text-right">Variação</th>
                <th class="px-2 py-2 font-medium text-right">INSE médio</th>
                <th class="px-2 py-2 font-medium">Contexto</th>
              </tr>
            </thead>
            <tbody>
              {#each redesOrdenadas as r (r.codigo_ibge)}
                <tr class="border-b border-gray-50">
                  <td class="px-2 py-1.5 text-gray-500">{ordem === "variacao" ? (r.posicao_variacao ?? "–") : r.posicao}</td>
                  <td class="px-2 py-1.5">
                    <a href="/municipio/compare?codigo_ibge={r.codigo_ibge}" class="text-blue-700 hover:underline">{r.municipio}</a>
                    {#if nacional}<span class="text-gray-400"> · {r.uf}</span>{/if}
                  </td>
                  <td class="px-2 py-1.5 text-right">{r.escolas}</td>
                  <td class="px-2 py-1.5 text-right font-medium">{num(r.media)}</td>
                  <td class="px-2 py-1.5 text-right whitespace-nowrap">
                    {variacao(r.variacao)}
                    {#if r.atipico}
                      <span class="ml-1 inline-block px-1.5 py-0.5 rounded bg-amber-50 text-amber-800 text-[11px] font-medium" data-testid="salto-atipico"
                        title="Variação muito acima ou abaixo das outras redes do recorte. É o dado publicado pelo INEP; confira os dados da rede antes de citar.">
                        salto atípico
                      </span>
                    {/if}
                  </td>
                  <td class="px-2 py-1.5 text-right">{num(r.inse)}</td>
                  <td class="px-2 py-1.5 text-xs text-gray-600">{contexto(r)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </section>
  {:else}
    <section class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-4">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
        <InputAutocomplete
          id="municipio-ranking"
          label="Município"
          placeholder="Ex: Vitória"
          bind:value={municipioTexto}
          fetchSuggestions={fetchMunicipioSuggestions}
          getOptionLabel={(city) => city.nome}
          getOptionKey={(city) => city.codigo_ibge}
          noResultsText="Nenhum município encontrado"
          onSelect={escolherMunicipio}
        >
          {#snippet option(city)}
            <span>{city.nome}</span>
            <span class="text-gray-400"> · {city.uf}</span>
          {/snippet}
        </InputAutocomplete>
        <div>
          <label for="indicador-escola" class="block text-sm text-gray-600 mb-1">Indicador</label>
          <select id="indicador-escola" bind:value={indicadorEscola} onchange={carregarEscolas}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            {#each INDICADORES_ESCOLA as i}<option value={i.id}>{i.label}</option>{/each}
          </select>
        </div>
        <div>
          <label for="rede" class="block text-sm text-gray-600 mb-1">Rede</label>
          <select id="rede" bind:value={rede} onchange={carregarEscolas}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            {#each REDES as r}<option value={r.id}>{r.label}</option>{/each}
          </select>
        </div>
      </div>
      <button type="button" onclick={alternarSentido} data-testid="sentido-escolas"
        class="px-3 py-2 text-sm rounded-md border border-gray-300 text-gray-700 hover:bg-gray-50">
        {sentido === "asc" ? "Menor primeiro ↑" : "Maior primeiro ↓"}
      </button>

      {#if !codigoIbge}
        <p class="text-sm text-gray-500">Escolha um município para ver as escolas.</p>
      {:else if loading}
        <p class="text-sm text-gray-500">Carregando…</p>
      {:else if error}
        <p class="text-sm text-red-700" role="alert">{error}</p>
      {:else if escolas}
        <div class="flex flex-wrap items-start justify-between gap-3">
          <p class="text-xs text-gray-600" data-testid="nota-escolas">
            {escolas.total} escolas de {escolas.municipio.nome} ({escolas.municipio.uf}) com {escolas.indicador.label} em {escolas.ano}.
            Escolas empatadas dividem a posição.
          </p>
          <button type="button" onclick={exportarEscolas}
            class="px-3 py-1.5 text-sm rounded-md bg-blue-700 text-white hover:bg-blue-800">Baixar CSV</button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm" data-testid="tabela-escolas">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-gray-500 border-b border-gray-100">
                <th class="px-2 py-2 font-medium">#</th>
                <th class="px-2 py-2 font-medium">Escola</th>
                <th class="px-2 py-2 font-medium">Rede</th>
                <th class="px-2 py-2 font-medium text-right">{escolas.ano}</th>
                <th class="px-2 py-2 font-medium text-right">INSE</th>
              </tr>
            </thead>
            <tbody>
              {#each escolasOrdenadas as e (e.co_entidade)}
                <tr class="border-b border-gray-50">
                  <td class="px-2 py-1.5 text-gray-500">{e.posicao}</td>
                  <td class="px-2 py-1.5">
                    <a href="/escola/panel?inep={e.co_entidade}" class="text-blue-700 hover:underline">{e.no_entidade}</a>
                  </td>
                  <td class="px-2 py-1.5 text-gray-600">{e.rede ?? "–"}</td>
                  <td class="px-2 py-1.5 text-right font-medium">{num(e.valor)}</td>
                  <td class="px-2 py-1.5 text-right">{num(e.inse)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </section>
  {/if}

  <FonteDado tela="ranking" class="pt-2" />
</div>
