<script>
  export let feature;
  // const log_feat = () => console.log(feature);
  const open_osm = () => {
    const id = feature?.properties?.id;
    const type = feature?.properties?.type || 'way'; // fallback

    const url = `https://www.openstreetmap.org/${type}/${id}`;
    window.open(url, '_blank');
  };

  let land = feature.properties?.landuse || 'Uso desconhecido';
  let name = feature.properties?.name || 'Sem Nome';
</script>
<div class="popup">
  <strong>{name}</strong><br />
  <strong>{land}</strong><br />
  <button on:click={open_osm}>Check</button><br />
</div>

<style>
</style>
