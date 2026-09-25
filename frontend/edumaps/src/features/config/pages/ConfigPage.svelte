<!-- src/features/config/pages/ConfigPage.svelte -->
<script>
  // Painel de Configuração do EduMaps (administrativo). Exige sessão de gestor
  // com access_role = 'admin'. Árvore em GET /api/admin/config/tree e editor
  // por folha (PUT/POST validate). Folhas desabilitadas aparecem como "Em breve".
  import { onMount } from "svelte";
  import { getConfigTree, getConfigItem, updateConfigItem, validateConfigItem } from "../api/configApi.js";
  import { fetchMe, logoutGestor } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "@/features/gestor/utils/gestorAuth.js";
  import { clearSessaoToken } from "@/features/gestor/utils/gestorSession.js";
  import GestorLoginCard from "@/features/gestor/components/survey/GestorLoginCard.svelte";
  import ConfigArvore from "../components/ConfigArvore.svelte";
  import ConfigEditor from "../components/ConfigEditor.svelte";

  let carregando = $state(true);
  let precisaLogin = $state(false);
  let semPermissao = $state(false);
  let error = $state(null);

  let tree = $state(null);
  let categorias = $derived(tree?.categories ?? []);
  let selecionada = $state(null);
  let item = $state(null);
  let salvando = $state(false);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && (err.status === 401)) {
      precisaLogin = true;
      return "";
    }
    if (err instanceof ApiError && err.status === 403) {
      semPermissao = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregarTree() {
    try {
      tree = await getConfigTree();
    } catch (err) {
      error = onApiError(err, "Não foi possível carregar a configuração.");
    }
  }

  function achatar(node, alvo = []) {
    if (node.children?.length) {
      for (const c of node.children) achatar(c, alvo);
    } else {
      alvo.push(node);
    }
    return alvo;
  }

  async function carregarItem(key) {
    selecionada = key;
    item = null;
    try {
      item = await getConfigItem(key);
    } catch (err) {
      addToast(onApiError(err, "Não foi possível carregar o item."), "error");
    }
  }

  async function salvar(key, valor) {
    salvando = true;
    try {
      item = await updateConfigItem(key, valor);
      addToast("Configuração salva.", "success");
      await carregarTree();
    } finally {
      salvando = false;
    }
  }

  async function validar(key, valor) {
    return validateConfigItem(key, valor);
  }

  // Encontra a folha na árvore e seleciona a primeira habilitada (Chaves).
  async function iniciar() {
    await carregarTree();
    if (!tree) return;
    const folhas = [];
    for (const cat of tree.categories) achatar(cat, folhas);
    const habilitada = folhas.find((f) => f.enabled && f.key !== selecionada);
    if (!item && habilitada) await carregarItem(habilitada.key);
  }

  onMount(() => {
    if (restaurarSessao()) {
      fetchMe()
        .then((me) => {
          if (me.access_role !== "admin") {
            semPermissao = true;
            carregando = false;
            return;
          }
          return iniciar().finally(() => {
            carregando = false;
          });
        })
        .catch((err) => {
          carregando = false;
          if (err instanceof ApiError && err.status === 401) precisaLogin = true;
          else error = err?.message ?? "Não foi possível carregar a configuração.";
        });
    } else {
      precisaLogin = true;
      carregando = false;
    }
  });

  function onLogin() {
    restaurarSessao();
    carregando = true;
    semPermissao = false;
    precisaLogin = false;
    fetchMe()
      .then((me) => {
        if (me.access_role !== "admin") {
          semPermissao = true;
          carregando = false;
          return;
        }
        return iniciar().finally(() => {
          carregando = false;
        });
      })
      .catch(() => {
        carregando = false;
      });
  }

  function sair() {
    logoutGestor().finally(() => {
      clearSessaoToken();
      precisaLogin = true;
    });
  }
</script>

<div class="space-y-5">
  {#if !precisaLogin && !semPermissao}
    <header class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Painel de Configuração</h1>
        <p class="text-sm text-gray-600 mt-1">
          Configurações gerais da plataforma, feitas pela administração da instalação.
        </p>
      </div>
      <button
        type="button"
        onclick={sair}
        class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-100"
      >
        Sair
      </button>
    </header>
  {/if}

  <div class="bg-indigo-50 border border-indigo-100 text-indigo-800 text-sm rounded-md p-3">
    Em desenvolvimento: hoje é possível configurar a <strong>chave do Assistente do Censo</strong>
    (Integrações). As demais categorias entram em breve.
  </div>

  {#if carregando}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando configuração…</p>
    </div>
  {:else if precisaLogin}
    <GestorLoginCard
      onLogin={onLogin}
      titulo="Entrar como administrador"
      mensagem={precisaLogin ? "Entre para acessar as configurações da plataforma." : null}
      descricao="Use o e-mail e a senha de um gestor com perfil de administração."
    />
  {:else if semPermissao}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">
      Esta área é restrita a administradores da instalação.
    </div>
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">{error}</div>
  {:else}
    <div class="grid lg:grid-cols-3 gap-5">
      <section class="border border-gray-200 rounded-lg p-3 bg-white">
        <h2 class="font-semibold text-gray-800 mb-1">Categorias</h2>
        <ConfigArvore categories={categorias} {selecionada} onSelecionarItem={carregarItem} />
      </section>
      <section class="lg:col-span-2 border border-gray-200 rounded-lg p-4 bg-white">
        <ConfigEditor {item} {salvando} onSalvar={salvar} onValidar={validar} />
      </section>
    </div>
  {/if}
</div>