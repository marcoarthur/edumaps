<script>
  // src/features/schools/components/SchoolCard.svelte
  //
  // Substitui o card inline duplicado dentro de SchList.svelte no
  // frontend antigo. Recebe o objeto exatamente como o backend retorna
  // (ver EduMaps::Model::School#default_columns).
  import { formatPhone } from "@/shared/utils/format.js";

  let { school } = $props();

  const TIPO_STYLES = {
    municipal: "bg-emerald-100 text-emerald-800",
    estadual: "bg-blue-100 text-blue-800",
    privada: "bg-purple-100 text-purple-800",
    federal: "bg-amber-100 text-amber-800",
  };

  let tipoClass = $derived(
    TIPO_STYLES[school.tipo?.toLowerCase()] ?? "bg-gray-100 text-gray-800"
  );

  let phone = $derived(formatPhone(school.telefone));
</script>

<article class="bg-white border border-gray-200 rounded-card shadow-card p-5 flex flex-col gap-3">
  <header class="flex items-start justify-between gap-3">
    <div>
      <h3 class="font-semibold text-gray-900 leading-snug">{school.escola}</h3>
      <p class="text-xs text-gray-500 mt-0.5">INEP: {school.codigo_inep}</p>
    </div>
    <span class={`shrink-0 px-2.5 py-1 rounded-full text-xs font-medium ${tipoClass}`}>
      {school.tipo ?? "Não informado"}
    </span>
  </header>

  <p class="text-sm text-gray-700">
    {school.endereco}
    <span class="block text-xs text-gray-500 mt-0.5">{school.municipio} - {school.uf}</span>
  </p>

  {#if school.modalidades?.length}
    <div class="flex flex-wrap gap-1.5">
      {#each school.modalidades as modalidade}
        <span class="px-2 py-0.5 bg-gray-100 text-gray-700 text-xs rounded">{modalidade}</span>
      {/each}
    </div>
  {/if}

  <div class="flex items-center justify-between text-sm pt-2 border-t border-gray-100">
    {#if phone}
      <a href={`tel:${school.telefone}`} class="text-brand-600 hover:underline">{phone}</a>
    {:else}
      <span class="text-gray-400">Telefone não informado</span>
    {/if}

    <div class="flex gap-3 text-xs">
      {#if school.osm}
        <a href={school.osm} target="_blank" rel="noopener noreferrer" class="text-brand-600 hover:underline">
          Mapa
        </a>
      {/if}
      {#if school.whatsapp}
        <a href={school.whatsapp} target="_blank" rel="noopener noreferrer" class="text-emerald-600 hover:underline">
          WhatsApp
        </a>
      {/if}
    </div>
  </div>
</article>
