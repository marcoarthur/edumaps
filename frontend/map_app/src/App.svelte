<script>
  import { onMount } from 'svelte';
  import BuscaEscolasPage from './lib/School/SearchSchoolPage.svelte';
  
  // Você pode adicionar outros componentes aqui quando necessário
  // import Map from './lib/Siope/Map.svelte';
  
  import Map from './lib/AppMap.svelte';
  let currentView = 'busca';
  
  // Simples roteamento baseado na URL
  onMount(() => {
    const path = window.location.pathname;
    if (path === '/mapa') {
      currentView = 'mapa';
    } else if (path === '/busca') {
      currentView = 'busca';
    }
  });
</script>

<main>
  <nav class="main-nav">
    <div class="nav-container">
      <div class="nav-brand">
        <span class="brand-icon">🏫</span>
        <span class="brand-name">Sistema Escolar</span>
      </div>
      <div class="nav-links">
        <a href="/busca" class="nav-link" class:active={currentView === 'busca'}>
          🔍 Buscar Escolas
        </a>
        <a href="/mapa" class="nav-link" class:active={currentView === 'mapa'}>
          🗺️ Mapa
        </a>
      </div>
    </div>
  </nav>
  
  <div class="content">
    {#if currentView === 'busca'}
      <BuscaEscolasPage />
    {:else if currentView === 'mapa'}
      <Map />
    {/if}
  </div>
</main>

<style>
  .main-nav {
    background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
    color: white;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }

  .nav-container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .nav-brand {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 1.25rem;
    font-weight: bold;
  }

  .brand-icon {
    font-size: 1.5rem;
  }

  .nav-links {
    display: flex;
    gap: 2rem;
  }

  .nav-link {
    color: white;
    text-decoration: none;
    padding: 0.5rem 1rem;
    border-radius: 0.375rem;
    transition: background-color 0.2s;
  }

  .nav-link:hover {
    background-color: rgba(255, 255, 255, 0.1);
  }

  .nav-link.active {
    background-color: rgba(255, 255, 255, 0.2);
    font-weight: 500;
  }

  .content {
    min-height: calc(100vh - 64px);
    background-color: #f9fafb;
  }

  .coming-soon {
    text-align: center;
    padding: 4rem;
    font-size: 1.25rem;
    color: #6b7280;
  }
</style>
