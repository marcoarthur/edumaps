<script>
  // src/app/App.svelte
  import { router, link } from "./router.svelte.js";
  import { matchRoute } from "./routes.js";
  import { eventBus, EVENTS } from "@/shared/events";
  import Toast from '@/shared/ui/components/Toast.svelte';
  import Logo from '@/shared/ui/components/Logo.svelte';

  const NAV_LINKS = [
    { to: "/", label: "Home" },
    { to: "/escola/search", label: "Busca Escola" },
    { to: "/cluster/geotag", label: "Análises" },
    { to: "/chat/censo", label: "Assistente do Censo" },
    { to: "/config", label: "Configurações" },
    { to: "/gestor", label: "Gestor" },
    { to: "/about", label: "Sobre o Refactor" },
  ];

  let match = $derived(matchRoute(router.path.split("?")[0]));

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

  function navLinkClass(path) {
    const state = router.path === path ? "bg-white/20" : "hover:bg-white/10";
    return `px-3 py-1.5 rounded-md transition-colors ${state}`;
  }
</script>

<div class="min-h-screen flex flex-col">
  {#if match?.path === "/p/:token"}
    {#if match}
      <match.component token={match.params.token} />
    {/if}
  {:else}
  <nav class="bg-brand-700 text-white shadow-sm">
    <div class="max-w-5xl mx-auto px-6 py-4 flex items-center gap-6">
      <a href="/" use:link class="flex items-center gap-2" aria-label="EduMaps — início">
        <Logo size={28} variant="light" />
        <span class="font-bold text-lg">EduMaps</span>
      </a>
      <div class="flex gap-4 text-sm">
        {#each NAV_LINKS as item}
          <a href={item.to} use:link class={navLinkClass(item.to)}>
            {item.label}
          </a>
        {/each}
      </div>
    </div>
  </nav>
  <Toast />
  <main class="flex-1 max-w-5xl mx-auto w-full px-6 py-8">
    {#if match}
      <match.component {...(match.params ?? {})} />
    {:else}
      <p class="text-gray-500">Página não encontrada.</p>
    {/if}
  </main>
  {/if}
</div>
