<script>
  // src/features/gestor/components/EquipmentSection.svelte
  import StatusGrid from "./StatusGrid.svelte";
  import Icon from "./icons/Icon.svelte";
  import { formatInt } from "../utils/transformGestorData.js";

  let { equipamentos = {} } = $props();

  const dispositivos = $derived(equipamentos.dispositivos ?? []);
  const itens = $derived(equipamentos.itens ?? []);
  const conectividade = $derived(equipamentos.conectividade ?? []);
</script>

<section class="space-y-4">
  {#if equipamentos.sem_equipamentos}
    <div class="bg-amber-50 border border-amber-200 text-amber-800 text-sm rounded-card p-4">
      A escola declarou <strong>não possuir equipamentos</strong> no Censo Escolar.
    </div>
  {/if}

  <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
    {#each dispositivos as dev (dev.key)}
      <div class="bg-white border border-gray-200 rounded-card shadow-card p-4 flex items-center gap-3">
        <Icon name={dev.key} size={32} active={!!dev.present} />
        <div>
          <p class="text-xs text-gray-500">{dev.label}</p>
          <p class="text-2xl font-bold text-gray-900 mt-0.5">{formatInt(dev.qtd)}</p>
        </div>
      </div>
    {/each}
  </div>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <h3 class="text-base font-bold text-gray-900 mb-4">Equipamentos</h3>
      <StatusGrid items={itens} />
    </div>
    <div class="bg-white border border-gray-200 rounded-card shadow-card p-5">
      <h3 class="text-base font-bold text-gray-900 mb-4">Conectividade</h3>
      <StatusGrid items={conectividade} />
    </div>
  </div>
</section>
