<!-- src/features/gestor/pages/RelacoesPage.svelte -->
<script>
  // Relações Institucionais da escola: cadastro de entidades externas e das
  // relações da escola com elas (o centro do módulo). Exige sessão do gestor.
  import { onMount } from "svelte";
  import {
    getRelacoes,
    createCategoria,
    deleteCategoria,
    createEntidade,
    updateEntidade,
    deleteEntidade,
    createRelacao,
    updateRelacao,
    deleteRelacao,
  } from "../api/gestorRelacoesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    RELACAO_STATUS,
    RELACAO_STATUS_LABELS,
    RELACAO_STATUS_BADGE,
    RELACAO_PRIORIDADES,
    RELACAO_PRIORIDADE_LABELS,
    RELACAO_PRIORIDADE_BADGE,
    GRUPOS_SUGERIDOS,
    FINALIDADES_SUGERIDAS,
    RELACAO_LIMITS as L,
  } from "../constants/relacoes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  const ABAS = [
    { key: "relacoes", label: "Relações" },
    { key: "entidades", label: "Entidades externas" },
  ];

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);
  let aba = $state("relacoes");

  let categorias = $state([]);
  let entidades = $state([]);
  let relacoes = $state([]);

  let filtros = $state({ q: "", status: "", prioridade: "" });

  let entForm = $state(null);
  let relForm = $state(null);
  let novaCategoria = $state({ aberto: false, eixo: "entidade", nome: "" });

  const grupos = $derived(categorias.filter((c) => c.eixo === "entidade").map((c) => c.nome));
  const finalidades = $derived(categorias.filter((c) => c.eixo === "finalidade").map((c) => c.nome));

  const relacoesFiltradas = $derived(
    relacoes.filter((r) => {
      if (filtros.status && r.status !== filtros.status) return false;
      if (filtros.prioridade && r.prioridade !== filtros.prioridade) return false;
      if (filtros.q) {
        const t = filtros.q.toLowerCase();
        if (
          !r.assunto.toLowerCase().includes(t) &&
          !(r.entidade_nome ?? "").toLowerCase().includes(t)
        )
          return false;
      }
      return true;
    }),
  );

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const data = await getRelacoes(me.cod_inep);
      categorias = data.categorias;
      entidades = data.entidades;
      relacoes = data.relacoes;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as relações.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  // ----------------------------- categorias --------------------------------
  async function salvarCategoria() {
    if (!novaCategoria.nome.trim()) return;
    try {
      const cat = await createCategoria(inep, { eixo: novaCategoria.eixo, nome: novaCategoria.nome.trim() });
      categorias.push(cat);
      novaCategoria = { aberto: false, eixo: "entidade", nome: "" };
      addToast("Categoria criada.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível criar a categoria.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirCategoria(cat) {
    if (!window.confirm(`Excluir a categoria "${cat.nome}"?`)) return;
    try {
      await deleteCategoria(inep, cat.id);
      categorias = categorias.filter((c) => c.id !== cat.id);
      addToast("Categoria excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a categoria.");
      if (msg) addToast(msg, "error");
    }
  }

  // ------------------------------ entidades --------------------------------
  function abrirEntidade(e = null) {
    entForm = e
      ? {
          id: e.id,
          nome: e.nome,
          tipo: e.tipo ?? "",
          identificador: e.identificador ?? "",
          responsavel_externo: e.responsavel_externo ?? "",
          email: e.email ?? "",
          telefone: e.telefone ?? "",
          site: e.site ?? "",
          endereco: e.endereco ?? "",
          observacoes: e.observacoes ?? "",
        }
      : {
          id: null, nome: "", tipo: "", identificador: "", responsavel_externo: "",
          email: "", telefone: "", site: "", endereco: "", observacoes: "",
        };
  }

  async function salvarEntidade() {
    if (!entForm.nome.trim()) {
      addToast("Informe o nome da entidade.", "warning");
      return;
    }
    const payload = {
      nome: entForm.nome.trim(),
      tipo: entForm.tipo.trim() || null,
      identificador: entForm.identificador.trim() || null,
      responsavel_externo: entForm.responsavel_externo.trim() || null,
      email: entForm.email.trim() || null,
      telefone: entForm.telefone.trim() || null,
      site: entForm.site.trim() || null,
      endereco: entForm.endereco.trim() || null,
      observacoes: entForm.observacoes.trim() || null,
    };
    try {
      if (entForm.id) {
        const atual = await updateEntidade(inep, entForm.id, payload);
        const idx = entidades.findIndex((e) => e.id === entForm.id);
        if (idx !== -1) entidades[idx] = atual;
        addToast("Entidade atualizada.", "success");
      } else {
        entidades.push(await createEntidade(inep, payload));
        addToast("Entidade cadastrada.", "success");
      }
      entForm = null;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar a entidade.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirEntidade(e) {
    if (!window.confirm(`Excluir "${e.nome}"?`)) return;
    try {
      await deleteEntidade(inep, e.id);
      entidades = entidades.filter((x) => x.id !== e.id);
      addToast("Entidade excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a entidade.");
      if (msg) addToast(msg, "error");
    }
  }

  // ------------------------------ relações ---------------------------------
  function abrirRelacao(r = null) {
    relForm = r
      ? {
          id: r.id,
          entidade_id: r.entidade_id,
          finalidade: r.finalidade ?? "",
          assunto: r.assunto,
          descricao: r.descricao ?? "",
          status: r.status,
          prioridade: r.prioridade,
          responsavel_interno: r.responsavel_interno ?? "",
          inicio: r.inicio ? r.inicio.slice(0, 10) : "",
          proxima_acao: r.proxima_acao ?? "",
          prazo: r.prazo ? r.prazo.slice(0, 10) : "",
        }
      : {
          id: null,
          entidade_id: entidades[0]?.id ?? "",
          finalidade: "",
          assunto: "",
          descricao: "",
          status: "aberta",
          prioridade: "media",
          responsavel_interno: "",
          inicio: "",
          proxima_acao: "",
          prazo: "",
        };
  }

  async function salvarRelacao() {
    if (!relForm.assunto.trim()) {
      addToast("Informe o assunto da relação.", "warning");
      return;
    }
    if (!relForm.entidade_id) {
      addToast("Selecione a entidade externa.", "warning");
      return;
    }
    const payload = {
      entidade_id: Number(relForm.entidade_id),
      finalidade: relForm.finalidade.trim() || null,
      assunto: relForm.assunto.trim(),
      descricao: relForm.descricao.trim() || null,
      status: relForm.status,
      prioridade: relForm.prioridade,
      responsavel_interno: relForm.responsavel_interno.trim() || null,
      inicio: relForm.inicio || null,
      proxima_acao: relForm.proxima_acao.trim() || null,
      prazo: relForm.prazo || null,
    };
    try {
      if (relForm.id) {
        const atual = await updateRelacao(inep, relForm.id, payload);
        const idx = relacoes.findIndex((r) => r.id === relForm.id);
        if (idx !== -1) relacoes[idx] = atual;
        addToast("Relação atualizada.", "success");
      } else {
        relacoes.unshift(await createRelacao(inep, payload));
        addToast("Relação registrada.", "success");
      }
      relForm = null;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar a relação.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirRelacao(r) {
    if (!window.confirm(`Excluir a relação "${r.assunto}"?`)) return;
    try {
      await deleteRelacao(inep, r.id);
      relacoes = relacoes.filter((x) => x.id !== r.id);
      addToast("Relação excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a relação.");
      if (msg) addToast(msg, "error");
    }
  }

  function fmtData(d) {
    if (!d) return "";
    const [a, m, dia] = d.slice(0, 10).split("-");
    return `${dia}/${m}/${a}`;
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
    await carregar();
  }

  onMount(() => {
    restaurarSessao();
    carregar();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Relações da escola</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}entidades externas e o que a escola trata com elas.
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button type="button" onclick={sair} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors">Sair</button>
      {/if}
      <a href="/gestor/inventario" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">Inventário</a>
      <a href="/gestor/reunioes" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">Reuniões</a>
      <a href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando relações…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerir as relações da escola." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else}
    <nav class="flex flex-wrap gap-1" aria-label="Seções das relações">
      {#each ABAS as a (a.key)}
        <button type="button" onclick={() => (aba = a.key)}
          class={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${aba === a.key ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"}`}>
          {a.label}
        </button>
      {/each}
    </nav>

    {#if aba === "relacoes"}
      <section class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex flex-wrap items-center gap-2">
            <input bind:value={filtros.q} placeholder="Buscar assunto/entidade…" class="h-9 px-3 rounded-md border border-gray-300 text-sm" />
            <select bind:value={filtros.status} class="h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              <option value="">Todos os status</option>
              {#each RELACAO_STATUS as s (s.value)}<option value={s.value}>{s.label}</option>{/each}
            </select>
            <select bind:value={filtros.prioridade} class="h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
              <option value="">Todas as prioridades</option>
              {#each RELACAO_PRIORIDADES as p (p.value)}<option value={p.value}>{p.label}</option>{/each}
            </select>
          </div>
          <button type="button" onclick={() => abrirRelacao()}
            class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors">+ Nova relação</button>
        </div>

        <div class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
          {#each relacoesFiltradas as r (r.id)}
            <div class={`flex flex-wrap items-start justify-between gap-2 p-3 ${r.vencida ? "bg-red-50/50" : ""}`}>
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-800 truncate">
                  {r.assunto}
                  {#if r.vencida}<span class="ml-2 text-[10px] uppercase text-red-600 font-semibold">vencida</span>{/if}
                </p>
                <p class="text-xs text-gray-500">
                  {r.entidade_nome}{#if r.entidade_tipo} ({r.entidade_tipo}){/if}
                  {#if r.finalidade}· {r.finalidade}{/if}
                  {#if r.responsavel_interno}· resp. {r.responsavel_interno}{/if}
                </p>
                {#if r.proxima_acao}<p class="text-xs text-gray-600 mt-0.5">Próxima ação: {r.proxima_acao}{#if r.prazo} · até {fmtData(r.prazo)}{/if}</p>{/if}
              </div>
              <div class="flex items-center gap-1">
                <span class={`px-2 py-0.5 rounded-full text-[11px] font-medium ${RELACAO_STATUS_BADGE[r.status] ?? "bg-gray-100 text-gray-600"}`}>{RELACAO_STATUS_LABELS[r.status] ?? r.status}</span>
                <span class={`px-2 py-0.5 rounded-full text-[11px] font-medium ${RELACAO_PRIORIDADE_BADGE[r.prioridade] ?? "bg-gray-100 text-gray-600"}`}>{RELACAO_PRIORIDADE_LABELS[r.prioridade] ?? r.prioridade}</span>
                <button type="button" onclick={() => abrirRelacao(r)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Editar</button>
                <button type="button" onclick={() => excluirRelacao(r)} class="px-3 py-1.5 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">Excluir</button>
              </div>
            </div>
          {:else}
            <p class="p-6 text-center text-sm text-gray-400">
              Nenhuma relação. Cadastre uma entidade externa e registre a relação.
            </p>
          {/each}
        </div>
      </section>

    {:else}
      <section class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <span class="text-xs text-gray-400">{entidades.length} entidade(s)</span>
          <div class="flex items-center gap-2">
            <button type="button" onclick={() => (novaCategoria = { aberto: true, eixo: "entidade", nome: "" })}
              class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors">+ Categoria</button>
            <button type="button" onclick={() => abrirEntidade()}
              class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors">+ Nova entidade</button>
          </div>
        </div>

        {#if novaCategoria.aberto}
          <div class="flex flex-wrap items-end gap-2 rounded-md border border-blue-200 bg-blue-50 p-3">
            <label class="text-xs text-gray-600">
              <span class="block">Eixo</span>
              <select bind:value={novaCategoria.eixo} class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm bg-white">
                <option value="entidade">Entidade</option>
                <option value="finalidade">Finalidade</option>
              </select>
            </label>
            <label class="text-xs text-gray-600">
              <span class="block">Nome</span>
              <input bind:value={novaCategoria.nome} maxlength="80" class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm" />
            </label>
            <button type="button" onclick={salvarCategoria} class="h-9 px-3 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700">Criar</button>
            <button type="button" onclick={() => (novaCategoria = { aberto: false, eixo: "entidade", nome: "" })} class="h-9 px-3 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
          </div>
        {/if}

        <div class="flex flex-wrap gap-1">
          {#each categorias.filter((c) => c.origem === "manual") as c (c.id)}
            <span class="inline-flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 px-2.5 py-0.5 text-[11px] text-gray-600">
              {c.nome} <span class="text-gray-400">({c.eixo})</span>
              <button type="button" onclick={() => excluirCategoria(c)} class="text-gray-400 hover:text-red-600" title="Excluir categoria">✕</button>
            </span>
          {/each}
        </div>

        <div class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
          {#each entidades as e (e.id)}
            <div class="flex flex-wrap items-center justify-between gap-2 p-3">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-800 truncate">{e.nome}</p>
                <p class="text-xs text-gray-500">
                  {e.tipo ?? "sem grupo"}
                  {#if e.responsavel_externo}· {e.responsavel_externo}{/if}
                  {#if e.email}· {e.email}{/if}
                  {#if e.telefone}· {e.telefone}{/if}
                  {#if e.n_relacoes}· {e.n_relacoes} relação(ões){/if}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <button type="button" onclick={() => abrirEntidade(e)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Editar</button>
                <button type="button" onclick={() => excluirEntidade(e)} class="px-3 py-1.5 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">Excluir</button>
              </div>
            </div>
          {:else}
            <p class="p-6 text-center text-sm text-gray-400">Nenhuma entidade cadastrada.</p>
          {/each}
        </div>
      </section>
    {/if}
  {/if}
</div>

<!-- modal de entidade -->
{#if entForm}
  <div class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4">
    <div class="w-full max-w-xl rounded-card bg-white shadow-xl">
      <header class="flex items-center justify-between border-b border-gray-100 p-4">
        <h2 class="text-base font-semibold text-gray-900">{entForm.id ? "Editar" : "Nova"} entidade externa</h2>
        <button type="button" onclick={() => (entForm = null)} class="text-gray-400 hover:text-gray-600">✕</button>
      </header>
      <div class="grid gap-3 p-4 sm:grid-cols-2">
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Nome *</span>
          <input bind:value={entForm.nome} maxlength={L.NOME_MAX} placeholder="Ex.: Prefeitura, Escola X, ONG…" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Grupo</span>
          <input bind:value={entForm.tipo} list="grupos-rel" placeholder="Órgãos públicos…" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
          <datalist id="grupos-rel">
            {#each grupos.length ? grupos : GRUPOS_SUGERIDOS as g (g)}<option value={g}></option>{/each}
          </datalist>
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Identificador</span>
          <input bind:value={entForm.identificador} placeholder="CNPJ / registro" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Responsável (externo)</span>
          <input bind:value={entForm.responsavel_externo} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Telefone</span>
          <input bind:value={entForm.telefone} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">E-mail</span>
          <input bind:value={entForm.email} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Site</span>
          <input bind:value={entForm.site} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Endereço</span>
          <input bind:value={entForm.endereco} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Observações</span>
          <textarea bind:value={entForm.observacoes} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea>
        </label>
      </div>
      <footer class="flex justify-end gap-2 border-t border-gray-100 p-4">
        <button type="button" onclick={() => (entForm = null)} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
        <button type="button" onclick={salvarEntidade} class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700">Salvar</button>
      </footer>
    </div>
  </div>
{/if}

<!-- modal de relação -->
{#if relForm}
  <div class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4">
    <div class="w-full max-w-xl rounded-card bg-white shadow-xl">
      <header class="flex items-center justify-between border-b border-gray-100 p-4">
        <h2 class="text-base font-semibold text-gray-900">{relForm.id ? "Editar" : "Nova"} relação institucional</h2>
        <button type="button" onclick={() => (relForm = null)} class="text-gray-400 hover:text-gray-600">✕</button>
      </header>
      <div class="grid gap-3 p-4 sm:grid-cols-2">
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Entidade externa *</span>
          <select bind:value={relForm.entidade_id} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white">
            <option value="">Selecione…</option>
            {#each entidades as e (e.id)}<option value={e.id}>{e.nome}</option>{/each}
          </select>
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Assunto *</span>
          <input bind:value={relForm.assunto} maxlength={L.ASSUNTO_MAX} placeholder="Ex.: Conserto do telhado da quadra" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Finalidade</span>
          <input bind:value={relForm.finalidade} list="finalidades-rel" placeholder="Solicitação…" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
          <datalist id="finalidades-rel">
            {#each finalidades.length ? finalidades : FINALIDADES_SUGERIDAS as f (f)}<option value={f}></option>{/each}
          </datalist>
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Responsável (interno)</span>
          <input bind:value={relForm.responsavel_interno} placeholder="Quem na escola" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Status</span>
          <select bind:value={relForm.status} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white">
            {#each RELACAO_STATUS as s (s.value)}<option value={s.value}>{s.label}</option>{/each}
          </select>
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Prioridade</span>
          <select bind:value={relForm.prioridade} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white">
            {#each RELACAO_PRIORIDADES as p (p.value)}<option value={p.value}>{p.label}</option>{/each}
          </select>
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Início</span>
          <input type="date" bind:value={relForm.inicio} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Prazo</span>
          <input type="date" bind:value={relForm.prazo} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Próxima ação</span>
          <input bind:value={relForm.proxima_acao} placeholder="Ex.: Cobrar orçamento" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Descrição</span>
          <textarea bind:value={relForm.descricao} maxlength={L.DESCRICAO_MAX} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea>
        </label>
      </div>
      <footer class="flex justify-end gap-2 border-t border-gray-100 p-4">
        <button type="button" onclick={() => (relForm = null)} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
        <button type="button" onclick={salvarRelacao} class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700">Salvar</button>
      </footer>
    </div>
  </div>
{/if}
