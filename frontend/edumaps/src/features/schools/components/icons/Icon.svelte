<script>
  // src/features/school/components/icons/Icon.svelte
  import { ICONS } from './icon-data.js';

  /**
   * Nome do ícone (chave em ICONS), ex.: 'agua_potavel', 'fundamental_i'.
   * `active`: true (tem), false (não tem: ×) ou null (sem dado: n/d, #510).
   * `detail`: complemento da dica do ícone (ex.: "outra solução").
   */
  let { name, size = 30, active = true, showLabel = false, detail = null } = $props();
  const semDado = $derived(active === null);
  const dica = $derived(
    ICONS[name]
      ? [ICONS[name].label, detail, semDado ? 'sem dado no Censo' : active === false ? 'não tem' : null]
          .filter(Boolean).join(' · ')
      : '',
  );

  const icon = $derived(ICONS[name]);

  // Cor pela categoria e pelo estado. #510: era `$derived(() => …)`, que
  // guardava a função (e não a classe): o ícone apagado tinha a mesma cor
  // do aceso, e a categoria das etapas é "etapa", não "stage".
  const colorClass = $derived.by(() => {
    if (!icon) return 'text-gray-400';
    if (!active) return 'text-gray-300';
    if (icon.category === 'infra') return 'text-blue-600';
    if (icon.category === 'etapa') return 'text-amber-500';
    return 'text-gray-700';
  });

  // Traço mais fino para tamanhos pequenos, mais robusto para grandes
  const strokeWidth = $derived(size >= 50 ? 1.6 : 1.9);

  // Classe de opacidade para estado inativo
  const opacityClass = $derived(active === false || semDado ? 'opacity-50' : '');
</script>

{#if icon}
  <span
    class="relative inline-flex flex-col items-center gap-1 {opacityClass}"
    style="--icon-size: {size}px;"
    title={dica}
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
        {#if detail}
          <span class="block text-[10px] text-gray-400" data-testid="detalhe-{name}">{detail}</span>
        {/if}
      </span>
    {/if}

    <!-- "×" para itens ausentes (acessibilidade para daltonismo / P&B) -->
    {#if semDado}
      <span
        class="absolute -top-1 -right-2 text-[9px] font-bold text-gray-500 bg-white rounded px-0.5"
        data-testid="nd-{name}"
      >
        n/d
      </span>
    {:else if active === false}
      <span
        class="absolute -top-1 -right-1 text-xs font-bold text-red-500 bg-white rounded-full w-3.5 h-3.5 flex items-center justify-center"
        aria-hidden="true"
      >
        ×
      </span>
    {/if}
  </span>
{/if}
