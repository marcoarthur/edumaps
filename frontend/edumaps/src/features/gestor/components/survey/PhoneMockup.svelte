<!-- src/features/gestor/components/survey/PhoneMockup.svelte -->
<script>
  // Pré-visualização da pesquisa dentro de uma "moldura de celular", como a
  // comunidade vai respondê-la (fase 2). Só renderização — campos desabilitados.
  import { ANSWER_TYPE_LABELS } from "../../constants/pesquisas.js";

  /** @type {{ titulo?: string, descricao?: string, perguntas?: Array }} */
  let { titulo = "", descricao = "", perguntas = [] } = $props();

  function placeholderFor(tipo) {
    if (tipo === "texto") return "Escreva sua resposta…";
    if (tipo === "dropdown") return "Selecione…";
    return ANSWER_TYPE_LABELS[tipo] ?? "Resposta";
  }
</script>

<div class="w-[300px] max-w-full mx-auto">
  <div
    class="rounded-[2.2rem] border-8 border-gray-800 bg-gray-900 shadow-card overflow-hidden"
    data-testid="phone-mockup"
  >
    <div class="h-7 flex items-center justify-center text-[10px] text-white">
      <span class="rounded-full bg-gray-700 px-3 py-0.5">EduMaps · Pesquisa</span>
    </div>
    <div class="h-[520px] bg-white px-4 py-5 overflow-y-auto space-y-5">
      <header>
        <h3 class="text-sm font-bold text-gray-900 leading-snug">
          {titulo || "Título da pesquisa"}
        </h3>
        {#if descricao}
          <p class="mt-1 text-xs text-gray-600">{descricao}</p>
        {/if}
      </header>

      {#if perguntas.length === 0}
        <div class="rounded-lg border border-dashed border-gray-300 p-6 text-center">
          <p class="text-xs text-gray-500">
            Adicione na primeira pergunta para ver como a comunidade vai responder.
          </p>
        </div>
      {:else}
        {#each perguntas as p, i (p.id)}
          <section class="space-y-2" aria-label={`Pergunta ${i + 1}`}>
            <p class="text-xs text-gray-800 font-medium">
              {i + 1}. {p.texto || "Pergunta sem texto"}
              {#if p.obrigatoria}<span class="text-red-600" title="Obrigatória">*</span>{/if}
            </p>

            {#if p.tipo === "unica"}
              {#each p.opcoes as op (op.id)}
                <label class="flex items-start gap-2 text-xs text-gray-700">
                  <input type="radio" disabled class="mt-0.5 accent-blue-600" name={p.id} />
                  {op.label || "Opção"}
                </label>
              {/each}
            {:else if p.tipo === "multipla"}
              {#each p.opcoes as op (op.id)}
                <label class="flex items-start gap-2 text-xs text-gray-700">
                  <input type="checkbox" disabled class="mt-0.5 accent-blue-600" />
                  {op.label || "Opção"}
                </label>
              {/each}
            {:else if p.tipo === "dropdown"}
              <div class="rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-xs text-gray-500">
                {p.opcoes[0]?.label || "Primeira opção"} ▾
              </div>
              <p class="text-[10px] text-gray-400">Lista suspensa</p>
            {:else}
              <div class="rounded-md border border-gray-300 bg-gray-50 px-3 py-2 text-xs text-gray-500">
                {placeholderFor("texto")}
              </div>
            {/if}
          </section>
        {/each}
      {/if}

      <div class="pt-2">
        <button
          type="button"
          disabled
          class="w-full rounded-md bg-blue-600 text-white text-xs font-semibold py-2 opacity-40"
        >
          Responder
        </button>
      </div>
    </div>
    <div class="h-1 bg-gray-800"></div>
  </div>
</div>