<script>
  // src/features/gestor/components/GestorPanel.svelte
  import StatCard from "./StatCard.svelte";
  import EnrollmentSection from "./EnrollmentSection.svelte";
  import TeachersSection from "./TeachersSection.svelte";
  import EquipmentSection from "./EquipmentSection.svelte";
  import StatusGrid from "./StatusGrid.svelte";
  import { resumoCards, formatInt } from "../utils/transformGestorData.js";

  /**
   * @typedef {Object} Props
   * @property {string|number} inep
   * @property {Object} escola
   * @property {Object} resumo
   * @property {Object} matriculas
   * @property {Object} turmas
   * @property {Object} docentes
   * @property {Object} infraestrutura
   * @property {Object} equipamentos
   * @property {Array} acessibilidade
   */

  /** @type {Props} */
  let {
    inep,
    escola = {},
    resumo = {},
    matriculas = {},
    turmas = {},
    docentes = {},
    infraestrutura = {},
    equipamentos = {},
    acessibilidade = [],
  } = $props();

  const cards = $derived(resumoCards(resumo));

  const NAV = [
    { href: "#matriculas", label: "Matrículas" },
    { href: "#docentes", label: "Docentes" },
    { href: "#infraestrutura", label: "Infraestrutura" },
    { href: "#equipamentos", label: "Equipamentos" },
    { href: "#acessibilidade", label: "Acessibilidade" },
  ];
</script>

<div class="space-y-7">
  <header class="flex flex-wrap items-start justify-between gap-4 border-b border-gray-200 pb-4">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">{escola.nome}</h1>
      <p class="text-sm text-gray-600 mt-1">
        {escola.municipio} · {escola.uf}
        {#if escola.rede}· {escola.rede}{/if}
        {#if escola.ano_censo}· Censo {escola.ano_censo}{/if}
        · INEP {inep}
      </p>
    </div>
    <div class="flex items-center gap-2">
      <a
        href={`/escola/panel?inep=${inep}`}
        class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors whitespace-nowrap"
      >
        Painel da escola
      </a>
      <a
        href={`/escola/financeiro?inep=${inep}`}
        class="px-3 py-2 text-sm font-medium rounded-md border border-gray-300 text-gray-700 hover:bg-gray-100 transition-colors whitespace-nowrap"
      >
        Painel financeiro
      </a>
    </div>
  </header>

  <section class="grid grid-cols-2 lg:grid-cols-4 gap-4">
    {#each cards as card (card.key)}
      <StatCard label={card.label} value={card.value} icon={card.icon} />
    {/each}
  </section>

  <nav class="flex flex-wrap gap-2">
    {#each NAV as item}
      <a
        href={item.href}
        class="px-3 py-1.5 text-xs font-medium rounded-full bg-white border border-gray-200 text-gray-600 hover:bg-gray-100"
      >
        {item.label}
      </a>
    {/each}
  </nav>

  <section id="matriculas" class="space-y-4 scroll-mt-4">
    <h2 class="text-lg font-bold text-gray-900">Matrículas</h2>
    <EnrollmentSection {matriculas} {resumo} />
  </section>

  <section id="docentes" class="space-y-4 scroll-mt-4">
    <h2 class="text-lg font-bold text-gray-900">Docentes</h2>
    <TeachersSection {docentes} />
  </section>

  <section id="infraestrutura" class="space-y-4 scroll-mt-4">
    <h2 class="text-lg font-bold text-gray-900">Infraestrutura</h2>

    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5 grid grid-cols-2 sm:grid-cols-4 gap-4">
      <div>
        <p class="text-xs text-gray-500">Salas utilizadas</p>
        <p class="text-xl font-bold text-gray-900">{formatInt(turmas.salas_utilizadas)}</p>
      </div>
      <div>
        <p class="text-xs text-gray-500">Alunos por sala</p>
        <p class="text-xl font-bold text-gray-900">{formatInt(resumo.alunos_por_sala)}</p>
      </div>
      <div>
        <p class="text-xs text-gray-500">Salas climatizadas</p>
        <p class="text-xl font-bold text-gray-900">{formatInt(turmas.salas_climatizadas)}</p>
      </div>
      <div>
        <p class="text-xs text-gray-500">Salas acessíveis</p>
        <p class="text-xl font-bold text-gray-900">{formatInt(turmas.salas_acessiveis)}</p>
      </div>
      {#if turmas.nota}
        <p class="text-[11px] text-gray-400 col-span-2 sm:col-span-4">{turmas.nota}</p>
      {/if}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <h3 class="text-base font-bold text-gray-900 mb-4">Serviços básicos</h3>
        <StatusGrid items={infraestrutura.basica ?? []} />
      </div>
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
        <h3 class="text-base font-bold text-gray-900 mb-4">Espaços</h3>
        <StatusGrid items={infraestrutura.espacos ?? []} />
      </div>
    </div>
  </section>

  <section id="equipamentos" class="space-y-4 scroll-mt-4">
    <h2 class="text-lg font-bold text-gray-900">Equipamentos</h2>
    <EquipmentSection {equipamentos} />
  </section>

  <section id="acessibilidade" class="space-y-4 scroll-mt-4">
    <h2 class="text-lg font-bold text-gray-900">Acessibilidade</h2>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <StatusGrid items={acessibilidade} />
    </div>
  </section>
</div>
