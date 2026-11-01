<script>
  // src/shared/tour/BotaoAjuda.svelte
  //
  // Botão "?" do menu: abre a ajuda guiada da página atual. Só aparece nas
  // páginas que têm tour.
  //
  // Não usar `disabled` enquanto o tour está aberto: o overlay já bloqueia o
  // clique, e um botão desabilitado perde o foco — o tourManager não
  // conseguiria devolvê-lo ao fechar.
  /** @type {{ path: string, manager: import('./tourManager.svelte.js').TourManager }} */
  let { path, manager } = $props();

  let tour = $derived(manager.tourDaRota(path));
</script>

{#if tour}
  <button
    type="button"
    onclick={() => manager.iniciar(tour.id)}
    aria-label={`Ajuda guiada: ${tour.titulo}`}
    title={`Ajuda guiada: ${tour.titulo}`}
    data-testid="botao-ajuda-guiada"
    class="w-8 h-8 shrink-0 rounded-full border border-white/40 font-bold leading-none hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-white"
  >
    ?
  </button>
{/if}
