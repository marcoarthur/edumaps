<script>
  // src/features/school/components/icons/Icon.svelte
  import { ICONS } from './icon-data.js';

  /**
   * Nome do ícone (chave em ICONS), ex.: 'potable_water', 'elementary_i'
   */
  let { name, size = 30, active = true, showLabel = false } = $props();

  const icon = $derived(ICONS[name]);

  // Define a classe de cor baseada na categoria e no estado 'active'
  const colorClass = $derived(() => {
    if (!icon) return 'text-gray-400';
    if (icon.category === 'infra') {
      return active ? 'text-blue-600' : 'text-gray-300';
    }
    if (icon.category === 'stage') {
      return active ? 'text-amber-500' : 'text-gray-300';
    }
    return active ? 'text-gray-700' : 'text-gray-300';
  });

  // Traço mais fino para tamanhos pequenos, mais robusto para grandes
  const strokeWidth = $derived(size >= 50 ? 1.6 : 1.9);

  // Classe de opacidade para estado inativo
  const opacityClass = $derived(active === false ? 'opacity-50' : '');
</script>

{#if icon}
  <span
    class="relative inline-flex flex-col items-center gap-1 {opacityClass}"
    style="--icon-size: {size}px;"
    title={icon.label}
  >
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      stroke-width={strokeWidth}
      stroke-linecap="round"
      stroke-linejoin="round"
      role="img"
      aria-label={icon.label}
      class="{colorClass}"
    >
      {@html icon.svg}
    </svg>

    {#if showLabel}
      <span class="text-[11px] leading-tight text-center text-gray-500 max-w-[calc(var(--icon-size)*1.8)]">
        {icon.label}
      </span>
    {/if}

    <!-- "×" para itens ausentes (acessibilidade para daltonismo / P&B) -->
    {#if active === false}
      <span
        class="absolute -top-1 -right-1 text-xs font-bold text-red-500 bg-white rounded-full w-3.5 h-3.5 flex items-center justify-center"
        aria-hidden="true"
      >
        ×
      </span>
    {/if}
  </span>
{/if}
