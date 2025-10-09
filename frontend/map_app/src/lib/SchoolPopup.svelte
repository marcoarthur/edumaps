<script>
  export let school;
</script>

<div>
  <strong>{school.escola || 'Escola - Sem Nome'}</strong><br>
  {#if school.categoria_administrativa}
    Tipo: {school.categoria_administrativa}<br>
  {/if}
  {school.telefone}
</div>
