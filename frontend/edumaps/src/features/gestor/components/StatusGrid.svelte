<script>
  // src/features/gestor/components/StatusGrid.svelte
  //
  // Grade de itens "tem / não tem" (infraestrutura, equipamentos, conectividade
  // e acessibilidade). Cada item vira um ícone (com × quando ausente) + rótulo.
  import Icon from "./icons/Icon.svelte";

  let { items = [] } = $props();

  const presentCount = $derived(items.filter((i) => i.present).length);
</script>

<div>
  <p class="text-xs text-gray-500 mb-3">
    {presentCount} de {items.length} itens presentes
  </p>
  <ul class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-x-4 gap-y-5">
    {#each items as item (item.key)}
      <li class="flex items-center gap-2 min-w-0">
        <Icon name={item.key} size={26} active={!!item.present} />
        <span
          class="text-sm leading-tight {item.present ? 'text-gray-800' : 'text-gray-400'}"
        >
          {item.label}
        </span>
      </li>
    {/each}
  </ul>
</div>
