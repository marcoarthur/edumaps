<script>
  // src/app/App.svelte
  import { router, link } from "./router.svelte.js";
  import { matchRoute, redirecionamento } from "./routes.js";
  import { eventBus, EVENTS } from "@/shared/events";
  import Toast from '@/shared/ui/components/Toast.svelte';
  import Logo from '@/shared/ui/components/Logo.svelte';
  import NovaVersaoAviso from '@/shared/ui/components/NovaVersaoAviso.svelte';
  import { untrack } from "svelte";
  import { tourManager, BotaoAjuda } from "@/shared/tour";

  const NAV_LINKS = [
    { to: "/", label: "Home" },
    { to: "/escola/search", label: "Busca Escola", tour: "menu-busca" },
    { to: "/cluster/geotag", label: "Análises", tour: "menu-analises" },
    { to: "/chat/censo", label: "Assistente do Censo", tour: "menu-assistente" },
    { to: "/config", label: "Configurações" },
    { to: "/admin", label: "Administração" },
    { to: "/gestor", label: "Gestor", tour: "menu-gestor" },
  ];

  // Páginas públicas abertas por link pessoal (token na URL): sem o menu da
  // plataforma e fora de qualquer sessão.
  const PUBLICAS_SEM_MENU = new Set([
    "/p/:token",
    "/inscricao/:token",
    "/privacidade/exclusao/:token",
    "/privacidade/sair/:token",
  ]);

  let match = $derived(matchRoute(router.path.split("?")[0]));

  // Endereços antigos (ex.: /about, a página "Sobre o Refactor" removida na
  // #392) trocam de URL sem entrar no histórico.
  $effect(() => {
    const destino = redirecionamento(router.path.split("?")[0]);
    if (destino) untrack(() => router.replace(destino));
  });

  // Navegação -> telemetria. Emite o PADRÃO da rota (ex.: /p/:token), nunca o
  // pathname cru — o link público de resposta carrega um token na URL, que não
  // pode ir para o repositório de eventos. O efeito roda no mount e a cada
  // mudança de router.path (pushState do router.navigate ou popstate).
  $effect(() => {
    eventBus.emit(
      EVENTS.NAVIGATE,
      { route: match?.path ?? router.path.split("?")[0] },
      { source: "App" }
    );
  });

  // Ajuda guiada: a cada rota, o tourManager decide se abre um tour
  // (`?tour=<id>`, retomada após recarregar, ou primeira visita). Só
  // `router.path` é dependência: o estado do próprio tour fica em `untrack`,
  // senão o fim de um tour re-dispararia este efeito.
  $effect(() => {
    const path = router.path.split("?")[0];
    untrack(() => {
      tourManager.aoNavegar(path, window.location.search);
      // `?tour=` é consumido uma vez: tirá-lo da URL evita reabrir no reload.
      const url = new URL(window.location.href);
      if (url.searchParams.has("tour")) {
        url.searchParams.delete("tour");
        window.history.replaceState(window.history.state, "", url);
      }
    });
  });

  function navLinkClass(path) {
    const state = router.path === path ? "bg-white/20" : "hover:bg-white/10";
    return `px-3 py-1.5 rounded-md transition-colors ${state}`;
  }
</script>

<div class="min-h-screen flex flex-col">
  {#if PUBLICAS_SEM_MENU.has(match?.path)}
    {#if match}
      <match.component token={match.params.token} />
    {/if}
  {:else}
  <nav class="bg-brand-700 text-white shadow-sm print:hidden">
    <div class="max-w-5xl mx-auto px-6 py-4 flex items-center gap-6">
      <a href="/" use:link class="flex items-center gap-2" aria-label="EduMaps — início">
        <Logo size={28} variant="light" />
        <span class="font-bold text-lg">EduMaps</span>
      </a>
      <div class="flex gap-4 text-sm">
        {#each NAV_LINKS as item}
          <a href={item.to} use:link class={navLinkClass(item.to)} data-tour={item.tour}>
            {item.label}
          </a>
        {/each}
      </div>
      <div class="ml-auto">
        <BotaoAjuda path={router.path.split("?")[0]} manager={tourManager} />
      </div>
    </div>
  </nav>
  <div class="print:hidden"><Toast /></div>
  <main class="flex-1 max-w-5xl mx-auto w-full px-6 py-8 print:max-w-none print:p-0">
    {#if match}
      <match.component {...(match.params ?? {})} />
    {:else}
      <p class="text-gray-500">Página não encontrada.</p>
    {/if}
  </main>
  {/if}
  <!-- Aviso de nova versão (#225): em todas as páginas, inclusive as públicas. -->
  <NovaVersaoAviso />
</div>
