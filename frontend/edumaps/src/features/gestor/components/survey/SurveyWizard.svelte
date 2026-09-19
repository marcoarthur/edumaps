<!-- src/features/gestor/components/survey/SurveyWizard.svelte -->
<script>
  // Wizard de criação de pesquisas do gestor (fase 1). Fluxo:
  //   0. Seus dados (upsert do gestor por e-mail — só se ainda não salvo)
  //   1. Dados da pesquisa (título + descrição)
  //   2..n. Uma pergunta por tela (autosave a cada edição)
  //   n+1. Revisão + Finalizar (publica → read-only)
  // Autosave: debounce -> PUT (id existe) ou POST (primeiro save do rascunho).
  import { onMount, tick } from "svelte";
  import { addToast } from "@/shared/stores/toastStore.js";
  import { ApiError } from "@/shared/api/client.js";
  import StepsIndicator from "./StepsIndicator.svelte";
  import PhoneMockup from "./PhoneMockup.svelte";
  import QuestionEditor from "./QuestionEditor.svelte";
  import { upsertGestor, createPesquisa, updatePesquisa, finalizarPesquisa } from "../../api/gestorPesquisasApi.js";
  import { setGestorSession } from "../../utils/gestorSession.js";
  import {
    emptyDraft,
    surveyToDraft,
    draftToPayload,
    newPergunta,
    perguntaErros,
    tituloValido,
    draftValidoParaFinalizar,
  } from "../../utils/pesquisaDraft.js";
  import { LIMITS } from "../../constants/pesquisas.js";

  /** @type {{
   *   inep: string|number,
   *   gestorId?: number|null,
   *   initialGestor?: object|null,
   *   initialSurvey?: object|null,
   *   readonly?: boolean,
   * }} */
  let {
    inep,
    gestorId = null,
    initialGestor = null,
    initialSurvey = null,
    readonly = false,
  } = $props();

  // ---- estado -----------------------------------------------------------
  let gestor = $state(initialGestor); // gestor salvo no servidor (id presente)
  let gestorNome = $state(initialGestor?.nome ?? "");
  let gestorEmail = $state(initialGestor?.email ?? "");
  let gestorTelefone = $state(initialGestor?.telefone ?? "");
  let gestorCargo = $state(initialGestor?.cargo ?? "");
  let gestorCpf = $state("");
  let gestorSenha = $state("");
  let salvandoGestor = $state(false);
  let gestorErro = $state(null);

  let draft = $state(initialSurvey ? surveyToDraft(initialSurvey) : emptyDraft());
  let step = $state(0);

  let saving = $state(false);
  let savedAt = $state(null); // Date ou "editando"
  let saveError = $state(null);

  let autosaveTimer = null;

  let finalized = $derived(readonly || draft.status === "publicada");

  // ---- etapas -----------------------------------------------------------
  let stepKeys = $derived((() => {
    const keys = [];
    if (!gestor && !finalized) keys.push("gestor");
    if (!finalized) keys.push("info");
    for (let i = 0; i < draft.perguntas.length; i += 1) keys.push(`q${i}`);
    keys.push("revisao");
    return keys;
  })());

  let stepLabels = $derived(
    stepKeys.map((k) => {
      if (k === "gestor") return "Seus dados";
      if (k === "info") return "Dados da pesquisa";
      if (k === "revisao") return "Revisão e finalizar";
      return `Pergunta ${Number(k.slice(1)) + 1}`;
    }),
  );

  let currentKey = $derived(stepKeys[step] ?? "revisao");
  let isQuestionStep = $derived(/^q\d+$/.test(currentKey));
  let questionIndex = $derived(isQuestionStep ? Number(currentKey.slice(1)) : -1);

  $effect(() => {
    if (step > stepKeys.length - 1) step = stepKeys.length - 1;
  });

  function goTo(index) {
    if (index < 0 || index >= stepKeys.length) return;
    step = index;
  }

  function goToKey(key) {
    const i = stepKeys.indexOf(key);
    if (i >= 0) step = i;
  }

  // ---- gestor -----------------------------------------------------------
  function gestorValido() {
    const senhaOk = gestorSenha.trim().length >= LIMITS.SENHA_MIN;
    return (
      gestorNome.trim().length >= LIMITS.NOME_MIN &&
      senhaOk &&
      /^\S+@\S+\.\S+$/.test(gestorEmail.trim())
    );
  }

  async function saveGestor() {
    if (!gestorValido()) {
      gestorErro =
        "Informe nome, e-mail e uma senha com pelo menos " + LIMITS.SENHA_MIN + " caracteres.";
      return;
    }
    salvandoGestor = true;
    gestorErro = null;
    try {
      const payload = {
        cod_inep: inep,
        nome: gestorNome.trim(),
        email: gestorEmail.trim(),
        senha: gestorSenha,
      };
      if (gestorTelefone.trim()) payload.telefone = gestorTelefone.trim();
      if (gestorCargo.trim()) payload.cargo = gestorCargo.trim();
      if (gestorCpf.replace(/\D/g, "") === "") {
        // cpf vazio: não enviar (o backend preserva o anterior)
      } else {
        payload.cpf = gestorCpf.replace(/\D/g, "");
      }
      gestor = await upsertGestor(payload);
      gestorSenha = "";
      setGestorSession(inep, gestor);
      goToKey("info");
      addToast("Dados salvos. Vamos montar sua pesquisa!", "success");
    } catch (err) {
      gestorErro =
        err instanceof ApiError
          ? err.message
          : "Não foi possível salvar seus dados.";
    } finally {
      salvandoGestor = false;
    }
  }

  // ---- link público (publicada) -----------------------------------------
  let linkPublico = $derived(
    draft?.token ? `${window.location.origin}/p/${draft.token}` : null,
  );

  async function copiarLink() {
    if (!linkPublico) return;
    try {
      await navigator.clipboard.writeText(linkPublico);
      addToast("Link de resposta copiado! Compartilhe com a comunidade.", "success");
    } catch {
      addToast("Não foi possível copiar o link.", "error");
    }
  }

  // ---- autosave ---------------------------------------------------------
  function scheduleAutosave() {
    if (finalized) return;
    savedAt = "editando";
    saveError = null;
    clearTimeout(autosaveTimer);
    autosaveTimer = setTimeout(save, LIMITS.AUTOSAVE_MS);
  }

  async function save() {
    if (finalized || !gestor?.id) return;
    if (!tituloValido(draft.titulo)) {
      savedAt = null;
      return;
    }
    saving = true;
    saveError = null;
    try {
      const payload = draftToPayload(draft);
      if (draft.id) {
        draft = surveyToDraft(await updatePesquisa(draft.id, payload));
      } else {
        draft = surveyToDraft(
          await createPesquisa({ gestor_id: gestor.id, ...payload }),
        );
      }
      savedAt = new Date();
    } catch (err) {
      saveError =
        err instanceof ApiError ? err.message : "Não foi possível salvar o rascunho.";
      savedAt = null;
    } finally {
      saving = false;
    }
  }

  function flushAutosave() {
    clearTimeout(autosaveTimer);
    save();
  }

  // ---- perguntas --------------------------------------------------------
  function addPergunta() {
    if (draft.perguntas.length >= LIMITS.MAX_PERGUNTAS) return;
    draft.perguntas.push(newPergunta());
    tick().then(() => goToKey(`q${draft.perguntas.length - 1}`));
    scheduleAutosave();
  }

  function remPergunta(index) {
    draft.perguntas.splice(index, 1);
    scheduleAutosave();
    goToKey("info");
  }

  // ---- finalizar --------------------------------------------------------
  async function finalize() {
    const problema = draftValidoParaFinalizar(draft);
    if (problema) {
      addToast(problema, "warning");
      return;
    }
    try {
      const updated = await finalizarPesquisa(draft.id);
      draft = surveyToDraft(updated);
      savedAt = new Date();
      addToast("Pesquisa publicada! 🎉", "success");
    } catch (err) {
      addToast(
        err instanceof ApiError ? err.message : "Não foi possível publicar.",
        "error",
      );
    }
  }

  function voltarParaLista() {
    window.location.href = `/gestor/pesquisas?inep=${inep}`;
  }

  onMount(() => {
    const flush = () => flushAutosave();
    window.addEventListener("beforeunload", flush);
    return () => {
      clearTimeout(autosaveTimer);
      window.removeEventListener("beforeunload", flush);
    };
  });

  // ---- indicadores ------------------------------------------------------
  function savedLabel() {
    if (saveError) return "Erro ao salvar — tente novamente.";
    if (saving) return "Salvando…";
    if (savedAt === "editando") return "Editando…";
    if (savedAt instanceof Date)
      return `Salvo às ${savedAt.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" })}`;
    return !gestor?.id ? "Salve seus dados para começar." : "Nada a salvar ainda.";
  }
</script>

{#if finalized}
  <div class="rounded-card bg-white border border-green-200 shadow-card p-6 space-y-5">
    <div class="rounded-md bg-green-50 border border-green-200 text-green-800 text-sm p-4">
      <p class="font-semibold">Pesquisa publicada!</p>
      <p class="mt-1 text-xs">
        A comunidade já pode responder. Compartilhe o link por WhatsApp ou
        cartaz impresso — quem abrir responde sem precisar de conta.
      </p>
    </div>

    {#if linkPublico}
      <div
        class="rounded-md border border-gray-200 bg-gray-50 p-4"
        data-testid="link-publico"
      >
        <p class="text-sm font-medium text-gray-700">Link de resposta</p>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <input
            readonly
            value={linkPublico}
            aria-label="Link público de resposta"
            class="flex-1 min-w-[220px] h-9 px-3 rounded-md border border-gray-300 bg-white text-xs text-gray-600 focus:outline-none"
          />
          <button
            type="button"
            onclick={copiarLink}
            class="px-4 py-2 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 transition-colors"
          >
            Copiar link
          </button>
        </div>
        <a
          href={linkPublico}
          target="_blank"
          rel="noopener noreferrer"
          class="mt-2 inline-block text-xs text-blue-600 hover:underline"
        >
          Abrir em nova aba →
        </a>
      </div>
    {/if}

    <div class="flex justify-center">
      <PhoneMockup titulo={draft.titulo} descricao={draft.descricao} perguntas={draft.perguntas} />
    </div>
    <div class="flex justify-end">
      <button
        type="button"
        onclick={voltarParaLista}
        class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
      >
        ← Voltar à lista
      </button>
    </div>
  </div>
{:else}
  <div class="rounded-card bg-white border border-gray-200 shadow-card p-6 space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <StepsIndicator steps={stepLabels} current={step} />
      <p class="text-xs text-gray-500" aria-live="polite">{savedLabel()}</p>
    </div>

    {#if saveError}
      <div class="rounded-md bg-red-50 border border-red-200 text-red-700 text-xs px-3 py-2">
        {saveError}
      </div>
    {/if}

    {#if currentKey === "gestor"}
      <div class="space-y-4">
        <header>
          <h2 class="text-lg font-bold text-gray-900">Quem está montando a pesquisa?</h2>
          <p class="text-sm text-gray-600 mt-1">
            Sem login: usamos seu e-mail para reconhecer você na próxima visita
            a esta escola. Seus dados ficam gravados com a escola.
          </p>
        </header>
        <div class="grid gap-4 sm:grid-cols-2">
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Nome</span>
            <input
              type="text"
              bind:value={gestorNome}
              placeholder="Seu nome completo"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">E-mail</span>
            <input
              type="email"
              bind:value={gestorEmail}
              placeholder="voce@escola.gov.br"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Telefone (opcional)</span>
            <input
              type="tel"
              bind:value={gestorTelefone}
              placeholder="(00) 00000-0000"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block">
            <span class="block text-sm font-medium text-gray-700">Cargo (opcional)</span>
            <input
              type="text"
              bind:value={gestorCargo}
              placeholder="Ex.: Professora, Diretora…"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block sm:col-span-2">
            <span class="block text-sm font-medium text-gray-700">CPF (opcional, usado só para fins de controle — é mascarado)</span>
            <input
              type="text"
              inputmode="numeric"
              bind:value={gestorCpf}
              placeholder="000.000.000-00"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
          <label class="block sm:col-span-2">
            <span class="block text-sm font-medium text-gray-700">
              Senha (mínimo {LIMITS.SENHA_MIN} caracteres) — para ver os resultados depois
            </span>
            <input
              type="password"
              autocomplete="new-password"
              minlength={LIMITS.SENHA_MIN}
              maxlength={LIMITS.SENHA_MAX}
              bind:value={gestorSenha}
              placeholder="Crie uma senha"
              class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </label>
        </div>
        {#if gestorErro}
          <p class="text-sm text-red-600">{gestorErro}</p>
        {/if}
        <div class="flex justify-end">
          <button
            type="button"
            onclick={saveGestor}
            disabled={salvandoGestor || !gestorValido()}
            class="px-5 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {salvandoGestor ? "Salvando…" : "Salvar e começar"}
          </button>
        </div>
      </div>

    {:else if currentKey === "info"}
      <div class="space-y-5">
        <header>
          <h2 class="text-lg font-bold text-gray-900">Dados da pesquisa</h2>
          <p class="text-sm text-gray-600 mt-1">
            Dê um título claro — é ele que a comunidade vai ver no celular.
          </p>
        </header>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">Título</span>
          <input
            type="text"
            maxlength={LIMITS.TITULO_MAX}
            bind:value={draft.titulo}
            oninput={scheduleAutosave}
            placeholder="Ex.: Pesquisa de clima escolar"
            class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700">
            Convite à comunidade (opcional)
          </span>
          <textarea
            maxlength={LIMITS.DESCRICAO_MAX}
            bind:value={draft.descricao}
            oninput={scheduleAutosave}
            rows="3"
            placeholder="Ex.: Estamos ouvindo pais, alunos e professores para melhorar nossos projetos."
            class="mt-1 w-full px-3 py-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
          ></textarea>
        </label>

        <div>
          <p class="text-sm font-medium text-gray-700 mb-2">
            Perguntas ({draft.perguntas.length}/{LIMITS.MAX_PERGUNTAS})
          </p>
          {#if draft.perguntas.length > 0}
            <ul class="space-y-2">
              {#each draft.perguntas as p, i (p.id)}
                <li class="flex items-center gap-2 rounded-md border border-gray-200 px-3 py-2">
                  <button
                    type="button"
                    onclick={() => goToKey(`q${i}`)}
                    class="flex-1 text-left text-sm text-gray-800 hover:text-blue-600"
                  >
                    <span class="mr-2 text-gray-400">{i + 1}.</span>
                    {p.texto ? p.texto : "Pergunta sem texto"}
                    {#if p.obrigatoria}<span class="text-red-500">*</span>{/if}
                  </button>
                  <button
                    type="button"
                    onclick={() => remPergunta(i)}
                    aria-label={`Remover pergunta ${i + 1}`}
                    class="text-gray-400 hover:text-red-600 text-sm"
                  >
                    ✕
                  </button>
                </li>
              {/each}
            </ul>
          {/if}
          <button
            type="button"
            onclick={addPergunta}
            disabled={draft.perguntas.length >= LIMITS.MAX_PERGUNTAS}
            class="mt-3 text-sm font-medium text-blue-600 hover:underline disabled:opacity-50"
          >
            + Adicionar pergunta
          </button>
        </div>

        <div class="pt-2 flex justify-between">
          <button
            type="button"
            onclick={() => goTo(0)}
            disabled={step === 0}
            class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 disabled:opacity-50 transition-colors"
          >
            ← Anterior
          </button>
          <button
            type="button"
            onclick={() => goTo(step + 1)}
            disabled={!tituloValido(draft.titulo)}
            class="px-5 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            Continuar →
          </button>
        </div>
      </div>

    {:else if isQuestionStep}
      <div class="space-y-5">
        <header class="flex items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-bold text-gray-900">Pergunta {questionIndex + 1}</h2>
            <p class="text-sm text-gray-600 mt-1">
              Uma pergunta por tela — a comunidade responde com mais tranquilidade.
            </p>
          </div>
          <button
            type="button"
            onclick={() => remPergunta(questionIndex)}
            class="text-xs text-red-600 hover:underline"
          >
            Remover pergunta
          </button>
        </header>

        <QuestionEditor pergunta={draft.perguntas[questionIndex]} onChange={scheduleAutosave} />

        <div class="grid gap-6 lg:grid-cols-2 items-start">
          <div class="text-xs text-gray-500 space-y-1">
            <p class="font-medium text-gray-600">Como aparece no celular:</p>
            <p>{questionIndex + 1}. {draft.perguntas[questionIndex].texto || "Pergunta sem texto"}</p>
            <p>Preview completo na revisão.</p>
          </div>
        </div>

        <div class="pt-2 flex flex-wrap items-center justify-between gap-2">
          <div class="flex gap-2">
            <button
              type="button"
              onclick={() => goTo(step - 1)}
              class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
            >
              ← Anterior
            </button>
            {#if questionIndex < draft.perguntas.length - 1}
              <button
                type="button"
                onclick={() => goTo(step + 1)}
                class="px-4 py-2 rounded-md bg-gray-100 text-gray-700 text-sm font-medium hover:bg-gray-200 transition-colors"
              >
                Próxima pergunta →
              </button>
            {:else}
              <button
                type="button"
                onclick={addPergunta}
                disabled={draft.perguntas.length >= LIMITS.MAX_PERGUNTAS}
                class="px-4 py-2 rounded-md bg-gray-100 text-gray-700 text-sm font-medium hover:bg-gray-200 disabled:opacity-50 transition-colors"
              >
                + Adicionar outra pergunta
              </button>
            {/if}
          </div>
          <button
            type="button"
            onclick={() => goToKey("revisao")}
            class="px-5 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 transition-colors"
          >
            Ir para revisão →
          </button>
        </div>
      </div>

    {:else}
      <!-- revisao -->
      <div class="space-y-5">
        <header>
          <h2 class="text-lg font-bold text-gray-900">Revisão e finalizar</h2>
          <p class="text-sm text-gray-600 mt-1">
            Confira como a pesquisa aparece para a comunidade antes de publicar.
          </p>
        </header>

        <div class="grid gap-6 lg:grid-cols-[300px_1fr] items-start justify-items-center lg:justify-items-start">
          <PhoneMockup titulo={draft.titulo} descricao={draft.descricao} perguntas={draft.perguntas} />

          <div class="w-full max-w-lg space-y-4">
            <div class="rounded-md border border-gray-200 p-4">
              <p class="text-sm font-semibold text-gray-900">{draft.titulo}</p>
              <p class="text-xs text-gray-600 mt-1">{draft.descricao || "Sem descrição."}</p>
            </div>
            <ol class="space-y-2 list-none">
              {#each draft.perguntas as p, i (p.id)}
                <li class="rounded-md border border-gray-200 px-3 py-2">
                  <button
                    type="button"
                    onclick={() => goToKey(`q${i}`)}
                    class="w-full text-left"
                  >
                    <span class="text-sm text-gray-800">
                      {i + 1}. {p.texto || "Pergunta sem texto"}
                      {#if p.obrigatoria}<span class="text-red-500">*</span>{/if}
                    </span>
                    <span class="block text-xs text-gray-400 mt-0.5">
                      {#if p.tipo === "texto"}
                        Resposta livre
                      {:else}
                        Opções: {p.opcoes.map((o) => o.label || "—").join(" · ")}
                      {/if}
                    </span>
                  </button>
                </li>
              {/each}
            </ol>
            <button
              type="button"
              onclick={addPergunta}
              disabled={draft.perguntas.length >= LIMITS.MAX_PERGUNTAS}
              class="text-sm font-medium text-blue-600 hover:underline disabled:opacity-50"
            >
              + Adicionar pergunta
            </button>
          </div>
        </div>

        <div class="pt-2 flex flex-wrap items-center justify-between gap-2">
          <button
            type="button"
            onclick={() => goTo(step - 1)}
            class="px-4 py-2 rounded-md bg-gray-200 text-gray-700 text-sm font-medium hover:bg-gray-300 transition-colors"
          >
            ← Voltar
          </button>
          <button
            type="button"
            onclick={finalize}
            class="px-5 py-2 rounded-md bg-green-600 text-white text-sm font-semibold hover:bg-green-700 transition-colors"
          >
            Finalizar e publicar
          </button>
        </div>
      </div>
    {/if}
  </div>
{/if}