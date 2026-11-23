<script>
  // src/features/fontes/components/FonteDado.svelte
  //
  // Selo de fonte de uma análise pública (#428, AN-08): de onde vem o dado,
  // de que ano e quando foi carregado, com link para "Fontes e metodologia".
  // Falha na busca não quebra a tela: o selo some.
  import { onMount } from "svelte";
  import { getFontes } from "../api/fontesApi.js";
  import { dataBR, fontesDaTela, rotuloFonte } from "../utils.js";

  /** @type {{ tela: string, class?: string }} */
  let { tela, class: className = "" } = $props();

  // #539: o catálogo é buscado uma vez; trocar a tela (ex.: o indicador do
  // ranking) só refiltra.
  let catalogo = $state([]);
  const fontes = $derived(fontesDaTela(catalogo, tela));

  onMount(async () => {
    try {
      catalogo = await getFontes();
    } catch {
      catalogo = [];
    }
  });
</script>

{#if fontes.length > 0}
  <p class="text-xs text-gray-500 {className}" data-testid="fonte-dado">
    <span class="font-medium text-gray-600">Fonte:</span>
    {#each fontes as f, i (f.id)}
      {#if i > 0}<span aria-hidden="true">{" · "}</span>{/if}
      <span>
        {rotuloFonte(f)} ({f.orgao}{#if f.carga?.data}, carga em {dataBR(f.carga.data)}{:else}, carga não registrada{/if})
      </span>
    {/each}
    <span aria-hidden="true">{" · "}</span>
    <a href="/fontes" class="text-blue-700 hover:underline">Fontes e metodologia</a>
  </p>
{/if}
