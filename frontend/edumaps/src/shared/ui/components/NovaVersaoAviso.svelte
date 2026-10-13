<!-- src/shared/ui/components/NovaVersaoAviso.svelte
     Aviso discreto de nova versão da SPA (issue #225). Só recarrega quando a
     pessoa clica em "Atualizar" — não perde formulário em andamento. -->
<script>
  import { atualizador as padrao } from "@/shared/pwa/atualizacao.js";

  /** @type {{ atualizador?: ReturnType<typeof import("@/shared/pwa/atualizacao.js").criarAtualizador> }} */
  let { atualizador = padrao } = $props();

  let estado = $state({ visivel: false, motivo: null });

  $effect(() => {
    const desinscrever = atualizador.subscribe((v) => {
      estado = v;
    });
    return desinscrever;
  });

  let mensagem = $derived(
    estado.motivo === "erro-chunk"
      ? "Esta página foi atualizada. Recarregue para continuar."
      : "Nova versão disponível."
  );
</script>

<div role="status" aria-live="polite" class="print:hidden">
  {#if estado.visivel}
    <div
      class="fixed bottom-4 right-4 z-50 max-w-sm flex items-center gap-3 rounded-lg border border-brand-700/30 bg-white px-4 py-3 text-sm text-gray-800 shadow-lg"
    >
      <span class="flex-1">{mensagem}</span>
      <button
        type="button"
        class="rounded-md bg-brand-700 px-3 py-1.5 font-medium text-white hover:bg-brand-600 focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-700 focus-visible:ring-offset-2"
        onclick={() => atualizador.atualizar()}
      >
        Atualizar
      </button>
      <button
        type="button"
        class="rounded-md px-2 py-1.5 text-gray-600 hover:bg-gray-100 focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-400"
        onclick={() => atualizador.adiar()}
      >
        Depois
      </button>
    </div>
  {/if}
</div>
