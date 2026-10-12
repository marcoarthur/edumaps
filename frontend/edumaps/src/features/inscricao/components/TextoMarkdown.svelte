<!-- src/features/inscricao/components/TextoMarkdown.svelte -->
<script>
  // Renderiza o "markdown simples" do consentimento (issue #214) com elementos
  // próprios — nunca com {@html}. Usado no termo da inscrição, na página de
  // privacidade e na pré-visualização do admin.
  import { markdownSimples } from "../utils/markdownSimples.js";

  /** @type {{texto?: string|null}} */
  let { texto = "" } = $props();

  const blocos = $derived(markdownSimples(texto));
</script>

{#snippet linha(trechos)}
  {#each trechos as t, i (i)}
    {#if t.negrito}<strong>{t.texto}</strong>{:else}{t.texto}{/if}
  {/each}
{/snippet}

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
