<script>
  // src/features/gestor/components/icons/Icon.svelte
  import { ICONS } from "./icon-data.js";

  let { name, size = 28, active = true, showLabel = false } = $props();

  const icon = $derived(ICONS[name] ?? ICONS.predio);

  const CATEGORY_COLOR = {
    etapa: ["text-amber-500", "text-gray-300"],
    matricula: ["text-brand-600", "text-gray-300"],
    porte: ["text-brand-600", "text-gray-300"],
    turno: ["text-cyan-600", "text-gray-300"],
    modalidade: ["text-amber-600", "text-gray-300"],
    idade: ["text-indigo-500", "text-gray-300"],
    docente: ["text-violet-600", "text-gray-300"],
    infra: ["text-blue-600", "text-gray-300"],
    espaco: ["text-blue-600", "text-gray-300"],
    equip: ["text-slate-600", "text-gray-300"],
    acess: ["text-emerald-600", "text-gray-300"],
    finance: ["text-gray-700", "text-gray-300"],
  };

  const colorClass = $derived(() => {
    const pair = CATEGORY_COLOR[icon.category] ?? ["text-gray-700", "text-gray-300"];
    return active ? pair[0] : pair[1];
  });

  const strokeWidth = $derived(size >= 48 ? 1.6 : 1.9);
  const opacityClass = $derived(active === false ? "opacity-50" : "");
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
      class={colorClass()}
    >
      {@html icon.svg}
    </svg>

    {#if showLabel}
      <span class="text-[11px] leading-tight text-center text-gray-500 max-w-[calc(var(--icon-size)*1.8)]">
        {icon.label}
      </span>
    {/if}

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
