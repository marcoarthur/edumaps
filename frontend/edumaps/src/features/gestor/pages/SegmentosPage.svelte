<!-- src/features/gestor/pages/SegmentosPage.svelte -->
<script>
  // Listas dinâmicas (segmentos, issue #216, Fase 3): um critério sobre as
  // listas da escola (estados, e-mail confirmado, período de inscrição) que
  // vira alvo de envio por e-mail. Lista, cria/edita com prévia ao vivo e apaga.
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao login.
  import { onMount } from "svelte";
  import {
    listSegmentos,
    createSegmento,
    atualizarSegmento,
    deleteSegmento,
  } from "../api/gestorEnviosApi.js";
  import { listListas } from "../api/gestorCanaisApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import SegmentoForm from "../components/envios/SegmentoForm.svelte";
  import ConfirmDialog from "@/shared/ui/components/ConfirmDialog.svelte";
  import { ESTADOS_MEMBRO } from "../constants/envios.js";

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let segmentos = $state([]);
  let listas = $state([]);

  let formAberto = $state(false);
  let editando = $state(null); // segmento ou null (novo)
  let formKey = $state(0);
  let salvando = $state(false);
  let erroForm = $state(null);

  let apagando = $state(null);
  let apagandoOcupado = $state(false);
  let erroApagar = $state(null);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  const ordenar = (rows) => [...rows].sort((a, b) => a.nome.localeCompare(b.nome, "pt-BR"));

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      const [segs, ls] = await Promise.all([listSegmentos(inep), listListas(inep)]);
      segmentos = segs;
      listas = ls;
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as listas dinâmicas.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  function abrirForm(seg = null) {
    editando = seg;
    erroForm = null;
    formKey += 1;
    formAberto = true;
  }

  async function salvar(dados) {
    salvando = true;
    erroForm = null;
    try {
      if (editando) {
        const salvo = await atualizarSegmento(inep, editando.id, dados);
        segmentos = ordenar(segmentos.map((s) => (s.id === salvo.id ? salvo : s)));
        addToast("Lista dinâmica atualizada.", "success");
      } else {
        const criado = await createSegmento(inep, dados);
        segmentos = ordenar([...segmentos, criado]);
        addToast("Lista dinâmica criada.", "success");
      }
      formAberto = false;
      editando = null;
    } catch (err) {
      if (err instanceof ApiError && err.status === 409) {
        erroForm = "Já existe uma lista dinâmica com esse nome.";
      } else {
        const msg = onApiError(err, "Não foi possível salvar a lista dinâmica.");
        if (msg) erroForm = msg;
        else formAberto = false;
      }
    } finally {
      salvando = false;
    }
  }

  async function confirmarApagar() {
    if (!apagando) return;
    apagandoOcupado = true;
    erroApagar = null;
    try {
      await deleteSegmento(inep, apagando.id);
      segmentos = segmentos.filter((s) => s.id !== apagando.id);
      apagando = null;
      addToast("Lista dinâmica apagada.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível apagar a lista dinâmica.");
      if (msg) erroApagar = msg;
      else apagando = null;
    } finally {
      apagandoOcupado = false;
    }
  }

  function resumo(seg) {
    const c = seg.criterios ?? {};
    const partes = [];
    if (c.estado?.length) {
      partes.push(
        c.estado.map((v) => ESTADOS_MEMBRO.find((e) => e.valor === v)?.rotulo ?? v).join(", "),
      );
    }
    if (c.email_confirmado === true) partes.push("e-mail confirmado");
    if (c.email_confirmado === false) partes.push("e-mail não confirmado");
    if (c.inscritos_desde) partes.push(`desde ${c.inscritos_desde.split("-").reverse().join("/")}`);
    if (c.inscritos_ate) partes.push(`até ${c.inscritos_ate.split("-").reverse().join("/")}`);
    return partes.length ? partes.join(" · ") : "todos os inscritos com e-mail";
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
</script>

<div class="space-y-6">
  <header class="flex flex-wrap items-center justify-between gap-3">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Listas dinâmicas</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}junte e filtre as suas listas para enviar e-mails.
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
        href="/gestor/envios"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Envios</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando listas dinâmicas…</p></div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerenciar as listas dinâmicas." />
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4" role="alert">{error}</div>
  {:else if formAberto}
    {#key formKey}
      <SegmentoForm
        {inep}
        segmento={editando}
        {listas}
        ocupado={salvando}
        erro={erroForm}
        onSalvar={salvar}
        onCancelar={() => { formAberto = false; editando = null; }}
        onSessaoExpirada={() => (precisaLogin = true)}
      />
    {/key}
  {:else}
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-sm font-semibold text-gray-900">Suas listas dinâmicas ({segmentos.length})</h2>
        <button
          type="button"
          onclick={() => abrirForm()}
          class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
        >+ Nova lista dinâmica</button>
      </div>

      {#if segmentos.length === 0}
        <p class="py-6 text-center text-sm text-gray-400">
          Nenhuma lista dinâmica ainda. Crie uma juntando listas e filtrando quem recebe.
        </p>
      {:else}
        <ul class="divide-y divide-gray-100">
          {#each segmentos as s (s.id)}
            <li class="py-3 flex flex-wrap items-center justify-between gap-3" data-testid="segmento-row">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-900">{s.nome}</p>
                <p class="text-xs text-gray-500">
                  {#each s.listas ?? [] as l, i (l.id)}
                    {i > 0 ? ", " : ""}{#if l.existe}{l.nome}{:else}<span class="text-amber-700">lista excluída</span>{/if}
                  {/each}
                  · {resumo(s)}
                </p>
              </div>
              <div class="flex items-center gap-1 shrink-0">
                <a
                  href={`/gestor/envios?novo=1&alvo_tipo=segmento&alvo_id=${s.id}`}
                  aria-label={`Enviar e-mail para ${s.nome}`}
                  class="px-2 py-1 rounded text-xs text-blue-700 hover:bg-blue-50 transition-colors"
                >Enviar e-mail</a>
                <button
                  type="button"
                  aria-label={`Editar ${s.nome}`}
                  onclick={() => abrirForm(s)}
                  class="px-2 py-1 rounded text-xs text-gray-600 hover:bg-gray-100 transition-colors"
                >Editar</button>
                <button
                  type="button"
                  aria-label={`Apagar ${s.nome}`}
                  onclick={() => { erroApagar = null; apagando = s; }}
                  class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50 transition-colors"
                >Apagar</button>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {/if}

  {#if apagando}
    <ConfirmDialog
      titulo="Apagar lista dinâmica"
      descricao={`A lista dinâmica "${apagando.nome}" será apagada. As listas e os inscritos não mudam.`}
      confirmarRotulo="Apagar"
      perigo
      ocupado={apagandoOcupado}
      erro={erroApagar}
      onConfirmar={confirmarApagar}
      onCancelar={() => (apagando = null)}
      testid="apagar-segmento-dialog"
    />
  {/if}
</div>
