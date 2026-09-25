<!-- src/features/config/components/ConfigArvore.svelte -->
<!--
  Árvore do Painel de Configuração: categorias fixas → grupos/funções com
  folhas. Cada folha é clicável (onSelecionarItem) e mostra tooltip "?" com
  a descrição. Itens não habilitados trazem selo "Em breve".
-->
<script>
  let { categories = [], selecionada = null, onSelecionarItem } = $props();

  let recolhidos = $state(new Set());

  function alternarGrupo(key) {
    const next = new Set(recolhidos);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    recolhidos = next;
  }
</script>

<div class="space-y-1">
  {#each categories as cat (cat.key)}
    <div>
      <p class="text-xs font-semibold uppercase tracking-wide text-gray-400 px-1.5 pt-2 pb-1">
        {cat.label}
      </p>
      <div class="space-y-0.5">
        {#each cat.children as grupo (grupo.key)}
          {#if grupo.children?.length}
            <div>
              <button
                type="button"
                aria-label={recolhidos.has(grupo.key) ? `Expandir ${grupo.label}` : `Recolher ${grupo.label}`}
                onclick={() => alternarGrupo(grupo.key)}
                class="w-full flex items-center gap-1 px-1.5 py-1 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-100"
              >
                <span class="text-gray-400 text-xs w-3">{recolhidos.has(grupo.key) ? "▸" : "▾"}</span>
                <span class="flex-1 text-left">{grupo.label}</span>
              </button>
              {#if !recolhidos.has(grupo.key)}
                <div class="ml-3 space-y-0.5 border-l border-gray-100 pl-1.5">
                  {#each grupo.children as item (item.key)}
                    <button
                      type="button"
                      aria-label={`Configurar ${item.label}`}
                      onclick={() => onSelecionarItem(item.key)}
                      class="w-full flex items-center gap-1.5 px-1.5 py-1 rounded-md text-sm text-left hover:bg-gray-100 {selecionada === item.key ? 'bg-indigo-50 ring-1 ring-indigo-200' : ''}"
                    >
                      <span class="flex-1 truncate text-gray-800">{item.label}</span>
                      {#if item.description}
                        <span
                          class="inline-flex items-center justify-center w-4 h-4 rounded-full bg-gray-200 text-gray-500 text-[10px] font-bold shrink-0"
                          title={item.description}
                          aria-label={`Sobre ${item.label}: ${item.description}`}
                        >
                          ?
                        </span>
                      {/if}
                      {#if !item.enabled}
                        <span class="text-[9px] uppercase tracking-wide text-amber-600 bg-amber-50 border border-amber-200 rounded px-1 py-px shrink-0">
                          Em breve
                        </span>
                      {/if}
                    </button>
                  {/each}
                </div>
              {/if}
            </div>
          {:else}
            <button
              type="button"
              aria-label={`Configurar ${grupo.label}`}
              onclick={() => onSelecionarItem(grupo.key)}
              class="w-full flex items-center gap-1.5 px-1.5 py-1 rounded-md text-sm text-left hover:bg-gray-100 {selecionada === grupo.key ? 'bg-indigo-50 ring-1 ring-indigo-200' : ''}"
            >
              <span class="flex-1 truncate text-gray-800">{grupo.label}</span>
              {#if grupo.description}
                <span
                  class="inline-flex items-center justify-center w-4 h-4 rounded-full bg-gray-200 text-gray-500 text-[10px] font-bold shrink-0"
                  title={grupo.description}
                  aria-label={`Sobre ${grupo.label}: ${grupo.description}`}
                >
                  ?
                </span>
              {/if}
              {#if !grupo.enabled}
                <span class="text-[9px] uppercase tracking-wide text-amber-600 bg-amber-50 border border-amber-200 rounded px-1 py-px shrink-0">
                  Em breve
                </span>
              {/if}
            </button>
          {/if}
        {/each}
      </div>
    </div>
  {/each}
</div>