<!-- src/features/gestor/components/survey/QuestionEditor.svelte -->
<script>
  // Editor de UMA pergunta (um passo do wizard). Muta o objeto `pergunta`
  // passado pelo pai — Svelte 5 rastreia a mutação do $state do rascunho.
  import { ANSWER_TYPES, LIMITS, isOpcaoType } from "../../constants/pesquisas.js";
  import { perguntaErros } from "../../utils/pesquisaDraft.js";
  import { uuid } from "@/shared/utils/uuid.js";

  /** @type {{ pergunta: object, onChange?: () => void }} */
  let { pergunta, onChange = () => {} } = $props();

  let erros = $derived(perguntaErros(pergunta));

  function addOpcao() {
    if (pergunta.opcoes.length >= LIMITS.MAX_OPCOES) return;
    pergunta.opcoes.push({ id: uuid(), label: "" });
    onChange();
  }

  function remOpcao(index) {
    pergunta.opcoes.splice(index, 1);
    onChange();
  }
</script>

<div class="space-y-4">
  <div>
    <label for="pergunta-texto" class="block text-sm font-medium text-gray-700">
      Texto da pergunta
    </label>
    <input
      id="pergunta-texto"
      type="text"
      maxlength={LIMITS.PERGUNTA_TEXTO_MAX}
      bind:value={pergunta.texto}
      oninput={onChange}
      placeholder="Ex.: A escola oferece atividades no contraturno?"
      class="mt-1 w-full h-10 px-3 rounded-md border border-gray-300 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
    />
  </div>

  <div class="grid gap-4 sm:grid-cols-2">
    <div>
      <label for="pergunta-tipo" class="block text-sm font-medium text-gray-700">
        Tipo de resposta
      </label>
      <select
        id="pergunta-tipo"
        bind:value={pergunta.tipo}
        onchange={onChange}
        class="mt-1 w-full h-10 px-2 rounded-md border border-gray-300 text-sm bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        {#each ANSWER_TYPES as t (t.value)}
          <option value={t.value}>{t.label} — {t.hint}</option>
        {/each}
      </select>
    </div>
    <div class="flex items-end pb-1">
      <label class="inline-flex items-center gap-2 text-sm text-gray-700 cursor-pointer">
        <input type="checkbox" class="w-4 h-4 accent-blue-600" bind:checked={pergunta.obrigatoria} onchange={onChange} />
        Resposta obrigatória
      </label>
    </div>
  </div>

  {#if isOpcaoType(pergunta.tipo)}
    <div>
      <p class="text-sm font-medium text-gray-700">
        Opções
        <span class="ml-1 text-xs font-normal text-gray-500">
          ({pergunta.opcoes.filter((o) => o.label.trim()).length} preenchidas ·
          {LIMITS.MIN_OPCOES} a {LIMITS.MAX_OPCOES})
        </span>
      </p>
      <ul class="mt-2 space-y-2">
        {#each pergunta.opcoes as op, i (op.id)}
          <li class="flex items-center gap-2">
            <span class="text-xs text-gray-400 w-4">{i + 1}.</span>
            <input
              type="text"
              maxlength="120"
              bind:value={op.label}
              oninput={onChange}
              placeholder={`Opção ${i + 1}`}
              class="flex-1 h-9 px-3 rounded-md border border-gray-300 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
            <button
              type="button"
              onclick={() => remOpcao(i)}
              aria-label={`Remover opção ${i + 1}`}
              class="h-9 px-2 rounded-md text-gray-400 hover:text-red-600 hover:bg-red-50 transition-colors"
            >
              ✕
            </button>
          </li>
        {/each}
      </ul>
      <button
        type="button"
        onclick={addOpcao}
        disabled={pergunta.opcoes.length >= LIMITS.MAX_OPCOES}
        class="mt-2 text-sm text-blue-600 hover:underline disabled:opacity-50"
      >
        + Adicionar opção
      </button>
    </div>
  {/if}

  {#if erros.length > 0}
    <ul class="rounded-md bg-amber-50 border border-amber-200 text-amber-800 text-xs px-3 py-2 space-y-1">
      {#each erros as e (e)}
        <li>{e}</li>
      {/each}
    </ul>
  {/if}
</div>