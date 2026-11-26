<script>
  // src/features/base-analise/pages/BaseAnalisePage.svelte
  //
  // Base de análise (#439, RV-02): uma linha por escola em funcionamento, com
  // os blocos de indicadores escolhidos, a versão dos dados e um dicionário
  // das colunas. Pública, uma UF por vez. A URL guarda o recorte e os blocos.
  import { fraseFechamento } from "../utils/fechamentoFolha.js";
  import { onMount } from "svelte";
  import { ApiError } from "@/shared/api/client.js";
  import InputAutocomplete from "@/shared/ui/components/InputAutocomplete.svelte";
  import { fetchMunicipioSuggestions } from "@/features/network-compare/api/networkCompareApi.js";
  import { ufDoMunicipio } from "@/features/ranking-recorte/constants.js";
  import FonteDado from "@/features/fontes/components/FonteDado.svelte";
  import { urlPisoPagina } from "@/features/schools/api/pisoApi.js";   // #601
  import { textoAnoFolha, textoSalarioRede, textoPisoRede } from "@/features/fontes/utils.js";
  import { getBaseAnalise, baseCsvUrl, dicionarioUrl, folhaMunicipiosUrl, FOLHA_MUNICIPIOS_DICIONARIO_URL } from "../api/baseAnaliseApi.js";

  const inicial = new URLSearchParams(window.location.search);

  let catalogo = $state(null);
  let uf = $state(/^[A-Z]{2}$/.test(inicial.get("uf") ?? "") ? inicial.get("uf") : "");
  let codigoIbge = $state(/^\d{7}$/.test(inicial.get("codigo_ibge") ?? "") ? inicial.get("codigo_ibge") : "");
  let municipioTexto = $state("");
  let rede = $state(inicial.get("rede") ?? "");
  let blocos = $state((inicial.get("blocos") ?? "").split(",").filter(Boolean));
  let anoIdeb = $state(Number(inicial.get("ano_ideb")) || null);
  let anoSiope = $state(Number(inicial.get("ano_siope")) || null);
  // #512 (QZ-01): a folha da UF (municípios, anos, meses e escolas) e as
  // escolas do recorte com folha em cada ano. O ano segue o padrão da UF até
  // a pessoa escolher um no seletor (ou vir na URL).
  let folha = $state(null);
  let anoSiopeEscolhido = $state(!!Number(inicial.get("ano_siope")));
  let total = $state(null);
  let contando = $state(false);
  let error = $state(null);

  const filtros = $derived({ uf, codigoIbge, rede, blocos, anoIdeb, anoSiope });
  const escolhidos = $derived(catalogo ? catalogo.blocos.filter((b) => b.fixo || blocos.includes(b.id)) : []);
  const nColunas = $derived(escolhidos.reduce((n, b) => n + b.colunas.length, 0));
  const temEtapas = $derived(!!catalogo && catalogo.blocos.some((b) => b.id === "etapas"));
  // #444 (BA-01): edição antiga do IDEB cruzada com o Censo mais recente.
  const folhaRecorte = $derived(folha && anoSiope ? (folha.escolas?.[anoSiope] ?? 0) : null);
  // #554 (QS-02 da P5): de onde vem o total declarado, por município do
  // recorte (só o município escolhido, se houver um).
  const fechamentos = $derived(
    folha && anoSiope
      ? folha.municipios
          .filter((m) => !codigoIbge || m.codigo_ibge === codigoIbge)
          .map((m) => fraseFechamento(m, anoSiope, catalogo?.anos?.censo))
          .filter(Boolean)
      : [],
  );
  // #571 (QI-01 da P3): o salário do magistério da rede, por município do recorte
  const salariosRede = $derived(
    folha && anoSiope
      ? folha.municipios
          .filter((m) => !codigoIbge || m.codigo_ibge === codigoIbge)
          .map((m) => ({ municipio: m.municipio, codigo_ibge: m.codigo_ibge, s: m.anos.find((a) => a.ano === anoSiope)?.salario_magisterio }))
          .filter((x) => x.s?.pessoas)
      : [],
  );
  const anosFolhaUf = $derived(
    folha ? [...new Set(folha.municipios.flatMap((m) => m.anos.filter((a) => a.escolas > 0).map((a) => a.ano)))].sort((a, b) => b - a) : [],
  );
  // #514 (QY-01): o aviso vale sempre que o IDEB e o Censo forem de anos
  // diferentes, inclusive na edição mais recente (2023 contra o Censo 2025).
  const censoDifere = $derived(
    !!catalogo && blocos.includes("desempenho") && anoIdeb != null && catalogo.anos.censo != null
      && anoIdeb !== catalogo.anos.censo,
  );
  // #583 (QF-01 da P4): a folha do SIOPE de outro ano que o IDEB também avisa
  const folhaDifere = $derived(
    !!catalogo && blocos.includes("desempenho") && blocos.includes("remuneracao")
      && anoIdeb != null && anoSiope != null && Number(anoSiope) !== anoIdeb,
  );
  const anosDiferentes = $derived(censoDifere || folhaDifere);
  const distanciaFolha = $derived(anoIdeb && anoSiope ? Math.abs(Number(anoSiope) - anoIdeb) : 0);
  const distanciaAnos = $derived(catalogo && anoIdeb ? Math.abs(catalogo.anos.censo - anoIdeb) : 0);
  const EXTENSO = { 1: "um ano", 2: "dois anos", 3: "três anos", 4: "quatro anos" };

  function definirUrl() {
    const p = new URLSearchParams();
    if (uf) p.set("uf", uf);
    if (codigoIbge) p.set("codigo_ibge", codigoIbge);
    if (rede) p.set("rede", rede);
    if (blocos.length) p.set("blocos", blocos.join(","));
    if (anoIdeb && blocos.includes("desempenho")) p.set("ano_ideb", String(anoIdeb));
    if (anoSiope && blocos.includes("remuneracao")) p.set("ano_siope", String(anoSiope));
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
      aplicarFolha(r.folha);
    } catch (err) {
      total = null;
      error = err instanceof ApiError ? err.message : "Não foi possível contar as escolas do recorte.";
    } finally {
      contando = false;
    }
  }

  function aplicarFolha(f) {
    folha = f ?? null;
    if (!anoSiopeEscolhido && folha?.padrao && (catalogo?.anos.siope ?? []).includes(folha.padrao)) {
      anoSiope = folha.padrao;
      definirUrl();
    }
  }

  function escolherAnoSiope() {
    anoSiopeEscolhido = true;
    definirUrl();
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
      // #491: sem ano pedido (ou inexistente), o ano completo mais recente.
      if (!(catalogo.anos.siope ?? []).includes(anoSiope)) {
        anoSiope = catalogo.anos.siope_padrao ?? null;
        anoSiopeEscolhido = false;
      }
      aplicarFolha(catalogo.folha);
    } catch (err) {
      error = err instanceof ApiError ? err.message : "Não foi possível carregar a base de análise.";
    }
  });
</script>

{#snippet avisoAnos(testid)}
  <p class="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-md px-3 py-2" role="note" data-testid={testid}>
    {#if censoDifere}
      A lista de escolas, a infraestrutura e a docência são do Censo {catalogo.anos.censo}; o IDEB é de {anoIdeb}
      ({EXTENSO[distanciaAnos] ?? `${distanciaAnos} anos`} {catalogo.anos.censo > anoIdeb ? "antes" : "depois"}).
      {#if catalogo.anos.censo > anoIdeb}
        Escolas fechadas depois de {anoIdeb} não entram, e num modelo o que vem do Censo foi medido depois do IDEB.
      {/if}
    {/if}
    {#if folhaDifere}
      <span data-testid="aviso-anos-folha">A folha do SIOPE é de {anoSiope}, {EXTENSO[distanciaFolha] ?? `${distanciaFolha} anos`}
      {Number(anoSiope) > anoIdeb ? "depois" : "antes"} do IDEB ({anoIdeb}): num modelo, o salário e o gasto são de outro ano que o desempenho.</span>
    {/if}
    {#if blocos.includes("inse") && catalogo.anos.inse}
      O INSE é da edição {catalogo.anos.inse} do SAEB{catalogo.anos.inse === anoIdeb ? ", a mesma do IDEB" : `, diferente da do IDEB (${anoIdeb})`}.
    {/if}
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
                {#if anosDiferentes}<div class="mt-2">{@render avisoAnos("aviso-anos")}</div>{/if}
                {#if temEtapas && !blocos.includes("etapas")}
                  <!-- #461 (RX-02): o vazio do IDEB mistura "não oferece" e "não teve nota". -->
                  <p class="mt-2 text-xs text-gray-700 bg-blue-50 border border-blue-200 rounded-md px-3 py-2" data-testid="dica-etapas">
                    O IDEB vazio mistura "não oferece a etapa" e "não teve nota", e a nota falta sobretudo nas escolas pequenas, rurais e sem infraestrutura.
                    <button type="button" class="text-blue-700 hover:underline" onclick={() => alternarBloco("etapas")}>Marcar também as etapas oferecidas</button>
                  </p>
                {/if}
              </div>
            {/if}
            {#if b.id === "remuneracao" && blocos.includes("remuneracao")}
              <div class="ml-6 mt-2">
                {#if (catalogo.anos.siope ?? []).length}
                  <label for="ano-siope" class="text-sm text-gray-600 mr-2">Ano da folha (SIOPE)</label>
                  <select id="ano-siope" bind:value={anoSiope} onchange={escolherAnoSiope}
                    class="border border-gray-300 rounded-md px-2 py-1 text-sm">
                    {#each catalogo.anos.siope as a}<option value={a}>{a}</option>{/each}
                  </select>
                {/if}
                {#if folha}
                  <!-- #512 (QZ-01): quem tem folha nesta UF, e quantas escolas do recorte no ano -->
                  <p class="mt-2 text-xs text-gray-700" data-testid="cobertura-siope">
                    {#if folha.municipios.length}
                      Folha por escola em {uf}:
                      {#each folha.municipios as m, i}{i ? "; " : ""}<strong>{m.municipio}</strong> ({m.anos.map((a) => `${a.ano}: ${textoAnoFolha(a)}`).join("; ")}){/each}.
                    {:else}
                      Nenhum município de {uf} tem a folha do SIOPE separada por escola: o bloco sai vazio.
                    {/if}
                  </p>
                  {#if folha.municipios.length && folhaRecorte != null}
                    {#if folhaRecorte > 0}
                      <p class="mt-1 text-xs text-gray-700" data-testid="folha-recorte">
                        {folhaRecorte.toLocaleString("pt-BR")} {folhaRecorte === 1 ? "escola" : "escolas"} deste recorte {folhaRecorte === 1 ? "tem" : "têm"} folha em {anoSiope}.
                      </p>
                    {:else}
                      <p class="mt-1 text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-md px-3 py-2" role="note" data-testid="aviso-folha-vazia">
                        Nenhuma escola deste recorte tem folha em {anoSiope}: a remuneração sai vazia.
                        {#if anosFolhaUf.length}Anos com folha em {uf}: {anosFolhaUf.join(", ")}.{/if}
                      </p>
                    {/if}
                  {/if}
                {/if}
                {#if fechamentos.length}
                  <!-- #554 (QS-02 da P5): a soma das escolas não é o total declarado -->
                  <div class="mt-2 text-xs text-gray-700" data-testid="fechamento-folha">
                    <p>A soma das escolas da base não é o total que o município declara ao SIOPE: falta a folha da Secretaria (sem escola) e a de escolas que a lista do Censo não tem. A divisão por fonte é da folha inteira, com a Secretaria, e não é a verificação do mínimo de 70% exigido em lei.</p>
                    <ul class="list-disc ml-5 mt-1">
                      {#each fechamentos as frase}<li>{frase}</li>{/each}
                    </ul>
                  </div>
                {/if}
                {#if salariosRede.length}
                  <!-- #571 (QI-01 da P3): o salário do magistério da rede inteira -->
                  <div class="mt-2 text-xs text-gray-700" data-testid="salario-rede-base">
                    <p>Magistério na rede municipal em {anoSiope} (toda a folha, nas escolas e no total da Secretaria; sem conversão para 40 horas):</p>
                    <ul class="list-disc ml-5 mt-1">
                      {#each salariosRede as x}<li>{x.municipio}: {textoSalarioRede(x.s)}.{#if textoPisoRede(x.s, anoSiope)}{" "}<span data-testid="piso-rede-base">{textoPisoRede(x.s, anoSiope)}</span>{#if x.s.abaixo_piso > 0}{" "}<a class="text-blue-700 hover:underline" href={urlPisoPagina(x.codigo_ibge, anoSiope)} data-testid="link-lista-piso-base">Ver a lista do ano →</a>{/if}{/if}</li>{/each}
                    </ul>
                  </div>
                {/if}
                {#if folha?.municipios?.length && uf}
                  <!-- #580 (QG-02 da P6): os números por município, num arquivo -->
                  <p class="mt-2 text-xs text-gray-700" data-testid="folha-municipios">
                    <a href={folhaMunicipiosUrl(uf)} class="text-blue-700 hover:underline">Baixar a folha por município de {uf} (CSV)</a>:
                    uma linha por município e ano, com o total declarado e de onde vem, a parte do Fundeb, o salário e o piso da rede e a data da carga.
                    <a href={FOLHA_MUNICIPIOS_DICIONARIO_URL} class="text-blue-700 hover:underline">Dicionário</a>.
                  </p>
                {/if}
                <!-- #491 (RJ-03): a cobertura é pequena e não aleatória. -->
                <p class="mt-2 text-xs text-gray-700 bg-blue-50 border border-blue-200 rounded-md px-3 py-2" data-testid="aviso-siope">
                  Só a rede municipal, e só os municípios em que o SIOPE separa a folha por escola: nas demais escolas a coluna fica vazia.
                  A lista de todos os municípios com folha está em <a href="/fontes" class="text-blue-700 hover:underline">Fontes e metodologia</a>.
                  Na educação infantil, quem está com as crianças pode estar na folha como auxiliar ou assistente educacional, não no magistério: veja as colunas <code>aux_educacional</code>.
                </p>
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
        Censo Escolar {catalogo.anos.censo}{#if blocos.includes("desempenho")}{" · "}IDEB {anoIdeb}{/if}{#if blocos.includes("inse")}{" · "}INSE {catalogo.anos.inse}{/if}{#if blocos.includes("porte") && catalogo.anos.populacao}{" · "}população {catalogo.anos.populacao}{/if}{#if blocos.includes("indices") && catalogo.anos.indices}{" · "}índices {catalogo.anos.indices}{/if}{#if blocos.includes("remuneracao") && anoSiope}{" · "}folha {anoSiope}{/if}.
        Separador ";" e vírgula decimal (abre direto no Excel). Ausência é célula vazia, nunca zero.
      </p>
      {#if anosDiferentes}{@render avisoAnos("aviso-anos-baixar")}{/if}
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
