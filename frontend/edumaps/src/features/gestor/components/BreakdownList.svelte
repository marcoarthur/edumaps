<script>
  // src/features/gestor/components/BreakdownList.svelte
  //
  // Lista com ícone + valor + barra proporcional (turno, modalidade, formação).
  import Icon from "./icons/Icon.svelte";
  import { formatInt } from "../utils/transformGestorData.js";

  let { items = [], color = "#2563eb" } = $props();

  const max = $derived(Math.max(1, ...items.map((i) => Number(i.value) || 0)));
</script>

<ul class="flex flex-col gap-3">
  {#each items as item (item.key)}
    {@const pct = Math.round(((Number(item.value) || 0) / max) * 100)}
    <li class="flex items-center gap-3">
      <Icon name={item.key} size={24} />
      <div class="grow min-w-0">
        <div class="flex justify-between gap-2 text-sm">
          <span class="text-gray-700 truncate">{item.label}</span>
          <span class="font-medium text-gray-900 whitespace-nowrap">
            {formatInt(item.value)}
          </span>
        </div>
        <div class="h-1.5 bg-gray-100 rounded mt-1 overflow-hidden">
          <div class="h-full rounded" style="width: {pct}%; background: {color};"></div>
        </div>
      </div>
    </li>
  {/each}
</ul>
