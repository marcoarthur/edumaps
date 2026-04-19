<script>
  import { activeCoverSchool } from './stores/activeCoverStore.js';
  export let school;
</script>

<div>
  <strong>{school.escola || 'Escola - Sem Nome'}</strong><br>
  {#if school.categoria_administrativa}
    Tipo: {school.categoria_administrativa}<br>
  {/if}
  {school.telefone}
  <br>
  <button on:click={() => activeCoverSchool.set({ properties: school })}>
    🗺️ Área de cobertura (5 km)
  </button>
</div>

<style>
  button {
    margin-top: 0.5rem;
    padding: 0.25rem 0.5rem;
    background: #2c7da0;
    color: white;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
  }
  button:hover {
    background: #1f5e7a;
  }
</style>
