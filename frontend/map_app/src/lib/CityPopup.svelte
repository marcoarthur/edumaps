<script>
  import { osmDisabled } from './osmStore.js';
  export let feature;
  export let onDetails;
  export let onSchools;
  export let onOSM;
  export let onCluster;  // Novo evento
  
  function handleCluster() {
    // Emite o evento com o código IBGE e nome da cidade
    onCluster({ 
      codigo_ibge: feature.fid,
      city: feature.name
    });
  }
</script>

<div class="popup">
  <strong>{feature.name}</strong><br />
  <button on:click={() => onDetails(feature.fid)}>Detalhes</button><br />
  <button on:click={() => onSchools(feature.fid)}>Escolas</button><br />
  <button on:click={() => onOSM(feature.fid)} disabled={$osmDisabled}>
  OSM {$osmDisabled ? '⏳' : ''} </button><br />
  <button on:click={handleCluster} class='cluster-btn'>Cluster</button>
</div>

<style>
  button {
    all: unset;
    color: #007bff;
    cursor: pointer;
    margin-top: 4px;
    display: inline-block;
  }
  button:hover {
    text-decoration: underline;
  }

  .cluster-btn {
    background-color: #8b5cf6;
    color: white;
  }
</style>
