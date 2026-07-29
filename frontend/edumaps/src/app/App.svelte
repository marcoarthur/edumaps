<script>
  // src/app/App.svelte
  import { router, link } from "./router.svelte.js";
  import { matchRoute } from "./routes.js";

  const NAV_LINKS = [{ to: "/about", label: "Sobre o Refactor" }];

  // ainda não existe uma "home" de verdade — redireciona para /about
  $effect(() => {
    if (router.path === "/") {
      router.navigate("/about");
    }
  });

  let match = $derived(matchRoute(router.path));

  function navLinkClass(path) {
    const state = router.path === path ? "bg-white/20" : "hover:bg-white/10";
    return `px-3 py-1.5 rounded-md transition-colors ${state}`;
  }
</script>

<div class="min-h-screen flex flex-col">
  <nav class="bg-brand-700 text-white shadow-sm">
    <div class="max-w-5xl mx-auto px-6 py-4 flex items-center gap-6">
      <span class="font-bold text-lg">EduMaps</span>
      <div class="flex gap-4 text-sm">
        {#each NAV_LINKS as item}
          <a href={item.to} use:link class={navLinkClass(item.to)}>
            {item.label}
          </a>
        {/each}
      </div>
    </div>
  </nav>

  <main class="flex-1 max-w-5xl mx-auto w-full px-6 py-8">
    {#if match}
      <match.component />
    {:else}
      <p class="text-gray-500">Página não encontrada.</p>
    {/if}
  </main>
</div>
