<script>
  import CitySelector from './CitySelector.svelte';
  
  let currentCity = null;
  
  const handleCitySelect = (city) => {
    console.log(`MunicipiosMapa: cidade selecionada`, city);
    currentCity = city.original;
    // Opcional: salvar no localStorage ou store global
    localStorage.setItem('lastSelectedCity', JSON.stringify(city));
  };
</script>

<div class="page">
  <h1 class="page-title">📊 Análise Municipal - Educação no Brasil</h1>
  <p class="page-subtitle">
    Explore indicadores educacionais, econômicos e demográficos de todos os municípios brasileiros
  </p>
  
  <CitySelector onCitySelect={handleCitySelect} />
  
  {#if currentCity}
    <div class="selected-indicator">
      ✅ Município selecionado: <strong>{currentCity.nome_municipio} - {currentCity.sigla_estado}</strong>
      <span class="selected-id">(IBGE: {currentCity.codigo_ibge})</span>
    </div>
  {/if}
</div>

<style>
  .page {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem;
  }

  .page-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: #111827;
    margin-bottom: 0.5rem;
  }

  .page-subtitle {
    color: #6b7280;
    margin-bottom: 1.5rem;
    font-size: 0.875rem;
  }

  .selected-indicator {
    margin-top: 1rem;
    padding: 0.5rem 1rem;
    background: #e0f2fe;
    border-radius: 0.5rem;
    font-size: 0.875rem;
    color: #0369a1;
  }

  .selected-id {
    font-size: 0.7rem;
    color: #0284c7;
  }
</style>
