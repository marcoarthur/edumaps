<!-- src/features/gestor/pages/RelatoriosPage.svelte -->
<script>
  // Assistente de Relatório (issue #219, fase 1). O gestor escolhe o recorte
  // (a própria escola, ou o município/UF/região — o da escola por padrão ou
  // outro pela cascata região → UF → município), o tema do nível e as opções;
  // "Gerar relatório" enfileira o job e a página consulta o estado a cada
  // 1,5 s até finished/failed. O polling para ao desmontar, ao gerar outro e
  // ao trocar nível/recorte/tema.
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao login.
  //
  // Fase 3: o relatório pronto ganha as ações de imprimir, baixar Markdown e
  // salvar (pelo job_id). A página aceita preenchimento por query — `nivel`,
  // `codigo`, `nome`, `tema`, `etapa`, `rede` e `gerar=1` — vindo do "Gerar de
  // novo com os dados atuais" de um relatório salvo: o recorte da query pode
  // ser outro que não o da escola ("Recorte: <nome>", com a opção de trocar) e,
  // com `gerar=1`, a geração dispara uma vez (a query sai da URL em seguida).
  import { onMount, onDestroy } from "svelte";
  import {
    getRecortePadrao,
    listTemasRelatorio,
    gerarRelatorio,
    getJobRelatorio,
    salvarRelatorio,
  } from "../api/gestorRelatoriosApi.js";
  import { getRegions, getUfs, getMunicipalities } from "@/features/cluster-geotag/api/clusterApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    NIVEIS,
    regiaoSigla,
    codigoMunicipio,
    valoresOpcao,
  } from "../utils/relatorioFormatos.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import RelatorioView from "../components/relatorios/RelatorioView.svelte";

  const INTERVALO_POLLING_MS = 1500;

  const ROTULO_OPCAO = { etapa: "Etapa", rede: "Rede" };
  // opções sem valor vazio (o R usa um default); as demais aceitam "todas"
  const OPCOES_OBRIGATORIAS = new Set(["etapa"]);

  // Uma opção é obrigatória quando o tema declara um padrão para ela
  // (`padroes`, vindo do catálogo do R); sem padrão, oferece "Todas". Sem o
  // campo `padroes` (catálogo antigo), vale a regra fixa (etapa obrigatória).
  function opcaoObrigatoria(t, chave) {
    if (t && t.padroes && typeof t.padroes === "object") return chave in t.padroes;
    return OPCOES_OBRIGATORIAS.has(chave);
  }
  // Formato do `codigo` por nível (o mesmo do geotag do contrato).
  const CODIGO_RE = {
    municipio: /^\d{7}$/,
    uf: /^[A-Z]{2}$/,
    regiao: /^(N|NE|SE|S|CO)$/,
  };

  /** Lê o preenchimento por query (uma vez, na montagem). */
  function lerQuery() {
    const q = new URLSearchParams(window.location.search);
    const nivelQ = q.get("nivel");
    if (!NIVEIS.some((n) => n.valor === nivelQ)) return null;
    const opcoesQ = {};
    for (const [k, v] of q.entries()) {
      if (!["nivel", "codigo", "nome", "tema", "gerar"].includes(k)) opcoesQ[k] = v;
    }
    const codigoQ = q.get("codigo") ?? "";
    return {
      nivel: nivelQ,
      codigo: CODIGO_RE[nivelQ]?.test(codigoQ) ? codigoQ : null,
      nome: q.get("nome") || null,
      tema: q.get("tema") || null,
      opcoes: opcoesQ,
      gerar: q.get("gerar") === "1",
    };
  }

  function valorInicialOpcao(t, chave, valores) {
    if (!opcaoObrigatoria(t, chave)) return "";
    const padrao = t?.padroes?.[chave];
    return valores.some((v) => v.valor === padrao) ? padrao : valores[0].valor;
  }

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let padrao = $state(null);
  let nivel = $state("municipio");
  let origem = $state("padrao"); // "padrao" | "outro" | "query"
  let recorteQuery = $state(null); // {nivel, codigo, nome} vindo da query

  let regioes = $state([]);
  let ufs = $state([]);
  let municipios = $state([]);
  let selRegiao = $state("");
  let selUf = $state("");
  let selMunicipio = $state("");
  let erroCascata = $state(null);

  let temas = $state([]);
  let carregandoTemas = $state(false);
  let erroTemas = $state(null);
  let temaId = $state("");
  let opcoes = $state({});

  let gerando = $state(false);
  let estadoJob = $state(null);
  let progresso = $state(null);
  let erroGerar = $state(null);
  let relatorio = $state(null);
  let relatorioJobId = $state(null); // job que gerou o relatório exibido (para salvar)

  let queryPendente = lerQuery();

  let timer = null;
  let jobAtual = null;
  let consultando = false;
  let destruido = false;
  let pedidoTemas = 0;

  const tema = $derived(temas.find((t) => t.id === temaId) ?? null);
  const opcoesTema = $derived(
    Object.entries(tema?.opcoes ?? {})
      .map(([chave, lista]) => ({ chave, valores: valoresOpcao(lista) }))
      .filter((o) => o.valores.length > 0),
  );

  const geotag = $derived.by(() => {
    if (!padrao) return null;
    if (nivel === "escola") {
      return { nivel, codigo: String(padrao.escola?.cod_inep ?? inep), nome: padrao.escola?.nome };
    }
    if (origem === "query") {
      return recorteQuery?.nivel === nivel ? { ...recorteQuery } : null;
    }
    if (origem === "padrao") {
      const p = padrao[nivel];
      return p?.codigo ? { nivel, codigo: String(p.codigo), nome: p.nome } : null;
    }
    if (nivel === "regiao") {
      const r = regioes.find((x) => String(x.co_regiao) === selRegiao);
      return r ? { nivel, codigo: regiaoSigla(r.co_regiao), nome: r.no_regiao } : null;
    }
    if (nivel === "uf") {
      const u = ufs.find((x) => String(x.co_uf) === selUf);
      return u ? { nivel, codigo: u.sg_uf, nome: u.no_uf } : null;
    }
    const m = municipios.find((x) => String(x.co_municipio) === selMunicipio);
    return m ? { nivel, codigo: codigoMunicipio(m.co_municipio), nome: m.no_municipio } : null;
  });

  const podeGerar = $derived(!!geotag?.codigo && !!tema && !gerando);

  const onApiError = (err, padraoMsg) => {
    if (err instanceof ApiError && err.status === 401) {
      pararPolling();
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padraoMsg;
  };

  // ------------------------------------------------------------- carga

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    let gerarAgora = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      padrao = await getRecortePadrao(inep);
      const q = queryPendente;
      if (q) aplicarRecorteDaQuery(q);
      await carregarTemas();
      if (q) {
        aplicarTemaDaQuery(q);
        queryPendente = null;
        gerarAgora = q.gerar;
        limparQueryDaUrl();
      }
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar o Assistente de Relatório.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
    if (gerarAgora && !error && !precisaLogin) gerar();
  }

  // ------------------------------------------------------------- query

  function aplicarRecorteDaQuery(q) {
    nivel = q.nivel;
    if (nivel === "escola" || !q.codigo) {
      origem = "padrao";
      return;
    }
    // o mesmo recorte da escola: fica como "Da minha escola"
    if (String(padrao?.[nivel]?.codigo ?? "") === q.codigo) {
      origem = "padrao";
      return;
    }
    recorteQuery = { nivel, codigo: q.codigo, nome: q.nome ?? q.codigo };
    origem = "query";
  }

  function aplicarTemaDaQuery(q) {
    if (!q.tema || !temas.some((t) => t.id === q.tema)) return;
    escolherTema(q.tema);
    const t = temas.find((x) => x.id === q.tema);
    const novas = { ...opcoes };
    for (const [chave, lista] of Object.entries(t?.opcoes ?? {})) {
      if (!(chave in q.opcoes)) continue;
      const v = q.opcoes[chave];
      const valido = v === "" ? !opcaoObrigatoria(t, chave) : valoresOpcao(lista).some((x) => x.valor === v);
      if (valido) novas[chave] = v;
    }
    opcoes = novas;
  }

  function limparQueryDaUrl() {
    if (window.location.search) {
      window.history.replaceState(window.history.state, "", window.location.pathname);
    }
  }

  function trocarRecorteDaQuery() {
    cancelarJob();
    recorteQuery = null;
    origem = "padrao";
  }

  async function carregarTemas() {
    const pedido = ++pedidoTemas;
    carregandoTemas = true;
    erroTemas = null;
    try {
      const lista = await listTemasRelatorio(inep, nivel);
      if (pedido !== pedidoTemas) return;
      temas = lista;
      if (!lista.some((t) => t.id === temaId)) escolherTema(lista[0]?.id ?? "");
    } catch (err) {
      if (pedido !== pedidoTemas) return;
      temas = [];
      escolherTema("");
      const msg = onApiError(err, "Não foi possível carregar os temas.");
      if (msg) erroTemas = msg;
    } finally {
      if (pedido === pedidoTemas) carregandoTemas = false;
    }
  }

  function escolherTema(id) {
    cancelarJob();
    temaId = id;
    const t = temas.find((x) => x.id === id);
    const novas = {};
    for (const [chave, lista] of Object.entries(t?.opcoes ?? {})) {
      const valores = valoresOpcao(lista);
      if (!valores.length) continue;
      novas[chave] = valorInicialOpcao(t, chave, valores);
    }
    opcoes = novas;
  }

  // ------------------------------------------------------------- recorte

  async function trocarNivel(novo) {
    if (novo === nivel) return;
    cancelarJob();
    nivel = novo;
    if (nivel === "escola" || origem === "query") origem = "padrao";
    recorteQuery = null;
    await Promise.all([carregarTemas(), garantirCascata()]);
  }

  async function trocarOrigem(nova) {
    cancelarJob();
    origem = nova;
    await garantirCascata();
  }

  async function chamarCascata(fn) {
    erroCascata = null;
    try {
      return await fn();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a lista de locais.");
      if (msg) erroCascata = msg;
      return null;
    }
  }

  /** Carrega o que falta da cascata para o nível atual. */
  async function garantirCascata() {
    if (origem !== "outro" || nivel === "escola") return;
    if (!regioes.length) regioes = (await chamarCascata(getRegions)) ?? [];
    if ((nivel === "uf" || nivel === "municipio") && selRegiao && !ufs.length) {
      ufs = (await chamarCascata(() => getUfs(selRegiao))) ?? [];
    }
    if (nivel === "municipio" && selUf && !municipios.length) {
      municipios = (await chamarCascata(() => getMunicipalities(selUf))) ?? [];
    }
  }

  async function trocarRegiao(valor) {
    cancelarJob();
    selRegiao = valor;
    selUf = "";
    selMunicipio = "";
    ufs = [];
    municipios = [];
    await garantirCascata();
  }

  async function trocarUf(valor) {
    cancelarJob();
    selUf = valor;
    selMunicipio = "";
    municipios = [];
    await garantirCascata();
  }

  function trocarMunicipio(valor) {
    cancelarJob();
    selMunicipio = valor;
  }

  // ------------------------------------------------------------- geração

  function pararPolling() {
    if (timer) clearInterval(timer);
    timer = null;
    jobAtual = null;
  }

  function cancelarJob() {
    pararPolling();
    gerando = false;
    estadoJob = null;
    progresso = null;
  }

  async function consultar(jobId) {
    if (consultando || jobAtual !== jobId) return;
    consultando = true;
    try {
      const job = await getJobRelatorio(inep, jobId);
      if (jobAtual !== jobId) return;
      estadoJob = job?.state ?? null;
      progresso = job?.progress ?? null;
      if (job?.state === "finished") {
        relatorio = job.result ?? null;
        relatorioJobId = relatorio ? jobId : null;
        cancelarJob();
      } else if (job?.state === "failed") {
        erroGerar = job.error || "Não foi possível gerar o relatório.";
        cancelarJob();
      }
    } catch (err) {
      if (jobAtual !== jobId) return;
      cancelarJob();
      const msg = onApiError(err, "Não foi possível acompanhar a geração do relatório.");
      if (msg) erroGerar = msg;
    } finally {
      consultando = false;
    }
  }

  async function gerar() {
    if (!podeGerar) return;
    cancelarJob();
    erroGerar = null;
    relatorio = null;
    relatorioJobId = null;
    gerando = true;
    estadoJob = "inactive";
    try {
      const { job_id } = await gerarRelatorio(inep, {
        geotag: { nivel: geotag.nivel, codigo: geotag.codigo },
        tema: temaId,
        opcoes,
      });
      if (destruido || !gerando) return;
      jobAtual = job_id;
      timer = setInterval(() => consultar(job_id), INTERVALO_POLLING_MS);
    } catch (err) {
      cancelarJob();
      const msg = onApiError(err, "Não foi possível gerar o relatório.");
      if (msg) erroGerar = msg;
    }
  }

  function salvarAtual() {
    return salvarRelatorio(inep, relatorioJobId);
  }

  // ------------------------------------------------------------- sessão

  async function sair() {
    cancelarJob();
    try {
      await logoutGestor();
    } finally {
      clearSessaoToken();
      gestor = null;
      precisaLogin = true;
    }
  }

  function onLogin(sessao) {
    setSessaoToken(sessao?.token);
    restaurarSessao();
    carregarTudo();
  }

  onMount(() => {
    restaurarSessao();
    carregarTudo();
  });

  onDestroy(() => {
    destruido = true;
    pararPolling();
  });

  const ESTADO_JOB = {
    inactive: "Na fila para gerar…",
    active: "Gerando o relatório…",
  };
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3 print:hidden">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Relatórios</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}relatórios sobre a escola e o território, a partir dos dados públicos.
      </p>
    </div>
    <div class="flex flex-wrap items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      {/if}
      <a
        href="/gestor/relatorios/salvos"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Meus relatórios</a>
      <a
        href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando o Assistente de Relatório…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerar relatórios." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{error}</div>
  {:else if padrao}
    <form
      class="bg-white border border-gray-200 rounded-card shadow-card p-5 space-y-5 print:hidden"
      onsubmit={(e) => {
        e.preventDefault();
        gerar();
      }}
      data-testid="relatorio-form"
    >
      <fieldset class="space-y-2">
        <legend class="text-sm font-semibold text-gray-900">Recorte</legend>
        <div class="flex flex-wrap gap-2" role="radiogroup" aria-label="Nível do recorte">
          {#each NIVEIS as n (n.valor)}
            <label
              class="px-3 py-1.5 rounded-md border text-sm cursor-pointer"
              class:bg-blue-50={nivel === n.valor}
              class:border-blue-400={nivel === n.valor}
              class:border-gray-300={nivel !== n.valor}
            >
              <input
                type="radio"
                name="nivel"
                value={n.valor}
                checked={nivel === n.valor}
                onchange={() => trocarNivel(n.valor)}
                class="mr-1"
              />{n.rotulo}
            </label>
          {/each}
        </div>

        {#if nivel === "escola"}
          <p class="text-sm text-gray-600" data-testid="recorte-atual">
            {padrao.escola?.nome} (INEP {padrao.escola?.cod_inep})
          </p>
        {:else if origem === "query"}
          <p class="text-sm text-gray-700 flex flex-wrap items-center gap-2" data-testid="recorte-query">
            <span>Recorte: <strong>{recorteQuery?.nome ?? recorteQuery?.codigo}</strong></span>
            <button
              type="button"
              onclick={trocarRecorteDaQuery}
              class="text-sm text-blue-700 hover:underline"
            >Trocar recorte</button>
          </p>
        {:else}
          <div class="flex flex-wrap gap-4 text-sm">
            <label class="flex items-center gap-1">
              <input
                type="radio"
                name="origem"
                value="padrao"
                checked={origem === "padrao"}
                onchange={() => trocarOrigem("padrao")}
              />
              Da minha escola{#if padrao[nivel]?.nome}: <strong>{padrao[nivel].nome}</strong>{/if}
            </label>
            <label class="flex items-center gap-1">
              <input
                type="radio"
                name="origem"
                value="outro"
                checked={origem === "outro"}
                onchange={() => trocarOrigem("outro")}
              />
              Escolher outro
            </label>
          </div>

          {#if origem === "outro"}
            <div class="grid gap-3 sm:grid-cols-3" data-testid="cascata">
              <label class="text-sm text-gray-700 space-y-1">
                <span class="block font-medium">Região</span>
                <select
                  class="w-full rounded-md border border-gray-300 px-2 py-1.5"
                  value={selRegiao}
                  onchange={(e) => trocarRegiao(e.currentTarget.value)}
                >
                  <option value="">Selecione…</option>
                  {#each regioes as r (r.co_regiao)}
                    <option value={String(r.co_regiao)}>{r.no_regiao}</option>
                  {/each}
                </select>
              </label>
              {#if nivel === "uf" || nivel === "municipio"}
                <label class="text-sm text-gray-700 space-y-1">
                  <span class="block font-medium">Estado (UF)</span>
                  <select
                    class="w-full rounded-md border border-gray-300 px-2 py-1.5"
                    value={selUf}
                    disabled={!selRegiao}
                    onchange={(e) => trocarUf(e.currentTarget.value)}
                  >
                    <option value="">Selecione…</option>
                    {#each ufs as u (u.co_uf)}
                      <option value={String(u.co_uf)}>{u.no_uf} ({u.sg_uf})</option>
                    {/each}
                  </select>
                </label>
              {/if}
              {#if nivel === "municipio"}
                <label class="text-sm text-gray-700 space-y-1">
                  <span class="block font-medium">Município</span>
                  <select
                    class="w-full rounded-md border border-gray-300 px-2 py-1.5"
                    value={selMunicipio}
                    disabled={!selUf}
                    onchange={(e) => trocarMunicipio(e.currentTarget.value)}
                  >
                    <option value="">Selecione…</option>
                    {#each municipios as m (m.co_municipio)}
                      <option value={String(m.co_municipio)}>{m.no_municipio}</option>
                    {/each}
                  </select>
                </label>
              {/if}
            </div>
            {#if erroCascata}
              <p class="text-sm text-red-700" role="alert">{erroCascata}</p>
            {/if}
          {/if}
        {/if}
      </fieldset>

      <fieldset class="space-y-2">
        <legend class="text-sm font-semibold text-gray-900">Tema</legend>
        {#if carregandoTemas}
          <p class="text-sm text-gray-500">Carregando temas…</p>
        {:else if erroTemas}
          <p class="text-sm text-red-700" role="alert">{erroTemas}</p>
        {:else if temas.length === 0}
          <p class="text-sm text-gray-500">Nenhum tema disponível para este nível.</p>
        {:else}
          <ul class="space-y-2" data-testid="temas">
            {#each temas as t (t.id)}
              <li>
                <label class="flex items-start gap-2 text-sm cursor-pointer">
                  <input
                    type="radio"
                    name="tema"
                    value={t.id}
                    checked={temaId === t.id}
                    onchange={() => escolherTema(t.id)}
                    aria-describedby="tema-desc-{t.id}"
                    class="mt-1"
                  />
                  <span>
                    <span class="font-medium text-gray-900">{t.titulo}</span>
                    {#if t.profundidade === "profunda"}
                      {" "}<span
                        class="ml-1 inline-block align-middle text-[11px] px-1.5 py-0.5 rounded-full bg-violet-50 text-violet-700 border border-violet-200"
                        data-testid="selo-profunda"
                      >Análise aprofundada</span>
                    {/if}
                    {#if t.descricao}
                      <span id="tema-desc-{t.id}" class="block text-gray-500">{t.descricao}</span>
                    {/if}
                  </span>
                </label>
              </li>
            {/each}
          </ul>
        {/if}
      </fieldset>

      {#if opcoesTema.length}
        <div class="grid gap-3 sm:grid-cols-3" data-testid="opcoes-tema">
          {#each opcoesTema as o (o.chave)}
            <label class="text-sm text-gray-700 space-y-1">
              <span class="block font-medium">{ROTULO_OPCAO[o.chave] ?? o.chave}</span>
              <select
                class="w-full rounded-md border border-gray-300 px-2 py-1.5"
                bind:value={opcoes[o.chave]}
                onchange={() => cancelarJob()}
              >
                {#if !opcaoObrigatoria(tema, o.chave)}
                  <option value="">{o.chave === "etapa" ? "Todas as etapas" : "Todas"}</option>
                {/if}
                {#each o.valores as v (v.valor)}
                  <option value={v.valor}>{v.rotulo}</option>
                {/each}
              </select>
            </label>
          {/each}
        </div>
      {/if}

      <div class="flex flex-wrap items-center gap-3">
        <button
          type="submit"
          disabled={!podeGerar}
          class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >Gerar relatório</button>
        {#if geotag}
          <span class="text-xs text-gray-500" data-testid="geotag-resumo">
            {geotag.nome ?? geotag.codigo}
          </span>
        {/if}
      </div>

      <div aria-live="polite">
        {#if gerando}
          <p class="text-sm text-gray-600" role="status" data-testid="job-estado">
            {ESTADO_JOB[estadoJob] ?? "Gerando o relatório…"}{#if progresso} ({progresso}%){/if}
          </p>
        {/if}
      </div>
      {#if erroGerar}
        <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-3" role="alert" data-testid="erro-gerar">
          {erroGerar}
        </div>
      {/if}
    </form>

    {#if relatorio}
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5 print:border-0 print:shadow-none print:p-0">
        {#key relatorioJobId}
          <RelatorioView {relatorio} acoes onSalvar={relatorioJobId ? salvarAtual : null} />
        {/key}
      </div>
    {/if}
  {/if}
</div>
