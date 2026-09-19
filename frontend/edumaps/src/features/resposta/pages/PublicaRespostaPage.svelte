<!-- src/features/resposta/pages/PublicaRespostaPage.svelte -->
<script>
  // Página pública de resposta (rota /p/:token). A comunidade responde sem
  // conta; o dispositivo é identificado por um UUID anônimo (localStorage),
  // p/ o bloqueio "já respondeu neste aparelho" (fase 2).
  import { onMount } from "svelte";
  import { getPesquisaPublica, enviarRespostaPublica } from "@/features/gestor/api/gestorPesquisasApi.js";
  import { getDispositivoId } from "../utils/dispositivo.js";
  import { ApiError } from "@/shared/api/client.js";
  import { LIMITS } from "@/features/gestor/constants/pesquisas.js";

  let { token } = $props();

  let survey = $state(null);
  let loading = $state(true);
  let error = $state(null);

  // respostas por pergunta: unica/dropdown -> id (string), multipla -> [], texto -> ""
  let respostas = $state({});
  let submitted = $state(false);
  let enviando = $state(false);

  const LIMITES_TEXTO = LIMITS.PERGUNTA_TEXTO_MAX;

  function resetRespostas(perguntas) {
    const acc = {};
    for (const p of perguntas) {
      if (p.tipo === "multipla") acc[p.id] = [];
      else acc[p.id] = p.tipo === "texto" ? "" : null;
    }
    respostas = acc;
  }

  function respostaValida(p) {
    const v = respostas[p.id];
    if (p.tipo === "unica" || p.tipo === "dropdown") return !!v;
    if (p.tipo === "multipla") return Array.isArray(v) && v.length > 0;
    return typeof v === "string" && v.trim().length > 0 && v.trim().length <= LIMITES_TEXTO;
  }

  function buildPayload() {
    const payload = { identificador_dispositivo: getDispositivoId(), respostas: [] };
    for (const p of survey.perguntas) {
      const v = respostas[p.id];
      if (p.tipo === "textarea" || p.tipo === "texto") {
        const texto = typeof v === "string" ? v.trim() : "";
        if (texto) payload.respostas.push({ pergunta_id: p.id, valor_texto: texto });
      } else if (p.tipo === "unica" || p.tipo === "dropdown") {
        if (v) payload.respostas.push({ pergunta_id: p.id, opcao_id: [v] });
      } else {
        const oids = Array.isArray(v) ? v : [];
        if (oids.length) payload.respostas.push({ pergunta_id: p.id, opcao_id: oids });
      }
    }
    return payload;
  }

  async function submit() {
    const invalidas = survey.perguntas
      .filter((p) => p.obrigatoria && !respostaValida(p))
      .map((p) => p.ordem);

    if (invalidas.length) {
      error =
        invalidas.length === 1
          ? `Responda a pergunta obrigatória ${invalidas[0]}.`
          : `Responda as perguntas obrigatórias ${invalidas.join(", ")}.`;
      return;
    }

    enviando = true;
    error = null;
    try {
      await enviarRespostaPublica(token, buildPayload());
      submitted = true;
    } catch (err) {
      if (err instanceof ApiError && err.status === 409) {
        error = "Você já respondeu esta pesquisa neste dispositivo.";
      } else {
        error =
          err instanceof ApiError
            ? err.message
            : "Não foi possível enviar sua resposta. Tente de novo.";
      }
    } finally {
      enviando = false;
    }
  }

  onMount(() => {
    if (!token) {
      error = "Link inválido.";
      loading = false;
      return;
    }
    getPesquisaPublica(token)
      .then((form) => {
        survey = form;
        resetRespostas(form.perguntas);
      })
      .catch((err) => {
        error =
          err instanceof ApiError
            ? err.message
            : "Não foi possível carregar a pesquisa.";
      })
      .finally(() => {
        loading = false;
      });
  });
</script>

<div class="min-h-[70vh] flex items-start justify-center px-4 py-10 bg-gray-50">
  <div class="w-full max-w-md space-y-4">
    {#if loading}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-10 text-center">
        <p class="text-gray-500">Carregando pesquisa…</p>
      </div>

    {:else if error && !survey}
      <div class="rounded-card bg-white border border-gray-200 shadow-card p-8 text-center space-y-3">
        <div class="mx-auto w-14 h-14 rounded-full bg-red-50 flex items-center justify-center text-2xl">
          😕
        </div>
        <p class="text-gray-700 text-sm">{error}</p>
        <p class="text-xs text-gray-400">
          Verifique se o link está completo ou peça outro ao gestor da escola.
        </p>
      </div>

    {:else if submitted}
      <div
        class="rounded-card bg-white border border-green-200 shadow-card p-10 text-center space-y-3"
        data-testid="resposta-enviada"
      >
        <div class="mx-auto w-14 h-14 rounded-full bg-green-50 flex items-center justify-center text-2xl">
          ✅
        </div>
        <h1 class="text-lg font-bold text-gray-900">Obrigado por responder!</h1>
        <p class="text-sm text-gray-600">
          Sua resposta ajuda a escola a melhorar. Você pode fechar esta página.
        </p>
      </div>

    {:else}
      <div class="rounded-card bg-white border border-gray-200 shadow-card">
        <header class="px-6 py-5 border-b border-gray-100">
          <p class="text-[11px] text-blue-600 font-semibold uppercase tracking-wide">
            Pesquisa da comunidade · {survey?.id ?? ""}
          </p>
          <h1 class="mt-1 text-lg font-bold text-gray-900 leading-snug">
            {survey?.titulo}
          </h1>
          {#if survey?.descricao}
            <p class="mt-1 text-sm text-gray-600">{survey.descricao}</p>
          {/if}
        </header>

        <div class="px-6 py-5 space-y-6">
          {#each survey.perguntas as p, i (p.id)}
            <section aria-label={`Pergunta ${i + 1}`}>
              <p class="text-sm font-medium text-gray-800">
                {i + 1}. {p.texto}
                {#if p.obrigatoria}<span class="text-red-600" title="Obrigatória">*</span>{/if}
              </p>
              <div class="mt-2 space-y-2">
                {#if p.tipo === "unica"}
                  {#each p.opcoes as op (op.id)}
                    <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                      <input
                        type="radio"
                        name={`pergunta-${p.id}`}
                        value={op.id}
                        checked={respostas[p.id] === op.id}
                        onchange={() => (respostas = { ...respostas, [p.id]: op.id })}
                        class="accent-blue-600"
                      />
                      {op.label}
                    </label>
                  {/each}
                {:else if p.tipo === "multipla"}
                  {#each p.opcoes as op (op.id)}
                    <label class="flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
                      <input
                        type="checkbox"
                        value={op.id}
                        checked={(respostas[p.id] ?? []).includes(op.id)}
                        onchange={() => {
                          const cur = respostas[p.id] ?? [];
                          const next = cur.includes(op.id)
                            ? cur.filter((x) => x !== op.id)
                            : [...cur, op.id];
                          respostas = { ...respostas, [p.id]: next };
                        }}
                        class="accent-blue-600"
                      />
                      {op.label}
                    </label>
                  {/each}
                {:else if p.tipo === "dropdown"}
                  <select
                    value={respostas[p.id] ?? ""}
                    onchange={(e) =>
                      (respostas = { ...respostas, [p.id]: e.currentTarget.value || null })
                    }
                    class="w-full h-10 px-3 rounded-md border border-gray-300 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Selecione…</option>
                    {#each p.opcoes as op (op.id)}
                      <option value={op.id}>{op.label}</option>
                    {/each}
                  </select>
                {:else}
                  <textarea
                    maxlength={LIMITES_TEXTO}
                    rows="3"
                    placeholder="Escreva aqui…"
                    value={respostas[p.id] ?? ""}
                    oninput={(e) =>
                      (respostas = { ...respostas, [p.id]: e.currentTarget.value })
                    }
                    class="w-full px-3 py-2 rounded-md border border-gray-300 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  ></textarea>
                {/if}
              </div>
            </section>
          {/each}
        </div>

        <footer class="px-6 py-4 border-t border-gray-100">
          {#if error}
            <p class="mb-3 text-sm text-red-600" role="alert">{error}</p>
          {/if}
          <button
            type="button"
            onclick={submit}
            disabled={enviando}
            class="w-full h-11 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50 transition-colors"
          >
            {enviando ? "Enviando…" : "Enviar resposta"}
          </button>
        </footer>
      </div>

      <p class="text-center text-[11px] text-gray-400">
        EduMaps · suas respostas são anônimas e ajudam a escola a melhorar
      </p>
    {/if}
  </div>
</div>