<!-- src/features/gestor/components/relatorios/SecaoTexto.svelte -->
<script>
  // Seção de texto do relatório (#219): markdown simples, renderizado com
  // elementos próprios pelo TextoMarkdown — nunca com {@html}.
  import TextoMarkdown from "@/features/inscricao/components/TextoMarkdown.svelte";

  /** @type {{secao: {id: string, titulo?: string, markdown?: string}, nivelTitulo?: number}} */
  // nivelTitulo: 2 (padrão) ou 3 quando a seção está dentro de um capítulo (fase 4)
  let { secao, nivelTitulo = 2 } = $props();
</script>

<section class="space-y-2" aria-labelledby="secao-{secao.id}" data-testid="secao-texto">
  {#if secao.titulo}
    <svelte:element this={`h${nivelTitulo}`} id="secao-{secao.id}" class="text-lg font-semibold text-gray-900">{secao.titulo}</svelte:element>
  {/if}
  <div class="text-sm text-gray-700 space-y-2 leading-relaxed">
    <TextoMarkdown texto={secao.markdown ?? ""} />
  </div>
</section>
