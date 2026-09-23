<!-- src/features/gestor/pages/DocumentosPage.svelte -->
<script>
  // Documentos e Planos Escolares: arquivos por pasta com versionamento
  // (sobrescrever mantém versões antigas), tags livres e auditoria de todas
  // as mudanças. Exige sessão do gestor da escola.
  import { onMount } from "svelte";
  import {
    getDocumentos,
    getAuditoriaDocumentos,
    createPasta,
    updatePasta,
    deletePasta,
    uploadDocumento,
    updateDocumento,
    setDocumentoTags,
    deleteDocumento,
    getDocumentoVersoes,
    getDocumentoHistorico,
    downloadDocumento,
  } from "../api/gestorDocumentosApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import { EXT_PERMITIDA, DOCUMENTOS_LIMITS as L } from "../constants/documentos.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import DocumentosArvore from "../components/documentos/DocumentosArvore.svelte";
  import VersoesModal from "../components/documentos/VersoesModal.svelte";
  import HistoricoModal from "../components/documentos/HistoricoModal.svelte";

  let inep = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let pastas = $state([]);
  let documentos = $state([]);
  let selecionada = $state(null);
  let enviando = $state(false);

  let versoesAbertas = $state(null);
  let historicoAberto = $state(null);
  let baixandoVersao = $state(null);
  let mostraAtividade = $state(false);
  let auditoria = $state([]);
  let carregandoAuditoria = $state(false);

  let fileInput = $state(null);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar(comToast) {
    try {
      const data = await getDocumentos(inep);
      pastas = data.pastas ?? [];
      documentos = data.documentos ?? [];
      if (comToast) addToast("Documentos atualizados.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar os documentos.");
      if (msg) addToast(msg, "error");
    }
  }

  async function carregarAuditoria() {
    if (!mostraAtividade) return;
    carregandoAuditoria = true;
    try {
      const data = await getAuditoriaDocumentos(inep);
      auditoria = data.auditoria ?? [];
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a atividade.");
      if (msg) addToast(msg, "error");
    } finally {
      carregandoAuditoria = false;
    }
  }

  function escolherArquivo() {
    fileInput?.click();
  }

  async function aoEnviar(evento) {
    const file = evento.currentTarget.files?.[0];
    evento.currentTarget.value = "";
    if (!file) return;
    if (file.size > L.MAX_UPLOAD_MB * 1024 * 1024) {
      addToast(`O arquivo não pode passar de ${L.MAX_UPLOAD_MB} MB.`, "error");
      return;
    }
    const ext = (file.name.split(".").pop() ?? "").toLowerCase();
    if (!EXT_PERMITIDA[ext]) {
      addToast("Extensão não permitida. Use PDF, DOCX, XLSX, PNG, JPG ou TXT.", "error");
      return;
    }
    enviando = true;
    try {
      const res = await uploadDocumento(inep, { file, pasta_id: selecionada });
      addToast(
        res.novo ? `"${res.nome}" enviado.` : `"${res.nome}" sobrescrito (versão ${res.versao}).`,
        "success",
      );
      await carregar();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível enviar o arquivo.");
      if (msg) addToast(msg, "error");
    } finally {
      enviando = false;
    }
  }

  async function criarPasta({ pai, nome }) {
    if (!nome) {
      addToast("Informe um nome para a pasta.", "warning");
      return;
    }
    try {
      await createPasta(inep, { nome, pasta_pai_id: pai ?? "" });
      await carregar();
      if (pai) {
        // garante o novo nó visível
      }
      addToast("Pasta criada.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível criar a pasta.");
      if (msg) addToast(msg, "error");
    }
  }

  async function renomearPasta({ id, nome }) {
    if (!nome?.trim()) {
      addToast("Informe um nome válido.", "warning");
      return;
    }
    try {
      await updatePasta(inep, id, { nome: nome.trim(), pasta_pai_id: "" });
      await carregar();
      addToast("Pasta renomeada.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível renomear a pasta.");
      if (msg) addToast(msg, "error");
    }
  }

  async function moverPasta({ id, novoPai }) {
    try {
      await updatePasta(inep, id, { pasta_pai_id: novoPai });
      await carregar();
      addToast("Pasta movida.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível mover a pasta.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirPasta({ id, nome }) {
    if (!window.confirm(`Excluir a pasta "${nome}"? Pastas e arquivos internos serão preservados.`))
      return;
    try {
      await deletePasta(inep, id);
      if (selecionada === id) selecionada = null;
      await carregar();
      addToast("Pasta excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a pasta.");
      if (msg) addToast(msg, "error");
    }
  }

  async function renomearDoc({ id, nome }) {
    if (!nome?.trim()) {
      addToast("Informe um nome válido.", "warning");
      return;
    }
    try {
      await updateDocumento(inep, id, { nome: nome.trim(), pasta_id: "" });
      await carregar();
      addToast("Documento renomeado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível renomear o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  async function moverDoc({ id, novoPai }) {
    try {
      await updateDocumento(inep, id, { pasta_id: novoPai });
      await carregar();
      addToast("Documento movido.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível mover o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  async function excluirDoc({ doc }) {
    if (!window.confirm(`Excluir o documento "${doc.nome}" e todas as suas versões?`)) return;
    try {
      await deleteDocumento(inep, doc.id);
      await carregar();
      addToast("Documento excluído.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir o documento.");
      if (msg) addToast(msg, "error");
    }
  }

  async function baixar(doc, versao) {
    try {
      const { blob, filename } = await downloadDocumento(inep, doc.id, versao);
      const url = window.URL.createObjectURL(blob);
      const a = window.document.createElement("a");
      a.href = url;
      a.download = filename;
      window.document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível baixar o arquivo.");
      if (msg) addToast(msg, "error");
    }
  }

  async function abrirVersoes(doc) {
    baixandoVersao = null;
    try {
      const data = await getDocumentoVersoes(inep, doc.id);
      versoesAbertas = { doc, versoes: data.versoes ?? [] };
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as versões.");
      if (msg) addToast(msg, "error");
    }
  }

  async function abrirHistorico(doc) {
    try {
      const data = await getDocumentoHistorico(inep, doc.id);
      historicoAberto = { doc, historico: data.historico ?? [] };
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar o histórico.");
      if (msg) addToast(msg, "error");
    }
  }

  async function aplicarTags({ doc, tags }) {
    await setDocumentoTags(inep, doc.id, tags);
    await carregar();
    addToast("Tags salvas.", "success");
  }

  function onAcao(tipo, payload) {
    const acoes = {
      "nova-pasta": () => criarPasta(payload),
      "renomear-pasta": () => renomearPasta(payload),
      "mover-pasta": () => moverPasta(payload),
      "excluir-pasta": () => excluirPasta(payload),
      "renomear-doc": () => renomearDoc(payload),
      "mover-doc": () => moverDoc(payload),
      "excluir-doc": () => excluirDoc(payload),
      "tags-doc": () => aplicarTags(payload),
      "download-doc": () => baixar(payload.doc),
      "versoes-doc": () => abrirVersoes(payload.doc),
      "historico-doc": () => abrirHistorico(payload.doc),
    };
    acoes[tipo]?.();
  }

  const qtdEm = (pai) =>
    documentos.filter((d) => (d.pasta_id ?? null) === pai).length +
    pastas.filter((p) => (p.pasta_pai_id ?? null) === pai).length;

  function pastaNome(pai) {
    if (pai == null) return "Raiz";
    return pastas.find((p) => p.id === pai)?.nome ?? "Raiz";
  }

  onMount(() => {
    if (restaurarSessao()) {
      fetchMe()
        .then((me) => {
          inep = me.cod_inep;
          carregando = false;
          return carregar();
        })
        .catch((err) => {
          carregando = false;
          const msg = onApiError(err, "Não foi possível carregar os documentos.");
          if (msg) error = msg;
        });
    } else {
      precisaLogin = true;
      carregando = false;
    }
  });

  function onLogin() {
    restaurarSessao();
    carregando = true;
    precisaLogin = false;
    fetchMe()
      .then((me) => {
        inep = me.cod_inep;
        carregando = false;
        return carregar();
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
  <header class="flex items-center justify-between flex-wrap gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Documentos e planos escolares</h1>
      <p class="text-sm text-gray-600 mt-1">
        Pastas, novos envios viram novas versões e tudo fica registrado no histórico.
      </p>
    </div>
    {#if inep}
      <div class="flex items-center gap-2 flex-wrap">
        <button
          type="button"
          onclick={escolherArquivo}
          disabled={enviando}
          class="px-4 py-2 bg-indigo-600 text-white text-sm font-medium rounded-md hover:bg-indigo-700 disabled:opacity-50"
        >
          {enviando ? "Enviando…" : "⬆ Enviar arquivo"}
        </button>
        <button
          type="button"
          onclick={() => {
            mostraAtividade = !mostraAtividade;
            carregarAuditoria();
          }}
          class="px-4 py-2 bg-gray-200 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-300"
        >
          🕓 Atividade recente
        </button>
        <button
          type="button"
          onclick={sair}
          class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-md hover:bg-gray-100"
        >
          Sair
        </button>
        <input
          bind:this={fileInput}
          type="file"
          class="hidden"
          onchange={aoEnviar}
        />
      </div>
    {/if}
  </header>

  {#if carregando}
    <div class="text-center py-12">
      <p class="text-gray-500">Carregando documentos…</p>
    </div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver os documentos da escola." />
  {:else if error}
    <div class="bg-red-50 border border-red-200 text-red-700 text-sm rounded-md p-4">{error}</div>
  {:else}
    <div class="grid lg:grid-cols-3 gap-5">
      <section class="lg:col-span-2 border border-gray-200 rounded-lg p-3 space-y-2 bg-white">
        <div class="flex items-center justify-between">
<h2 class="font-semibold text-gray-800">
          Arquivos em <span class="text-indigo-700">{pastaNome(selecionada)}</span>
        </h2>
      </div>
      <DocumentosArvore
          {pastas}
          {documentos}
          {selecionada}
          onSelecionarPasta={(id) => (selecionada = id)}
          {onAcao}
        />
        <p class="text-xs text-gray-400 pt-1 border-t">
          # {qtdEm(selecionada)} itens em {pastaNome(selecionada)}. Sobrescrever um arquivo
          mantém as versões anteriores acessíveis em "Versões".
        </p>
      </section>

      <aside class="border border-gray-200 rounded-lg p-3 bg-white h-fit">
        <h2 class="font-semibold text-gray-800 mb-2">🧭 Como funciona</h2>
        <ul class="text-sm text-gray-600 space-y-1.5 list-disc pl-4">
          <li><strong>Enviar arquivo</strong> público ou dentro de uma pasta.</li>
          <li>Mesmo nome, mesma pasta = <strong>nova versão</strong> (a anterior continua baixável).</li>
          <li><strong>Tags</strong> livres ajudam a achar rápido o PPP de cada ano.</li>
          <li>Tudo que muda fica no <strong>histórico</strong> com autor e data.</li>
        </ul>
      </aside>
    </div>
  {/if}

  {#if mostraAtividade && !precisaLogin}
    <section class="border border-gray-200 rounded-lg p-3 bg-white">
      <h2 class="font-semibold text-gray-800 mb-2">🕓 Atividade recente</h2>
      {#if carregandoAuditoria}
        <p class="text-sm text-gray-500">Carregando…</p>
      {:else if !auditoria.length}
        <p class="text-sm text-gray-400">Nenhuma atividade registrada ainda.</p>
      {:else}
        <ul class="divide-y divide-gray-100">
          {#each auditoria.slice(0, 15) as a (a.id)}
            <li class="py-2 flex items-baseline justify-between gap-3">
              <p class="text-sm text-gray-700">
                <strong>{a.nome}</strong>
                <span class="text-gray-400 mx-1">·</span>
                {a.acao === "criado" ? "criado" : a.acao === "sobrescrito" ? "nova versão" : a.acao === "renomeado" ? "renomeado" : a.acao === "movido" ? "movido" : a.acao === "tags" ? "tags atualizadas" : "excluído"}
                <span class="text-gray-400 mx-1">·</span>
                {a.gestor}
              </p>
              <span class="text-xs text-gray-400 shrink-0">
                {new Date(a.criado_em).toLocaleString("pt-BR")}
              </span>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {/if}

  {#if versoesAbertas}
    <VersoesModal
      nome={versoesAbertas.doc.nome}
      versoes={versoesAbertas.versoes}
      baixando={baixandoVersao}
      onDownload={(versao) => {
        baixandoVersao = versao;
        baixar(versoesAbertas.doc, versao).finally(() => (baixandoVersao = null));
      }}
      onFechar={() => (versoesAbertas = null)}
    />
  {/if}

  {#if historicoAberto}
    <HistoricoModal
      nome={historicoAberto.doc.nome}
      historico={historicoAberto.historico}
      onFechar={() => (historicoAberto = null)}
    />
  {/if}
</div>