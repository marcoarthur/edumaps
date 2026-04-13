<script>
  import { selectedSchool, hoveredSchool, sortedSchools } from './js/schoolStore.js';
</script>

<div class="school-table-wrapper">
  {#if $sortedSchools.length === 0}
    <p class="empty">Nenhuma escola carregada.</p>
  {:else}
    <table>
      <thead>
        <tr>
          <th>Código INEP</th>
          <th>Escola</th>
          <th>Telefone</th>
        </tr>
      </thead>
      <tbody>
        {#each $sortedSchools as school (school.properties.codigo_inep)}
          {@const p = school.properties}
          {@const isSelected = $selectedSchool?.properties.codigo_inep === p.codigo_inep}
          {@const isHovered  = $hoveredSchool?.properties.codigo_inep  === p.codigo_inep}
          <tr
            class:selected={isSelected}
            class:hovered={isHovered}
            on:click={() => selectedSchool.set(school)}
            on:mouseenter={() => hoveredSchool.set(school)}
            on:mouseleave={() => hoveredSchool.set(null)}
          >
            <td>{p.codigo_inep ?? '—'}</td>
            <td>{p.escola      ?? '—'}</td>
            <td>{p.telefone ?? '—'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .school-table-wrapper {
    max-height: 400px;
    overflow-y: auto;
    border: 1px solid rgba(0,0,0,.12);
    border-radius: 8px;
    font-size: 13px;
  }
  table { width: 100%; border-collapse: collapse; }
  thead th {
    position: sticky; top: 0;
    background: var(--color-background-secondary, #f5f5f5);
    padding: 8px 10px;
    text-align: left;
    font-weight: 500;
    border-bottom: 1px solid rgba(0,0,0,.1);
  }
  tbody tr {
    cursor: pointer;
    transition: background .15s;
  }
  tbody tr:hover, tr.hovered   { background: rgba(255, 209, 102, .25); }
  tr.selected                  { background: rgba(230,  57,  70, .12); font-weight: 500; }
  td { padding: 7px 10px; border-bottom: 1px solid rgba(0,0,0,.06); }
  .empty { padding: 16px; color: var(--color-text-secondary); text-align: center; }
</style>
