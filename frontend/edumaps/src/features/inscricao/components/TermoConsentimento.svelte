<!-- src/features/inscricao/components/TermoConsentimento.svelte -->
<script>
  // Texto de consentimento vigente (issue #214), expansível e com a versão
  // visível. O markdown simples vira elementos próprios (sem {@html}).
  import { markdownSimples } from "../utils/markdownSimples.js";

  /** @type {{consentimento: {versao: string, texto: string}, aberto?: boolean}} */
  let { consentimento, aberto = $bindable(false) } = $props();

  const blocos = $derived(markdownSimples(consentimento?.texto));
</script>

{#snippet linha(trechos)}
  {#each trechos as t, i (i)}
    {#if t.negrito}<strong>{t.texto}</strong>{:else}{t.texto}{/if}
  {/each}
{/snippet}

<details
  class="rounded-md border border-gray-200 bg-gray-50"
  data-testid="termo-consentimento"
  bind:open={aberto}
>
  <summary class="cursor-pointer px-3 py-2 text-sm font-medium text-gray-700">
    Ler o termo de consentimento
    <span class="text-xs text-gray-500" data-testid="termo-versao">(versão {consentimento.versao})</span>
  </summary>
  <div class="px-3 pb-3 space-y-2 text-sm text-gray-700" data-testid="termo-texto">
    {#each blocos as b, i (i)}
      {#if b.tipo === "h"}
        <p class="font-semibold text-gray-900">{@render linha(b.trechos)}</p>
      {:else if b.tipo === "p"}
        <p>{@render linha(b.trechos)}</p>
      {:else if b.tipo === "ul"}
        <ul class="list-disc pl-5 space-y-0.5">
          {#each b.itens as item, j (j)}<li>{@render linha(item)}</li>{/each}
        </ul>
      {:else}
        <ol class="list-decimal pl-5 space-y-0.5">
          {#each b.itens as item, j (j)}<li>{@render linha(item)}</li>{/each}
        </ol>
      {/if}
    {/each}
  </div>
</details>
