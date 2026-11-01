<script>
  // src/shared/tour/BotaoAjuda.svelte
  //
  // Botão "?" do menu: abre a ajuda guiada da página atual. Só aparece nas
  // páginas que têm tour — e, se o tour declara `prontoQuando` (página que
  // carrega dados, ex.: painel do gestor), só quando esse alvo existe no
  // DOM: nem em "Carregando…" nem na tela de erro, onde o tour não teria o
  // que mostrar e cada passo cairia no popover centralizado.
  //
  // Não usar `disabled` enquanto o tour está aberto: o overlay já bloqueia o
  // clique, e um botão desabilitado perde o foco — o tourManager não
  // conseguiria devolvê-lo ao fechar.
  import { seletorDoAlvo } from "./tourManager.svelte.js";

  /** @type {{ path: string, manager: import('./tourManager.svelte.js').TourManager }} */
  let { path, manager } = $props();

  let tour = $derived(manager.tourDaRota(path));

  // Presença do alvo `prontoQuando`, acompanhada por MutationObserver só
  // enquanto a página atual tem um tour assim (o observer é desligado ao
  // trocar de página).
  let alvoPronto = $state(false);
  $effect(() => {
    const seletor = tour?.prontoQuando ? seletorDoAlvo(tour.prontoQuando) : null;
    if (!seletor) return;
    const verificar = () => {
      alvoPronto = document.querySelector(seletor) !== null;
    };
    verificar();
    const observador = new MutationObserver(verificar);
    observador.observe(document.body, { childList: true, subtree: true });
    return () => observador.disconnect();
  });

  let disponivel = $derived(Boolean(tour) && (!tour.prontoQuando || alvoPronto));
</script>

{#if disponivel}
  <button
    type="button"
    onclick={() => manager.iniciar(tour.id)}
    aria-label={`Ajuda guiada: ${tour.titulo}`}
    title={`Ajuda guiada: ${tour.titulo}`}
    data-testid="botao-ajuda-guiada"
    data-tour="menu-ajuda"
    class="w-8 h-8 shrink-0 rounded-full border border-white/40 font-bold leading-none hover:bg-white/10 focus:outline-none focus-visible:ring-2 focus-visible:ring-white"
  >
    ?
  </button>
{/if}
