<!-- src/features/gestor/components/relatorios/SecaoTabela.svelte -->
<script>
  // Seção de tabela (#219): tabela acessível (caption + th scope) com os
  // formatos do contrato; colunas numéricas alinhadas à direita.
  import { formatarValor, ehNumerico } from "../../utils/relatorioFormatos.js";

  /** @type {{secao: {id: string, titulo?: string, colunas?: Array<object>, linhas?: Array<object>, nota?: string}}} */
  let { secao } = $props();

  const colunas = $derived(secao.colunas ?? []);
  const linhas = $derived(secao.linhas ?? []);
</script>

<section class="space-y-2" data-testid="secao-tabela">
  <div class="overflow-x-auto bg-white border border-gray-200 rounded-card shadow-card">
    <table class="min-w-full text-sm">
      <caption class="text-left text-lg font-semibold text-gray-900 px-4 pt-3 pb-2">
        {secao.titulo ?? "Tabela"}
      </caption>
      <thead class="bg-gray-50 text-gray-600">
        <tr>
          {#each colunas as col (col.id)}
            <th
              scope="col"
              class="font-medium px-4 py-2"
              class:text-right={ehNumerico(col.formato)}
              class:text-left={!ehNumerico(col.formato)}
            >{col.rotulo ?? col.id}</th>
          {/each}
        </tr>
      </thead>
      <tbody class="divide-y divide-gray-100">
        {#each linhas as linha, i (i)}
          <tr>
            {#each colunas as col, j (col.id)}
              {#if j === 0}
                <th scope="row" class="font-medium text-gray-900 px-4 py-2" class:text-right={ehNumerico(col.formato)} class:text-left={!ehNumerico(col.formato)}>
                  {formatarValor(linha[col.id], col.formato)}
                </th>
              {:else}
                <td class="px-4 py-2 text-gray-700" class:text-right={ehNumerico(col.formato)}>
                  {formatarValor(linha[col.id], col.formato)}
                </td>
              {/if}
            {/each}
          </tr>
        {:else}
          <tr><td class="px-4 py-4 text-center text-gray-500" colspan={colunas.length || 1}>Sem dados para este recorte.</td></tr>
        {/each}
      </tbody>
    </table>
  </div>
  {#if secao.nota}
    <p class="text-xs text-gray-500">{secao.nota}</p>
  {/if}
</section>
