<script>
  import { osmDisabled } from './osmStore.js';
  export let feature;
  export let onDetails;
  export let onSchools;
  export let onOSM;
</script>

<div class="popup">
  <strong>{feature.name}</strong><br />
  <button on:click={() => onDetails(feature.fid)}>Detalhes</button><br />
  <button on:click={() => onSchools(feature.name)}>Escolas</button><br />
  <button on:click={() => onOSM(feature.fid)} disabled={$osmDisabled}>
  OSM {$osmDisabled ? '⏳' : ''}
  </button>
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
</style>
