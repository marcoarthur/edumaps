<!-- src/features/gestor/pages/EnviosPage.svelte -->
<script>
  // Envios por e-mail para as listas da escola (issue #216, Fase 3, onda 1).
  // Painel de limites (saldo do dia, cota, suspensão, SMTP), lista de envios
  // com selo de estado, contadores e datas; "Novo envio" abre o editor de
  // rascunho; um envio já disparado abre o detalhe (contadores ao vivo).
  // Query aceita: `?novo=1&alvo_tipo=lista&alvo_id=N` (abre o editor com o
  // alvo preenchido — ação "Enviar e-mail" da ListasPage) e `?id=N`.
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao login.
  import { onMount } from "svelte";
  import { listEnvios, getEnvio, getLimitesEnvio, listSegmentos } from "../api/gestorEnviosApi.js";
  import { listListas } from "../api/gestorCanaisApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import EnvioSelo from "../components/envios/EnvioSelo.svelte";
  import LimitesPainel from "../components/envios/LimitesPainel.svelte";
  import EnvioEditor from "../components/envios/EnvioEditor.svelte";
  import EnvioDetalhe from "../components/envios/EnvioDetalhe.svelte";
  import { ESTADOS_ENVIO, rotuloOperacao, formatarDataHora } from "../constants/envios.js";

  const POR_PAGINA = 20;

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let limites = $state(null);
  let envios = $state({ items: [], total: 0, page: 1, per_page: POR_PAGINA });
  let filtroStatus = $state("");
  let pagina = $state(1);
  let listas = $state([]);
  let segmentos = $state([]);

  // modo da página: lista | editor | detalhe
  let modo = $state("lista");
  let editando = $state(null); // envio (rascunho completo) ou null para novo
  let alvoInicial = $state(null);
  let detalheId = $state(null);
  let editorKey = $state(0);

  const totalPaginas = $derived(
    Math.max(1, Math.ceil((envios.total ?? 0) / (envios.per_page || POR_PAGINA))),
  );

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  const sessaoExpirada = () => {
    precisaLogin = true;
    modo = "lista";
  };

  async function carregarEnvios() {
    try {
      envios = await listEnvios(inep, {
        status: filtroStatus || undefined,
        page: pagina,
        per_page: POR_PAGINA,
      });
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os envios.");
      if (msg) addToast(msg, "error");
    }
  }

  async function carregarLimites() {
    try {
      limites = await getLimitesEnvio(inep);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os limites de envio.");
      if (msg) addToast(msg, "error");
    }
  }

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const [lims, pagina1, ls, segs] = await Promise.all([
        getLimitesEnvio(inep),
        listEnvios(inep, { page: 1, per_page: POR_PAGINA }),
        listListas(inep).catch(() => []),
        listSegmentos(inep).catch(() => []),
      ]);
      limites = lims;
      envios = pagina1;
      listas = ls;
      segmentos = segs;
      await aplicarQuery();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os envios.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function aplicarQuery() {
    const params = new URLSearchParams(window.location.search);
    const id = Number(params.get("id"));
    if (id) {
      await abrirEnvio({ id, status: null });
      return;
    }
    if (params.get("novo")) {
      const tipo = params.get("alvo_tipo");
      const alvoId = Number(params.get("alvo_id"));
      novoEnvio(
        ["lista", "segmento"].includes(tipo) && alvoId ? { tipo, id: alvoId } : null,
      );
    }
  }

  function novoEnvio(alvo = null) {
    editando = null;
    alvoInicial = alvo;
    editorKey += 1;
    modo = "editor";
  }

  async function abrirEnvio(item) {
    if (item.status && item.status !== "rascunho") {
      detalheId = item.id;
      modo = "detalhe";
      return;
    }
    // rascunho: a listagem não traz o corpo, busca o envio completo
    try {
      const completo = await getEnvio(inep, item.id);
      if (completo.status === "rascunho") {
        editando = completo;
        alvoInicial = null;
        editorKey += 1;
        modo = "editor";
      } else {
        detalheId = completo.id;
        modo = "detalhe";
      }
    } catch (err) {
      const msg = onApiError(err, "Não foi possível abrir o envio.");
      if (msg) addToast(msg, "error");
    }
  }

  function voltarLista() {
    modo = "lista";
    editando = null;
    detalheId = null;
    if (window.location.search) window.history.replaceState({}, "", window.location.pathname);
    carregarEnvios();
    carregarLimites();
  }

  function aoSalvar(envio) {
    const existe = envios.items.some((e) => e.id === envio.id);
    envios = existe
      ? { ...envios, items: envios.items.map((e) => (e.id === envio.id ? { ...e, ...envio } : e)) }
      : { ...envios, items: [envio, ...envios.items], total: envios.total + 1 };
  }

  function aoDisparar(envio) {
    aoSalvar(envio);
    detalheId = envio.id;
    modo = "detalhe";
    carregarLimites();
  }

  function aoApagar(id) {
    envios = {
      ...envios,
      items: envios.items.filter((e) => e.id !== id),
      total: Math.max(0, envios.total - 1),
    };
    voltarLista();
  }

  function mudarFiltro(valor) {
    filtroStatus = valor;
    pagina = 1;
    carregarEnvios();
  }

  function irPagina(p) {
    pagina = p;
    carregarEnvios();
  }

  async function sair() {
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

  const resumoContadores = (c = {}) =>
    `${c.enviados ?? 0}/${c.destinatarios ?? 0} enviados` +
    ((c.falhas ?? 0) > 0 ? ` · ${c.falhas} falha(s)` : "") +
    ((c.pendentes ?? 0) > 0 ? ` · ${c.pendentes} pendente(s)` : "");

  function dataDoEnvio(e) {
    if (e.status === "agendado" && e.agendado_para) return `agendado para ${formatarDataHora(e.agendado_para)}`;
    if (e.concluido_em) return `concluído em ${formatarDataHora(e.concluido_em)}`;
    if (e.cancelado_em) return `cancelado em ${formatarDataHora(e.cancelado_em)}`;
    if (e.iniciado_em) return `iniciado em ${formatarDataHora(e.iniciado_em)}`;
    return `criado em ${formatarDataHora(e.created_at)}`;
  }
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Envios por e-mail</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}mande avisos por e-mail para quem se inscreveu nas suas listas.
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
        href="/gestor/listas"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Listas e QR</a>
      <a
        href="/gestor/segmentos"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Listas dinâmicas</a>
      <a
        href="/gestor/relatorios"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Relatórios</a>
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
    <div class="text-center py-12"><p class="text-gray-500">Carregando envios…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para enviar e-mails às suas listas." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{error}</div>
  {:else}
    <LimitesPainel {limites} />

    {#if modo === "editor"}
      {#key editorKey}
        <EnvioEditor
          {inep}
          envio={editando}
          {alvoInicial}
          {listas}
          {segmentos}
          {limites}
          onSalvo={aoSalvar}
          onDisparado={aoDisparar}
          onApagado={aoApagar}
          onFechar={voltarLista}
          onSessaoExpirada={sessaoExpirada}
        />
      {/key}
    {:else if modo === "detalhe" && detalheId != null}
      {#key detalheId}
        <EnvioDetalhe
          {inep}
          envioId={detalheId}
          onVoltar={voltarLista}
          onAtualizado={aoSalvar}
          onSessaoExpirada={sessaoExpirada}
        />
      {/key}
    {:else}
      <section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="text-sm font-semibold text-gray-900">Envios ({envios.total})</h2>
          <div class="flex items-center gap-2">
            <label class="flex items-center gap-2 text-xs text-gray-600">
              Estado
              <select
                value={filtroStatus}
                onchange={(e) => mudarFiltro(e.currentTarget.value)}
                aria-label="Filtrar envios por estado"
                class="h-8 px-2 rounded-md border border-gray-300 text-xs bg-white"
              >
                <option value="">Todos</option>
                {#each Object.entries(ESTADOS_ENVIO) as [valor, s] (valor)}
                  <option value={valor}>{s.rotulo}</option>
                {/each}
              </select>
            </label>
            <button
              type="button"
              onclick={() => novoEnvio()}
              class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
            >+ Novo envio</button>
          </div>
        </div>

        {#if envios.items.length === 0}
          <p class="py-6 text-center text-sm text-gray-400">
            {filtroStatus ? "Nenhum envio neste estado." : "Nenhum envio ainda. Crie o primeiro."}
          </p>
        {:else}
          <ul class="divide-y divide-gray-100">
            {#each envios.items as e (e.id)}
              <li class="py-3 flex flex-wrap items-center justify-between gap-3" data-testid="envio-row">
                <div class="min-w-0">
                  <p class="text-sm font-medium text-gray-900 flex items-center gap-2">
                    <EnvioSelo status={e.status} />
                    <span class="truncate">{e.assunto}</span>
                  </p>
                  <p class="text-xs text-gray-500">
                    {rotuloOperacao(e.operacao)} · para {e.alvo?.nome ?? "alvo excluído"}
                    {e.alvo?.tipo === "segmento" ? "(lista dinâmica)" : ""}
                    {#if e.status !== "rascunho"}· {resumoContadores(e.contadores)}{/if}
                    · {dataDoEnvio(e)}
                  </p>
                </div>
                <button
                  type="button"
                  aria-label={`${e.status === "rascunho" ? "Editar" : "Ver"} envio ${e.assunto}`}
                  onclick={() => abrirEnvio(e)}
                  class="px-2 py-1 rounded text-xs text-blue-700 hover:bg-blue-50 transition-colors"
                >{e.status === "rascunho" ? "Editar" : "Ver"}</button>
              </li>
            {/each}
          </ul>
          {#if totalPaginas > 1}
            <nav class="flex items-center justify-end gap-2 text-xs" aria-label="Páginas de envios">
              <button
                type="button"
                disabled={pagina <= 1}
                onclick={() => irPagina(pagina - 1)}
                class="px-2 py-1 rounded border border-gray-300 disabled:opacity-40"
              >Anterior</button>
              <span>Página {pagina} de {totalPaginas}</span>
              <button
                type="button"
                disabled={pagina >= totalPaginas}
                onclick={() => irPagina(pagina + 1)}
                class="px-2 py-1 rounded border border-gray-300 disabled:opacity-40"
              >Próxima</button>
            </nav>
          {/if}
        {/if}
      </section>
    {/if}
  {/if}
</div>
