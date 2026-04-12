<script>
  import { getSiopePayroll } from './js/siope.js';
  import Payroll     from './Siope/Payroll.svelte';
  import JobProgress from './Siope/JobProgress.svelte';
  export let data = null;
  export let year = new Date().getFullYear() - 1; //  Last year
  
  const fieldLabels = {
    'id': 'ID',
    'area': 'Área (km²)',
    'codigo_municipio': 'Código do Município',
    'nome_municipio': 'Município',
    'codigo_unidade_federativa': 'Código UF',
    'nome_unidade_federativa': 'Estado',
    'sigla_unidade_federativa': 'UF',
    'codigo_regiao': 'Código Região',
    'nome_regiao_intermediaria': 'Região Intermediária',
    'nome_regiao_interna': 'Região Imediata',
    'sigla_regiao': 'Sigla Região',
    'codigo_concurso': 'Código Concurso',
    'nome_concurso': 'Nome Concurso',
    'total_escolas': 'Total de Escolas'
  };

  function formatValue(key, value) {
    if (value === null) return 'N/A';
    
    switch (key) {
      case 'area':
        return Number(value).toLocaleString('pt-BR', {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2
        });
      case 'codigo_municipio':
      case 'codigo_unidade_federativa':
        return `"${value}"`;
      default:
        return String(value);
    }
  }

  // Variáveis de estado para o SIOPE
  let siopePayroll = null; // Armazena os dados finais (Componente 1)
  let siopeJobId = null;  // Armazena o ID do Job (Componente 2)
  let isFetching = false; // Estado de carregamento inicial
  let hasAttempted = false; // Para não mostrar o botão de primeira
  let fetchError = null;

  async function handleFetchSiope() {
      if (!data || !data.codigo_ibge) {
          console.error("Código do município não disponível.");
          return;
      }

      const cityId = String(data.codigo_ibge).slice(0,-1);
      isFetching = true;
      hasAttempted = true;
      siopeJobId = null;
      siopePayroll = null;
      fetchError = null;

      try {
          // Chamada da função principal (GET -> POST, se necessário)
          const result = await getSiopePayroll(cityId, year);
          
          // O getSiopePayroll resolve com o job ID ou com os dados.
          if (typeof result === 'number') {
              // Caso 202 Accepted, result é o Job ID
              siopeJobId = result;
              // O monitorJobProgress do JobProgress.svelte continuará o fluxo
          } else {
              // Caso 200 OK, result são os dados do payroll
              siopePayroll = result;
          }

      } catch (e) {
          fetchError = e.message;
          console.error("Erro no fluxo SIOPE:", e);
      } finally {
          isFetching = false;
      }
  }

  // Callback chamado pelo JobProgress.svelte quando o job Minion termina
  function handleJobComplete(data) {
      siopeJobId = null;
      siopePayroll = data;
      console.log("Fluxo SIOPE concluído e dados recebidos!");
  }
</script>

{#if data}
  <div class="details-container">
    <h3 class="details-header">Detalhes {data.nome_municipio || ''}</h3>
    <p class="details-subheader">Dados malha IBGE, municípios paulista</p>
    
    <table class="geojson-details">
      <tbody>
        {#each Object.entries(data) as [key, value]}
          {#if key !== 'type' && key !== 'geometry'}
            <tr>
              <th>{fieldLabels[key] || key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}</th>
              <td class:null-value={value === null}>
                {formatValue(key, value)}
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>

    <hr/>
    
    <div class="siope-section">
        {#if siopePayroll}
            <Payroll payrollData={siopePayroll} />

        {:else if siopeJobId}
            <JobProgress 
                jobId={siopeJobId} 
                onJobComplete={handleJobComplete} 
                jobName={`Cálculo SIOPE para ${year}`}
            />

        {:else if fetchError}
            <div class="error-message">⚠️ Erro ao buscar dados SIOPE: {fetchError}</div>
            <button on:click={handleFetchSiope} class="fetch-button">Tentar novamente</button>

        {:else}
            <button 
                on:click={handleFetchSiope} 
                disabled={isFetching}
                class="fetch-button primary"
            >
                {#if isFetching}
                    Carregando...
                {:else}
                    Buscar Detalhes SIOPE {year}
                {/if}
            </button>
            <p class="fetch-note">A primeira busca pode iniciar um processo demorado.</p>
        {/if}
    </div>

  </div>

{/if}

<style>
  .details-container {
    background: white;
    padding: 1.5rem;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.5);
    margin: 1rem 0;
  }

  .details-header {
    color: #2c3e50;
    margin-bottom: 0.5rem;
    font-size: 1.2rem;
    font-weight: 600;
  }

  .details-subheader {
    color: #6c757d;
    margin-bottom: 1rem;
    font-size: 0.9rem;
  }

  .geojson-details {
    width: 100%;
    border-collapse: collapse;
    margin: 1rem 0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    font-size: 0.9rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.5);
    border-radius: 8px;
    overflow: hidden;
  }

  .geojson-details th {
    background-color: #f8f9fa;
    padding: 12px 16px;
    text-align: left;
    font-weight: 600;
    color: #2c3e50;
    border-bottom: 2px solid #e9ecef;
    width: 30%;
  }

  .geojson-details td {
    padding: 12px 16px;
    border-bottom: 1px solid #e9ecef;
    background-color: white;
    word-break: break-word;
  }

  .geojson-details tr:last-child td {
    border-bottom: none;
  }

  .geojson-details tr:hover td {
    background-color: #f8f9fa;
  }

  .null-value {
    color: #6c757d;
    font-style: italic;
  }

  @media (max-width: 768px) {
    .geojson-details {
      font-size: 0.8rem;
    }
    
    .geojson-details th,
    .geojson-details td {
      padding: 8px 12px;
    }
    
    .details-container {
      padding: 1rem;
    }
  }
</style>
