<script>
  // src/features/home/pages/HomePage.svelte
  //
  // LandPage do EduMaps: apresenta o contexto do projeto — mapas, educação,
  // Censo Escolar, ferramentas analíticas e gestão escolar — e encaminha para
  // as entradas principais da plataforma (busca de escolas, análise de clusters
  // e área do gestor).
  import { router } from "@/app/router.svelte.js";
  import Logo from "@/shared/ui/components/Logo.svelte";

  const pillars = [
    {
      title: "Mapas",
      description:
        "Escolas georreferenciadas em mapas interativos, por município, rede e etapa de ensino.",
    },
    {
      title: "Educação",
      description:
        "Etapas de ensino, infraestrutura e indicadores das escolas públicas brasileiras.",
    },
    {
      title: "Censo Escolar",
      description:
        "Microdados do Censo Escolar e do IDEB que alimentam os indicadores da plataforma.",
    },
    {
      title: "Ferramentas analíticas",
      description:
        "Ranking, escolas semelhantes e agrupamento (clusters) descritos em linguagem natural.",
    },
    {
      title: "Gestão escolar",
      description:
        "Painel do gestor: pesquisas com a comunidade, reuniões e atas, inventário e relações institucionais da escola.",
    },
  ];

  function go(event, path) {
    event.preventDefault();
    router.navigate(path);
  }
</script>

<article class="space-y-12">
  <header class="text-center space-y-4 py-8">
    <div class="flex justify-center">
      <Logo size={80} />
    </div>
    <h1 class="text-4xl font-bold text-gray-900">EduMaps</h1>
    <p class="text-gray-600 max-w-2xl mx-auto leading-relaxed">
      Mapeamento, análise e gestão das escolas públicas brasileiras:
      geolocalização, indicadores educacionais e ferramentas analíticas em uma só
      plataforma.
    </p>
    <div class="flex flex-wrap justify-center gap-3 pt-2">
      <a
        href="/escola/search"
        onclick={(event) => go(event, "/escola/search")}
        class="px-5 py-2.5 rounded-md bg-brand-700 text-white font-medium hover:bg-brand-600 transition-colors"
      >
        Buscar escola
      </a>
      <a
        href="/cluster/geotag"
        onclick={(event) => go(event, "/cluster/geotag")}
        class="px-5 py-2.5 rounded-md border border-gray-300 text-gray-800 font-medium hover:bg-gray-100 transition-colors"
      >
        Ver análises
      </a>
      <a
        href="/gestor"
        onclick={(event) => go(event, "/gestor")}
        class="px-5 py-2.5 rounded-md border border-brand-700 text-brand-700 font-medium hover:bg-brand-50 transition-colors"
      >
        Sou gestor
      </a>
    </div>
  </header>

  <section class="grid gap-4 sm:grid-cols-2">
    {#each pillars as pillar}
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-2">{pillar.title}</h2>
        <p class="text-gray-600 text-sm leading-relaxed">{pillar.description}</p>
      </div>
    {/each}
  </section>
</article>
