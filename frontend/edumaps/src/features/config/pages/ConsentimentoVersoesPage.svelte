<!-- src/features/config/pages/ConsentimentoVersoesPage.svelte -->
<script>
  // Versões do texto de consentimento (rota admin /config/consentimento,
  // issue #214). Mesma proteção do /config: sessão de gestor com
  // access_role = 'admin'. Lista as versões (vigente/rascunho/arquivada),
  // cria e edita rascunhos (texto em markdown simples, com pré-visualização
  // segura — sem {@html}) e publica com confirmação: a vigente é arquivada e
  // a publicada fica imutável. Erros 400/409 mostram a mensagem do backend.
  import { onMount } from "svelte";
  import {
    listConsentimentoVersoes,
    criarConsentimentoVersao,
    atualizarConsentimentoVersao,
    publicarConsentimentoVersao,
  } from "../api/configApi.js";
  import { fetchMe } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { link } from "@/app/router.svelte.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";
  import TextoMarkdown from "@/features/inscricao/components/TextoMarkdown.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);

  let versoes = $state([]);
  // editor: { modo: "novo" | "editar" | "ver", id?, versao, texto }
  let editor = $state(null);
  let salvando = $state(false);
  let erroEditor = $state(null);

  let publicando = $state(null); // versão a publicar
  let publicandoOcupado = $state(false);
  let erroPublicar = $state(null);

  const STATUS = {
    vigente: { texto: "Vigente", classe: "bg-green-100 text-green-700" },
    rascunho: { texto: "Rascunho", classe: "bg-amber-100 text-amber-700" },
    arquivada: { texto: "Arquivada", classe: "bg-gray-100 text-gray-600" },
  };

  const vigente = $derived(versoes.find((v) => v.status === "vigente") ?? null);
  // vigente primeiro, depois rascunhos, depois arquivadas (mais recentes antes)
  const ORDEM = { vigente: 0, rascunho: 1, arquivada: 2 };
  const ordenadas = $derived(
    [...versoes].sort(
      (a, b) =>
        (ORDEM[a.status] ?? 3) - (ORDEM[b.status] ?? 3) ||
        String(b.publicada_em ?? b.created_at ?? "").localeCompare(String(a.publicada_em ?? a.created_at ?? "")),
    ),
  );

  const data = (iso) => (iso ? new Date(iso).toLocaleString("pt-BR") : "—");

  const mensagemErro = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    if (err instanceof ApiError && err.status === 403) {
      semPermissao = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregarVersoes() {
    try {
      const d = await listConsentimentoVersoes();
      versoes = Array.isArray(d) ? d : (d?.versoes ?? []);
    } catch (err) {
      const msg = mensagemErro(err, "Não foi possível carregar as versões.");
      if (msg) error = msg;
    }
  }

  async function iniciar() {
    carregando = true;
    precisaLogin = false;
    semPermissao = false;
    error = null;
    if (!restaurarSessao()) {
      precisaLogin = true;
      carregando = false;
      return;
    }
    try {
      const me = await fetchMe();
      if (me.access_role !== "admin") {
        semPermissao = true;
        return;
      }
      await carregarVersoes();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) precisaLogin = true;
      else error = err?.message ?? "Não foi possível carregar as versões.";
    } finally {
      carregando = false;
    }
  }

  function novaVersao() {
    erroEditor = null;
    editor = { modo: "novo", versao: "", texto: vigente?.texto ?? "" };
  }

  function abrir(v) {
    erroEditor = null;
    editor = {
      modo: v.status === "rascunho" ? "editar" : "ver",
      id: v.id,
      versao: v.versao,
      texto: v.texto,
      status: v.status,
    };
  }

  async function salvar() {
    const versao = editor.versao.trim();
    const texto = editor.texto.trim();
    if (!versao || !texto) {
      erroEditor = "Informe a versão e o texto.";
      return;
    }
    salvando = true;
    erroEditor = null;
    try {
      if (editor.modo === "novo") {
        await criarConsentimentoVersao({ versao, texto });
        addToast(`Rascunho ${versao} criado.`, "success");
      } else {
        await atualizarConsentimentoVersao(editor.id, { versao, texto });
        addToast(`Rascunho ${versao} salvo.`, "success");
      }
      editor = null;
      await carregarVersoes();
    } catch (err) {
      const msg = mensagemErro(err, "Não foi possível salvar o rascunho.");
      if (msg) erroEditor = msg;
    } finally {
      salvando = false;
    }
  }

  function pedirPublicacao(v) {
    erroPublicar = null;
    publicando = v;
  }

  async function publicar() {
    if (!publicando) return;
    publicandoOcupado = true;
    erroPublicar = null;
    try {
      await publicarConsentimentoVersao(publicando.id);
      addToast(`Versão ${publicando.versao} publicada.`, "success");
      if (editor?.id === publicando.id) editor = null;
      publicando = null;
      await carregarVersoes();
    } catch (err) {
      const msg = mensagemErro(err, "Não foi possível publicar a versão.");
      if (msg) erroPublicar = msg;
      else publicando = null;
      if (err instanceof ApiError && err.status === 409) await carregarVersoes();
    } finally {
      publicandoOcupado = false;
    }
  }

  onMount(iniciar);
</script>

<div class="space-y-5">
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Versões do consentimento</h1>
      <p class="text-sm text-gray-600 mt-1">
        Texto que quem se inscreve nas listas da escola aceita. Cada inscrição guarda a versão aceita.
      </p>
    </div>
    <a
      href="/config"
      use:link
      class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-100"
    >← Configurações</a>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando versões…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard
      onLogin={iniciar}
      titulo="Entrar como administrador"
      mensagem="Entre para gerenciar o texto de consentimento."
      descricao="Use o e-mail e a senha de um gestor com perfil de administração."
    />
  {:else if semPermissao}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      Esta área é restrita a administradores da instalação.
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">{error}</div>
  {:else}
    <section class="border border-gray-200 rounded-lg p-4 bg-white space-y-3">
      <div class="flex items-center justify-between gap-2">
        <h2 class="font-semibold text-gray-800">Versões ({versoes.length})</h2>
        <button
          type="button"
          onclick={novaVersao}
          disabled={editor?.modo === "novo"}
          class="px-3 h-9 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-40"
        >+ Nova versão</button>
      </div>

      {#if versoes.length === 0}
        <p class="py-4 text-center text-sm text-gray-400">Nenhuma versão cadastrada.</p>
      {:else}
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500 text-xs uppercase">
            <tr>
              <th class="text-left font-medium px-3 py-2">Versão</th>
              <th class="text-left font-medium px-3 py-2">Status</th>
              <th class="text-left font-medium px-3 py-2">Publicada em</th>
              <th class="text-right font-medium px-3 py-2"><span class="sr-only">Ações</span></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            {#each ordenadas as v (v.id)}
              {@const st = STATUS[v.status] ?? { texto: v.status, classe: "bg-gray-100 text-gray-600" }}
              <tr data-testid="versao-row">
                <td class="px-3 py-2 font-medium text-gray-900">{v.versao}</td>
                <td class="px-3 py-2" data-testid="versao-status">
                  <span class={`inline-block rounded-full px-2 py-0.5 text-[11px] font-semibold ${st.classe}`}>{st.texto}</span>
                </td>
                <td class="px-3 py-2 text-gray-600">{data(v.publicada_em)}</td>
                <td class="px-3 py-2 text-right whitespace-nowrap">
                  {#if v.status === "rascunho"}
                    <button
                      type="button"
                      aria-label={`Editar versão ${v.versao}`}
                      onclick={() => abrir(v)}
                      class="px-2 py-1 rounded text-xs text-indigo-700 hover:bg-indigo-50"
                    >Editar</button>
                    <button
                      type="button"
                      aria-label={`Publicar versão ${v.versao}`}
                      onclick={() => pedirPublicacao(v)}
                      class="px-2 py-1 rounded text-xs text-green-700 hover:bg-green-50"
                    >Publicar</button>
                  {:else}
                    <button
                      type="button"
                      aria-label={`Ver versão ${v.versao}`}
                      onclick={() => abrir(v)}
                      class="px-2 py-1 rounded text-xs text-gray-600 hover:bg-gray-100"
                    >Ver</button>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </section>

    {#if editor}
      <section
        class="border border-gray-200 rounded-lg p-4 bg-white space-y-3"
        aria-labelledby="editor-titulo"
        data-testid="versao-editor"
      >
        <div class="flex items-center justify-between gap-2">
          <h2 id="editor-titulo" class="font-semibold text-gray-800">
            {editor.modo === "novo"
              ? "Novo rascunho"
              : editor.modo === "editar"
                ? `Editar rascunho ${editor.versao}`
                : `Versão ${editor.versao}`}
          </h2>
          <button
            type="button"
            onclick={() => (editor = null)}
            class="text-xs text-gray-600 hover:underline"
          >Fechar</button>
        </div>

        {#if editor.modo === "ver"}
          <p class="text-xs text-gray-500">Versões publicadas não podem ser editadas.</p>
          <div class="rounded-md border border-gray-200 bg-gray-50 p-3 space-y-2 text-sm text-gray-700" data-testid="versao-texto">
            <TextoMarkdown texto={editor.texto} />
          </div>
        {:else}
          <form
            novalidate
            onsubmit={(e) => {
              e.preventDefault();
              salvar();
            }}
            class="space-y-3"
          >
            <label class="block text-sm text-gray-700">
              Versão
              <input
                bind:value={editor.versao}
                maxlength="20"
                placeholder="Ex.: 1.1"
                class="mt-1 w-40 h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </label>
            <div class="grid md:grid-cols-2 gap-3">
              <label class="block text-sm text-gray-700">
                Texto
                <textarea
                  bind:value={editor.texto}
                  rows="12"
                  class="mt-1 w-full px-3 py-2 rounded-md border border-gray-300 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500"
                ></textarea>
                <span class="block text-xs text-gray-500 mt-1">
                  Markdown simples: parágrafos, títulos (#), listas (- ou 1.) e **negrito**.
                </span>
              </label>
              <div>
                <p class="text-sm text-gray-700">Pré-visualização</p>
                <div
                  class="mt-1 rounded-md border border-gray-200 bg-gray-50 p-3 space-y-2 text-sm text-gray-700 min-h-24"
                  data-testid="versao-preview"
                >
                  <TextoMarkdown texto={editor.texto} />
                </div>
              </div>
            </div>
            {#if erroEditor}
              <p class="text-sm text-red-600" role="alert">{erroEditor}</p>
            {/if}
            <button
              type="submit"
              disabled={salvando}
              class="px-4 h-9 rounded-md bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700 disabled:opacity-40"
            >{editor.modo === "novo" ? "Salvar rascunho" : "Salvar alterações"}</button>
          </form>
        {/if}
      </section>
    {/if}
  {/if}

  {#if publicando}
    <ConfirmDialog
      titulo={`Publicar a versão ${publicando.versao}?`}
      descricao={`${vigente ? `A versão vigente (${vigente.versao}) será arquivada` : "Esta versão passa a ser a vigente"} e as novas inscrições passam a aceitar este texto. Versões publicadas não podem ser editadas.`}
      confirmarRotulo="Publicar"
      ocupado={publicandoOcupado}
      erro={erroPublicar}
      onConfirmar={publicar}
      onCancelar={() => (publicando = null)}
      testid="publicar-dialog"
    />
  {/if}
</div>
