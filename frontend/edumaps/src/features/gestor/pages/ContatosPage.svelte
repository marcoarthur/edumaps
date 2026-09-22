<!-- src/features/gestor/pages/ContatosPage.svelte -->
<script>
  // Agenda de contatos e grupos do gestor (módulo Reuniões & Atas).
  // Exige sessão: sem token mostra o cartão de login; 401 volta ao login.
  import { onMount } from "svelte";
  import {
    listContatos,
    createContato,
    updateContato,
    deleteContato,
    importContatos,
    importarContatosFolha,
    listGrupos,
    createGrupo,
    deleteGrupo,
  } from "../api/gestorReunioesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import { parseContatos } from "../utils/contatoParser.js";
  import { REUNIAO_LIMITS as L } from "../constants/reunioes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let contatos = $state([]);
  let grupos = $state([]);
  let busca = $state("");
  let novoAberto = $state(false);
  let novo = $state({ nome: "", email: "", telefone: "", cargo: "", grupo_id: "" });
  let editId = $state(null);
  let edit = $state({ nome: "", email: "", telefone: "", cargo: "", grupo_id: "" });

  let textoImport = $state("");
  let resultadoImport = $state(null);
  let novoGrupo = $state("");

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return;
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const [contatosLista, gruposLista] = await Promise.all([
        listContatos(me.cod_inep),
        listGrupos(me.cod_inep),
      ]);
      contatos = contatosLista;
      grupos = gruposLista;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a agenda.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  const contatosFiltrados = $derived(
    contatos.filter((c) => c.nome.toLowerCase().includes(busca.toLowerCase())),
  );

  const totalSelecionados = $derived(parseContatos(textoImport).length);

  async function salvarNovo() {
    if (!novo.nome.trim()) {
      addToast("Informe o nome do contato.", "warning");
      return;
    }
    error = null;
    try {
      const criado = await createContato(inep, {
        nome: novo.nome.trim(),
        email: novo.email.trim() || null,
        telefone: novo.telefone.trim() || null,
        cargo: novo.cargo.trim() || null,
        grupo_id: novo.grupo_id ? Number(novo.grupo_id) : null,
      });
      contatos.push(criado);
      novo = { nome: "", email: "", telefone: "", cargo: "", grupo_id: "" };
      novoAberto = false;
      addToast("Contato salvo.", "success");
    } catch (err) {
      error = onApiError(err, "Não foi possível salvar o contato.") ?? "Não foi possível salvar o contato.";
    }
  }

  async function salvarEdicao() {
    if (!edit.nome.trim()) {
      addToast("Informe o nome do contato.", "warning");
      return;
    }
    try {
      const atualizado = await updateContato(inep, editId, {
        nome: edit.nome.trim(),
        email: edit.email.trim() || null,
        telefone: edit.telefone.trim() || null,
        cargo: edit.cargo.trim() || null,
        grupo_id: edit.grupo_id ? Number(edit.grupo_id) : null,
      });
      const idx = contatos.findIndex((c) => c.id === editId);
      if (idx !== -1) contatos[idx] = atualizado;
      editId = null;
      addToast("Contato atualizado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível atualizar o contato.");
      if (msg) addToast(msg, "error");
    }
  }

  function abrirEdicao(c) {
    editId = c.id;
    edit = {
      nome: c.nome,
      email: c.email ?? "",
      telefone: c.telefone ?? "",
      cargo: c.cargo ?? "",
      grupo_id: c.grupo_id ?? "",
    };
  }

  async function excluirContato(c) {
    if (!window.confirm(`Excluir ${c.nome}?`)) return;
    try {
      await deleteContato(inep, c.id);
      contatos = contatos.filter((x) => x.id !== c.id);
      addToast("Contato excluído.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o contato.");
      if (msg) addToast(msg, "error");
    }
  }

  async function enviarImport() {
    const lista = parseContatos(textoImport);
    if (lista.length === 0) {
      addToast("Cole ao menos um contato no formato nome; email; telefone; grupo.", "warning");
      return;
    }
    if (lista.length > L.IMPORT_MAX) {
      addToast(`No máximo ${L.IMPORT_MAX} contatos por importação.`, "warning");
      return;
    }
    resultadoImport = null;
    try {
      const res = await importContatos(inep, lista);
      resultadoImport = res;
      const [listaAtualizada] = await Promise.all([listContatos(inep)]);
      contatos = listaAtualizada;
      textoImport = "";
      addToast(`${res.n_inseridos} contato(s) importado(s).`, "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível importar os contatos.");
      if (msg) addToast(msg, "error");
    }
  }

  // Importa os profissionais da folha de pagamento como contatos (nome + cargo).
  async function importarDaFolha() {
    resultadoImport = null;
    try {
      const res = await importarContatosFolha(inep);
      const [c, g] = await Promise.all([listContatos(inep), listGrupos(inep)]);
      contatos = c;
      grupos = g;
      addToast(
        res.n_inseridos > 0
          ? `${res.n_inseridos} contato(s) importado(s) da folha.`
          : "Nenhum contato novo na folha (já importados).",
        res.n_inseridos > 0 ? "success" : "warning",
      );
    } catch (err) {
      const msg = onApiError(err, "Não foi possível importar da folha.");
      if (msg) addToast(msg, "error");
    }
  }

  async function criarGrupo() {
    if (!novoGrupo.trim()) return;
    try {
      const criado = await createGrupo(inep, novoGrupo.trim());
      grupos.push(criado);
      novoGrupo = "";
      addToast("Grupo criado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível criar o grupo.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirGrupo(g) {
    if (!window.confirm(`Excluir o grupo "${g.nome}" (${g.n_contatos} contato(s))?`)) return;
    try {
      await deleteGrupo(inep, g.id);
      grupos = grupos.filter((x) => x.id !== g.id);
      contatos = contatos.map((c) =>
        c.grupo_id === g.id ? { ...c, grupo_id: null, grupo_nome: null } : c,
      );
      addToast("Grupo excluído.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o grupo.");
      if (msg) addToast(msg, "error");
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
    carregarTudo();
  }

  onMount(() => {
    restaurarSessao();
    carregarTudo();
  });
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Agenda de contatos</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}quem a escola chama para as reuniões.
      </p>
    </div>
    <div class="flex items-center gap-2">
      {#if gestor}
        <span class="text-xs text-gray-500">{gestor.nome}</span>
        <button
          type="button"
          onclick={sair}
          class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
        >Sair</button>
      {/if}
      <a
        href="/gestor/reunioes"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Reuniões →</a>
      <a
        href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando agenda…</p></div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerenciar os contatos." />
  {:else}
    <div class="grid gap-6 lg:grid-cols-2">
      <!-- Importação por colagem -->
      <section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-gray-900">Importar contatos</h2>
        <p class="text-xs text-gray-500">
          Cole uma lista com uma pessoa por linha no formato
          <code class="text-gray-700">nome; email; telefone; grupo</code>
          (grupo é opcional).
        </p>
        <textarea
          bind:value={textoImport}
          rows="4"
          placeholder="Maria da Silva; maria@escola.edu.br; +55 11 99999-0001; Professores"
          class="w-full rounded-md border border-gray-300 text-sm p-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        ></textarea>
        <p class="text-xs text-gray-500">
          {totalSelecionados} contato(s) reconhecido(s){(totalSelecionados > L.IMPORT_MAX ? ` · limite ${L.IMPORT_MAX}` : "")}.
        </p>
        <button
          type="button"
          onclick={enviarImport}
          disabled={totalSelecionados === 0}
          class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 disabled:opacity-50 transition-colors"
        >Importar</button>
        {#if resultadoImport}
          <p class="text-xs text-green-700">
            {resultadoImport.n_inseridos} inseridos, {resultadoImport.n_pulados} pulados.
          </p>
        {/if}

        <!-- importar da folha de pagamento -->
        <div class="pt-2 border-t border-gray-100 space-y-2">
          <h3 class="text-xs font-semibold uppercase tracking-wide text-gray-500">
            Da folha de pagamento
          </h3>
          <p class="text-xs text-gray-500">
            Traz os profissionais da folha da escola como contatos (nome e cargo),
            organizados nos grupos da folha. Não repete quem já está na agenda.
          </p>
          <button
            type="button"
            onclick={importarDaFolha}
            class="px-4 py-2 rounded-md bg-emerald-600 text-white text-sm font-medium hover:bg-emerald-700 transition-colors"
          >Importar da folha</button>
        </div>

        <!-- grupos -->
        <div class="pt-2 border-t border-gray-100 space-y-2">
          <h3 class="text-xs font-semibold uppercase tracking-wide text-gray-500">Grupos</h3>
          <div class="flex gap-1 flex-wrap">
            {#each grupos as g (g.id)}
              <span class="inline-flex items-center gap-1 rounded-full bg-blue-50 text-blue-700 px-3 py-1 text-xs">
                {g.nome} ({g.n_contatos})
                {#if g.origem === "folha"}
                  <span
                    title="Grupo pré-listado pela folha de pagamento da escola"
                    class="rounded bg-emerald-100 text-emerald-700 px-1.5 py-0.5 text-[10px] font-semibold uppercase"
                  >folha</span>
                {:else}
                  <button
                    type="button"
                    title={`Excluir ${g.nome}`}
                    onclick={() => excluirGrupo(g)}
                    class="text-blue-400 hover:text-red-600 transition-colors"
                  >✕</button>
                {/if}
              </span>
            {/each}
          </div>
          <form
            onsubmit={(e) => { e.preventDefault(); criarGrupo(); }}
            class="flex gap-2"
          >
            <input
              bind:value={novoGrupo}
              placeholder="Nome do grupo…"
              class="flex-1 h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="submit"
              disabled={!novoGrupo.trim()}
              class="px-3 h-9 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 disabled:opacity-50 transition-colors"
            >Criar</button>
          </form>
        </div>
      </section>

      <!-- Lista de contatos -->
      <section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold text-gray-900">Contatos ({contatos.length})</h2>
          <button
            type="button"
            onclick={() => { novoAberto = !novoAberto; }}
            class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
          >{novoAberto ? "Cancelar" : "+ Novo contato"}</button>
        </div>

        <input
          bind:value={busca}
          placeholder="Buscar…"
          class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        />

        {#if novoAberto}
          <form
            onsubmit={(e) => { e.preventDefault(); salvarNovo(); }}
            class="rounded-md border border-blue-200 bg-blue-50/50 p-3 space-y-2"
          >
            {#each ["nome", "email", "telefone", "cargo"] as campo}
              <input
                bind:value={novo[campo]}
                placeholder={campo === "nome" ? "Nome *" : campo}
                type={campo === "email" ? "email" : campo === "telefone" ? "tel" : "text"}
                class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            {/each}
            <select
              bind:value={novo.grupo_id}
              class="w-full h-9 px-2 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Sem grupo</option>
              {#each grupos as g (g.id)}
                <option value={g.id}>{g.nome}</option>
              {/each}
            </select>
            <button
              type="submit"
              class="w-full h-9 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 transition-colors"
            >Salvar</button>
          </form>
        {/if}

        <ul class="divide-y divide-gray-100">
          {#each contatosFiltrados as c (c.id)}
            <li class="py-2 flex items-center justify-between gap-3">
              {#if editId === c.id}
                <form
                  onsubmit={(e) => { e.preventDefault(); salvarEdicao(); }}
                  class="flex-1 space-y-1"
                >
                  <input bind:value={edit.nome} placeholder="Nome" class="w-full h-8 px-2 rounded-md border border-gray-300 text-xs" />
                  <input bind:value={edit.email} placeholder="E-mail" class="w-full h-8 px-2 rounded-md border border-gray-300 text-xs" />
                  <input bind:value={edit.telefone} placeholder="Telefone" class="w-full h-8 px-2 rounded-md border border-gray-300 text-xs" />
                  <select bind:value={edit.grupo_id} class="w-full h-8 px-1 rounded-md border border-gray-300 text-xs bg-white">
                    <option value="">Sem grupo</option>
                    {#each grupos as g (g.id)}
                      <option value={g.id}>{g.nome}</option>
                    {/each}
                  </select>
                  <div class="flex gap-1">
                    <button type="submit" class="px-2 h-7 rounded bg-blue-600 text-white text-xs">Salvar</button>
                    <button type="button" onclick={() => { editId = null; }} class="px-2 h-7 rounded bg-gray-200 text-gray-700 text-xs">Cancelar</button>
                  </div>
                </form>
              {:else}
                <div class="min-w-0">
                  <p class="text-sm font-medium text-gray-900">{c.nome}</p>
                  <p class="text-xs text-gray-500 truncate">
                    {[c.email, c.telefone, c.cargo].filter(Boolean).join(" · ") || "sem contato"}
                  </p>
                  {#if c.grupo_nome}
                    <span class="inline-block mt-1 rounded-full bg-gray-100 text-gray-600 px-2 py-0.5 text-[10px]">{c.grupo_nome}</span>
                  {/if}
                </div>
                <div class="flex items-center gap-1 shrink-0">
                  <button type="button" onclick={() => abrirEdicao(c)} class="px-2 py-1 rounded text-xs text-gray-500 hover:bg-gray-100 transition-colors">Editar</button>
                  <button type="button" onclick={() => excluirContato(c)} class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50 transition-colors">Excluir</button>
                </div>
              {/if}
            </li>
          {:else}
            <li class="py-8 text-center text-sm text-gray-400">
              {busca ? "Nada encontrado." : "Nenhum contato ainda. Importe ou adicione um novo."}
            </li>
          {/each}
        </ul>
      </section>
    </div>
  {/if}
</div>