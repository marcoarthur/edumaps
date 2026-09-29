<script>
  // src/shared/ui/components/InfoHint.svelte
  //
  // Botão "(?)" que abre uma caixa explicativa sobre um dado (tabela/gráfico):
  // de onde vem, como é calculado e o que significa. Acessível por teclado
  // (Enter/Espaço abre; Escape fecha) e fecha ao clicar fora.
  //
  // Uso:
  //   <InfoHint title="Como calculamos…" text="…" items={["…", "…"]} />
  /** @type {{ title?: string, text?: string, items?: string[], label?: string, align?: 'left'|'right' }} */
  let {
    title = "Sobre este dado",
    text = "",
    items = [],
    label = "Detalhes sobre este dado",
    align = "right",
  } = $props();

  let open = $state(false);

  function toggle() {
    open = !open;
  }

  function close() {
    open = false;
  }

  function onKeydown(event) {
    if (event.key === "Escape") close();
  }
</script>

<span class="relative inline-flex align-middle">
  <button
    type="button"
    class="inline-flex items-center justify-center w-5 h-5 rounded-full border border-gray-300 text-gray-500 text-[11px] font-bold leading-none hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-400"
    aria-label={label}
    aria-expanded={open}
    title={label}
    onclick={toggle}
    onkeydown={onKeydown}
  >
    ?
  </button>

  {#if open}
    <button
      type="button"
      class="fixed inset-0 z-10 cursor-default"
      aria-hidden="true"
      tabindex="-1"
      onclick={close}
    ></button>
    <div
      role="dialog"
      aria-label={title}
      class="absolute z-20 top-6 {align === 'left' ? 'left-0' : 'right-0'} w-72 max-w-[85vw] bg-white border border-gray-200 rounded-md shadow-lg p-3 text-left"
    >
      <div class="flex items-start justify-between gap-2 mb-1">
        <strong class="text-xs font-semibold text-gray-900">{title}</strong>
        <button
          type="button"
          class="text-gray-400 hover:text-gray-700 leading-none text-sm"
          aria-label="Fechar"
          onclick={close}
        >
          ×
        </button>
      </div>

      {#if text}
        <p class="text-xs text-gray-600">{text}</p>
      {/if}

      {#if items.length > 0}
        <ul class="mt-2 flex flex-col gap-1 list-disc pl-4">
          {#each items as item}
            <li class="text-xs text-gray-600">{item}</li>
          {/each}
        </ul>
      {/if}
    </div>
  {/if}
</span>
