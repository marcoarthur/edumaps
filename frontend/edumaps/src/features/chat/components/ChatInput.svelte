<!-- src/features/chat/components/ChatInput.svelte -->
<script>
  /**
   * @param {boolean} [disabled]
   * @param {string} [placeholder]
   * @param {Object} [contexto] - escopo do gestor exibido como chips
   * @param {(value: string) => void} [onsend] - callback ao enviar
   */
  let {
    disabled = false,
    placeholder = "Pergunte sobre o Censo Escolar...",
    contexto = {},
    onsend = () => {},
  } = $props();

  let value = $state("");
  let isComposing = false;

  const canSend = $derived(value.trim().length > 0 && !disabled);

  function submit() {
    const pergunta = value.trim();
    if (!pergunta || disabled) return;
    value = "";
    onsend(pergunta);
  }

  function handleKeydown(e) {
    if (isComposing) return;
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }

  function handleSubmit(e) {
    e.preventDefault();
    submit();
  }
</script>

<form onsubmit={handleSubmit} class="w-full">
  <div class="relative">
    <textarea
      bind:value
      onkeydown={handleKeydown}
      oncompositionstart={() => (isComposing = true)}
      oncompositionend={() => (isComposing = false)}
      {placeholder}
      {disabled}
      rows={1}
      class="w-full border border-gray-300 rounded-lg px-4 py-3 pr-12 text-sm resize-none
        focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
        disabled:bg-gray-100 disabled:cursor-not-allowed
        placeholder:text-gray-400"
      aria-label="Pergunta para o Assistente do Censo"
      aria-describedby="context-hint"
    ></textarea>
    <button
      type="submit"
      disabled={!canSend}
      class="absolute bottom-2 right-2 p-2 rounded-full
        bg-blue-600 text-white hover:bg-blue-700
        disabled:opacity-40 disabled:cursor-not-allowed
        transition-colors"
      aria-label="Enviar pergunta"
    >
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
      </svg>
    </button>
  </div>

  {#if Object.keys(contexto).length}
    <div id="context-hint" class="mt-1.5 text-xs text-gray-500 flex flex-wrap gap-2">
      {#if contexto.nome_municipio}
        <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-blue-50 text-blue-700 rounded-full text-xs">
          📍 {contexto.nome_municipio}
        </span>
      {/if}
      {#if contexto.cod_municipio}
        <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full text-xs">
          IBGE: {contexto.cod_municipio}
        </span>
      {/if}
      {#if contexto.nome_escola}
        <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-emerald-50 text-emerald-700 rounded-full text-xs">
          🏫 {contexto.nome_escola}
        </span>
      {/if}
      {#if contexto.cod_inep}
        <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full text-xs">
          INEP: {contexto.cod_inep}
        </span>
      {/if}
      {#if contexto.sg_uf}
        <span class="inline-flex items-center gap-1 px-2 py-0.5 bg-amber-50 text-amber-700 rounded-full text-xs">
          UF: {contexto.sg_uf}
        </span>
      {/if}
    </div>
  {/if}
</form>
