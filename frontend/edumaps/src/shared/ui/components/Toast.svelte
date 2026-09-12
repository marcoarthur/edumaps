<!-- src/shared/ui/components/Toast.svelte -->
<script>
  import { toast$, removeToast } from "@/shared/stores/toastStore.js";
  import { fade, fly } from "svelte/transition";

  let toasts = $state([]);

  $effect(() => {
    const subscription = toast$.subscribe((value) => {
      toasts = value;
    });
    return () => subscription.unsubscribe();
  });

  const typeClasses = {
    success: "bg-green-50 border-green-500 text-green-800",
    error: "bg-red-50 border-red-500 text-red-800",
    warning: "bg-yellow-50 border-yellow-500 text-yellow-800",
    info: "bg-blue-50 border-blue-500 text-blue-800",
  };

  const iconMap = {
    success: "✅",
    error: "❌",
    warning: "⚠️",
    info: "ℹ️",
  };
</script>

{#if toasts.length > 0}
  <div class="fixed top-4 right-4 z-50 flex flex-col gap-2 w-96 max-w-full pointer-events-none">
    {#each toasts as item (item.id)}
      <div
        in:fly={{ x: 50, duration: 300 }}
        out:fade={{ duration: 200 }}
        class="pointer-events-auto flex items-start gap-3 p-4 rounded-lg border shadow-lg {typeClasses[item.type]}"
      >
        <span class="text-2xl flex-shrink-0">{iconMap[item.type]}</span>
        <span class="flex-1 text-sm font-medium break-words">{item.message}</span>
        <button
          class="flex-shrink-0 text-gray-400 hover:text-gray-600 transition-colors"
          onclick={() => removeToast(item.id)}
          aria-label="Fechar"
        >
          ✕
        </button>
      </div>
    {/each}
  </div>
{/if}
