<script>
  export let feature;
  const log_feat = () => console.log(feature);
  let land = feature.properties?.landuse || 'Uso desconhecido';
  let name = feature.properties?.name || 'Sem Nome';
</script>
<div class="popup">
  <strong>{name}</strong><br />
  <strong>{land}</strong><br />
  <button on:click={log_feat}>Check</button><br />
</div>

<style>
</style>
