<!-- src/features/gestor/pages/ReunioesWizardPage.svelte -->
<script>
  // Wizard de reunião (criar em /gestor/reunioes/nova e editar em
  // /gestor/reunioes/:id/editar). Quatro passos: 1 quando · 2 quem · 3 aviso ·
  // 4 pauta. Em edição, expande os participantes existentes nos seletores.
  import { onMount } from "svelte";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { ApiError } from "@/shared/api/client.js";
  import {
    listContatos,
    listGrupos,
    getReuniao,
    createReuniao,
    updateReuniao,
  } from "../api/gestorReunioesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    estadoInicial,
    buildReuniaoPayload,
    primeiroErro,
    participantesPreview,
  } from "../utils/reuniaoDraft.js";
  import { buildConvite } from "../utils/convite.js";
  import { AVISO_METODOS, REUNIAO_LIMITS as L } from "../constants/reunioes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import ConviteBox from "../components/reunioes/ConviteBox.svelte";

  const PASSOS = ["Quando", "Quem", "Aviso", "Pauta"];

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let estado = $state(estadoInicial(false));
  let contatos = $state([]);
  let grupos = $state([]);
  let passo = $state(0);
  let buscaContato = $state("");
  let salvando = $state(false);

  let editId = $state(null);
  const params = new URL(location.href).pathname;
  const isEdit = /^\/gestor\/reunioes\/\d+\/editar$/.test(params);
  if (isEdit) editId = Number(params.match(/\/(\d+)\/editar$/)[1]);

  const convite = $derived(
    buildConvite({
      titulo: estado.titulo,
      quando: (estado.dataLocal ?? "").replace("T", " ") + ":00",
      duracaoMin: estado.duracaoMin,
      ondeLabel: estado.ondeLabel,
      ondeLink: estado.ondeLink,
    }),
  );

  const preview = $derived(participantesPreview(contatos, grupos, estado));
  const contatosFiltrados = $derived(
    contatos.filter((c) => c.nome.toLowerCase().includes(buscaContato.toLowerCase())),
  );

  function toggleContato(id) {
    if (estado.contatoIds.has(id)) estado.contatoIds.delete(id);
    else estado.contatoIds.add(id);
    // reatividade de Set: reatribui para disparar $state
    estado.contatoIds = new Set(estado.contatoIds);
  }

  function toggleGrupo(id) {
    if (estado.grupoIds.has(id)) estado.grupoIds.delete(id);
    else estado.grupoIds.add(id);
    estado.grupoIds = new Set(estado.grupoIds);
  }

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregarRascunho() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      if (!isEdit) {
        const me = await fetchMe();
        inep = me.cod_inep;
        gestor = me;
        const [c2, g2] = await Promise.all([listContatos(inep), listGrupos(inep)]);
        contatos = c2;
        grupos = g2;
        return;
      }

      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const [det, c2, g2] = await Promise.all([
        getReuniao(inep, editId),
        listContatos(inep),
        listGrupos(inep),
      ]);
      contatos = c2;
      grupos = g2;
      estado = {
        ...estadoInicial(true),
        titulo: det.titulo,
        dataLocal: (det.quando ?? "").replace(" ", "T").slice(0, 16),
        duracaoMin: det.duracao_min ?? L.DURACAO_DEFAULT,
        ondeLabel: det.onde_label ?? "",
        ondeLink: det.onde_link ?? "",
        avisoMetodo: det.aviso_metodo ?? "todos",
        pautaTexto: det.pauta_texto ?? "",
        contatoIds: new Set(
          (det.participantes ?? [])
            .filter((p) => !p.via_grupo_id)
            .map((p) => p.id),
        ),
        grupoIds: new Set(
          (det.participantes ?? [])
            .filter((p) => p.via_grupo_id)
            .map((p) => p.via_grupo_id),
        ),
      };
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a reunião.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function salvar() {
    const problema = primeiroErro(estado);
    if (problema) {
      addToast(problema, "warning");
      return;
    }
    salvando = true;
    error = null;
    try {
      const payload = buildReuniaoPayload(estado);
      if (isEdit) {
        const atual = await updateReuniao(inep, editId, payload);
        addToast("Reunião atualizada.", "success");
        window.location.href = `/gestor/reunioes/${atual.id ?? editId}`;
      } else {
        const criada = await createReuniao(inep, payload);
        addToast("Reunião agendada!", "success");
        window.location.href = `/gestor/reunioes/${criada.id}`;
      }
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar a reunião.");
      if (msg) addToast(msg, "error");
    } finally {
      salvando = false;
    }
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

  async function onLogin(sessao) {
    setSessaoToken(sessao.token);
    restaurarSessao();
    await carregarRascunho();
  }

  onMount(() => {
    restaurarSessao();
    carregarRascunho();
  });
</script>

<div class="space-y-6 max-w-3xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">
        {isEdit ? "Editar reunião" : "Nova reunião"}
      </h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}organize em quatro passos.
      </p>
    </div>
    <a href="/gestor/reunioes" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">
      ← Lista de reuniões
    </a>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando…</p></div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para agendar reuniões." />
  {:else}
    <!-- indicador de passos -->
    <nav class="flex gap-1" aria-label="Passos">
      {#each PASSOS as nome, i (i)}
        <button
          type="button"
          onclick={() => { if (i < passo) passo = i; }}
          class={`flex-1 py-2 rounded-md text-sm font-medium transition-colors ${
            i === passo
              ? "bg-blue-600 text-white"
              : i < passo
                ? "bg-blue-100 text-blue-700 hover:bg-blue-200"
                : "bg-gray-100 text-gray-400"
          }`}
        >
          {i + 1}. {nome}
        </button>
      {/each}
    </nav>

    <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-4">
      {#if passo === 0}
        <!-- passo 1: quando -->
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Título *</span>
          <input
            bind:value={estado.titulo}
            maxlength={L.TITULO_MAX}
            placeholder="Ex.: Reunião de planejamento pedagógico"
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <div class="grid gap-4 sm:grid-cols-2">
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Data e hora *</span>
            <input
              type="datetime-local"
              bind:value={estado.dataLocal}
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Duração (minutos)</span>
            <input
              type="number"
              bind:value={estado.duracaoMin}
              min={L.DURACAO_MIN}
              max={L.DURACAO_MAX}
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <span class="text-[11px] text-gray-400">{L.DURACAO_MIN}–{L.DURACAO_MAX} min</span>
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Onde (nome)</span>
            <input
              bind:value={estado.ondeLabel}
              maxlength="80"
              placeholder="Ex.: Sala de professores / Google Meet"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Onde (link)</span>
            <input
              bind:value={estado.ondeLink}
              type="url"
              placeholder="https://meet.google.com/…"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
        </div>
      {:else if passo === 1}
        <!-- passo 2: quem -->
        <div>
          <div class="flex items-center justify-between gap-2">
            <h2 class="text-sm font-semibold text-gray-900">Quem participa?</h2>
            <p class="text-xs text-gray-500">
              {preview.diretos.length} direto(s) + {preview.nExpandidos} em
              {preview.grupoSel.length} grupo(s) = {preview.total} pessoa(s)
            </p>
          </div>

          <div class="mt-3 grid gap-4 sm:grid-cols-2">
            <section>
              <input
                bind:value={buscaContato}
                placeholder="Buscar contato…"
                class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 mb-2"
              />
              <ul class="max-h-64 overflow-y-auto divide-y divide-gray-100 rounded-md border border-gray-200">
                {#each contatosFiltrados as c (c.id)}
                  <li>
                    <label class="flex items-center gap-2 px-3 py-2 hover:bg-gray-50 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={estado.contatoIds.has(c.id)}
                        onchange={() => toggleContato(c.id)}
                        class="accent-blue-600"
                      />
                      <span class="min-w-0">
                        <span class="block text-sm text-gray-800 truncate">{c.nome}</span>
                        <span class="block text-[11px] text-gray-400 truncate">
                          {[c.email, c.telefone].filter(Boolean).join(" · ") || "sem contato"}
                        </span>
                      </span>
                    </label>
                  </li>
                {:else}
                  <li class="px-3 py-6 text-center text-xs text-gray-400">Nenhum contato. <a href="/gestor/contatos" class="text-blue-600 hover:underline">Adicionar na agenda</a>.</li>
                {/each}
              </ul>
            </section>

            <section class="space-y-2">
              <h3 class="text-xs font-medium text-gray-600">Grupos (todos os membros)</h3>
              {#each grupos as g (g.id)}
                <label class="flex items-center justify-between rounded-md border p-3 cursor-pointer hover:bg-gray-50 transition-colors">
                  <span class="flex items-center gap-2">
                    <input
                      type="checkbox"
                      checked={estado.grupoIds.has(g.id)}
                      onchange={() => toggleGrupo(g.id)}
                      class="accent-blue-600"
                    />
                    <span class="text-sm text-gray-800">{g.nome}</span>
                  </span>
                  <span class="text-xs text-gray-400">{g.n_contatos}</span>
                </label>
              {:else}
                <p class="text-xs text-gray-400">Nenhum grupo ainda.</p>
              {/each}
            </section>
          </div>
        </div>
      {:else if passo === 2}
        <!-- passo 3: aviso -->
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Como avisar?</span>
          <select bind:value={estado.avisoMetodo} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
            {#each AVISO_METODOS as m (m.value)}
              <option value={m.value}>{m.label}</option>
            {/each}
          </select>
        </label>
        <p class="text-xs text-gray-500">
          O convite é gerado para você copiar e enviar — registramos o método
          escolhido na reunião.
        </p>
        <ConviteBox convite={convite} />
      {:else}
        <!-- passo 4: pauta -->
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Pauta</span>
          <textarea
            bind:value={estado.pautaTexto}
            maxlength={L.PAUTA_MAX}
            rows="8"
            placeholder="1. …&#10;2. …&#10;3. …"
            class="mt-1 w-full rounded-md border border-gray-300 text-sm p-3 focus:outline-none focus:ring-2 focus:ring-blue-500"
          ></textarea>
          <span class="text-[11px] text-gray-400">{estado.pautaTexto.length}/{L.PAUTA_MAX}</span>
        </label>
      {/if}

      <div class="flex items-center justify-between pt-2 border-t border-gray-100">
        <button
          type="button"
          onclick={() => { if (passo > 0) passo -= 1; }}
          disabled={passo === 0}
          class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 disabled:opacity-40 transition-colors"
        >← Voltar</button>
        {#if passo < PASSOS.length - 1}
          <button
            type="button"
            onclick={() => passo += 1}
            class="px-5 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
          >Continuar →</button>
        {:else}
          <button
            type="button"
            onclick={salvar}
            disabled={salvando}
            class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors"
          >
            {salvando ? "Salvando…" : isEdit ? "Salvar alterações" : "Agendar reunião"}
          </button>
        {/if}
      </div>
    </div>

    {#if gestor}
      <div class="flex items-center justify-end gap-2">
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      </div>
    {/if}
  {/if}
</div>