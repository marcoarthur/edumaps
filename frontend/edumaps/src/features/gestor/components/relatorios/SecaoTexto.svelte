<!-- src/features/gestor/components/relatorios/SecaoTexto.svelte -->
<script>
  // Seção de texto do relatório (#219): markdown simples, renderizado com
  // elementos próprios pelo TextoMarkdown — nunca com {@html}.
  import TextoMarkdown from "@/features/inscricao/components/TextoMarkdown.svelte";

  /** @type {{secao: {id: string, titulo?: string, markdown?: string}}} */
  let { secao } = $props();
</script>

<section class="space-y-2" aria-labelledby="secao-{secao.id}" data-testid="secao-texto">
  {#if secao.titulo}
    <h2 id="secao-{secao.id}" class="text-lg font-semibold text-gray-900">{secao.titulo}</h2>
  {/if}
  <div class="text-sm text-gray-700 space-y-2 leading-relaxed">
    <TextoMarkdown texto={secao.markdown ?? ""} />
  </div>
</section>
