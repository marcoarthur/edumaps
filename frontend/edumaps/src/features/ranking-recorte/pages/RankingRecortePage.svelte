<script>
  // src/features/ranking-recorte/pages/RankingRecortePage.svelte
  //
  // Ranking por recorte (#430, AN-11):
  //   * Redes municipais — as redes dos municípios de uma UF, de uma região
  //     (#445) ou do Brasil
  //     por um indicador do IDEB/SAEB, com a variação entre edições e o
  //     contexto socioeconômico (INSE) ao lado;
  //   * Escolas de um município — todas as escolas por um indicador.
  // A URL guarda a aba e os filtros (link estável); cada tabela exporta CSV.
  import { onMount } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import InputAutocomplete from "@/shared/ui/components/InputAutocomplete.svelte";
  import { fetchMunicipioSuggestions } from "@/features/network-compare/api/networkCompareApi.js";
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { dataBR } from "@/features/fontes/utils.js";
  import { getRankingRedes, getRankingEscolas } from "../api/rankingRecorteApi.js";
  import { INDICADORES_IDEB, INDICADORES_ESCOLA, UFS, REDES, MINIMOS, PORTES, REGIOES, rotuloPorte, rotuloRegiao } from "../constants.js";
  import { num, variacao, contexto, csv, baixarCsv } from "../utils/formato.js";
  import { tabelaRedes, tabelaEscolas } from "../utils/exportar.js";

  const inicial = new URLSearchParams(window.location.search);

  let aba = $state(inicial.get("aba") === "escolas" ? "escolas" : "redes");

  // ---- redes municipais -----------------------------------------------
  let uf = $state(UFS.includes(inicial.get("uf") ?? "") ? inicial.get("uf") : "ES");
  // #445: abrangência do recorte — UF, região ou Brasil. O link antigo com
  // nacional=1 continua valendo.
  const regiaoInicial = REGIOES.some((r) => r.id === inicial.get("regiao")) ? inicial.get("regiao") : "";
  let abrangencia = $state(inicial.get("nacional") === "1" ? "brasil" : regiaoInicial ? "regiao" : "uf");
  let regiao = $state(regiaoInicial || "SE");
  const multiUf = $derived(abrangencia !== "uf");
  let indicadorRede = $state(
    INDICADORES_IDEB.some((i) => i.id === inicial.get("indicador")) ? inicial.get("indicador") : "ideb_anos_iniciais",
  );
  let ordem = $state(inicial.get("ordem") === "variacao" ? "variacao" : "media");
  // #437: mínimo de escolas por rede e sentido da ordem (as duas abas).
  let minimo = $state(MINIMOS.includes(Number(inicial.get("minimo"))) ? Number(inicial.get("minimo")) : 3);
  let sentido = $state(inicial.get("sentido") === "asc" ? "asc" : "desc");
  // #439: porte do município (classes de população do IBGE); "" = todos.
  let porte = $state(PORTES.some((p) => p.id === inicial.get("porte")) ? inicial.get("porte") : "");
  let redes = $state(null);
  // #449 (RG-03): município destacado na lista de redes (código IBGE).
  let destaque = $state(/^\d{7}$/.test(inicial.get("destaque") ?? "") ? inicial.get("destaque") : "");
  let destaqueTexto = $state("");

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
      if (abrangencia === "brasil") p.set("nacional", "1");
      else if (abrangencia === "regiao") p.set("regiao", regiao);
      else p.set("uf", uf);
      if (ordem !== "media") p.set("ordem", ordem);
      if (minimo !== 3) p.set("minimo", String(minimo));
      if (porte) p.set("porte", porte);
      if (destaque) p.set("destaque", destaque);
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
      redes = await getRankingRedes({ indicador: indicadorRede, abrangencia, uf, regiao, minimo, porte, destaque });
      if (redes?.destaque?.municipio && !destaqueTexto) destaqueTexto = redes.destaque.municipio;
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
    // #449: o município destacado nas redes já vem escolhido nas escolas.
    if (nova === "escolas" && !codigoIbge && destaque) {
      codigoIbge = destaque;
      municipioTexto = destaqueTexto;
    }
    if (nova === "redes") carregarRedes();
    else carregarEscolas();
  }

  function escolherMunicipio(city) {
    codigoIbge = city?.codigo_ibge ? String(city.codigo_ibge) : "";
    carregarEscolas();
  }

  function escolherDestaque(city) {
    destaque = city?.codigo_ibge ? String(city.codigo_ibge) : "";
    destaqueTexto = city?.nome ?? "";
    carregarRedes();
  }

  function limparDestaque() {
    destaque = "";
    destaqueTexto = "";
    carregarRedes();
  }

  // Sugestões de recorte a partir do município destacado.
  function compararPorteRegiao() {
    const d = redes.destaque;
    abrangencia = "regiao";
    regiao = d.regiao;
    porte = d.porte;
    carregarRedes();
  }

  function compararNaUf() {
    abrangencia = "uf";
    uf = redes.destaque.uf;
    carregarRedes();
  }

  const d = $derived(redes?.destaque ?? null);
  // #453 (VJ-03): redes sem variação. Pela regra do modelo, a variação fica
  // vazia só quando a rede tinha menos escolas com dado que o mínimo na
  // edição anterior (ou não havia edição anterior).
  const semVariacao = $derived(redes ? redes.redes.filter((r) => r.variacao == null).length : 0);
  const linhaDestaque = $derived(d ? redes.redes.find((r) => r.codigo_ibge === d.codigo_ibge) : null);
  const jaPorteRegiao = $derived(
    !!d && abrangencia === "regiao" && regiao === d.regiao && porte === (d.porte ?? ""),
  );
  const jaNaUf = $derived(!!d && abrangencia === "uf" && uf === d.uf);

  // Leva a linha destacada para a vista quando a lista chega ou muda de
  // ordem. Rolagem direta depois do próximo quadro: a suave era interrompida
  // pelo resto da página ainda montando.
  function irParaDestaque() {
    if (!linhaDestaque) return;
    const el = document.getElementById(`rede-${linhaDestaque.codigo_ibge}`);
    el?.scrollIntoView?.({ block: "center" });
  }

  $effect(() => {
    if (!linhaDestaque || loading) return;
    void redesOrdenadas;
    const raf = requestAnimationFrame(() => setTimeout(irParaDestaque, 50));
    return () => cancelAnimationFrame(raf);
  });

  function motivo(x, r) {
    const fora = "A rede não está nesta lista:";
    switch (x.situacao) {
      case "fora_do_recorte":
        return `${fora} o município é de ${x.uf} (${rotuloRegiao(x.regiao) || "região desconhecida"}), fora deste recorte.`;
      case "fora_do_porte":
        return `${fora} o município tem ${num(x.populacao, 0)} habitantes (${rotuloPorte(x.porte)}), fora do porte escolhido.`;
      case "sem_populacao":
        return `${fora} o município não tem estimativa de população carregada, então não entra com filtro de porte.`;
      case "poucas_escolas":
        return `${fora} só ${x.escolas} ${x.escolas === 1 ? "escola municipal" : "escolas municipais"} com dado em ${r.ano}; o mínimo é ${r.minimo_escolas}.`;
      default:
        return `${fora} nenhuma escola municipal com ${r.indicador.label} em ${r.ano}.`;
    }
  }

  const csvDe = (t) => csv(t.cabecalho, t.linhas);

  function exportarRedes() {
    const r = redes;
    baixarCsv(
      `ranking-redes-${r.indicador.id}-${abrangencia === "brasil" ? "BR" : abrangencia === "regiao" ? regiao : uf}${porte ? `-${porte}` : ""}-${r.ano}-min${r.minimo_escolas}.csv`,
      csvDe(tabelaRedes(r, redesOrdenadas)),
    );
  }

  function exportarEscolas() {
    const e = escolas;
    baixarCsv(
      `ranking-escolas-${e.municipio.codigo_ibge}-${e.indicador.id}-${e.ano}.csv`,
      csvDe(tabelaEscolas(e, escolasOrdenadas)),
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
      Compare as redes municipais de um estado, de uma região ou do Brasil, ou as escolas de um município, por um indicador.
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
      <div class="grid grid-cols-1 sm:grid-cols-3 lg:grid-cols-4 gap-4 items-end">
        <div>
          <label for="abrangencia" class="block text-sm text-gray-600 mb-1">Abrangência</label>
          <select id="abrangencia" bind:value={abrangencia} onchange={carregarRedes}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            <option value="uf">Uma UF</option>
            <option value="regiao">Uma região</option>
            <option value="brasil">Brasil inteiro</option>
          </select>
        </div>
        {#if abrangencia === "uf"}
          <div>
            <label for="uf" class="block text-sm text-gray-600 mb-1">UF</label>
            <select id="uf" bind:value={uf} onchange={carregarRedes}
              class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
              {#each UFS as u}<option value={u}>{u}</option>{/each}
            </select>
          </div>
        {:else if abrangencia === "regiao"}
          <div>
            <label for="regiao" class="block text-sm text-gray-600 mb-1">Região</label>
            <select id="regiao" bind:value={regiao} onchange={carregarRedes}
              class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
              {#each REGIOES as r}<option value={r.id}>{r.label}</option>{/each}
            </select>
          </div>
        {/if}
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
        <div>
          <label for="porte" class="block text-sm text-gray-600 mb-1">Porte do município</label>
          <select id="porte" bind:value={porte} onchange={carregarRedes}
            class="w-full border border-gray-300 rounded-md px-3 py-2 text-sm">
            <option value="">Todos</option>
            {#each PORTES as p}<option value={p.id}>{p.label}</option>{/each}
          </select>
        </div>
        <div>
          <InputAutocomplete
            id="destaque-rede"
            label="Destacar município"
            placeholder="Ex: Vitória"
            bind:value={destaqueTexto}
            fetchSuggestions={fetchMunicipioSuggestions}
            getOptionLabel={(city) => city.nome}
            getOptionKey={(city) => city.codigo_ibge}
            noResultsText="Nenhum município encontrado"
            onSelect={escolherDestaque}
          >
            {#snippet option(city)}
              <span>{city.nome}</span>
              <span class="text-gray-400"> · {city.uf}</span>
            {/snippet}
          </InputAutocomplete>
          {#if destaque}
            <button type="button" onclick={limparDestaque} class="mt-1 text-xs text-blue-700 hover:underline">Tirar o destaque</button>
          {/if}
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
        {#if d}
          <div class="rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-gray-800 space-y-2" data-testid="destaque-resumo" role="status">
            <p>
              <strong>{d.municipio ?? d.codigo_ibge}</strong>
              {#if d.uf}({d.uf}{d.regiao ? `, ${rotuloRegiao(d.regiao)}` : ""}{d.porte ? `, ${rotuloPorte(d.porte)}` : ""}){/if}:
              {#if d.situacao === "no_ranking"}
                {d.posicao}ª de {redes.total} {redes.total === 1 ? "rede" : "redes"} neste recorte pelo valor de {redes.ano}{#if ordem === "variacao" && linhaDestaque?.posicao_variacao}{" "}e {linhaDestaque.posicao_variacao}ª pela variação{/if}.
                <button type="button" onclick={irParaDestaque} data-testid="ir-destaque" class="ml-1 text-xs text-blue-700 hover:underline">Ver na tabela</button>
              {:else}
                {motivo(d, redes)}
              {/if}
            </p>
            {#if d.uf && (!jaPorteRegiao || !jaNaUf)}
              <div class="flex flex-wrap gap-2">
                {#if d.regiao && d.porte && !jaPorteRegiao}
                  <button type="button" onclick={compararPorteRegiao} data-testid="sugerir-porte-regiao"
                    class="px-2 py-1 text-xs rounded-md border border-blue-700 text-blue-700 hover:bg-white">
                    Comparar com os de mesmo porte no {rotuloRegiao(d.regiao)}
                  </button>
                {/if}
                {#if !jaNaUf}
                  <button type="button" onclick={compararNaUf} data-testid="sugerir-uf"
                    class="px-2 py-1 text-xs rounded-md border border-blue-700 text-blue-700 hover:bg-white">
                    Comparar na UF ({d.uf})
                  </button>
                {/if}
              </div>
            {/if}
          </div>
        {/if}
        <div class="flex flex-wrap items-start justify-between gap-3">
          <p class="text-xs text-gray-600 max-w-3xl" data-testid="nota-redes">
            Valor da rede = <strong>média simples das escolas municipais</strong> com {redes.indicador.label} em {redes.ano}
            (não é o IDEB oficial da rede, calculado pelo INEP). Variação: diferença para {redes.ano_anterior ?? "a edição anterior"}.
            {#if semVariacao > 0}
              <span data-testid="sem-variacao">
                <strong>{semVariacao.toLocaleString("pt-BR")} {semVariacao === 1 ? "rede sem variação" : "redes sem variação"}</strong>:
                {#if redes.ano_anterior}
                  tinham menos de {redes.minimo_escolas} escolas com dado em {redes.ano_anterior} (o mesmo mínimo do ranking).
                {:else}
                  sem edição anterior para comparar.
                {/if}
              </span>
            {/if}
            Entram as redes com pelo menos {redes.minimo_escolas} escolas com dado: {redes.total} redes;
            {redes.fora_por_poucas_escolas} ficaram de fora por terem menos escolas.
            "INSE parecido" = municípios do mesmo quinto de nível socioeconômico no recorte.
            Porte: população estimada pelo IBGE{redes.populacao_fonte?.ano ? ` (${redes.populacao_fonte.ano})` : ""}, nas classes de tamanho do IBGE.
            {#if redes.recorte?.regiao}
              Só as redes da região {redes.recorte.regiao.nome ?? rotuloRegiao(redes.recorte.regiao.id)}: a posição, o INSE parecido e o salto atípico comparam só redes da região.
            {/if}
            {#if porte}
              Só as redes de municípios com {rotuloPorte(porte).replace(" hab.", " habitantes").toLowerCase()}: a posição, o INSE parecido e o salto atípico comparam só redes desse porte.
            {/if}
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
                <th class="px-2 py-2 font-medium text-right">População</th>
                <th class="px-2 py-2 font-medium">Contexto</th>
              </tr>
            </thead>
            <tbody>
              {#each redesOrdenadas as r (r.codigo_ibge)}
                <tr id="rede-{r.codigo_ibge}"
                  class="border-b border-gray-50 {d && r.codigo_ibge === d.codigo_ibge ? 'bg-yellow-50 font-semibold' : ''}"
                  data-testid={d && r.codigo_ibge === d.codigo_ibge ? "linha-destaque" : undefined}
                  aria-current={d && r.codigo_ibge === d.codigo_ibge ? "true" : undefined}>
                  <td class="px-2 py-1.5 text-gray-500">{ordem === "variacao" ? (r.posicao_variacao ?? "–") : r.posicao}</td>
                  <td class="px-2 py-1.5">
                    <a href="/municipio/compare?codigo_ibge={r.codigo_ibge}" class="text-blue-700 hover:underline">{r.municipio}</a>
                    {#if multiUf}<span class="text-gray-400"> · {r.uf}</span>{/if}
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
                  <td class="px-2 py-1.5 text-right whitespace-nowrap" title={rotuloPorte(r.porte)}>{num(r.populacao, 0)}</td>
                  <td class="px-2 py-1.5 text-xs text-gray-600">{contexto(r)}</td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
        {#if redes.total === 0}
          <p class="text-sm text-gray-500" data-testid="redes-vazio">Nenhuma rede neste recorte. Tente outro porte ou um mínimo de escolas menor.</p>
        {/if}
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
            {#if escolas.indicador.metodo}
              <span class="block mt-1" data-testid="metodo-indicador"><strong>Como se calcula{#if escolas.indicador.versao}{" "}(<span data-testid="versao-indicador">{escolas.indicador.versao}</span>, de {dataBR(escolas.indicador.versao_data)}){/if}:</strong> {escolas.indicador.metodo}
                Veja <a href="/fontes" class="text-blue-700 hover:underline">Fontes e metodologia</a>.</span>
            {/if}
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
                {#if escolas.indicador.maximo}<th class="px-2 py-2 font-medium">Falta</th>{/if}
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
                  <td class="px-2 py-1.5 text-right font-medium whitespace-nowrap">
                    {escolas.indicador.maximo ? `${num(e.valor, 0)} de ${escolas.indicador.maximo}` : num(e.valor)}
                  </td>
                  {#if escolas.indicador.maximo}
                    <td class="px-2 py-1.5 text-gray-700" data-testid="faltam">{e.faltam?.length ? e.faltam.join(", ") : "–"}</td>
                  {/if}
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
