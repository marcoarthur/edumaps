<script>
  // src/features/about/pages/AboutPage.svelte
  const goals = [
    "PWA com Svelte 5 (runes) e build estático para nginx",
    "Estilo centralizado com Tailwind, sem CSS inline duplicado por componente",
    "Rotas estruturadas por feature, sem roteamento manual em onMount",
    "Componentes reutilizáveis (mapa, cards, tabelas) em vez de duplicação",
    "Testes unitários para cada componente e cada chamada de API",
  ];
</script>

<article class="max-w-3xl mx-auto space-y-8">
  <header>
    <h1 class="text-3xl font-bold text-gray-900">Sobre o Refactor</h1>
    <p class="mt-2 text-gray-600">
      O frontend do EduMaps está sendo completamente reescrito. Esta página existe
      para acompanhar o motivo e o formato da reescrita.
    </p>
  </header>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Por que reescrever?</h2>
    <p class="text-gray-700 leading-relaxed">
      O frontend anterior (<code class="bg-gray-100 px-1.5 py-0.5 rounded text-sm">map_app</code>)
      cresceu de forma ad-hoc: roteamento manual via
      <code class="bg-gray-100 px-1.5 py-0.5 rounded text-sm">window.location.pathname</code>,
      estilo duplicado em dezenas de componentes e pouca cobertura de testes.
      A reescrita em <code class="bg-gray-100 px-1.5 py-0.5 rounded text-sm">frontend/edumaps</code>
      parte do zero, abandonando o código antigo.
    </p>
  </section>

  <section class="bg-white border border-gray-200 rounded-card shadow-card p-6">
    <h2 class="text-lg font-semibold text-gray-900 mb-3">Objetivos da nova base</h2>
    <ul class="space-y-2">
      {#each goals as goal}
        <li class="flex gap-2 text-gray-700">
          <span class="text-brand-600 font-bold">→</span>
          <span>{goal}</span>
        </li>
      {/each}
    </ul>
  </section>
</article>
