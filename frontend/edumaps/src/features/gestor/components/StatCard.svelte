<script>
  // src/features/gestor/components/StatCard.svelte
  import Icon from "./icons/Icon.svelte";

  let { label, value, hint = "", icon = null } = $props();
</script>

<div class="bg-white border border-gray-200 rounded-card shadow-card p-4 flex items-center gap-3">
  {#if icon}
    <Icon name={icon} size={32} />
  {/if}
  <div class="min-w-0">
    <p class="text-xs text-gray-500">{label}</p>
    <p class="text-2xl font-bold text-gray-900 mt-0.5">{value}</p>
    {#if hint}
      <p class="text-[11px] text-gray-400 truncate">{hint}</p>
    {/if}
  </div>
</div>
