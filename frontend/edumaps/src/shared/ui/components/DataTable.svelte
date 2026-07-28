<script>
  /**
   * Generic data table with sortable columns, caption and footer.
   *
   * @template T
   * @property {Array<{ key: keyof T, label: string, sortable?: boolean, render?: (row: T) => string | Snippet }>} columns
   * @property {T[]} data
   * @property {string} [caption]
   * @property {string} [footer]
   * @property {string} [rowKey] - unique key for each row (default: 'id')
   */
  let { columns = [], data = [], caption = '', footer = '', rowKey = 'id' } = $props();

  // Sorting state
  let sortField = $state(null);
  let sortDirection = $state(null); // 'asc' or 'desc'

  // Derived sorted data
  let sortedData = $derived.by(() => {
    if (!sortField || !sortDirection) return data;

    const field = sortField;
    const dir = sortDirection;

    // Determine type for comparison
    const sample = data[0]?.[field];
    const isNumeric = typeof sample === 'number' || sample === null || sample === undefined;

    return [...data].sort((a, b) => {
      let valA = a[field] ?? '';
      let valB = b[field] ?? '';
      let compareResult;

      if (isNumeric) {
        compareResult = (Number(valA) || 0) - (Number(valB) || 0);
      } else {
        compareResult = String(valA).localeCompare(String(valB));
      }

      return dir === 'asc' ? compareResult : -compareResult;
    });
  });

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
    {#each sortedData as row (row[rowKey] || row.id)}
      <tr class="border-b border-gray-200 hover:bg-gray-50">
        {#each columns as col}
          <td class="px-4 py-2">
            {#if col.render}
              <!-- Suporta tanto função que retorna string quanto snippet -->
              {#if typeof col.render === 'function' && !col.render.name?.startsWith('snippet')}
                {col.render(row)}
              {:else}
                {@render col.render(row)}
              {/if}
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
