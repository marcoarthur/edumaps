<!-- src/features/gestor/components/relatorios/SecaoIndicadores.svelte -->
<script>
  // Seção de indicadores (#219): um cartão por item, com o valor formatado e,
  // quando houver, a referência (ex.: o valor da UF para comparação).
  import { formatarValor } from "../../utils/relatorioFormatos.js";

  /** @type {{secao: {id: string, titulo?: string, itens?: Array<object>}}} */
  let { secao } = $props();
</script>

<section class="space-y-3" aria-labelledby="secao-{secao.id}" data-testid="secao-indicadores">
  {#if secao.titulo}
    <h2 id="secao-{secao.id}" class="text-lg font-semibold text-gray-900">{secao.titulo}</h2>
  {/if}
  <ul class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
    {#each secao.itens ?? [] as item, i (i)}
      <li class="bg-white border border-gray-200 rounded-card shadow-card p-4" data-testid="indicador">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wide">{item.rotulo}</p>
        <p class="text-2xl font-bold text-gray-900 mt-1">{formatarValor(item.valor, item.formato)}</p>
        {#if item.referencia}
          <p class="text-xs text-gray-500 mt-1" data-testid="indicador-referencia">
            {item.referencia.rotulo}: {formatarValor(item.referencia.valor, item.referencia.formato ?? item.formato)}
          </p>
        {/if}
      </li>
    {/each}
  </ul>
</section>
