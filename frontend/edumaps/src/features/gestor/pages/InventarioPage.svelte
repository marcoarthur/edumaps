<!-- src/features/gestor/pages/InventarioPage.svelte -->
<script>
  // Painel de Inventário Escolar: baseline do Censo (somente leitura) +
  // categorias/itens/fornecedores criados pelo gestor. Exige sessão.
  import { onMount } from "svelte";
  import {
    getInventario,
    importarCenso,
    createCategoria,
    deleteCategoria,
    createFornecedor,
    updateFornecedor,
    deleteFornecedor,
    createItem,
    updateItem,
    deleteItem,
    getItem,
    uploadAnexo,
    downloadAnexo,
    deleteAnexo,
  } from "../api/gestorInventarioApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import {
    INVENTARIO_TIPOS,
    UNIDADES,
    ESTADOS,
    PERIODICIDADES,
    INVENTARIO_LIMITS as L,
  } from "../constants/inventario.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";

  const ABAS = [
    { key: "censo", label: "Do Censo" },
    { key: "recursos", label: "Recursos" },
    { key: "servicos", label: "Serviços" },
    { key: "fornecedores", label: "Fornecedores" },
  ];

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);
  let aba = $state("censo");

  let censo = $state(null);
  let categorias = $state([]);
  let fornecedores = $state([]);
  let itens = $state([]);
  let importando = $state(false);

  let novaCategoria = $state({ aberto: false, tipo: "recurso", nome: "" });

  let itemForm = $state(null);
  let itemAnexos = $state([]);
  let enviandoAnexo = $state(false);

  let fornForm = $state(null);

  const catsRecurso = $derived(categorias.filter((c) => c.tipo === "recurso"));
  const catsServico = $derived(categorias.filter((c) => c.tipo === "servico"));
  const itensRecurso = $derived(itens.filter((i) => i.categoria_tipo === "recurso"));
  const itensServico = $derived(itens.filter((i) => i.categoria_tipo === "servico"));

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  function vazioItem(tipo) {
    return {
      id: null,
      tipo,
      categoria_id: tipo === "servico" ? catsServico[0]?.id ?? "" : catsRecurso[0]?.id ?? "",
      fornecedor_id: "",
      nome: "",
      descricao: "",
      quantidade: tipo === "servico" ? 1 : "",
      unidade: tipo === "servico" ? "conta" : "un",
      estado: "",
      identificador: "",
      periodicidade: tipo === "servico" ? "mensal" : "",
      valor: "",
      data_aquisicao: "",
      atributos: [],
    };
  }

  async function carregar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const data = await getInventario(me.cod_inep);
      censo = data.censo;
      categorias = data.categorias;
      fornecedores = data.fornecedores;
      itens = data.itens;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar o inventário.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function importar() {
    importando = true;
    try {
      const res = await importarCenso(inep);
      await carregar();
      addToast(
        res.importados > 0
          ? `${res.importados} item(ns) importado(s) do Censo.`
          : "Nada novo para importar do Censo.",
        res.importados > 0 ? "success" : "warning",
      );
    } catch (err) {
      const msg = onApiError(err, "Não foi possível importar do Censo.");
      if (msg) addToast(msg, "error");
    } finally {
      importando = false;
    }
  }

  async function salvarCategoria() {
    if (!novaCategoria.nome.trim()) return;
    try {
      const cat = await createCategoria(inep, {
        tipo: novaCategoria.tipo,
        nome: novaCategoria.nome.trim(),
      });
      categorias.push(cat);
      novaCategoria = { aberto: false, tipo: "recurso", nome: "" };
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

  function abrirItem(tipo, item = null) {
    if (item) {
      itemForm = {
        id: item.id,
        tipo: item.categoria_tipo,
        categoria_id: item.categoria_id,
        fornecedor_id: item.fornecedor_id ?? "",
        nome: item.nome,
        descricao: item.descricao ?? "",
        quantidade: item.quantidade ?? "",
        unidade: item.unidade ?? "",
        estado: item.estado ?? "",
        identificador: item.identificador ?? "",
        periodicidade: item.periodicidade ?? "",
        valor: item.valor ?? "",
        data_aquisicao: item.data_aquisicao ? item.data_aquisicao.slice(0, 10) : "",
        atributos: Object.entries(item.atributos ?? {}).map(([chave, valor]) => ({ chave, valor })),
      };
      carregarAnexos(item.id);
    } else {
      itemForm = vazioItem(tipo);
      itemAnexos = [];
    }
  }

  function fecharItem() {
    itemForm = null;
    itemAnexos = [];
  }

  async function carregarAnexos(id) {
    try {
      const det = await getItem(inep, id);
      itemAnexos = det.anexos ?? [];
    } catch {
      itemAnexos = [];
    }
  }

  function atributosObjeto() {
    const out = {};
    for (const { chave, valor } of itemForm.atributos) {
      if (chave.trim()) out[chave.trim()] = valor;
    }
    return out;
  }

  async function salvarItem() {
    if (!itemForm.nome.trim()) {
      addToast("Informe o nome do item.", "warning");
      return;
    }
    if (!itemForm.categoria_id) {
      addToast("Selecione uma categoria.", "warning");
      return;
    }
    const payload = {
      categoria_id: Number(itemForm.categoria_id),
      fornecedor_id: itemForm.fornecedor_id ? Number(itemForm.fornecedor_id) : null,
      nome: itemForm.nome.trim(),
      descricao: itemForm.descricao.trim() || null,
      quantidade: itemForm.quantidade === "" ? 1 : Number(String(itemForm.quantidade).replace(",", ".")),
      unidade: itemForm.unidade.trim() || null,
      estado: itemForm.estado.trim() || null,
      identificador: itemForm.identificador.trim() || null,
      periodicidade: itemForm.periodicidade.trim() || null,
      valor: itemForm.valor === "" ? null : Number(String(itemForm.valor).replace(",", ".")),
      data_aquisicao: itemForm.data_aquisicao || null,
      atributos: atributosObjeto(),
    };
    try {
      if (itemForm.id) {
        const atual = await updateItem(inep, itemForm.id, payload);
        const idx = itens.findIndex((i) => i.id === itemForm.id);
        if (idx !== -1) itens[idx] = atual;
        addToast("Item atualizado.", "success");
      } else {
        const criado = await createItem(inep, payload);
        itens.push(criado);
        addToast("Item criado.", "success");
      }
      fecharItem();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar o item.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirItem(item) {
    if (!window.confirm(`Excluir "${item.nome}"?`)) return;
    try {
      await deleteItem(inep, item.id);
      itens = itens.filter((i) => i.id !== item.id);
      addToast("Item excluído.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o item.");
      if (msg) addToast(msg, "error");
    }
  }

  async function enviarAnexo(event) {
    const file = event.target.files?.[0];
    if (!file) return;
    enviandoAnexo = true;
    try {
      const res = await uploadAnexo(inep, itemForm.id, file);
      itemAnexos = res.anexos ?? [];
      const idx = itens.findIndex((i) => i.id === itemForm.id);
      if (idx !== -1) itens[idx] = { ...itens[idx], n_anexos: itemAnexos.length };
      addToast("Anexo enviado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível enviar o anexo.");
      if (msg) addToast(msg, "error");
    } finally {
      enviandoAnexo = false;
      event.target.value = "";
    }
  }

  async function baixarAnexo(anexo) {
    try {
      const { blob, filename } = await downloadAnexo(inep, itemForm.id, anexo.id);
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = filename;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível baixar o anexo.");
      if (msg) addToast(msg, "error");
    }
  }

  async function removerAnexo(anexo) {
    try {
      await deleteAnexo(inep, itemForm.id, anexo.id);
      itemAnexos = itemAnexos.filter((a) => a.id !== anexo.id);
      const idx = itens.findIndex((i) => i.id === itemForm.id);
      if (idx !== -1) itens[idx] = { ...itens[idx], n_anexos: itemAnexos.length };
    } catch (err) {
      const msg = onApiError(err, "Não foi possível remover o anexo.");
      if (msg) addToast(msg, "error");
    }
  }

  function abrirFornecedor(f = null) {
    fornForm = f
      ? {
          id: f.id,
          nome: f.nome,
          tipo_servico: f.tipo_servico ?? "",
          email: f.email ?? "",
          telefone: f.telefone ?? "",
          site: f.site ?? "",
          documento: f.documento ?? "",
          observacoes: f.observacoes ?? "",
        }
      : { id: null, nome: "", tipo_servico: "", email: "", telefone: "", site: "", documento: "", observacoes: "" };
  }

  async function salvarFornecedor() {
    if (!fornForm.nome.trim()) {
      addToast("Informe o nome do fornecedor.", "warning");
      return;
    }
    const payload = {
      nome: fornForm.nome.trim(),
      tipo_servico: fornForm.tipo_servico.trim() || null,
      email: fornForm.email.trim() || null,
      telefone: fornForm.telefone.trim() || null,
      site: fornForm.site.trim() || null,
      documento: fornForm.documento.trim() || null,
      observacoes: fornForm.observacoes.trim() || null,
    };
    try {
      if (fornForm.id) {
        const atual = await updateFornecedor(inep, fornForm.id, payload);
        const idx = fornecedores.findIndex((f) => f.id === fornForm.id);
        if (idx !== -1) fornecedores[idx] = atual;
      } else {
        fornecedores.push(await createFornecedor(inep, payload));
      }
      fornForm = null;
      addToast("Fornecedor salvo.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar o fornecedor.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirFornecedor(f) {
    if (!window.confirm(`Excluir o fornecedor "${f.nome}"?`)) return;
    try {
      await deleteFornecedor(inep, f.id);
      fornecedores = fornecedores.filter((x) => x.id !== f.id);
      addToast("Fornecedor excluído.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o fornecedor.");
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
      <h1 class="text-2xl font-bold text-gray-900">Inventário da escola</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}recursos e serviços a partir do Censo, com o que o gestor acrescentar.
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
      <a href="/gestor/contatos" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">Contatos</a>
      <a href="/gestor/reunioes" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">Reuniões</a>
      <a
        href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando inventário…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver o inventário da escola." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else}
    <!-- abas -->
    <nav class="flex flex-wrap gap-1" aria-label="Seções do inventário">
      {#each ABAS as a (a.key)}
        <button
          type="button"
          onclick={() => (aba = a.key)}
          class={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
            aba === a.key ? "bg-blue-600 text-white" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
          }`}
        >{a.label}</button>
      {/each}
    </nav>

    {#if aba === "censo"}
      <section class="space-y-4">
        <div class="flex items-center justify-between gap-2">
          <p class="text-sm text-gray-600">
            Dados do Censo Escolar {censo?.ano ?? ""} — somente leitura. Importe para começar seu inventário.
          </p>
          <button
            type="button"
            onclick={importar}
            disabled={importando}
            class="px-4 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 disabled:opacity-50 transition-colors"
          >{importando ? "Importando…" : "Importar para o inventário"}</button>
        </div>

        {#each censo?.grupos ?? [] as grupo (grupo.key)}
          <div class="rounded-card bg-white border border-gray-200 shadow-card p-4">
            <h2 class="text-sm font-semibold text-gray-900">{grupo.label}</h2>
            <ul class="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {#each grupo.itens as it (it.key)}
                <li class="flex items-center justify-between rounded-md border border-gray-100 px-3 py-2">
                  <span class="text-sm text-gray-700">{it.label}</span>
                  <span class="text-xs text-gray-500">
                    {it.qtd > 1 ? `${it.qtd} un` : it.presente ? "presente" : "—"}
                  </span>
                </li>
              {/each}
            </ul>
          </div>
        {:else}
          <p class="text-sm text-gray-500">Sem dados de Censo para esta escola.</p>
        {/each}
      </section>

    {:else if aba === "recursos" || aba === "servicos"}
      {@const tipo = aba === "servicos" ? "servico" : "recurso"}
      {@const lista = tipo === "servico" ? itensServico : itensRecurso}
      {@const cats = tipo === "servico" ? catsServico : catsRecurso}
      <section class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-2">
            <h2 class="text-sm font-semibold text-gray-900">
              {tipo === "servico" ? "Serviços (contas e contratos)" : "Recursos (bens)"}
            </h2>
            <span class="text-xs text-gray-400">{lista.length} item(ns)</span>
          </div>
          <div class="flex items-center gap-2">
            <button
              type="button"
              onclick={() => (novaCategoria = { aberto: true, tipo, nome: "" })}
              class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
            >+ Categoria</button>
            <button
              type="button"
              onclick={() => abrirItem(tipo)}
              class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
            >{tipo === "servico" ? "+ Novo serviço" : "+ Novo recurso"}</button>
          </div>
        </div>

        {#if novaCategoria.aberto}
          <div class="flex flex-wrap items-end gap-2 rounded-md border border-blue-200 bg-blue-50 p-3">
            <label class="text-xs text-gray-600">
              <span class="block">Nome da categoria</span>
              <input bind:value={novaCategoria.nome} maxlength={L.CATEGORIA_NOME_MAX} placeholder="Ex.: Material de limpeza" class="mt-1 h-9 px-2 rounded-md border border-gray-300 text-sm" />
            </label>
            <button type="button" onclick={salvarCategoria} class="h-9 px-3 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700">Criar</button>
            <button type="button" onclick={() => (novaCategoria = { aberto: false, tipo, nome: "" })} class="h-9 px-3 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
          </div>
        {/if}

        {#if cats.length}
          <div class="flex flex-wrap gap-1">
            {#each cats as c (c.id)}
              <span class="inline-flex items-center gap-1 rounded-full border border-gray-200 bg-gray-50 px-2.5 py-0.5 text-[11px] text-gray-600">
                {c.nome}
                {#if c.origem === "manual"}
                  <button type="button" onclick={() => excluirCategoria(c)} class="text-gray-400 hover:text-red-600" title="Excluir categoria">✕</button>
                {/if}
              </span>
            {/each}
          </div>
        {/if}

        <div class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
          {#each lista as item (item.id)}
            <div class="flex flex-wrap items-center justify-between gap-2 p-3">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-800 truncate">
                  {item.nome}
                  {#if item.censo_ref}<span class="ml-1 text-[10px] uppercase text-gray-400">censo</span>{/if}
                </p>
                <p class="text-xs text-gray-500">
                  {item.categoria_nome}
                  {#if item.quantidade}· {item.quantidade} {item.unidade ?? ""}{/if}
                  {#if item.valor !== null && item.valor !== undefined}· R$ {item.valor}{/if}
                  {#if item.estado}· {item.estado}{/if}
                  {#if item.fornecedor_nome}· {item.fornecedor_nome}{/if}
                  {#if item.n_anexos}· {item.n_anexos} anexo(s){/if}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <button type="button" onclick={() => abrirItem(tipo, item)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Editar</button>
                <button type="button" onclick={() => excluirItem(item)} class="px-3 py-1.5 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">Excluir</button>
              </div>
            </div>
          {:else}
            <p class="p-6 text-center text-sm text-gray-400">
              Nenhum item ainda. {tipo === "recurso" ? "Importe do Censo ou crie um recurso." : "Crie um serviço (conta/contrato)."}
            </p>
          {/each}
        </div>
      </section>

    {:else if aba === "fornecedores"}
      <section class="space-y-4">
        <div class="flex items-center justify-between gap-2">
          <h2 class="text-sm font-semibold text-gray-900">Fornecedores e prestadores</h2>
          <button
            type="button"
            onclick={() => abrirFornecedor()}
            class="px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
          >+ Novo fornecedor</button>
        </div>

        <div class="rounded-card bg-white border border-gray-200 shadow-card divide-y divide-gray-100">
          {#each fornecedores as f (f.id)}
            <div class="flex flex-wrap items-center justify-between gap-2 p-3">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-800 truncate">{f.nome}</p>
                <p class="text-xs text-gray-500">
                  {f.tipo_servico ?? "—"}
                  {#if f.email}· {f.email}{/if}
                  {#if f.telefone}· {f.telefone}{/if}
                  {#if f.n_itens}· {f.n_itens} item(ns){/if}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <button type="button" onclick={() => abrirFornecedor(f)} class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300">Editar</button>
                <button type="button" onclick={() => excluirFornecedor(f)} class="px-3 py-1.5 rounded-md bg-red-50 text-red-700 text-xs font-medium hover:bg-red-100">Excluir</button>
              </div>
            </div>
          {:else}
            <p class="p-6 text-center text-sm text-gray-400">Nenhum fornecedor cadastrado.</p>
          {/each}
        </div>
      </section>
    {/if}
  {/if}
</div>

<!-- modal de item -->
{#if itemForm}
  <div class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4">
    <div class="w-full max-w-2xl rounded-card bg-white shadow-xl">
      <header class="flex items-center justify-between border-b border-gray-100 p-4">
        <h2 class="text-base font-semibold text-gray-900">
          {itemForm.id ? "Editar" : "Novo"} {itemForm.tipo === "servico" ? "serviço" : "recurso"}
        </h2>
        <button type="button" onclick={fecharItem} class="text-gray-400 hover:text-gray-600">✕</button>
      </header>

      <div class="grid gap-3 p-4 sm:grid-cols-2">
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Nome *</span>
          <input bind:value={itemForm.nome} maxlength={L.NOME_MAX} placeholder="Ex.: Caixa de giz" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Categoria *</span>
          <select bind:value={itemForm.categoria_id} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white">
            <option value="">Selecione…</option>
            {#each itemForm.tipo === "servico" ? catsServico : catsRecurso as c (c.id)}
              <option value={c.id}>{c.nome}</option>
            {/each}
          </select>
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Fornecedor</span>
          <select bind:value={itemForm.fornecedor_id} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white">
            <option value="">—</option>
            {#each fornecedores as f (f.id)}
              <option value={f.id}>{f.nome}</option>
            {/each}
          </select>
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Quantidade</span>
          <input bind:value={itemForm.quantidade} placeholder="1" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Unidade</span>
          <input bind:value={itemForm.unidade} list="unidades-inv" placeholder="un" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
          <datalist id="unidades-inv">
            {#each UNIDADES as u (u)}<option value={u}></option>{/each}
          </datalist>
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Estado</span>
          <input bind:value={itemForm.estado} list="estados-inv" placeholder="bom" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
          <datalist id="estados-inv">
            {#each ESTADOS as e (e)}<option value={e}></option>{/each}
          </datalist>
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Valor (R$)</span>
          <input bind:value={itemForm.valor} placeholder="0,00" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Identificador</span>
          <input bind:value={itemForm.identificador} placeholder="nº de série / conta / contrato" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Periodicidade</span>
          <input bind:value={itemForm.periodicidade} list="periodicidades-inv" placeholder="mensal" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
          <datalist id="periodicidades-inv">
            {#each PERIODICIDADES as p (p)}<option value={p}></option>{/each}
          </datalist>
        </label>

        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Data de aquisição</span>
          <input type="date" bind:value={itemForm.data_aquisicao} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>

        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Descrição</span>
          <textarea bind:value={itemForm.descricao} maxlength={L.DESCRICAO_MAX} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea>
        </label>

        <!-- atributos livres (chave/valor) -->
        <div class="sm:col-span-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium text-gray-600">Atributos livres</span>
            <button
              type="button"
              onclick={() => (itemForm.atributos = [...itemForm.atributos, { chave: "", valor: "" }])}
              class="text-xs text-blue-600 hover:underline"
            >+ atributo</button>
          </div>
          {#each itemForm.atributos as at, i (i)}
            <div class="mt-1 flex gap-2">
              <input bind:value={at.chave} placeholder="chave" class="flex-1 h-9 px-2 rounded-md border border-gray-300 text-sm" />
              <input bind:value={at.valor} placeholder="valor" class="flex-1 h-9 px-2 rounded-md border border-gray-300 text-sm" />
              <button type="button" onclick={() => (itemForm.atributos = itemForm.atributos.filter((_, j) => j !== i))} class="px-2 text-gray-400 hover:text-red-600">✕</button>
            </div>
          {/each}
        </div>

        <!-- anexos (só em item existente) -->
        {#if itemForm.id}
          <div class="sm:col-span-2 rounded-md border border-gray-200 p-3">
            <div class="flex items-center justify-between">
              <span class="text-xs font-medium text-gray-600">Anexos (fotos, notas fiscais)</span>
              <label class="text-xs text-blue-600 hover:underline cursor-pointer">
                {enviandoAnexo ? "Enviando…" : "+ enviar"}
                <input type="file" class="hidden" accept=".pdf,.docx,.xlsx,.png,.jpg,.jpeg,.txt" onchange={enviarAnexo} />
              </label>
            </div>
            <ul class="mt-2 space-y-1">
              {#each itemAnexos as a (a.id)}
                <li class="flex items-center justify-between text-xs text-gray-600">
                  <button type="button" onclick={() => baixarAnexo(a)} class="text-blue-600 hover:underline truncate">{a.nome_original}</button>
                  <button type="button" onclick={() => removerAnexo(a)} class="text-gray-400 hover:text-red-600">✕</button>
                </li>
              {:else}
                <li class="text-xs text-gray-400">Nenhum anexo.</li>
              {/each}
            </ul>
          </div>
        {/if}
      </div>

      <footer class="flex justify-end gap-2 border-t border-gray-100 p-4">
        <button type="button" onclick={fecharItem} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
        <button type="button" onclick={salvarItem} class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700">Salvar</button>
      </footer>
    </div>
  </div>
{/if}

<!-- modal de fornecedor -->
{#if fornForm}
  <div class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/40 p-4">
    <div class="w-full max-w-lg rounded-card bg-white shadow-xl">
      <header class="flex items-center justify-between border-b border-gray-100 p-4">
        <h2 class="text-base font-semibold text-gray-900">{fornForm.id ? "Editar" : "Novo"} fornecedor</h2>
        <button type="button" onclick={() => (fornForm = null)} class="text-gray-400 hover:text-gray-600">✕</button>
      </header>
      <div class="grid gap-3 p-4 sm:grid-cols-2">
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Nome *</span>
          <input bind:value={fornForm.nome} maxlength={L.FORNECEDOR_NOME_MAX} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Tipo de serviço</span>
          <input bind:value={fornForm.tipo_servico} placeholder="água, luz, internet…" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Documento</span>
          <input bind:value={fornForm.documento} placeholder="CNPJ/CPF" class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">E-mail</span>
          <input bind:value={fornForm.email} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block">
          <span class="block text-xs font-medium text-gray-600">Telefone</span>
          <input bind:value={fornForm.telefone} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Site</span>
          <input bind:value={fornForm.site} class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm" />
        </label>
        <label class="block sm:col-span-2">
          <span class="block text-xs font-medium text-gray-600">Observações</span>
          <textarea bind:value={fornForm.observacoes} rows="2" class="mt-1 w-full rounded-md border border-gray-300 text-sm p-2"></textarea>
        </label>
      </div>
      <footer class="flex justify-end gap-2 border-t border-gray-100 p-4">
        <button type="button" onclick={() => (fornForm = null)} class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300">Cancelar</button>
        <button type="button" onclick={salvarFornecedor} class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700">Salvar</button>
      </footer>
    </div>
  </div>
{/if}
