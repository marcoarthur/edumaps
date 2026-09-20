<!-- src/features/gestor/pages/ReuniaoDetailPage.svelte -->
<script>
  // Detalhe de uma reunião: participantes, anexos (pauta/ata), convite,
  // ata em texto e transições de status (realizada / cancelada / excluir).
  import { onMount } from "svelte";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { ApiError } from "@/shared/api/client.js";
  import {
    getReuniao,
    salvarAta,
    marcarRealizada,
    cancelarReuniao,
    deleteReuniao,
    uploadAnexo,
    downloadAnexo,
  } from "../api/gestorReunioesApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import { buildConvite } from "../utils/convite.js";
  import {
    REUNIAO_STATUS_BADGE,
    REUNIAO_STATUS_LABELS,
    AVISO_METODO_LABELS,
    ANEXO_EXTENSOES,
    REUNIAO_LIMITS as L,
    TAMANHO_LABEL,
  } from "../constants/reunioes.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import ConviteBox from "../components/reunioes/ConviteBox.svelte";

  const ANEXO_LABELS = { pauta: "Pauta", ata: "Ata" };

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let reuniao = $state(null);
  let ataTexto = $state("");
  let salvandoAta = $state(false);
  let acaoOcupada = $state(false);
  let enviando = $state(null);

  const url = new URL(location.href);
  const id = Number(url.pathname.match(/^\/gestor\/reunioes\/(\d+)/)?.[1] ?? url.searchParams.get("id") ?? 0);

  const convite = $derived(
    reuniao
      ? buildConvite({
          titulo: reuniao.titulo,
          quando: reuniao.quando,
          duracaoMin: reuniao.duracao_min,
          ondeLabel: reuniao.onde_label,
          ondeLink: reuniao.onde_link,
        })
      : null,
  );

  const telefoneInicial = $derived(reuniao?.participantes?.[0]?.telefone ?? null);

  const ax = $derived({
    pauta: (reuniao?.anexos ?? []).find((a) => a.tipo === "pauta") ?? null,
    ata: (reuniao?.anexos ?? []).find((a) => a.tipo === "ata") ?? null,
  });

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  async function carregar() {
    if (!inep || !id) return;
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      reuniao = await getReuniao(inep, id);
      ataTexto = reuniao.ata_texto ?? "";
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a reunião.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function iniciar() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      if (!id) throw new ApiError("Nenhuma reunião informada.", { status: 404 });
      await carregar();
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar a reunião.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function transicao(tipo) {
    if (acaoOcupada) return;
    if (tipo === "excluir" && !window.confirm(`Excluir a reunião "${reuniao.titulo}"?`)) return;
    acaoOcupada = true;
    try {
      if (tipo === "realizada") await marcarRealizada(inep, id);
      else if (tipo === "cancelar") await cancelarReuniao(inep, id);
      else if (tipo === "excluir") {
        await deleteReuniao(inep, id);
        window.location.href = "/gestor/reunioes";
        return;
      }
      await carregar();
      addToast(
        { realizada: "Reunião marcada como realizada.", cancelar: "Reunião cancelada." }[tipo],
        "success",
      );
    } catch (err) {
      const msg = onApiError(err, "Não foi possível concluir a ação.");
      if (msg) addToast(msg, "error");
    } finally {
      acaoOcupada = false;
    }
  }

  async function salvarAtaAtual() {
    if (salvandoAta) return;
    salvandoAta = true;
    try {
      const atual = await salvarAta(inep, id, ataTexto);
      reuniao = atual;
      ataTexto = atual.ata_texto ?? "";
      addToast("Ata salva.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível salvar a ata.");
      if (msg) addToast(msg, "error");
    } finally {
      salvandoAta = false;
    }
  }

  function validarArquivo(file) {
    const ext = (file.name.split(".").pop() ?? "").toLowerCase();
    if (!ANEXO_EXTENSOES.includes(ext)) {
      addToast(`Extensão não permitida: ${ext || "sem extensão"}.`, "warning");
      return false;
    }
    if (file.size > L.MAX_UPLOAD_BYTES) {
      addToast(`Máximo de ${L.MAX_UPLOAD_LABEL} por arquivo.`, "warning");
      return false;
    }
    return true;
  }

  async function aoEscolherArquivo(tipo, event) {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    if (!validarArquivo(file)) return;
    enviando = tipo;
    try {
      const atual = await uploadAnexo(inep, id, tipo, file);
      reuniao = atual;
      addToast(`${ANEXO_LABELS[tipo]} enviada.`, "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível enviar o anexo.");
      if (msg) addToast(msg, "error");
    } finally {
      enviando = null;
    }
  }

  async function baixarAnexo(tipo) {
    try {
      const { blob, filename } = await downloadAnexo(inep, id, tipo);
      const urlObj = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = urlObj;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(urlObj);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível baixar o anexo.");
      if (msg) addToast(msg, "error");
    }
  }

  function dataHora(iso) {
    if (!iso) return "—";
    const d = new Date(iso.replace(" ", "T"));
    return Number.isNaN(d.getTime())
      ? iso
      : d.toLocaleDateString("pt-BR") + " " + d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
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
    await iniciar();
  }

  onMount(() => {
    restaurarSessao();
    iniciar();
  });
</script>

<div class="space-y-6 max-w-3xl mx-auto">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">{reuniao?.titulo ?? "Reunião"}</h1>
      <p class="text-sm text-gray-600 mt-1">{inep ? `Escola ${inep}` : ""}</p>
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
      <a href="/gestor/reunioes" class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors">
        ← Lista
      </a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando reunião…</p></div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para ver a reunião." />
  {:else if reuniao}
    <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-5">
      <section class="flex flex-wrap items-center gap-2">
        <span class={`rounded-full px-3 py-1 text-xs font-semibold ${REUNIAO_STATUS_BADGE[reuniao.status] ?? "bg-gray-100 text-gray-600"}`}>
          {REUNIAO_STATUS_LABELS[reuniao.status] ?? reuniao.status}
        </span>
        <span class="text-xs text-gray-500">{AVISO_METODO_LABELS[reuniao.aviso_metodo] ?? reuniao.aviso_metodo}</span>
        <span class="text-xs text-gray-500">{reuniao.n_participantes} participante(s)</span>
      </section>

      <dl class="grid gap-3 sm:grid-cols-2 text-sm">
        <div>
          <dt class="text-xs text-gray-500 uppercase tracking-wide">Data e hora</dt>
          <dd class="text-gray-900">{dataHora(reuniao.quando)}</dd>
        </div>
        <div>
          <dt class="text-xs text-gray-500 uppercase tracking-wide">Duração</dt>
          <dd class="text-gray-900">{reuniao.duracao_min} min</dd>
        </div>
        <div>
          <dt class="text-xs text-gray-500 uppercase tracking-wide">Onde</dt>
          <dd class="text-gray-900">
            {#if reuniao.onde_label}
              {reuniao.onde_label}
              {#if reuniao.onde_link}
                · <a href={reuniao.onde_link} target="_blank" rel="noopener noreferrer" class="text-blue-600 hover:underline">abrir link</a>
              {/if}
            {:else}<span class="text-gray-400">não informado</span>{/if}
          </dd>
        </div>
        <div>
          <dt class="text-xs text-gray-500 uppercase tracking-wide">Cadastrada por</dt>
          <dd class="text-gray-900">{reuniao.gestor?.nome ?? "—"}</dd>
        </div>
      </dl>

      {#if convite}
        <ConviteBox convite={convite} telefoneInicial={telefoneInicial} />
      {/if}

      {#if reuniao.pauta_texto}
        <section>
          <h2 class="text-xs font-semibold uppercase tracking-wide text-gray-500">Pauta</h2>
          <p class="mt-1 whitespace-pre-wrap text-sm text-gray-700">{reuniao.pauta_texto}</p>
        </section>
      {/if}

      <section>
        <h2 class="text-xs font-semibold uppercase tracking-wide text-gray-500">Participantes</h2>
        <ul class="mt-2 divide-y divide-gray-100 border border-gray-200 rounded-md">
          {#each reuniao.participantes ?? [] as p (p.id)}
            <li class="px-3 py-2 flex items-center justify-between gap-2">
              <div class="min-w-0">
                <p class="text-sm text-gray-900">{p.nome}</p>
                <p class="text-[11px] text-gray-400 truncate">
                  {[p.email, p.telefone, p.cargo].filter(Boolean).join(" · ") || "sem contato"}
                </p>
              </div>
              {#if p.via_grupo_nome}
                <span class="shrink-0 rounded-full bg-gray-100 text-gray-600 px-2 py-0.5 text-[10px]">{p.via_grupo_nome}</span>
              {/if}
            </li>
          {:else}
            <li class="px-3 py-4 text-center text-xs text-gray-400">Nenhum participante.</li>
          {/each}
        </ul>
      </section>

      <!-- anexos pauta/ata -->
      <section class="space-y-3">
        <h2 class="text-xs font-semibold uppercase tracking-wide text-gray-500">Anexos</h2>
        {#each ["pauta", "ata"] as tipo (tipo)}
          {@const anexo = ax[tipo]}
          <div class="flex flex-wrap items-center justify-between gap-2 rounded-md border border-gray-200 p-3">
            <div class="min-w-0">
              <p class="text-sm font-medium text-gray-900">{ANEXO_LABELS[tipo]}{anexo ? "" : " (nenhuma enviada)"}</p>
              {#if anexo}
                <p class="text-[11px] text-gray-400">
                  {anexo.nome_original} · {TAMANHO_LABEL(anexo.tamanho)} · {dataHora(anexo.criado_em)}
                </p>
              {/if}
            </div>
            <div class="flex items-center gap-2">
              {#if anexo}
                <button
                  type="button"
                  onclick={() => baixarAnexo(tipo)}
                  class="px-3 py-1.5 rounded-md bg-gray-200 text-gray-700 text-xs font-medium hover:bg-gray-300 transition-colors"
                >Baixar</button>
              {/if}
              <label class="relative cursor-pointer px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors">
                {enviando === tipo ? "Enviando…" : anexo ? "Substituir" : "Enviar"}
                <input
                  type="file"
                  accept={ANEXO_EXTENSOES.map((e) => `.${e}`).join(",")}
                  class="sr-only"
                  onchange={(e) => aoEscolherArquivo(tipo, e)}
                  disabled={enviando === tipo}
                />
              </label>
            </div>
          </div>
        {/each}
      </section>

      <!-- ata em texto -->
      <section class="space-y-2">
        <div class="flex items-center justify-between">
          <h2 class="text-xs font-semibold uppercase tracking-wide text-gray-500">Ata (decisões da reunião)</h2>
          {#if reuniao.status === "cancelada"}
            <span class="text-[11px] text-gray-400">reunião cancelada — ata não pode ser salva</span>
          {/if}
        </div>
        <textarea
          bind:value={ataTexto}
          maxlength={L.ATA_MAX}
          rows="6"
          disabled={reuniao.status === "cancelada"}
          placeholder="O que ficou decidido? Quem assume o quê? Até quando?"
          class="w-full rounded-md border border-gray-300 text-sm p-3 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-50"
        ></textarea>
        <div class="flex items-center justify-between">
          <span class="text-[11px] text-gray-400">{ataTexto.length}/{L.ATA_MAX}</span>
          <button
            type="button"
            onclick={salvarAtaAtual}
            disabled={salvandoAta || reuniao.status === "cancelada"}
            class="px-4 py-2 rounded-md bg-green-600 text-white text-sm font-medium hover:bg-green-700 disabled:opacity-40 transition-colors"
          >{salvandoAta ? "Salvando…" : "Salvar ata"}</button>
        </div>
      </section>

      <!-- status / ações -->
      <section class="flex flex-wrap items-center gap-2 pt-4 border-t border-gray-100">
        {#if reuniao.status === "agendada"}
          <button
            type="button"
            onclick={() => transicao("realizada")}
            disabled={acaoOcupada}
            class="px-4 py-2 rounded-md bg-green-600 text-white text-sm font-medium hover:bg-green-700 disabled:opacity-40 transition-colors"
          >Marcar como realizada</button>
          <button
            type="button"
            onclick={() => transicao("cancelar")}
            disabled={acaoOcupada}
            class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 disabled:opacity-40 transition-colors"
          >Cancelar</button>
          <a
            href={`/gestor/reunioes/${id}/editar`}
            class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
          >Editar</a>
        {/if}
        {#if reuniao.status === "cancelada"}
          <button
            type="button"
            onclick={() => transicao("excluir")}
            disabled={acaoOcupada}
            class="px-4 py-2 rounded-md bg-red-50 text-red-600 text-sm font-medium hover:bg-red-100 disabled:opacity-40 transition-colors"
          >Excluir</button>
        {/if}
      </section>
    </div>
  {/if}
</div>