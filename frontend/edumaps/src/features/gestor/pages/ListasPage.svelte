<!-- src/features/gestor/pages/ListasPage.svelte -->
<script>
  // Listas e QR: cria listas nomeadas, gera/rotaciona o QR code de
  // autoinscrição e vê os contatos que se inscreveram (issue #208, Fase 0).
  // Issue #212: a lista pode exigir a confirmação do telefone; o gestor liga/
  // desliga a opção, vê o estado de cada membro (selo) e filtra por estado.
  // Exige sessão do gestor: sem token mostra o cartão de login; 401 volta ao login.
  import { onMount } from "svelte";
  import {
    listListas,
    createLista,
    atualizarLista,
    getLista,
    deleteLista,
    gerarQrCode,
    revogarQrCode,
    listInscricoes,
  } from "../api/gestorCanaisApi.js";
  import { fetchMe, logoutGestor } from "../api/gestorPesquisasApi.js";
  import { ApiError } from "@/shared/api/client.js";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { restaurarSessao } from "../utils/gestorAuth.js";
  import { setSessaoToken, clearSessaoToken } from "../utils/gestorSession.js";
  import GestorLoginCard from "../components/survey/GestorLoginCard.svelte";
  import QRModal from "../components/canais/QRModal.svelte";
  import MembrosTable from "../components/canais/MembrosTable.svelte";

  let inep = $state(null);
  let gestor = $state(null);
  let carregando = $state(true);
  let error = $state(null);
  let precisaLogin = $state(false);

  let listas = $state([]);
  let novaAberto = $state(false);
  let nova = $state({ nome: "", descricao: "", exige_confirmacao: false });

  let selecionada = $state(null);
  let membros = $state([]);
  let membrosCarregando = $state(false);
  let filtroEstado = $state("todos"); // todos | confirmado | pendente | nao_exigida
  let salvandoExige = $state(false);

  const FILTROS = [
    { valor: "todos", rotulo: "Todos" },
    { valor: "confirmado", rotulo: "Confirmados" },
    { valor: "pendente", rotulo: "Pendentes" },
    { valor: "nao_exigida", rotulo: "Não exigida" },
  ];

  let membrosFiltrados = $derived(
    filtroEstado === "todos" ? membros : membros.filter((m) => m.estado === filtroEstado),
  );

  let qrcodeAberto = $state(null); // { lista, qrcode }
  let gerando = $state(false);
  let revogando = $state(false);

  const onApiError = (err, padrao) => {
    if (err instanceof ApiError && err.status === 401) {
      precisaLogin = true;
      return "";
    }
    return err instanceof ApiError ? err.message : padrao;
  };

  function atualizarListaLocal(detalhe) {
    if (!detalhe || detalhe.id == null) return;
    listas = listas.map((l) => (l.id === detalhe.id ? { ...l, ...detalhe } : l));
  }

  async function carregarTudo() {
    carregando = true;
    error = null;
    precisaLogin = false;
    try {
      const me = await fetchMe();
      inep = me.cod_inep;
      gestor = me;
      listas = await listListas(me.cod_inep);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as listas.");
      if (msg) error = msg;
    } finally {
      carregando = false;
    }
  }

  async function criarLista() {
    const nome = nova.nome.trim();
    if (!nome) {
      addToast("Informe o nome da lista.", "warning");
      return;
    }
    error = null;
    try {
      const criada = await createLista(inep, {
        nome,
        descricao: nova.descricao.trim() || null,
        exige_confirmacao: nova.exige_confirmacao,
      });
      listas = [criada, ...listas];
      nova = { nome: "", descricao: "", exige_confirmacao: false };
      novaAberto = false;
      addToast("Lista criada.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível criar a lista.");
      if (msg) error = msg;
    }
  }

  async function excluirLista(lista) {
    if (!window.confirm(`Excluir a lista "${lista.nome}"? Os contatos ficam na agenda da escola.`)) {
      return;
    }
    try {
      await deleteLista(inep, lista.id);
      listas = listas.filter((l) => l.id !== lista.id);
      if (selecionada === lista.id) {
        selecionada = null;
        membros = [];
      }
      addToast("Lista excluída.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível excluir a lista.");
      if (msg) addToast(msg, "error");
    }
  }

  async function alternarExigeConfirmacao(lista, exige, el = null) {
    salvandoExige = true;
    try {
      const detalhe = await atualizarLista(inep, lista.id, { exige_confirmacao: exige });
      atualizarListaLocal({ ...detalhe, id: lista.id, exige_confirmacao: exige });
      addToast(
        exige
          ? "Confirmação do telefone passou a ser exigida."
          : "Confirmação do telefone deixou de ser exigida.",
        "success",
      );
      // o estado derivado dos membros muda (pendente ↔ não exigida)
      if (selecionada === lista.id) {
        membros = await listInscricoes(inep, lista.id);
      }
    } catch (err) {
      if (el) el.checked = !exige; // desfaz o clique: a lista não mudou
      const msg = onApiError(err, "Não foi possível atualizar a lista.");
      if (msg) addToast(msg, "error");
    } finally {
      salvandoExige = false;
    }
  }

  async function abrirMembros(lista) {
    selecionada = lista.id;
    filtroEstado = "todos";
    membrosCarregando = true;
    membros = [];
    try {
      const [rows, detalhe] = await Promise.all([
        listInscricoes(inep, lista.id),
        getLista(inep, lista.id).catch(() => null),
      ]);
      membros = rows;
      atualizarListaLocal(detalhe);
    } catch (err) {
      const msg = onApiError(err, "Não foi possível carregar as inscrições.");
      if (msg) addToast(msg, "error");
    } finally {
      membrosCarregando = false;
    }
  }

  async function abrirQr(lista) {
    qrcodeAberto = { lista, qrcode: lista.qrcode ?? null };
  }

  async function gerarQr(lista) {
    gerando = true;
    try {
      const qr = await gerarQrCode(inep, lista.id);
      atualizarListaLocal({ id: lista.id, qrcode: qr });
      qrcodeAberto = { lista: { ...lista, qrcode: qr }, qrcode: qr };
      addToast("QR code gerado.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível gerar o QR code.");
      if (msg) addToast(msg, "error");
    } finally {
      gerando = false;
    }
  }

  async function revogarQr() {
    if (!qrcodeAberto) return;
    const alvo = qrcodeAberto.lista;
    revogando = true;
    try {
      await revogarQrCode(inep, alvo.id);
      atualizarListaLocal({ id: alvo.id, qrcode: null });
      qrcodeAberto = null;
      addToast("QR revogado. O link deixa de funcionar.", "success");
    } catch (err) {
      const msg = onApiError(err, "Não foi possível revogar o QR.");
      if (msg) addToast(msg, "error");
    } finally {
      revogando = false;
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
      <h1 class="text-2xl font-bold text-gray-900">Listas e QR</h1>
      <p class="text-sm text-gray-600 mt-1">
        {inep ? `Escola ${inep} · ` : ""}crie uma lista e colete contatos por QR code.
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
        href="/gestor/contatos"
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >Contatos →</a>
      <a
        href={inep ? `/gestor/painel?inep=${inep}` : "/gestor/painel"}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >← Painel</a>
    </div>
  </header>

  {#if carregando}
    <div class="text-center py-12"><p class="text-gray-500">Carregando listas…</p></div>
  {:else if error}
    <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-sm p-4">{error}</div>
  {:else if precisaLogin}
    <GestorLoginCard onLogin={onLogin} mensagem="Entre para gerenciar as listas e QR codes." />
  {:else}
    <section class="rounded-card bg-white border border-gray-200 shadow-card p-5 space-y-3">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-sm font-semibold text-gray-900">Suas listas ({listas.length})</h2>
        <button
          type="button"
          onclick={() => { novaAberto = !novaAberto; }}
          class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-medium hover:bg-blue-700 transition-colors"
        >{novaAberto ? "Cancelar" : "+ Nova lista"}</button>
      </div>

      {#if novaAberto}
        <form
          onsubmit={(e) => { e.preventDefault(); criarLista(); }}
          class="rounded-md border border-blue-200 bg-blue-50/50 p-3 space-y-2"
        >
          <input
            bind:value={nova.nome}
            placeholder="Nome da lista (ex.: Responsáveis 6ºA)"
            maxlength="120"
            class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <input
            bind:value={nova.descricao}
            placeholder="Descrição (opcional)"
            class="w-full h-9 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <label class="flex items-start gap-2 text-sm text-gray-700 cursor-pointer">
            <input
              type="checkbox"
              bind:checked={nova.exige_confirmacao}
              class="mt-0.5 accent-blue-600"
            />
            <span>
              Exigir confirmação do telefone
              <span class="block text-xs text-gray-500">
                Quem se inscrever confirma o número pelo Telegram ou WhatsApp.
              </span>
            </span>
          </label>
          <button
            type="submit"
            class="w-full h-9 rounded-md bg-blue-600 text-white text-sm font-medium hover:bg-blue-700 transition-colors"
          >Criar lista</button>
        </form>
      {/if}

      {#if listas.length === 0}
        <p class="py-6 text-center text-sm text-gray-400">
          Nenhuma lista ainda. Crie a primeira e gere um QR code.
        </p>
      {:else}
        <ul class="divide-y divide-gray-100">
          {#each listas as lista (lista.id)}
            <li class="py-3 flex flex-wrap items-center justify-between gap-3" data-testid="lista-row">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-900">{lista.nome}</p>
                <p class="text-xs text-gray-500">
                  {lista.n_membros ?? 0} contato(s) · {lista.canal ?? "telefone"}
                  {#if lista.qrcode}
                    · <span class="text-green-700 font-medium">QR ativo</span>
                  {:else}
                    · <span class="text-gray-400">sem QR</span>
                  {/if}
                  {#if lista.exige_confirmacao}
                    · <span class="text-blue-700 font-medium">exige confirmação</span>
                  {/if}
                </p>
              </div>
              <div class="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  aria-label={`Ver inscrições de ${lista.nome}`}
                  onclick={() => abrirMembros(lista)}
                  class="px-2 py-1 rounded text-xs text-gray-600 hover:bg-gray-100 transition-colors"
                >Inscrições</button>
                <button
                  type="button"
                  aria-label={`QR code de ${lista.nome}`}
                  onclick={() => abrirQr(lista)}
                  class="px-2 py-1 rounded text-xs text-blue-700 hover:bg-blue-50 transition-colors"
                >{lista.qrcode ? "Ver QR" : "Gerar QR"}</button>
                <button
                  type="button"
                  aria-label={`Excluir lista ${lista.nome}`}
                  onclick={() => excluirLista(lista)}
                  class="px-2 py-1 rounded text-xs text-red-600 hover:bg-red-50 transition-colors"
                >Excluir</button>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </section>

    {#if selecionada != null}
      {@const listaSel = listas.find((l) => l.id === selecionada)}
      <section class="space-y-2" data-testid="lista-detalhe">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <h2 class="text-sm font-semibold text-gray-900">
            Inscrições — {listaSel?.nome ?? ""}
          </h2>
          {#if listaSel}
            <label class="flex items-center gap-2 text-xs text-gray-700 cursor-pointer">
              <input
                type="checkbox"
                checked={Boolean(listaSel.exige_confirmacao)}
                disabled={salvandoExige}
                onchange={(e) => alternarExigeConfirmacao(listaSel, e.currentTarget.checked, e.currentTarget)}
                class="accent-blue-600"
              />
              Exigir confirmação do telefone
            </label>
          {/if}
        </div>

        <div class="flex flex-wrap items-center justify-between gap-2">
          {#if listaSel?.exige_confirmacao}
            <p class="text-xs text-gray-600" data-testid="contadores-confirmacao">
              <span class="font-semibold text-green-700">{listaSel.membros_confirmados ?? 0}</span> confirmado(s)
              · <span class="font-semibold text-amber-700">{listaSel.membros_pendentes ?? 0}</span> pendente(s)
            </p>
          {/if}
          <label class="ml-auto flex items-center gap-2 text-xs text-gray-600">
            Estado
            <select
              bind:value={filtroEstado}
              aria-label="Filtrar por estado"
              class="h-8 px-2 rounded-md border border-gray-300 text-xs bg-white"
            >
              {#each FILTROS as f (f.valor)}
                <option value={f.valor}>{f.rotulo}</option>
              {/each}
            </select>
          </label>
        </div>

        <MembrosTable
          membros={membrosFiltrados}
          carregando={membrosCarregando}
          mensagemVazia={membros.length > 0
            ? "Nenhuma inscrição neste estado."
            : undefined}
        />
      </section>
    {/if}
  {/if}

  {#if qrcodeAberto}
    <QRModal
      lista={qrcodeAberto.lista}
      qrcode={qrcodeAberto.qrcode}
      {gerando}
      {revogando}
      onFechar={() => (qrcodeAberto = null)}
      onGerar={() => gerarQr(qrcodeAberto.lista)}
      onRevogar={revogarQr}
    />
  {/if}
</div>
