<!-- src/features/gestor/components/documentos/TagEditor.svelte -->
<!--
  Editor de tags livres de um documento: chips removíveis + texto com Enter.
  Aplicar dispara onAplicar(tags) que o container usa para chamar a API.
-->
<script>
  import { DOCUMENTOS_LIMITS as L } from "../../constants/documentos.js";

  let { tags = [], onAplicar, onFechar } = $props();

  let locais = $state([...(tags ?? [])]);
  let valor = $state("");
  let enviando = $state(false);
  let erro = $state("");

  function adicionar() {
    const t = valor.trim();
    if (!t) return;
    if (locais.includes(t)) {
      valor = "";
      return;
    }
    if (locais.length >= L.MAX_TAGS) {
      erro = `Limite de ${L.MAX_TAGS} tags por documento.`;
      return;
    }
    if (t.length > L.TAG_MAX_LEN) {
      erro = `Cada tag tem no máximo ${L.TAG_MAX_LEN} caracteres.`;
      return;
    }
    locais = [...locais, t];
    valor = "";
    erro = "";
  }

  function remover(t) {
    locais = locais.filter((x) => x !== t);
  }

  async function salvar() {
    erro = "";
    enviando = true;
    try {
      await onAplicar(locais);
    } catch (err) {
      erro = err?.message ?? "Não foi possível salvar as tags.";
    } finally {
      enviando = false;
    }
  }
</script>

<div class="bg-gray-50 border border-gray-200 rounded-md p-3 space-y-2">
  <div class="flex flex-wrap gap-1.5">
    {#each locais as tag}
      <span
        class="inline-flex items-center gap-1 bg-indigo-50 text-indigo-700 text-xs font-medium rounded-full px-2 py-0.5"
      >
        {tag}
        <button
          type="button"
          aria-label={`Remover tag ${tag}`}
          onclick={() => remover(tag)}
          class="hover:text-indigo-900"
        >
          ×
        </button>
      </span>
    {/each}
    {#if !locais.length}
      <span class="text-xs text-gray-400">Nenhuma tag ainda.</span>
    {/if}
  </div>
  <div class="flex items-center gap-2">
    <input
      type="text"
      placeholder="Nova tag + Enter"
      value={valor}
      oninput={(e) => (valor = e.currentTarget.value)}
      onkeydown={(e) => {
        if (e.key === "Enter") {
          e.preventDefault();
          adicionar();
        }
      }}
      class="flex-1 text-sm border border-gray-300 rounded-md px-2 py-1"
    />
    <button
      type="button"
      onclick={adicionar}
      class="text-sm px-2 py-1 bg-gray-200 text-gray-700 rounded-md hover:bg-gray-300"
    >
      + tag
    </button>
  </div>
  {#if erro}
    <p class="text-xs text-red-600">{erro}</p>
  {/if}
  <div class="flex justify-end gap-2">
    <button
      type="button"
      onclick={onFechar}
      class="text-sm px-3 py-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-100"
    >
      Cancelar
    </button>
    <button
      type="button"
      onclick={salvar}
      disabled={enviando}
      class="text-sm px-3 py-1.5 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50"
    >
      {enviando ? "Salvando…" : "Salvar tags"}
    </button>
  </div>
</div>