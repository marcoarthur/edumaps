<script>
  /**
   * Generic data table with sortable columns, caption and footer.
   *
   * @template T
   * @property {Array<{ key: keyof T, label: string, sortable?: boolean, render?: (row: T) => string, cell?: Snippet<[T]> }>} columns
   *   `render` devolve texto; `cell` é um snippet (`{#snippet celula(row)}`)
   *   para conteúdo com marcação. Se os dois vierem, vale o `cell`.
   * @property {T[]} data
   * @property {string} [caption]
   * @property {string} [footer]
   * @property {string} [rowKey] - campo que identifica a linha (padrão: 'id').
   *   Só vale se for único e preenchido em TODAS as linhas; senão a tabela usa
   *   a posição da linha em `data` (uma chave repetida derrubava a página
   *   inteira com `each_key_duplicate`).
   * @property {(field: string|null, dir: 'asc'|'desc'|null) => void} [onsort] - #602: com ele, a
   *   tabela não ordena o que mostra; avisa a coluna e a direção, e quem
   *   pagina ordena a lista inteira (use `ordenar` de `@/shared/ui`).
   */
  import { ordenar } from '../ordenar.js';

  let { columns = [], data = [], caption = '', footer = '', rowKey = 'id', onsort = undefined } = $props();

  // Chave do {#each}: o rowKey quando é único e preenchido em todas as linhas;
  // senão, a posição da linha em `data` (estável ao ordenar).
  let chaveUnica = $derived.by(() => {
    const chaves = data.map((linha) => linha?.[rowKey]);
    return (
      chaves.every((c) => c !== undefined && c !== null && c !== '') &&
      new Set(chaves).size === chaves.length
    );
  });
  let posicao = $derived(new Map(data.map((linha, i) => [linha, i])));

  // Sorting state
  let sortField = $state(null);
  let sortDirection = $state(null); // 'asc' or 'desc'

  // Derived sorted data (#602: com `onsort`, quem chama já ordenou)
  let sortedData = $derived(onsort ? data : ordenar(data, sortField, sortDirection));

  function handleSort(columnKey) {
    if (sortField === columnKey) {
      if (sortDirection === 'asc') sortDirection = 'desc';
      else if (sortDirection === 'desc') {
        sortField = null;
        sortDirection = null;
      } else {
        sortDirection = 'asc';
      }
    } else {
      sortField = columnKey;
      sortDirection = 'asc';
    }
    onsort?.(sortField, sortDirection);
  }

  function getSortIndicator(columnKey) {
    if (sortField !== columnKey) return '';
    return sortDirection === 'asc' ? ' ▲' : ' ▼';
  }
</script>

<table class="w-full text-sm border-collapse">
  {#if caption}
    <caption class="font-bold text-left mb-2 caption-top">{caption}</caption>
  {/if}

  <thead>
    <tr>
      {#each columns as col}
        <th
          class="px-4 py-2 text-left border-b-2 border-gray-300 bg-gray-100"
          class:sortable={col.sortable !== false}
          class:cursor-pointer={col.sortable !== false}
          class:hover:bg-gray-200={col.sortable !== false}
          class:select-none={col.sortable !== false}
          onclick={col.sortable !== false ? () => handleSort(col.key) : undefined}
        >
          {col.label}
          {#if col.sortable !== false}
            <span class="inline-block ml-1 text-xs text-gray-600">{getSortIndicator(col.key)}</span>
          {/if}
        </th>
      {/each}
    </tr>
  </thead>

  <tbody>
    {#each sortedData as row (chaveUnica ? row[rowKey] : posicao.get(row))}
      <tr class="border-b border-gray-200 hover:bg-gray-50">
        {#each columns as col}
          <td class="px-4 py-2">
            <!-- Snippet e texto vêm em propriedades separadas: adivinhar pelo
                 nome da função (snippet*) falha com o código minificado. -->
            {#if col.cell}
              {@render col.cell(row)}
            {:else if col.render}
              {col.render(row)}
            {:else}
              {row[col.key]}
            {/if}
          </td>
        {/each}
      </tr>
    {/each}
  </tbody>

  {#if footer}
    <tfoot>
      <tr>
        <td class="px-4 py-2 bg-gray-50 italic border-t border-gray-300" colspan={columns.length}>
          {footer}
        </td>
      </tr>
    </tfoot>
  {/if}
</table>
